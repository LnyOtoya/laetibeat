use std::sync::{Mutex, OnceLock};

use flutter_rust_bridge::frb;
use laetibeat_lx::search as lx_search;
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
}

#[frb(non_opaque)]
pub struct UiLxLyric {
    pub lyric: String,
    pub tlyric: Option<String>,
    pub rlyric: Option<String>,
    pub lxlyric: Option<String>,
}

static MANAGER: OnceLock<Mutex<Option<LxSourceManager>>> = OnceLock::new();

fn manager_slot() -> &'static Mutex<Option<LxSourceManager>> {
    MANAGER.get_or_init(|| Mutex::new(None))
}

/// Initialize the filesystem-backed source store.
///
/// `root` should be an application-private directory, e.g.
/// `<application support>/laetibeat_lx`.
pub fn init_lx_source_store(root: String) -> Result<(), String> {
    let mut manager = LxSourceManager::open(root).map_err(format_error)?;
    // Restore previously enabled sources so independent LX search works after
    // a cold start even when no local/Subsonic source is configured.
    manager.load_enabled_sources();
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
    f(manager)
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

pub fn list_lx_sources() -> Result<Vec<UiLxSourceEntry>, String> {
    with_manager(|manager| Ok(manager.list().into_iter().map(map_entry).collect()))
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

pub fn resolve_lx_lyric(source: String, music: UiLxMusicInfo) -> Result<Option<UiLxLyric>, String> {
    with_manager(|manager| {
        let value = manager
            .resolve_lyric(&source, &music.into())
            .map_err(format_error)?;
        Ok(parse_lyric(value))
    })
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
        priority: entry.record.priority,
        allow_update_alert: entry.record.allow_update_alert,
        status,
        status_message,
        capabilities,
    }
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
            extra: Default::default(),
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
}

#[frb(non_opaque)]
pub struct UiLxSearchPage {
    pub tracks: Vec<UiLxSearchTrack>,
    pub total: u64,
    pub page: u32,
    pub limit: u32,
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
            })
            .collect(),
        total: result.total,
        page: result.page,
        limit: result.limit,
        has_more: result.has_more,
    })
}
