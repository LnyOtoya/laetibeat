use flutter_rust_bridge::frb;
use laetibeat_netease::{NeteaseClient, NeteaseLyric, NeteaseStatus, NeteaseStream, NeteaseTrack};

use crate::api::simple::UiTrack;

/// 网易云 Node API 的连接/登录状态。
#[frb(non_opaque)]
pub struct UiNeteaseStatus {
    pub reachable: bool,
    pub logged_in: bool,
    pub code: i32,
    pub nickname: Option<String>,
    pub user_id: Option<u64>,
    pub avatar_url: Option<String>,
}

/// 播放 URL 解析结果。
#[frb(non_opaque)]
pub struct UiNeteaseStream {
    pub url: Option<String>,
    pub bitrate: Option<u64>,
    pub level: Option<String>,
    pub expires_in_seconds: Option<u64>,
    pub is_trial: bool,
    pub trial_end_seconds: Option<u64>,
    pub fee: Option<i64>,
    pub message: Option<String>,
}

/// 网易云歌词。
#[frb(non_opaque)]
pub struct UiNeteaseLyric {
    pub lyric: String,
    pub translated: Option<String>,
    pub word_by_word: Option<String>,
}

fn client(base_url: &str) -> Result<NeteaseClient, String> {
    NeteaseClient::new(base_url).map_err(|error| error.to_string())
}

/// 测试 API 是否可达，以及当前是否已登录。
pub fn netease_status(base_url: String) -> Result<UiNeteaseStatus, String> {
    let status = client(&base_url)?
        .status()
        .map_err(|error| error.to_string())?;
    Ok(map_status(status))
}

/// 搜索单曲。目前只请求单曲类型。
pub fn netease_search(
    base_url: String,
    keywords: String,
    limit: Option<u32>,
    offset: Option<u32>,
) -> Result<Vec<UiTrack>, String> {
    let tracks = client(&base_url)?
        .search(&keywords, limit.unwrap_or(30), offset.unwrap_or(0))
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&base_url, track))
        .collect())
}

/// 按歌曲 id 获取详情。
pub fn netease_song_detail(
    base_url: String,
    song_ids: Vec<String>,
) -> Result<Vec<UiTrack>, String> {
    let tracks = client(&base_url)?
        .song_detail(&song_ids)
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&base_url, track))
        .collect())
}

/// 每日推荐。未登录时返回网易云提供的默认/匿名推荐。
pub fn netease_daily_recommendations(base_url: String) -> Result<Vec<UiTrack>, String> {
    let tracks = client(&base_url)?
        .daily_recommendations()
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&base_url, track))
        .collect())
}

/// 获取播放 URL。level 默认 exhigh。
pub fn netease_song_url(
    base_url: String,
    song_id: String,
    level: Option<String>,
    cookie: Option<String>,
) -> Result<UiNeteaseStream, String> {
    let stream = client(&base_url)?
        .song_url(
            &song_id,
            level.as_deref().unwrap_or("exhigh"),
            cookie.as_deref(),
        )
        .map_err(|error| error.to_string())?;
    Ok(map_stream(stream))
}

/// 获取歌词。优先返回逐字歌词字段，同时保留普通歌词和翻译。
pub fn netease_lyric(base_url: String, song_id: String) -> Result<UiNeteaseLyric, String> {
    let lyric = client(&base_url)?
        .lyric(&song_id)
        .map_err(|error| error.to_string())?;
    Ok(map_lyric(lyric))
}

/// 下载封面字节。cover_id 是网易云返回的封面 URL。
pub fn netease_get_cover(url: String) -> Result<Vec<u8>, String> {
    // 封面 URL 不依赖 API 域名；用一个临时 client 直接请求。
    let client = NeteaseClient::new("http://127.0.0.1").map_err(|error| error.to_string())?;
    client.cover(&url).map_err(|error| error.to_string())
}

fn map_status(status: NeteaseStatus) -> UiNeteaseStatus {
    UiNeteaseStatus {
        reachable: status.reachable,
        logged_in: status.logged_in,
        code: status.code,
        nickname: status.nickname,
        user_id: status.user_id,
        avatar_url: status.avatar_url,
    }
}

fn map_stream(stream: NeteaseStream) -> UiNeteaseStream {
    UiNeteaseStream {
        url: stream.url,
        bitrate: stream.bitrate,
        level: stream.level,
        expires_in_seconds: stream.expires_in_seconds,
        is_trial: stream.is_trial,
        trial_end_seconds: stream.trial_end_seconds,
        fee: stream.fee,
        message: stream.message,
    }
}

fn map_lyric(lyric: NeteaseLyric) -> UiNeteaseLyric {
    UiNeteaseLyric {
        lyric: lyric.lyric,
        translated: lyric.translated,
        word_by_word: lyric.word_by_word,
    }
}

fn map_track(base_url: &str, track: NeteaseTrack) -> UiTrack {
    let seconds = track.duration_ms / 1000;
    let duration = format!("{}:{:02}", seconds / 60, seconds % 60);
    let album_artist = track.artist.clone();
    let extra = serde_json::json!({
        "songId": track.id,
        "albumId": track.album_id,
        "artistId": track.artist_id,
        "durationMs": track.duration_ms,
        "fee": track.fee,
    });

    UiTrack {
        id: format!("netease:{}", track.id),
        relative_path: None,
        title: track.title,
        artist: track.artist,
        album: track.album,
        album_artist,
        album_id: track.album_id.to_string(),
        artist_id: track.artist_id.to_string(),
        track_number: track.track_number,
        disc_number: track.disc_number,
        year: None,
        genre: None,
        duration,
        duration_seconds: seconds,
        path: String::new(),
        source: "netease".to_string(),
        source_id: base_url.trim_end_matches('/').to_string(),
        cover_id: track.cover_url,
        source_extra_json: Some(extra.to_string()),
        bitrate: Some(320),
        sample_rate: None,
        channels: None,
        modified_ms: None,
        file_size: None,
    }
}
