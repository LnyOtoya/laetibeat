use serde::Deserialize;

use crate::error::{OnlineError, Result};
use crate::http::HttpClient;
use crate::model::{
    map_album, map_platform_status, map_playlist, map_qr_result, map_qr_session, map_quality,
    map_song, map_top_list, ApiHomeFeed, ApiHotSongsData, ApiLyricData, ApiPlatformStatus,
    ApiPlaylist, ApiQrResult, ApiQrSession, ApiQualitiesData, ApiSearchData, ApiSong,
    ApiTopListsData, ApiUrlData, ApiUserPlaylistsData, OnlineAlbum, OnlineHomeFeed, OnlineLyric,
    OnlinePlatformStatus, OnlinePlaylist, OnlineQrResult, OnlineQrSession, OnlineQuality,
    OnlineResolvedAudio, OnlineSearchResult, OnlineTopList, OnlineTrack,
};

#[derive(Debug, Deserialize)]
struct HealthResponse {
    #[serde(default)]
    status: String,
}

pub struct OnlineClient {
    http: HttpClient,
    instance_id: String,
}

impl OnlineClient {
    pub fn new(base_url: &str, token: Option<&str>) -> Result<Self> {
        let http = HttpClient::new(base_url, token)?;
        let instance_id = format!("musicapi:{}", http.base_url());
        Ok(Self { http, instance_id })
    }

    /// 规范化后的服务地址。
    pub fn base_url(&self) -> &str {
        self.http.base_url()
    }

    /// 用于 `UiTrack.sourceId` 的服务实例标识。
    pub fn instance_id(&self) -> &str {
        &self.instance_id
    }

    pub fn health(&self) -> Result<()> {
        let response: HealthResponse = self.http.get_json("/laetibeat/health", &[])?;
        if response.status == "ok" {
            Ok(())
        } else {
            Err(OnlineError::Api("健康检查未返回 ok".to_string()))
        }
    }

    pub fn daily_songs(&self, source: &str, refresh: bool) -> Result<Vec<OnlineTrack>> {
        let data: ApiSearchData = self.http.get_data(
            "/api/v1/recommend/daily/songs",
            &[
                ("source", source.to_string()),
                (
                    "refresh",
                    if refresh { "true" } else { "false" }.to_string(),
                ),
            ],
        )?;
        Ok(data
            .songs
            .unwrap_or_default()
            .into_iter()
            .map(|song| map_song(source, song))
            .collect())
    }

    pub fn personal_fm(
        &self,
        source: &str,
        mode: Option<&str>,
        submode: Option<&str>,
        limit: u32,
    ) -> Result<Vec<OnlineTrack>> {
        let data: ApiSearchData = self.http.get_data(
            "/api/v1/personal/fm",
            &[
                ("source", source.to_string()),
                ("mode", mode.unwrap_or("").to_string()),
                ("submode", submode.unwrap_or("").to_string()),
                ("limit", limit.to_string()),
            ],
        )?;
        Ok(data
            .songs
            .unwrap_or_default()
            .into_iter()
            .map(|song| map_song(source, song))
            .collect())
    }

    pub fn similar_songs(
        &self,
        source: &str,
        track_id: &str,
        limit: u32,
    ) -> Result<Vec<OnlineTrack>> {
        let data: ApiSearchData = self.http.get_data(
            "/api/v1/music/similar",
            &[
                ("source", source.to_string()),
                ("id", track_id.to_string()),
                ("limit", limit.to_string()),
            ],
        )?;
        Ok(data
            .songs
            .unwrap_or_default()
            .into_iter()
            .map(|song| map_song(source, song))
            .collect())
    }

    pub fn intelligence(
        &self,
        source: &str,
        track_id: &str,
        playlist_id: Option<&str>,
        count: u32,
    ) -> Result<Vec<OnlineTrack>> {
        let data: ApiSearchData = self.http.get_data(
            "/api/v1/recommend/intelligence",
            &[
                ("source", source.to_string()),
                ("id", track_id.to_string()),
                ("pid", playlist_id.unwrap_or("").to_string()),
                ("count", count.to_string()),
            ],
        )?;
        Ok(data
            .songs
            .unwrap_or_default()
            .into_iter()
            .map(|song| map_song(source, song))
            .collect())
    }

