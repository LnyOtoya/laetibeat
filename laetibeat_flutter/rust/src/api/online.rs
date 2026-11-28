use flutter_rust_bridge::frb;
use laetibeat_online::{
    OnlineAlbum, OnlineClient, OnlineHomeBlock, OnlineHomeFeed, OnlineHomeItem,
    OnlinePlatformStatus, OnlinePlaylist, OnlineQrResult, OnlineQrSession, OnlineQuality,
    OnlineTopList, OnlineTrack,
};

use crate::api::simple::UiTrack;

#[frb(non_opaque)]
pub struct UiOnlineStatus {
    pub base_url: String,
}

#[frb(non_opaque)]
pub struct UiOnlinePlaylist {
    pub source: String,
    pub id: String,
    pub name: String,
    pub cover_url: Option<String>,
    pub track_count: u32,
    pub play_count: u64,
    pub creator: Option<String>,
    pub description: Option<String>,
    pub link: Option<String>,
}

#[frb(non_opaque)]
pub struct UiOnlineAlbum {
    pub source: String,
    pub id: String,
    pub name: String,
    pub cover_url: Option<String>,
    pub track_count: u32,
    pub artist: Option<String>,
}

#[frb(non_opaque)]
pub struct UiOnlineTopList {
    pub source: String,
    pub id: String,
    pub name: String,
    pub cover_url: Option<String>,
    pub description: Option<String>,
    pub update_frequency: Option<String>,
    pub track_count: u32,
    pub play_count: u64,
}

#[frb(non_opaque)]
pub struct UiOnlineResolvedAudio {
    pub url: String,
    pub quality: String,
    pub ext: String,
}

#[frb(non_opaque)]
pub struct UiOnlineLyric {
    pub lyric: String,
}

#[frb(non_opaque)]
pub struct UiOnlineQuality {
    pub value: String,
    pub label: String,
    pub format: String,
    pub bitrate: Option<u32>,
    pub vip: bool,
}

#[frb(non_opaque)]
pub struct UiOnlinePlatformStatus {
    pub source: String,
    pub has_cookie: bool,
}

#[frb(non_opaque)]
pub struct UiOnlineQrSession {
    pub source: String,
    pub key: String,
    pub url: String,
    pub image_url: String,
    pub expires_at: Option<i64>,
}

#[frb(non_opaque)]
pub struct UiOnlineQrResult {
    pub source: String,
    pub status: String,
    pub message: String,
    pub cookie_saved: bool,
}

#[frb(non_opaque)]
pub struct UiOnlineHomeFeed {
    pub cursor: Option<String>,
    pub blocks: Vec<UiOnlineHomeBlock>,
}

#[frb(non_opaque)]
pub struct UiOnlineHomeBlock {
    pub code: String,
    pub show_type: String,
    pub title: String,
    pub action: String,
    pub items: Vec<UiOnlineHomeItem>,
}

#[frb(non_opaque)]
pub struct UiOnlineHomeItem {
    pub kind: String,
    pub id: String,
    pub title: String,
    pub subtitle: String,
    pub cover_url: Option<String>,
    pub section: String,
    pub artists: String,
    pub album: String,
    pub album_id: String,
    pub duration_seconds: u64,
    pub play_count: u64,
    pub track_count: u32,
    pub action: String,
    pub source: String,
}

fn client(base_url: &str, token: Option<String>) -> Result<OnlineClient, String> {
    OnlineClient::new(base_url, token.as_deref()).map_err(|error| error.to_string())
}

pub fn online_health(base_url: String, token: Option<String>) -> Result<UiOnlineStatus, String> {
    let client = client(&base_url, token)?;
    client.health().map_err(|error| error.to_string())?;
    Ok(UiOnlineStatus {
        base_url: client.base_url().to_string(),
    })
}

pub fn online_radar_playlists(
    base_url: String,
    token: Option<String>,
    source: String,
    limit: Option<u32>,
) -> Result<Vec<UiOnlinePlaylist>, String> {
    let client = client(&base_url, token)?;
    let playlists = client
        .radar_playlists(&source, limit.unwrap_or(50))
        .map_err(|error| error.to_string())?;
    Ok(playlists.into_iter().map(map_playlist).collect())
}

