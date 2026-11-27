use std::collections::BTreeMap;

use serde::Deserialize;

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ApiSong {
    #[serde(default)]
    pub id: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub artist: String,
    #[serde(default)]
    pub album: String,
    #[serde(default)]
    pub album_id: String,
    #[serde(default)]
    pub duration: i64,
    #[serde(default)]
    pub size: i64,
    #[serde(default)]
    pub bitrate: i64,
    #[serde(default)]
    pub source: String,
    #[serde(default)]
    pub cover: String,
    #[serde(default)]
    pub link: String,
    #[serde(default)]
    pub extra: BTreeMap<String, String>,
    #[serde(default)]
    pub is_vip: bool,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ApiPlaylist {
    #[serde(default)]
    pub id: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub cover: String,
    #[serde(default)]
    pub track_count: i64,
    #[serde(default)]
    pub play_count: i64,
    #[serde(default)]
    pub creator: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub source: String,
    #[serde(default)]
    pub link: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ApiTopList {
    #[serde(default)]
    pub id: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub cover: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub update_frequency: String,
    #[serde(default)]
    pub track_count: i64,
    #[serde(default)]
    pub play_count: i64,
    #[serde(default)]
    pub source: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ApiSearchData {
    #[serde(default)]
    pub songs: Option<Vec<ApiSong>>,
    #[serde(default)]
    pub playlists: Option<Vec<ApiPlaylist>>,
    #[serde(default)]
    pub albums: Option<Vec<ApiPlaylist>>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ApiUserPlaylistsData {
    #[serde(default)]
    pub playlists: Option<Vec<ApiPlaylist>>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ApiTopListsData {
    #[serde(default)]
    pub toplists: Option<Vec<ApiTopList>>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ApiHotSongsData {
    #[serde(default)]
    pub songs: Option<Vec<ApiSong>>,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ApiUrlData {
    #[serde(default)]
    pub url: String,
    #[serde(default)]
    pub quality: String,
    #[serde(default)]
    pub ext: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ApiLyricData {
    #[serde(default)]
    pub lyric: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ApiQuality {
    #[serde(default)]
    pub value: String,
    #[serde(default)]
    pub label: String,
    #[serde(default)]
    pub format: String,
    #[serde(default)]
    pub bitrate: Option<i64>,
    #[serde(default)]
    pub vip: bool,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ApiQualitiesData {
    #[serde(default)]
    pub qualities: Vec<ApiQuality>,
}

#[derive(Debug, Clone)]
pub struct OnlineTrack {
    pub source: String,
    pub platform_id: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub album_id: String,
    pub cover_url: Option<String>,
    pub link: Option<String>,
    pub duration_seconds: u64,
    pub bitrate: Option<u32>,
    pub file_size: Option<u64>,
    pub is_vip: bool,
    pub extra_json: Option<String>,
}

impl OnlineTrack {
    pub fn ui_id(&self) -> String {
        format!("{}:{}", self.source, self.platform_id)
    }
}

#[derive(Debug, Clone)]
pub struct OnlinePlaylist {
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

#[derive(Debug, Clone)]
pub struct OnlineAlbum {
    pub source: String,
    pub id: String,
    pub name: String,
    pub cover_url: Option<String>,
    pub track_count: u32,
    pub artist: Option<String>,
}

#[derive(Debug, Clone)]
pub struct OnlineTopList {
    pub source: String,
    pub id: String,
    pub name: String,
    pub cover_url: Option<String>,
    pub description: Option<String>,
    pub update_frequency: Option<String>,
    pub track_count: u32,
    pub play_count: u64,
}

#[derive(Debug, Clone)]
pub struct OnlineResolvedAudio {
    pub url: String,
    pub quality: String,
    pub ext: String,
}

#[derive(Debug, Clone)]
pub struct OnlineLyric {
    pub lyric: String,
}

#[derive(Debug, Clone)]
pub struct OnlineQuality {
    pub value: String,
    pub label: String,
    pub format: String,
    pub bitrate: Option<u32>,
    pub vip: bool,
}

#[derive(Debug, Clone, Default)]
pub struct OnlineSearchResult {
    pub songs: Vec<OnlineTrack>,
    pub playlists: Vec<OnlinePlaylist>,
    pub albums: Vec<OnlineAlbum>,
}

pub(crate) fn map_song(source: &str, song: ApiSong) -> OnlineTrack {
    let resolved_source = if song.source.trim().is_empty() {
        source.to_string()
    } else {
        song.source.clone()
    };
    let mut extra = song.extra;
    extra
        .entry("platformId".to_string())
        .or_insert_with(|| song.id.clone());
    extra
        .entry("source".to_string())
        .or_insert_with(|| resolved_source.clone());
    let extra_json = if extra.is_empty() {
        None
    } else {
        serde_json::to_string(&extra).ok()
    };

    OnlineTrack {
        source: resolved_source,
        platform_id: song.id,
        title: song.name,
        artist: song.artist,
        album: song.album,
        album_id: song.album_id,
        cover_url: https_url(song.cover),
        link: non_empty(song.link),
        duration_seconds: song.duration.max(0) as u64,
        bitrate: (song.bitrate > 0).then_some(song.bitrate as u32),
        file_size: (song.size > 0).then_some(song.size as u64),
        is_vip: song.is_vip,
        extra_json,
    }
}

pub(crate) fn map_playlist(source: &str, playlist: ApiPlaylist) -> OnlinePlaylist {
    OnlinePlaylist {
        source: if playlist.source.trim().is_empty() {
            source.to_string()
        } else {
            playlist.source
        },
        id: playlist.id,
        name: playlist.name,
        cover_url: https_url(playlist.cover),
        track_count: playlist.track_count.max(0) as u32,
        play_count: playlist.play_count.max(0) as u64,
        creator: non_empty(playlist.creator),
        description: non_empty(playlist.description),
        link: non_empty(playlist.link),
    }
}

pub(crate) fn map_album(source: &str, playlist: ApiPlaylist) -> OnlineAlbum {
    OnlineAlbum {
        source: if playlist.source.trim().is_empty() {
            source.to_string()
        } else {
            playlist.source
        },
        id: playlist.id,
        name: playlist.name,
        cover_url: https_url(playlist.cover),
        track_count: playlist.track_count.max(0) as u32,
        artist: non_empty(playlist.creator),
    }
}

pub(crate) fn map_top_list(source: &str, top_list: ApiTopList) -> OnlineTopList {
    OnlineTopList {
        source: if top_list.source.trim().is_empty() {
            source.to_string()
        } else {
            top_list.source
        },
        id: top_list.id,
        name: top_list.name,
        cover_url: https_url(top_list.cover),
        description: non_empty(top_list.description),
        update_frequency: non_empty(top_list.update_frequency),
        track_count: top_list.track_count.max(0) as u32,
        play_count: top_list.play_count.max(0) as u64,
    }
}

pub(crate) fn map_quality(quality: ApiQuality) -> OnlineQuality {
    OnlineQuality {
        value: quality.value,
        label: quality.label,
        format: quality.format,
        bitrate: quality.bitrate.map(|value| value.max(0) as u32),
        vip: quality.vip,
    }
}

fn non_empty(value: String) -> Option<String> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}

/// 封面只允许 HTTPS；NetEase 搜索有时返回 http:// 链接，这里统一升级。
fn https_url(value: String) -> Option<String> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return None;
    }
    if let Some(rest) = trimmed.strip_prefix("http://") {
        return Some(format!("https://{rest}"));
    }
    if trimmed.starts_with("https://") {
        return Some(trimmed.to_string());
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn maps_nulls_and_extra() {
        let data: ApiSearchData = serde_json::from_str(
            r#"{
                "songs": [{
                    "id": "123",
                    "name": "晴天",
                    "artist": "周杰伦",
                    "album": "叶惠美",
                    "album_id": "456",
                    "duration": 269,
                    "size": 4317292,
                    "bitrate": 128,
                    "source": "netease",
                    "cover": "https://example.com/a.jpg",
                    "link": "https://music.163.com/#/song?id=123",
                    "extra": {"song_id": "123"},
                    "is_vip": false
                }],
                "playlists": null,
                "albums": null
            }"#,
        )
        .unwrap();

        assert!(data.playlists.is_none());
        let track = map_song("netease", data.songs.unwrap().remove(0));
        assert_eq!(track.ui_id(), "netease:123");
        assert_eq!(track.duration_seconds, 269);
        assert_eq!(track.bitrate, Some(128));
        assert!(track.cover_url.is_some());
        let extra: serde_json::Value =
            serde_json::from_str(track.extra_json.as_deref().unwrap()).unwrap();
        assert_eq!(extra["song_id"], "123");
        assert_eq!(extra["platformId"], "123");
    }

    #[test]
    fn upgrades_http_cover_to_https() {
        let track = map_song(
            "netease",
            ApiSong {
                id: "1".to_string(),
                name: "歌".to_string(),
                cover: "http://p2.music.126.net/a.jpg".to_string(),
                ..Default::default()
            },
        );
        assert_eq!(
            track.cover_url.as_deref(),
            Some("https://p2.music.126.net/a.jpg")
        );
    }

    #[test]
    fn maps_album_creator_to_artist() {
        let album = map_album(
            "qq",
            ApiPlaylist {
                id: "1".to_string(),
                name: "专辑".to_string(),
                creator: "歌手".to_string(),
                track_count: 10,
                ..Default::default()
            },
        );
        assert_eq!(album.artist.as_deref(), Some("歌手"));
        assert_eq!(album.track_count, 10);
    }
}