    pub fn home_feed(
        &self,
        source: &str,
        refresh: bool,
        cursor: Option<&str>,
    ) -> Result<OnlineHomeFeed> {
        let data: ApiHomeFeed = self.http.get_data(
            "/api/v1/home/feed",
            &[
                ("source", source.to_string()),
                (
                    "refresh",
                    if refresh { "true" } else { "false" }.to_string(),
                ),
                ("cursor", cursor.unwrap_or("").to_string()),
            ],
        )?;
        Ok(OnlineHomeFeed::from_api(data))
    }

    pub fn search_songs(
        &self,
        source: &str,
        query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<Vec<OnlineTrack>> {
        Ok(self.search(source, query, "song", limit, offset)?.songs)
    }

    pub fn search_playlists(
        &self,
        source: &str,
        query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<Vec<OnlinePlaylist>> {
        Ok(self
            .search(source, query, "playlist", limit, offset)?
            .playlists)
    }

    pub fn search_albums(
        &self,
        source: &str,
        query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<Vec<OnlineAlbum>> {
        Ok(self.search(source, query, "album", limit, offset)?.albums)
    }

    pub fn search(
        &self,
        source: &str,
        query: &str,
        kind: &str,
        limit: u32,
        offset: u32,
    ) -> Result<OnlineSearchResult> {
        let data: ApiSearchData = self.http.get_data(
            "/api/v1/music/search",
            &[
                ("q", query.to_string()),
                ("type", kind.to_string()),
                ("sources", source.to_string()),
                ("limit", limit.max(1).to_string()),
                ("offset", offset.to_string()),
            ],
        )?;

        Ok(OnlineSearchResult {
            songs: data
                .songs
                .unwrap_or_default()
                .into_iter()
                .map(|song| map_song(source, song))
                .collect(),
            playlists: data
                .playlists
                .unwrap_or_default()
                .into_iter()
                .map(|playlist| map_playlist(source, playlist))
                .collect(),
            albums: data
                .albums
                .unwrap_or_default()
                .into_iter()
                .map(|album| map_album(source, album))
                .collect(),
        })
    }

    pub fn playlist_tracks(&self, source: &str, id: &str) -> Result<Vec<OnlineTrack>> {
        let songs = self
            .http
            .get_data_opt::<Vec<ApiSong>>(
                "/api/v1/playlist/detail",
                &[("source", source.to_string()), ("id", id.to_string())],
            )?
            .unwrap_or_default();
        Ok(songs
            .into_iter()
            .map(|song| map_song(source, song))
            .collect())
    }

    pub fn album_tracks(&self, source: &str, id: &str) -> Result<Vec<OnlineTrack>> {
        let songs = self
            .http
            .get_data_opt::<Vec<ApiSong>>(
                "/api/v1/album/detail",
                &[("source", source.to_string()), ("id", id.to_string())],
            )?
            .unwrap_or_default();
        Ok(songs
            .into_iter()
            .map(|song| map_song(source, song))
            .collect())
    }

    pub fn user_playlists(
        &self,
        source: &str,
        page: u32,
        limit: u32,
    ) -> Result<Vec<OnlinePlaylist>> {
        let data: ApiUserPlaylistsData = self.http.get_data(
            "/api/v1/playlist/user",
            &[
                ("source", source.to_string()),
                ("page", page.max(1).to_string()),
                ("limit", limit.max(1).to_string()),
            ],
        )?;
        Ok(data
            .playlists
            .unwrap_or_default()
            .into_iter()
            .map(|playlist| map_playlist(source, playlist))
            .collect())
    }

    pub fn recommend_playlists(&self, source: &str) -> Result<Vec<OnlinePlaylist>> {
        let playlists = self
            .http
            .get_data_opt::<Vec<ApiPlaylist>>(
                "/api/v1/playlist/recommend",
                &[("sources", source.to_string())],
            )?
            .unwrap_or_default();
        Ok(playlists
            .into_iter()
            .map(|playlist| map_playlist(source, playlist))
            .collect())
    }

    pub fn top_lists(&self, source: &str) -> Result<Vec<OnlineTopList>> {
        let data: ApiTopListsData = self.http.get_data(
            "/api/v1/ranking/toplists",
            &[("sources", source.to_string())],
        )?;
        Ok(data
            .toplists
            .unwrap_or_default()
            .into_iter()
            .map(|top_list| map_top_list(source, top_list))
            .collect())
    }

    pub fn top_list_songs(&self, source: &str, id: &str) -> Result<Vec<OnlineTrack>> {
        let data: ApiHotSongsData = self.http.get_data(
            "/api/v1/ranking/toplist",
            &[
                ("source", source.to_string()),
                ("toplist_id", id.to_string()),
            ],
        )?;
        Ok(data
            .songs
            .unwrap_or_default()
            .into_iter()
            .map(|song| map_song(source, song))
            .collect())
    }

    pub fn hot_songs(&self, source: &str, limit: u32) -> Result<Vec<OnlineTrack>> {
        let data: ApiHotSongsData = self.http.get_data(
            "/api/v1/ranking/hot",
            &[
                ("source", source.to_string()),
                ("limit", limit.max(1).to_string()),
            ],
        )?;
        Ok(data
            .songs
            .unwrap_or_default()
            .into_iter()
            .map(|song| map_song(source, song))
            .collect())
    }

    pub fn resolve_audio(
        &self,
        source: &str,
        id: &str,
        quality: &str,
    ) -> Result<OnlineResolvedAudio> {
        let data: ApiUrlData = self.http.get_data(
            "/api/v1/music/url",
            &[
                ("source", source.to_string()),
                ("id", id.to_string()),
                ("quality", quality.to_string()),
            ],
        )?;
        if data.url.trim().is_empty() {
            return Err(OnlineError::Api("没有返回可播放地址".to_string()));
        }
        Ok(OnlineResolvedAudio {
            url: data.url,
            quality: data.quality,
            ext: data.ext,
        })
    }

    pub fn lyric(&self, source: &str, id: &str) -> Result<OnlineLyric> {
        let data: ApiLyricData = self.http.get_data(
            "/api/v1/music/lyric",
            &[("source", source.to_string()), ("id", id.to_string())],
        )?;
        Ok(OnlineLyric { lyric: data.lyric })
    }

    pub fn qualities(&self, source: &str) -> Result<Vec<OnlineQuality>> {
        let data: ApiQualitiesData = self
            .http
            .get_data("/api/v1/music/qualities", &[("source", source.to_string())])?;
        Ok(data.qualities.into_iter().map(map_quality).collect())
    }

    pub fn platform_statuses(&self) -> Result<Vec<OnlinePlatformStatus>> {
        let statuses: Vec<ApiPlatformStatus> =
            self.http.get_json("/laetibeat/system/platforms", &[])?;
        Ok(statuses.into_iter().map(map_platform_status).collect())
    }

    pub fn logout(&self, source: &str) -> Result<()> {
        let _: serde_json::Value = self
            .http
            .delete_data(&format!("/laetibeat/system/platforms/{source}"))?;
        Ok(())
    }

    pub fn qr_login_create(&self, source: &str) -> Result<OnlineQrSession> {
        let session: ApiQrSession = self
            .http
            .post_data(&format!("/api/v1/system/qr_login/{source}"), &[])?;
        Ok(map_qr_session(session))
    }

    pub fn qr_login_check(&self, source: &str, key: &str) -> Result<OnlineQrResult> {
        let result: ApiQrResult = self.http.get_data(
            &format!("/api/v1/system/qr_login/{source}"),
            &[("key", key.to_string())],
        )?;
        Ok(map_qr_result(result))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn instance_id_uses_normalized_base_url() {
        let client = OnlineClient::new("http://127.0.0.1:8080/", Some("t")).unwrap();
        assert_eq!(client.instance_id(), "musicapi:http://127.0.0.1:8080");
    }

    /// 本地联调 native sidecar：
    /// `LAETIBEAT_MUSICAPI_BASE_URL=http://127.0.0.1:PORT \
    ///  LAETIBEAT_MUSICAPI_TOKEN=secret LAETIBEAT_MUSICAPI_SOURCE=qq \
    ///  cargo test -p laetibeat_online native_mode_probe -- --ignored`
    #[test]
    #[ignore]
    fn native_mode_probe() {
        let base_url =
            std::env::var("LAETIBEAT_MUSICAPI_BASE_URL").expect("set LAETIBEAT_MUSICAPI_BASE_URL");
        let token = std::env::var("LAETIBEAT_MUSICAPI_TOKEN").ok();
        let source =
            std::env::var("LAETIBEAT_MUSICAPI_SOURCE").expect("set LAETIBEAT_MUSICAPI_SOURCE");
        let client = OnlineClient::new(&base_url, token.as_deref()).unwrap();
        client.health().unwrap();

        let songs = client.search_songs(&source, "稻香", 10, 0).unwrap();
        assert!(!songs.is_empty(), "{source} search returned no songs");
        assert!(songs[0].ui_id().starts_with(&format!("{source}:")));
        println!(
            "songs: {} first={} / {}",
            songs.len(),
            songs[0].title,
            songs[0].artist
        );

        let lyric = client.lyric(&source, &songs[0].platform_id).unwrap();
        assert!(!lyric.lyric.is_empty(), "{source} lyric empty");
        println!("lyric: {} bytes", lyric.lyric.len());

        let playlists = client.recommend_playlists(&source).unwrap();
        assert!(!playlists.is_empty(), "{source} recommend playlists empty");
        println!("recommend: {} first={}", playlists.len(), playlists[0].name);
        let playlist_songs = client.playlist_tracks(&source, &playlists[0].id).unwrap();
        assert!(!playlist_songs.is_empty(), "{source} playlist tracks empty");
        println!("playlist tracks: {}", playlist_songs.len());

        let top_lists = client.top_lists(&source).unwrap();
        assert!(!top_lists.is_empty(), "{source} top lists empty");
        println!("toplists: {} first={}", top_lists.len(), top_lists[0].name);
        let top_songs = client.top_list_songs(&source, &top_lists[0].id).unwrap();
        assert!(!top_songs.is_empty(), "{source} top list songs empty");
        println!("top songs: {}", top_songs.len());

        let hot = client.hot_songs(&source, 5).unwrap();
        assert!(!hot.is_empty(), "{source} hot songs empty");
        println!("hot: {} first={}", hot.len(), hot[0].title);

        let albums = client.search_albums(&source, "稻香", 3, 0).unwrap();
        if let Some(album) = albums.first() {
            let album_songs = client.album_tracks(&source, &album.id).unwrap();
            assert!(!album_songs.is_empty(), "{source} album tracks empty");
            println!("album tracks: {}", album_songs.len());
        }

        if let Ok(song_id) = std::env::var("LAETIBEAT_MUSICAPI_PROBE_SONG_ID") {
            let audio = client.resolve_audio(&source, &song_id, "standard").unwrap();
            assert!(!audio.url.is_empty());
            println!("audio: {} {}", audio.quality, audio.ext);
        }

        let statuses = client.platform_statuses().unwrap();
        assert!(statuses.iter().any(|status| status.source == source));
        let qr = client.qr_login_create(&source).unwrap();
        assert!(!qr.key.is_empty(), "{source} QR key empty");
        println!(
            "qr: key={} url={} image={}",
            qr.key.len(),
            qr.url.len(),
            qr.image_url.len()
        );
        let qr_status = client.qr_login_check(&source, &qr.key).unwrap();
        assert!(!qr_status.status.is_empty());
        println!("qr status: {}", qr_status.status);
    }

    /// 本地联调：
    /// `LAETIBEAT_MUSICAPI_BASE_URL=http://127.0.0.1:PORT \
    ///  LAETIBEAT_MUSICAPI_TOKEN=secret \
    ///  cargo test -p laetibeat_online live_probe -- --ignored`
    #[test]
    #[ignore]
    fn live_probe() {
        let base_url =
            std::env::var("LAETIBEAT_MUSICAPI_BASE_URL").expect("set LAETIBEAT_MUSICAPI_BASE_URL");
        let token = std::env::var("LAETIBEAT_MUSICAPI_TOKEN").ok();
        let client = OnlineClient::new(&base_url, token.as_deref()).unwrap();
        client.health().unwrap();

        let qq_songs = client.search_songs("qq", "稻香", 10, 0).unwrap();
        assert!(!qq_songs.is_empty(), "QQ search returned no songs");
        assert!(qq_songs[0].ui_id().starts_with("qq:"));

        let netease_songs = client.search_songs("netease", "稻香", 10, 0).unwrap();
        assert!(
            !netease_songs.is_empty(),
            "NetEase search returned no songs"
        );
        assert!(netease_songs[0].ui_id().starts_with("netease:"));
        if let Some(cover) = &netease_songs[0].cover_url {
            assert!(
                cover.starts_with("https://"),
                "cover must be HTTPS: {cover}"
            );
        }

        let resolved = client
            .resolve_audio("qq", "002PZvTU4YHsBI", "standard")
            .unwrap();
        assert!(!resolved.url.is_empty());

        let netease_resolved = client
            .resolve_audio("netease", "1973665667", "high")
            .unwrap();
        assert!(!netease_resolved.url.is_empty());

        let recommend = client.recommend_playlists("netease").unwrap();
        assert!(!recommend.is_empty(), "NetEase recommend playlists empty");
        let recommended_tracks = client.playlist_tracks("netease", &recommend[0].id).unwrap();
        assert!(
            !recommended_tracks.is_empty(),
            "NetEase playlist tracks empty"
        );

        let top_lists = client.top_lists("qq").unwrap();
        assert!(!top_lists.is_empty(), "QQ top lists empty");
        let top_songs = client.top_list_songs("qq", &top_lists[0].id).unwrap();
        assert!(!top_songs.is_empty(), "QQ top list songs empty");

        let hot = client.hot_songs("netease", 5).unwrap();
        assert!(!hot.is_empty(), "NetEase hot songs empty");

        let statuses = client.platform_statuses().unwrap();
        assert!(
            statuses.iter().any(|status| status.source == "netease"),
            "platform statuses missing netease"
        );

        let session = client.qr_login_create("netease").unwrap();
        assert!(!session.key.is_empty(), "NetEase QR key empty");
        assert!(!session.url.is_empty(), "NetEase QR URL empty");
        let qr = client.qr_login_check("netease", &session.key).unwrap();
        assert!(
            matches!(
                qr.status.as_str(),
                "waiting" | "scanned" | "success" | "expired" | "failed"
            ),
            "unexpected QR status: {}",
            qr.status
        );

        let qq_session = client.qr_login_create("qq").unwrap();
        assert!(
            !qq_session.image_url.is_empty() || !qq_session.url.is_empty(),
            "QQ QR session has neither image nor URL"
        );
        let qq_qr = client.qr_login_check("qq", &qq_session.key).unwrap();
        assert!(
            matches!(
                qq_qr.status.as_str(),
                "waiting" | "scanned" | "success" | "expired" | "failed"
            ),
            "unexpected QQ QR status: {}",
            qq_qr.status
        );

        client.logout("netease").unwrap();
        let after_logout = client.platform_statuses().unwrap();
        assert!(
            after_logout
                .iter()
                .all(|status| status.source != "netease" || !status.has_cookie),
            "logout did not clear NetEase cookie"
        );

        let lyric = client.lyric("netease", "1973665667").unwrap();
        assert!(!lyric.lyric.is_empty());
    }
}