pub fn online_daily_songs(
    base_url: String,
    token: Option<String>,
    source: String,
    refresh: Option<bool>,
) -> Result<Vec<UiTrack>, String> {
    let client = client(&base_url, token)?;
    let tracks = client
        .daily_songs(&source, refresh.unwrap_or(false))
        .map_err(|error| error.to_string())?;
    Ok(map_tracks(&client, tracks))
}

pub fn online_personal_fm(
    base_url: String,
    token: Option<String>,
    source: String,
    mode: Option<String>,
    submode: Option<String>,
    limit: Option<u32>,
) -> Result<Vec<UiTrack>, String> {
    let client = client(&base_url, token)?;
    let tracks = client
        .personal_fm(
            &source,
            mode.as_deref().filter(|value| !value.is_empty()),
            submode.as_deref().filter(|value| !value.is_empty()),
            limit.unwrap_or(10),
        )
        .map_err(|error| error.to_string())?;
    Ok(map_tracks(&client, tracks))
}

pub fn online_similar_songs(
    base_url: String,
    token: Option<String>,
    source: String,
    track_id: String,
    limit: Option<u32>,
) -> Result<Vec<UiTrack>, String> {
    let client = client(&base_url, token)?;
    let tracks = client
        .similar_songs(&source, &track_id, limit.unwrap_or(30))
        .map_err(|error| error.to_string())?;
    Ok(map_tracks(&client, tracks))
}

pub fn online_intelligence(
    base_url: String,
    token: Option<String>,
    source: String,
    track_id: String,
    playlist_id: Option<String>,
    count: Option<u32>,
) -> Result<Vec<UiTrack>, String> {
    let client = client(&base_url, token)?;
    let tracks = client
        .intelligence(
            &source,
            &track_id,
            playlist_id.as_deref().filter(|value| !value.is_empty()),
            count.unwrap_or(10),
        )
        .map_err(|error| error.to_string())?;
    Ok(map_tracks(&client, tracks))
}

pub fn online_home_feed(
    base_url: String,
    token: Option<String>,
    source: String,
    refresh: Option<bool>,
    cursor: Option<String>,
) -> Result<UiOnlineHomeFeed, String> {
    let client = client(&base_url, token)?;
    let feed = client
        .home_feed(&source, refresh.unwrap_or(false), cursor.as_deref())
        .map_err(|error| error.to_string())?;
    Ok(map_home_feed(feed))
}

pub fn online_search_songs(
    base_url: String,
    token: Option<String>,
    source: String,
    query: String,
    limit: Option<u32>,
    offset: Option<u32>,
) -> Result<Vec<UiTrack>, String> {
    let client = client(&base_url, token)?;
    let tracks = client
        .search_songs(&source, &query, limit.unwrap_or(10), offset.unwrap_or(0))
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&client, track))
        .collect())
}

pub fn online_search_playlists(
    base_url: String,
    token: Option<String>,
    source: String,
    query: String,
    limit: Option<u32>,
    offset: Option<u32>,
) -> Result<Vec<UiOnlinePlaylist>, String> {
    let client = client(&base_url, token)?;
    let playlists = client
        .search_playlists(&source, &query, limit.unwrap_or(10), offset.unwrap_or(0))
        .map_err(|error| error.to_string())?;
    Ok(playlists.into_iter().map(map_playlist).collect())
}

pub fn online_search_albums(
    base_url: String,
    token: Option<String>,
    source: String,
    query: String,
    limit: Option<u32>,
    offset: Option<u32>,
) -> Result<Vec<UiOnlineAlbum>, String> {
    let client = client(&base_url, token)?;
    let albums = client
        .search_albums(&source, &query, limit.unwrap_or(10), offset.unwrap_or(0))
        .map_err(|error| error.to_string())?;
    Ok(albums.into_iter().map(map_album).collect())
}

pub fn online_playlist_tracks(
    base_url: String,
    token: Option<String>,
    source: String,
    playlist_id: String,
) -> Result<Vec<UiTrack>, String> {
    let client = client(&base_url, token)?;
    let tracks = client
        .playlist_tracks(&source, &playlist_id)
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&client, track))
        .collect())
}

pub fn online_album_tracks(
    base_url: String,
    token: Option<String>,
    source: String,
    album_id: String,
) -> Result<Vec<UiTrack>, String> {
    let client = client(&base_url, token)?;
    let tracks = client
        .album_tracks(&source, &album_id)
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&client, track))
        .collect())
}

