use std::sync::{Mutex, OnceLock, RwLock};

use flutter_rust_bridge::frb;
use laetibeat_core::remote_library as core_lib;
use laetibeat_lx::search as lx_search;
use laetibeat_lx::songlist as lx_songlist;
use laetibeat_lx::{LxError, LxMusicInfo, LxSourceEntry, LxSourceManager, LxSourceStatus};

/// A source capability declared by `inited`.
#[frb(non_opaque)]
pub struct UiLxSourceCapability {
    /// Platform key: kw / kg / tx / wy / mg / local.
    pub source: String,
    pub source_type: String,
    pub actions: Vec<String>,
    pub qualitys: Vec<String>,
}

/// Imported source plus its current runtime state.
#[frb(non_opaque)]
pub struct UiLxSourceEntry {
    pub id: String,
    pub name: String,
    pub description: String,
    pub version: String,
    pub author: String,
    pub homepage: String,
    pub enabled: bool,
    /// Whether this source is preferred over other enabled sources.
    pub active: bool,
    pub priority: i32,
    pub allow_update_alert: bool,
    /// uninitialized / initializing / ready / failed
    pub status: String,
    pub status_message: Option<String>,
    pub capabilities: Vec<UiLxSourceCapability>,
}

#[frb(non_opaque)]
pub struct UiLxMusicInfo {
    pub source: String,
    pub id: String,
    pub name: String,
    pub singer: Vec<String>,
    pub album: String,
    pub album_id: String,
    pub interval: i64,
    pub img: Option<String>,
    /// JSON object with platform-specific fields (kg hash, mg copyrightId,
    /// tx strMediaMid/songId/albumMid, ...).
    pub extra_json: Option<String>,
}

#[frb(non_opaque)]
pub struct UiLxLyric {
    pub lyric: String,
    pub tlyric: Option<String>,
    pub rlyric: Option<String>,
    pub lxlyric: Option<String>,
}

static MANAGER: OnceLock<Mutex<Option<LxSourceManager>>> = OnceLock::new();

/// 无锁读取的源列表快照。
///
/// `list_lx_sources` 只读这个快照，不参与 manager 的互斥锁：后台预热或
/// 解析播放地址可能把 manager 锁占用数秒，UI 的能力查询不应被它堵住。
/// 快照在每次变更后（`with_manager` 结束时）刷新。
static SNAPSHOT: OnceLock<RwLock<Vec<LxSourceEntry>>> = OnceLock::new();

fn manager_slot() -> &'static Mutex<Option<LxSourceManager>> {
    MANAGER.get_or_init(|| Mutex::new(None))
}

fn snapshot_cell() -> &'static RwLock<Vec<LxSourceEntry>> {
    SNAPSHOT.get_or_init(|| RwLock::new(Vec::new()))
}

/// 调用方必须已持有 manager 锁，保证写入顺序与变更顺序一致。
fn publish_snapshot(manager: &LxSourceManager) {
    if let Ok(mut snapshot) = snapshot_cell().write() {
        *snapshot = manager.list();
    }
}

/// Initialize the filesystem-backed source store.
///
/// `root` should be an application-private directory, e.g.
/// `<application support>/laetibeat_lx`.
pub fn init_lx_source_store(root: String) -> Result<(), String> {
    crate::init_logging();
    let manager = LxSourceManager::open(root).map_err(format_error)?;
    // Do not load scripts here. Enabled sources are restored lazily the first
    // time the list/search path asks for capabilities, so QuickJS init or a
    // slow source HTTP request cannot block app bootstrap.
    publish_snapshot(&manager);
    *manager_slot()
        .lock()
        .map_err(|_| "LX manager lock poisoned".to_string())? = Some(manager);
    Ok(())
}

fn with_manager<T>(f: impl FnOnce(&mut LxSourceManager) -> Result<T, String>) -> Result<T, String> {
    let mut guard = manager_slot()
        .lock()
        .map_err(|_| "LX manager lock poisoned".to_string())?;
    let manager = guard
        .as_mut()
        .ok_or_else(|| "LX source store is not initialized".to_string())?;
    let result = f(manager);
    // 失败也要发布：失败会改状态、清声明缓存。
    publish_snapshot(manager);
    result
}

