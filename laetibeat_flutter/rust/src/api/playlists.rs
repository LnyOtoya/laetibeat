use flutter_rust_bridge::frb;
use laetibeat_core::local_playlists as core_playlists;

#[frb(non_opaque)]
pub struct UiLocalPlaylistSummary {
    pub id: i64,
    pub name: String,
    pub item_count: i64,
    pub duration_seconds: i64,
    pub created_at: i64,
    pub updated_at: i64,
    pub cover_source: Option<String>,
    pub cover_source_id: Option<String>,
    pub cover_track_id: Option<String>,
    pub cover_id: Option<String>,
}

#[frb(non_opaque)]
pub struct UiLocalPlaylistItem {
    pub id: i64,
    pub position: i64,
    pub source: String,
    pub source_id: String,
    pub track_id: String,
    pub relative_path: Option<String>,
    pub cover_id: Option<String>,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration_seconds: i64,
}

#[frb(non_opaque)]
pub struct UiLocalPlaylistDetail {
    pub playlist: UiLocalPlaylistSummary,
    pub items: Vec<UiLocalPlaylistItem>,
}

#[frb(non_opaque)]
pub struct UiPlaylistTrackInput {
    pub source: String,
    pub source_id: String,
    pub track_id: String,
    pub relative_path: Option<String>,
    pub cover_id: Option<String>,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration_seconds: i64,
}

/// 初始化本地歌单库（应用启动时调用）
pub fn init_playlist_db(path: String) -> Result<(), String> {
    core_playlists::init_db(&path)
}

pub fn list_local_playlists() -> Result<Vec<UiLocalPlaylistSummary>, String> {
    Ok(core_playlists::list()?.into_iter().map(map_summary).collect())
}

pub fn get_local_playlist(id: i64) -> Result<Option<UiLocalPlaylistDetail>, String> {
    Ok(core_playlists::get(id)?.map(map_detail))
}

pub fn create_local_playlist(name: String) -> Result<UiLocalPlaylistSummary, String> {
    Ok(map_summary(core_playlists::create(&name)?))
}

pub fn rename_local_playlist(id: i64, name: String) -> Result<(), String> {
    core_playlists::rename(id, &name)
}

pub fn delete_local_playlist(id: i64) -> Result<bool, String> {
    core_playlists::delete(id)
}

pub fn add_local_playlist_tracks(
    playlist_id: i64,
    tracks: Vec<UiPlaylistTrackInput>,
) -> Result<usize, String> {
    let tracks = tracks.into_iter().map(map_input).collect::<Vec<_>>();
    core_playlists::add_tracks(playlist_id, &tracks)
}

pub fn remove_local_playlist_item(playlist_id: i64, item_id: i64) -> Result<bool, String> {
    core_playlists::remove_item(playlist_id, item_id)
}

pub fn reorder_local_playlist_items(
    playlist_id: i64,
    item_ids: Vec<i64>,
) -> Result<(), String> {
    core_playlists::reorder(playlist_id, &item_ids)
}

fn map_summary(summary: core_playlists::LocalPlaylistSummary) -> UiLocalPlaylistSummary {
    UiLocalPlaylistSummary {
        id: summary.id,
        name: summary.name,
        item_count: summary.item_count,
        duration_seconds: summary.duration_seconds,
        created_at: summary.created_at,
        updated_at: summary.updated_at,
        cover_source: summary.cover_source,
        cover_source_id: summary.cover_source_id,
        cover_track_id: summary.cover_track_id,
        cover_id: summary.cover_id,
    }
}

fn map_item(item: core_playlists::LocalPlaylistItem) -> UiLocalPlaylistItem {
    UiLocalPlaylistItem {
        id: item.id,
        position: item.position,
        source: item.source,
        source_id: item.source_id,
        track_id: item.track_id,
        relative_path: item.relative_path,
        cover_id: item.cover_id,
        title: item.title,
        artist: item.artist,
        album: item.album,
        duration_seconds: item.duration_seconds,
    }
}

fn map_detail(detail: core_playlists::LocalPlaylistDetail) -> UiLocalPlaylistDetail {
    UiLocalPlaylistDetail {
        playlist: map_summary(detail.playlist),
        items: detail.items.into_iter().map(map_item).collect(),
    }
}

fn map_input(input: UiPlaylistTrackInput) -> core_playlists::PlaylistTrackInput {
    core_playlists::PlaylistTrackInput {
        source: input.source,
        source_id: input.source_id,
        track_id: input.track_id,
        relative_path: input.relative_path,
        cover_id: input.cover_id,
        title: input.title,
        artist: input.artist,
        album: input.album,
        duration_seconds: input.duration_seconds,
    }
}