pub fn online_user_playlists(
    base_url: String,
    token: Option<String>,
    source: String,
    page: Option<u32>,
    limit: Option<u32>,
) -> Result<Vec<UiOnlinePlaylist>, String> {
    let client = client(&base_url, token)?;
    let playlists = client
        .user_playlists(&source, page.unwrap_or(1), limit.unwrap_or(30))
        .map_err(|error| error.to_string())?;
    Ok(playlists.into_iter().map(map_playlist).collect())
}

pub fn online_recommend_playlists(
    base_url: String,
    token: Option<String>,
    source: String,
) -> Result<Vec<UiOnlinePlaylist>, String> {
    let client = client(&base_url, token)?;
    let playlists = client
        .recommend_playlists(&source)
        .map_err(|error| error.to_string())?;
    Ok(playlists.into_iter().map(map_playlist).collect())
}

pub fn online_top_lists(
    base_url: String,
    token: Option<String>,
    source: String,
) -> Result<Vec<UiOnlineTopList>, String> {
    let client = client(&base_url, token)?;
    let top_lists = client
        .top_lists(&source)
        .map_err(|error| error.to_string())?;
    Ok(top_lists.into_iter().map(map_top_list).collect())
}

pub fn online_top_list_songs(
    base_url: String,
    token: Option<String>,
    source: String,
    top_list_id: String,
) -> Result<Vec<UiTrack>, String> {
    let client = client(&base_url, token)?;
    let tracks = client
        .top_list_songs(&source, &top_list_id)
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&client, track))
        .collect())
}

pub fn online_hot_songs(
    base_url: String,
    token: Option<String>,
    source: String,
    limit: Option<u32>,
) -> Result<Vec<UiTrack>, String> {
    let client = client(&base_url, token)?;
    let tracks = client
        .hot_songs(&source, limit.unwrap_or(20))
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&client, track))
        .collect())
}

pub fn online_resolve_audio(
    base_url: String,
    token: Option<String>,
    source: String,
    track_id: String,
    quality: String,
) -> Result<UiOnlineResolvedAudio, String> {
    let client = client(&base_url, token)?;
    let resolved = client
        .resolve_audio(&source, &track_id, &quality)
        .map_err(|error| error.to_string())?;
    Ok(UiOnlineResolvedAudio {
        url: resolved.url,
        quality: resolved.quality,
        ext: resolved.ext,
    })
}

pub fn online_lyric(
    base_url: String,
    token: Option<String>,
    source: String,
    track_id: String,
) -> Result<UiOnlineLyric, String> {
    let client = client(&base_url, token)?;
    let lyric = client
        .lyric(&source, &track_id)
        .map_err(|error| error.to_string())?;
    Ok(UiOnlineLyric { lyric: lyric.lyric })
}

pub fn online_qualities(
    base_url: String,
    token: Option<String>,
    source: String,
) -> Result<Vec<UiOnlineQuality>, String> {
    let client = client(&base_url, token)?;
    let qualities = client
        .qualities(&source)
        .map_err(|error| error.to_string())?;
    Ok(qualities.into_iter().map(map_quality).collect())
}

pub fn online_platform_statuses(
    base_url: String,
    token: Option<String>,
) -> Result<Vec<UiOnlinePlatformStatus>, String> {
    let client = client(&base_url, token)?;
    let statuses = client
        .platform_statuses()
        .map_err(|error| error.to_string())?;
    Ok(statuses.into_iter().map(map_platform_status).collect())
}

pub fn online_logout(
    base_url: String,
    token: Option<String>,
    source: String,
) -> Result<(), String> {
    let client = client(&base_url, token)?;
    client.logout(&source).map_err(|error| error.to_string())
}

pub fn online_qr_create(
    base_url: String,
    token: Option<String>,
    source: String,
) -> Result<UiOnlineQrSession, String> {
    let client = client(&base_url, token)?;
    let session = client
        .qr_login_create(&source)
        .map_err(|error| error.to_string())?;
    Ok(map_qr_session(session))
}

pub fn online_qr_check(
    base_url: String,
    token: Option<String>,
    source: String,
    key: String,
) -> Result<UiOnlineQrResult, String> {
    let client = client(&base_url, token)?;
    let result = client
        .qr_login_check(&source, &key)
        .map_err(|error| error.to_string())?;
    Ok(map_qr_result(result))
}