/// Import a source script. Imported sources default to disabled.
pub fn import_lx_source(script: String) -> Result<UiLxSourceEntry, String> {
    with_manager(|manager| {
        let record = manager.import_script(&script).map_err(format_error)?;
        let entry = manager
            .get(&record.id)
            .ok_or_else(|| "imported LX source is missing".to_string())?;
        Ok(map_entry(entry))
    })
}

/// List sources and their capabilities.
///
/// 只读快照，**不获取 manager 锁**：后台预热/解析播放地址期间 UI 依然能
/// 秒回。能力来自本次进程已加载的声明，或上次成功加载后持久化的缓存。
pub fn list_lx_sources() -> Result<Vec<UiLxSourceEntry>, String> {
    let snapshot = snapshot_cell()
        .read()
        .map_err(|_| "LX snapshot lock poisoned".to_string())?;
    Ok(snapshot.iter().cloned().map(map_entry).collect())
}

pub fn load_lx_source(id: String) -> Result<UiLxSourceEntry, String> {
    with_manager(|manager| {
        manager.load_source(&id).map_err(format_error)?;
        manager
            .get(&id)
            .map(map_entry)
            .ok_or_else(|| "LX source not found".to_string())
    })
}

pub fn set_lx_source_enabled(id: String, enabled: bool) -> Result<UiLxSourceEntry, String> {
    with_manager(|manager| {
        manager.set_enabled(&id, enabled).map_err(format_error)?;
        manager
            .get(&id)
            .map(map_entry)
            .ok_or_else(|| "LX source not found".to_string())
    })
}

pub fn set_lx_active_source(id: String, active: bool) -> Result<(), String> {
    with_manager(|manager| manager.set_active(&id, active).map_err(format_error))
}

pub fn set_lx_source_priority(id: String, priority: i32) -> Result<(), String> {
    with_manager(|manager| manager.set_priority(&id, priority).map_err(format_error))
}

pub fn set_lx_allow_update_alert(id: String, allow: bool) -> Result<(), String> {
    with_manager(|manager| {
        manager
            .set_allow_update_alert(&id, allow)
            .map_err(format_error)
    })
}

pub fn remove_lx_source(id: String) -> Result<bool, String> {
    with_manager(|manager| manager.remove(&id).map_err(format_error))
}

/// Resolve a music URL from enabled sources in priority order.
pub fn resolve_lx_music_url(
    source: String,
    music: UiLxMusicInfo,
    quality: String,
) -> Result<String, String> {
    with_manager(|manager| {
        manager
            .resolve_music_url(&source, &music.into(), &quality)
            .map_err(format_error)
    })
}

/// 歌词正缓存长期保留；未找到时缓存 1 天，避免反复请求。
const LX_LYRICS_NEGATIVE_TTL_MS: i64 = 24 * 60 * 60 * 1000;

pub fn resolve_lx_lyric(source: String, music: UiLxMusicInfo) -> Result<Option<UiLxLyric>, String> {
    let cache_key = format!("lx:{source}:{}", music.id);
    if let Ok(Some(entry)) = core_lib::get_lyrics_cache(&cache_key) {
        return Ok(entry.raw_text.as_deref().and_then(parse_cached_lyric));
    }

    let music_info: LxMusicInfo = music.into();
    with_manager(
        |manager| match manager.resolve_lyric(&source, &music_info) {
            Ok(value) => {
                let parsed = parse_lyric(value);
                let now = core_lib::now_ms();
                match &parsed {
                    Some(lyric) => {
                        let raw = serde_json::json!({
                            "lyric": &lyric.lyric,
                            "tlyric": &lyric.tlyric,
                            "rlyric": &lyric.rlyric,
                            "lxlyric": &lyric.lxlyric,
                        })
                        .to_string();
                        let synced = lyric.lxlyric.is_some() || lyric.lyric.contains('[');
                        let _ = core_lib::put_lyrics_cache(
                            &cache_key,
                            "lx",
                            Some(&raw),
                            synced,
                            None,
                            now,
                            None,
                        );
                    }
                    None => {
                        let _ = core_lib::put_lyrics_cache(
                            &cache_key,
                            "lx",
                            None,
                            false,
                            None,
                            now,
                            Some(now + LX_LYRICS_NEGATIVE_TTL_MS),
                        );
                    }
                }
                Ok(parsed)
            }
            Err(error) => Err(format_error(error)),
        },
    )
}

pub fn resolve_lx_pic(source: String, music: UiLxMusicInfo) -> Result<Option<String>, String> {
    with_manager(|manager| {
        let value = manager
            .resolve_pic(&source, &music.into())
            .map_err(format_error)?;
        Ok(value.as_str().map(ToString::to_string))
    })
}

fn map_entry(entry: LxSourceEntry) -> UiLxSourceEntry {
    let (status, status_message) = match entry.status {
        LxSourceStatus::Uninitialized => ("uninitialized".to_string(), None),
        LxSourceStatus::Initializing => ("initializing".to_string(), None),
        LxSourceStatus::Ready => ("ready".to_string(), None),
        LxSourceStatus::Failed(message) => ("failed".to_string(), Some(message)),
    };
    let capabilities = entry
        .declaration
        .map(|declaration| {
            declaration
                .sources
                .into_iter()
                .map(|(source, capability)| UiLxSourceCapability {
                    source,
                    source_type: capability.source_type,
                    actions: capability.actions,
                    qualitys: capability.qualitys,
                })
                .collect()
        })
        .unwrap_or_default();

    UiLxSourceEntry {
        id: entry.record.id,
        name: entry.record.manifest.name,
        description: entry.record.manifest.description,
        version: entry.record.manifest.version,
        author: entry.record.manifest.author,
        homepage: entry.record.manifest.homepage,
        enabled: entry.record.enabled,
        active: entry.record.active,
        priority: entry.record.priority,
        allow_update_alert: entry.record.allow_update_alert,
        status,
        status_message,
        capabilities,
    }
}

fn parse_cached_lyric(raw: &str) -> Option<UiLxLyric> {
    if let Ok(value) = serde_json::from_str::<serde_json::Value>(raw) {
        if let Some(lyric) = parse_lyric(value) {
            return Some(lyric);
        }
    }
    // Older cache entries may be plain LRC text.
    Some(UiLxLyric {
        lyric: raw.to_string(),
        tlyric: None,
        rlyric: None,
        lxlyric: None,
    })
}

fn parse_lyric(value: serde_json::Value) -> Option<UiLxLyric> {
    if let Some(text) = value.as_str() {
        return Some(UiLxLyric {
            lyric: text.to_string(),
            tlyric: None,
            rlyric: None,
            lxlyric: None,
        });
    }
    let object = value.as_object()?;
    let lyric = object.get("lyric")?.as_str()?.to_string();
    let text = |key: &str| {
        object
            .get(key)
            .and_then(|value| value.as_str())
            .filter(|value| !value.is_empty())
            .map(ToString::to_string)
    };
    Some(UiLxLyric {
        lyric,
        tlyric: text("tlyric"),
        rlyric: text("rlyric"),
        lxlyric: text("lxlyric"),
    })
}

impl From<UiLxMusicInfo> for LxMusicInfo {
    fn from(value: UiLxMusicInfo) -> Self {
        Self {
            source: value.source,
            id: value.id,
            name: value.name,
            singer: value.singer.join("、"),
            album: value.album,
            album_id: value.album_id,
            interval: value.interval,
            img: value.img,
            extra: value
                .extra_json
                .as_deref()
                .and_then(|raw| serde_json::from_str(raw).ok())
                .unwrap_or_default(),
        }
    }
}

fn format_error(error: LxError) -> String {
    error.to_string()
}

#[frb(non_opaque)]
pub struct UiLxSearchTrack {
    pub source: String,
    pub id: String,
    pub name: String,
    pub singer: Vec<String>,
    pub album: String,
    pub album_id: String,
    pub interval: i64,
    pub img: Option<String>,
    pub extra_json: String,
}

#[frb(non_opaque)]
pub struct UiLxSearchPage {
    pub tracks: Vec<UiLxSearchTrack>,
    pub total: u64,
    pub page: u32,
    pub limit: u32,
    pub has_more: bool,
}

#[frb(non_opaque)]
pub struct UiLxPlaylistSummary {
    pub source: String,
    pub id: String,
    pub name: String,
    pub author: String,
    pub cover_url: Option<String>,
    pub play_count: String,
    pub total: u64,
    pub description: String,
}

#[frb(non_opaque)]
pub struct UiLxPlaylistDetail {
    pub info: UiLxPlaylistSummary,
    pub tracks: Vec<UiLxSearchTrack>,
    pub page: u32,
    pub limit: u32,
    pub total: u64,
    pub has_more: bool,
}

pub fn supported_lx_search_platforms() -> Vec<String> {
    lx_search::SUPPORTED_PLATFORMS
        .iter()
        .map(|platform| (*platform).to_string())
        .collect()
}