fn map_tracks(client: &OnlineClient, tracks: Vec<OnlineTrack>) -> Vec<UiTrack> {
    tracks
        .into_iter()
        .map(|track| map_track(client, track))
        .collect()
}

fn map_track(client: &OnlineClient, track: OnlineTrack) -> UiTrack {
    let seconds = track.duration_seconds;
    let duration = format!("{}:{:02}", seconds / 60, seconds % 60);
    UiTrack {
        id: track.ui_id(),
        relative_path: None,
        title: track.title,
        artist: track.artist.clone(),
        album: track.album,
        album_artist: track.artist,
        album_id: track.album_id,
        artist_id: String::new(),
        track_number: None,
        disc_number: None,
        year: None,
        genre: None,
        duration,
        duration_seconds: seconds,
        path: String::new(),
        source: track.source,
        source_id: client.instance_id().to_string(),
        cover_id: track.cover_url,
        source_extra_json: track.extra_json,
        bitrate: track.bitrate,
        sample_rate: None,
        channels: None,
        modified_ms: None,
        file_size: track.file_size,
    }
}

fn map_home_feed(feed: OnlineHomeFeed) -> UiOnlineHomeFeed {
    UiOnlineHomeFeed {
        cursor: feed.cursor,
        blocks: feed.blocks.into_iter().map(map_home_block).collect(),
    }
}

fn map_home_block(block: OnlineHomeBlock) -> UiOnlineHomeBlock {
    UiOnlineHomeBlock {
        code: block.code,
        show_type: block.show_type,
        title: block.title,
        action: block.action,
        items: block.items.into_iter().map(map_home_item).collect(),
    }
}

fn map_home_item(item: OnlineHomeItem) -> UiOnlineHomeItem {
    UiOnlineHomeItem {
        kind: item.kind,
        id: item.id,
        title: item.title,
        subtitle: item.subtitle,
        cover_url: item.cover_url,
        section: item.section,
        artists: item.artists,
        album: item.album,
        album_id: item.album_id,
        duration_seconds: item.duration_seconds,
        play_count: item.play_count,
        track_count: item.track_count,
        action: item.action,
        source: item.source,
    }
}

fn map_playlist(playlist: OnlinePlaylist) -> UiOnlinePlaylist {
    UiOnlinePlaylist {
        source: playlist.source,
        id: playlist.id,
        name: playlist.name,
        cover_url: playlist.cover_url,
        track_count: playlist.track_count,
        play_count: playlist.play_count,
        creator: playlist.creator,
        description: playlist.description,
        link: playlist.link,
    }
}

fn map_album(album: OnlineAlbum) -> UiOnlineAlbum {
    UiOnlineAlbum {
        source: album.source,
        id: album.id,
        name: album.name,
        cover_url: album.cover_url,
        track_count: album.track_count,
        artist: album.artist,
    }
}

fn map_top_list(top_list: OnlineTopList) -> UiOnlineTopList {
    UiOnlineTopList {
        source: top_list.source,
        id: top_list.id,
        name: top_list.name,
        cover_url: top_list.cover_url,
        description: top_list.description,
        update_frequency: top_list.update_frequency,
        track_count: top_list.track_count,
        play_count: top_list.play_count,
    }
}

fn map_quality(quality: OnlineQuality) -> UiOnlineQuality {
    UiOnlineQuality {
        value: quality.value,
        label: quality.label,
        format: quality.format,
        bitrate: quality.bitrate,
        vip: quality.vip,
    }
}

fn map_platform_status(status: OnlinePlatformStatus) -> UiOnlinePlatformStatus {
    UiOnlinePlatformStatus {
        source: status.source,
        has_cookie: status.has_cookie,
    }
}

fn map_qr_session(session: OnlineQrSession) -> UiOnlineQrSession {
    UiOnlineQrSession {
        source: session.source,
        key: session.key,
        url: session.url,
        image_url: session.image_url,
        expires_at: session.expires_at,
    }
}

fn map_qr_result(result: OnlineQrResult) -> UiOnlineQrResult {
    UiOnlineQrResult {
        source: result.source,
        status: result.status,
        message: result.message,
        cookie_saved: result.cookie_saved,
    }
}