/// Search an independent LX platform. No local library/Subsonic is required.
pub fn search_lx_music(
    platform: String,
    keyword: String,
    page: u32,
    limit: u32,
) -> Result<UiLxSearchPage, String> {
    let result = lx_search::search(&platform, &keyword, page, limit).map_err(format_error)?;
    Ok(UiLxSearchPage {
        tracks: result
            .tracks
            .into_iter()
            .map(|track| UiLxSearchTrack {
                source: track.source,
                id: track.id,
                name: track.name,
                singer: track.singer,
                album: track.album,
                album_id: track.album_id,
                interval: track.interval,
                img: track.img,
                extra_json: serde_json::to_string(&track.extra).unwrap_or_default(),
            })
            .collect(),
        total: result.total,
        page: result.page,
        limit: result.limit,
        has_more: result.has_more,
    })
}

pub fn search_lx_playlists(
    platform: String,
    keyword: String,
    page: u32,
    limit: u32,
) -> Result<Vec<UiLxPlaylistSummary>, String> {
    lx_songlist::search_playlists(&platform, &keyword, page, limit)
        .map(|items| items.into_iter().map(map_lx_playlist).collect())
        .map_err(format_error)
}

pub fn get_lx_playlist(
    platform: String,
    playlist_id: String,
    page: u32,
    limit: u32,
) -> Result<UiLxPlaylistDetail, String> {
    lx_songlist::get_playlist_detail(&platform, &playlist_id, page, limit)
        .map(map_lx_playlist_detail)
        .map_err(format_error)
}

pub fn get_lx_playlist_all(
    platform: String,
    playlist_id: String,
) -> Result<UiLxPlaylistDetail, String> {
    lx_songlist::get_playlist_all(&platform, &playlist_id)
        .map(map_lx_playlist_detail)
        .map_err(format_error)
}

fn map_lx_playlist(item: lx_songlist::LxPlaylistSummary) -> UiLxPlaylistSummary {
    UiLxPlaylistSummary {
        source: item.source,
        id: item.id,
        name: item.name,
        author: item.author,
        cover_url: item.cover_url,
        play_count: item.play_count,
        total: item.total,
        description: item.description,
    }
}

fn map_lx_playlist_detail(detail: lx_songlist::LxPlaylistDetail) -> UiLxPlaylistDetail {
    UiLxPlaylistDetail {
        info: map_lx_playlist(detail.info),
        tracks: detail.tracks.into_iter().map(map_lx_search_track).collect(),
        page: detail.page,
        limit: detail.limit,
        total: detail.total,
        has_more: detail.has_more,
    }
}

fn map_lx_search_track(track: lx_search::LxSearchTrack) -> UiLxSearchTrack {
    UiLxSearchTrack {
        source: track.source,
        id: track.id,
        name: track.name,
        singer: track.singer,
        album: track.album,
        album_id: track.album_id,
        interval: track.interval,
        img: track.img,
        extra_json: serde_json::to_string(&track.extra).unwrap_or_default(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::mpsc;
    use std::time::{Duration, SystemTime, UNIX_EPOCH};

    fn temp_root() -> String {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir()
            .join(format!("laetibeat_lx_api_{}_{}", std::process::id(), nonce))
            .to_string_lossy()
            .into_owned()
    }

    /// `list_lx_sources` 必须只读快照，不能等 manager 锁。
    ///
    /// 后台预热或解析播放地址会持有 manager 锁数秒；如果 list 也去抢锁，
    /// 搜索页/平台栏就会被堵住。这里用一个线程在持锁期间调用 list，
    /// 超时即视为回归（而不是让测试挂死）。
    #[test]
    fn list_lx_sources_does_not_wait_for_manager_lock() {
        let root = temp_root();
        init_lx_source_store(root.clone()).unwrap();
        assert!(list_lx_sources().unwrap().is_empty());

        let guard = manager_slot().lock().unwrap();
        let (sender, receiver) = mpsc::channel();
        std::thread::spawn(move || {
            let _ = sender.send(list_lx_sources().is_ok());
        });
        let received = receiver.recv_timeout(Duration::from_secs(2));
        drop(guard);

        assert_eq!(
            received,
            Ok(true),
            "list_lx_sources blocked on the manager lock"
        );

        let _ = std::fs::remove_dir_all(root);
    }
}
