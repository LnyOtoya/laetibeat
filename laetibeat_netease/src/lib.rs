//! Client for a self-hosted NeteaseCloudMusicApi Enhanced instance.
//!
//! Laetibeat deliberately treats the Node service as an external provider
//! backend: this crate only knows HTTP/JSON, not NetEase's EAPI encryption.
//! That keeps the first implementation independent from the eventual native
//! Rust provider.

use std::time::{Duration, SystemTime, UNIX_EPOCH};

use reqwest::blocking::Client;
use reqwest::Url;
use serde::de::DeserializeOwned;
use serde::Deserialize;

#[derive(Debug, thiserror::Error)]
pub enum NeteaseError {
    #[error("API 地址无效: {0}")]
    InvalidBaseUrl(String),
    #[error("网络请求失败: {0}")]
    Network(#[from] reqwest::Error),
    #[error("API 返回异常: {0}")]
    Api(String),
    #[error("解析响应失败: {0}")]
    Decode(#[from] serde_json::Error),
}

pub type Result<T> = std::result::Result<T, NeteaseError>;

#[derive(Debug, Clone)]
pub struct NeteaseStatus {
    pub reachable: bool,
    pub logged_in: bool,
    pub code: i32,
    pub nickname: Option<String>,
    pub user_id: Option<u64>,
    pub avatar_url: Option<String>,
}

#[derive(Debug, Clone)]
pub struct NeteaseTrack {
    pub id: u64,
    pub title: String,
    pub artist: String,
    pub artist_id: u64,
    pub album: String,
    pub album_id: u64,
    pub cover_url: Option<String>,
    pub duration_ms: u64,
    pub track_number: Option<u32>,
    pub disc_number: Option<u32>,
    pub fee: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct NeteasePlaylist {
    pub id: u64,
    pub name: String,
    pub cover_url: Option<String>,
    pub track_count: u32,
    pub creator: Option<String>,
}

#[derive(Debug, Clone)]
pub struct NeteaseAlbum {
    pub id: u64,
    pub name: String,
    pub artist: String,
    pub artist_id: u64,
    pub cover_url: Option<String>,
    pub track_count: u32,
    pub publish_time_ms: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct NeteaseArtist {
    pub id: u64,
    pub name: String,
    pub cover_url: Option<String>,
    pub album_size: u32,
    pub alias: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct NeteaseAlbumDetail {
    pub album: NeteaseAlbum,
    pub tracks: Vec<NeteaseTrack>,
}

#[derive(Debug, Clone)]
pub struct NeteaseArtistDetail {
    pub artist: NeteaseArtist,
    pub tracks: Vec<NeteaseTrack>,
}

#[derive(Debug, Clone)]
pub struct NeteaseStream {
    pub url: Option<String>,
    pub bitrate: Option<u64>,
    pub level: Option<String>,
    pub expires_in_seconds: Option<u64>,
    pub is_trial: bool,
    pub trial_end_seconds: Option<u64>,
    pub fee: Option<i64>,
    pub message: Option<String>,
}

#[derive(Debug, Clone, Default)]
pub struct NeteaseLyric {
    pub lyric: String,
    pub translated: Option<String>,
    pub word_by_word: Option<String>,
}

#[derive(Debug, Clone)]
pub struct NeteaseQrCode {
    pub key: String,
    pub qr_url: String,
    pub qr_image_base64: Option<String>,
}

#[derive(Debug, Clone)]
pub struct NeteaseQrCheck {
    pub code: i32,
    pub message: String,
    pub cookie: Option<String>,
}

#[derive(Debug, Clone)]
pub struct NeteaseLoginResult {
    pub cookie: String,
    pub nickname: Option<String>,
    pub user_id: Option<u64>,
}

#[derive(Debug, Clone)]
pub struct NeteaseCaptchaResult {
    pub code: i32,
    pub message: String,
}

#[derive(Debug, Clone)]
pub struct NeteaseClient {
    base_url: String,
    http: Client,
}

impl NeteaseClient {
    pub fn new(base_url: impl Into<String>) -> Result<Self> {
        let base_url = base_url.into().trim().trim_end_matches('/').to_string();
        if base_url.is_empty() {
            return Err(NeteaseError::InvalidBaseUrl("地址为空".to_string()));
        }

        let parsed = Url::parse(&base_url)
            .map_err(|error| NeteaseError::InvalidBaseUrl(error.to_string()))?;
        if !matches!(parsed.scheme(), "http" | "https") {
            return Err(NeteaseError::InvalidBaseUrl(
                "只支持 http/https".to_string(),
            ));
        }
        if parsed.host_str().is_none() {
            return Err(NeteaseError::InvalidBaseUrl("缺少主机名".to_string()));
        }

        let http = Client::builder().timeout(Duration::from_secs(15)).build()?;
        Ok(Self { base_url, http })
    }

    pub fn base_url(&self) -> &str {
        &self.base_url
    }

    pub fn status(&self, cookie: Option<&str>) -> Result<NeteaseStatus> {
        let timestamp = now_millis();
        let envelope: LoginStatusEnvelope = match cookie.filter(|value| !value.trim().is_empty()) {
            Some(cookie) => self.post_form_json(
                "/login/status",
                &[("cookie", cookie.to_string()), ("timestamp", timestamp)],
            )?,
            None => self.get_json("/login/status", &[("timestamp", timestamp)])?,
        };
        let data = envelope
            .data
            .ok_or_else(|| NeteaseError::Api("登录状态响应缺少 data".to_string()))?;
        let profile = data.profile;
        let account = data.account;
        Ok(NeteaseStatus {
            reachable: true,
            logged_in: account.is_some() || profile.is_some(),
            code: data.code.unwrap_or(200),
            nickname: profile.as_ref().and_then(|item| item.nickname.clone()),
            user_id: profile
                .as_ref()
                .and_then(|item| item.user_id)
                .or_else(|| account.as_ref().and_then(|item| item.id)),
            avatar_url: profile.and_then(|item| item.avatar_url),
        })
    }

    pub fn qr_key(&self) -> Result<String> {
        let envelope: QrKeyEnvelope =
            self.get_json("/login/qr/key", &[("timestamp", now_millis())])?;
        envelope
            .data
            .and_then(|data| data.unikey)
            .filter(|key| !key.trim().is_empty())
            .ok_or_else(|| NeteaseError::Api("二维码 key 响应缺少 unikey".to_string()))
    }

    pub fn qr_create(&self, key: &str) -> Result<NeteaseQrCode> {
        let envelope: QrCreateEnvelope = self.get_json(
            "/login/qr/create",
            &[
                ("key", key.to_string()),
                ("qrimg", "true".to_string()),
                ("timestamp", now_millis()),
            ],
        )?;
        let data = envelope
            .data
            .ok_or_else(|| NeteaseError::Api("二维码响应缺少 data".to_string()))?;
        let qr_url = data
            .qrurl
            .filter(|value| !value.trim().is_empty())
            .ok_or_else(|| NeteaseError::Api("二维码响应缺少 qrurl".to_string()))?;
        Ok(NeteaseQrCode {
            key: key.to_string(),
            qr_url,
            qr_image_base64: data.qrimg.filter(|value| !value.trim().is_empty()),
        })
    }

    pub fn qr_check(&self, key: &str) -> Result<NeteaseQrCheck> {
        let response: QrCheckResponse = self.get_json(
            "/login/qr/check",
            &[
                ("key", key.to_string()),
                ("timestamp", now_millis()),
                ("noCookie", "true".to_string()),
            ],
        )?;
        Ok(NeteaseQrCheck {
            code: response.code.unwrap_or(0),
            message: response.message.unwrap_or_default(),
            cookie: response.cookie.filter(|value| !value.trim().is_empty()),
        })
    }

    pub fn send_captcha(&self, phone: &str, countrycode: &str) -> Result<NeteaseCaptchaResult> {
        let response: ApiCodeResponse = self.post_form_json(
            "/captcha/sent",
            &[
                ("phone", phone.to_string()),
                ("countrycode", countrycode.to_string()),
                ("timestamp", now_millis()),
            ],
        )?;
        Ok(NeteaseCaptchaResult {
            code: response.code.unwrap_or(0),
            message: response.message.unwrap_or_default(),
        })
    }

    pub fn login_cellphone(
        &self,
        phone: &str,
        captcha: &str,
        countrycode: &str,
    ) -> Result<NeteaseLoginResult> {
        let response: LoginResponse = self.post_form_json(
            "/login/cellphone",
            &[
                ("phone", phone.to_string()),
                ("captcha", captcha.to_string()),
                ("countrycode", countrycode.to_string()),
                ("timestamp", now_millis()),
            ],
        )?;
        let code = response.code.unwrap_or(0);
        let cookie = response
            .cookie
            .filter(|value| !value.trim().is_empty())
            .ok_or_else(|| {
                NeteaseError::Api(
                    response
                        .message
                        .clone()
                        .unwrap_or_else(|| format!("登录失败（code {code}）")),
                )
            })?;
        let profile = response.profile;
        Ok(NeteaseLoginResult {
            cookie,
            nickname: profile.as_ref().and_then(|item| item.nickname.clone()),
            user_id: profile.and_then(|item| item.user_id),
        })
    }

    pub fn search(&self, keywords: &str, limit: u32, offset: u32) -> Result<Vec<NeteaseTrack>> {
        let envelope: SearchEnvelope = self.get_json(
            "/cloudsearch",
            &[
                ("keywords", keywords.to_string()),
                ("type", "1".to_string()),
                ("limit", limit.to_string()),
                ("offset", offset.to_string()),
            ],
        )?;
        let songs = envelope
            .result
            .and_then(|result| result.songs)
            .ok_or_else(|| NeteaseError::Api("搜索响应缺少歌曲".to_string()))?;
        Ok(songs.into_iter().map(NeteaseTrack::from).collect())
    }

    pub fn search_playlists(
        &self,
        keywords: &str,
        limit: u32,
        offset: u32,
    ) -> Result<Vec<NeteasePlaylist>> {
        let envelope: SearchPlaylistEnvelope = self.get_json(
            "/cloudsearch",
            &[
                ("keywords", keywords.to_string()),
                ("type", "1000".to_string()),
                ("limit", limit.to_string()),
                ("offset", offset.to_string()),
            ],
        )?;
        let playlists = envelope
            .result
            .and_then(|result| result.playlists)
            .ok_or_else(|| NeteaseError::Api("搜索响应缺少歌单".to_string()))?;
        Ok(playlists.into_iter().map(NeteasePlaylist::from).collect())
    }

    pub fn search_albums(
        &self,
        keywords: &str,
        limit: u32,
        offset: u32,
    ) -> Result<Vec<NeteaseAlbum>> {
        let envelope: SearchAlbumEnvelope = self.get_json(
            "/cloudsearch",
            &[
                ("keywords", keywords.to_string()),
                ("type", "10".to_string()),
                ("limit", limit.to_string()),
                ("offset", offset.to_string()),
            ],
        )?;
        let albums = envelope
            .result
            .and_then(|result| result.albums)
            .ok_or_else(|| NeteaseError::Api("搜索响应缺少专辑".to_string()))?;
        Ok(albums.into_iter().map(NeteaseAlbum::from).collect())
    }

    pub fn search_artists(
        &self,
        keywords: &str,
        limit: u32,
        offset: u32,
    ) -> Result<Vec<NeteaseArtist>> {
        let envelope: SearchArtistEnvelope = self.get_json(
            "/cloudsearch",
            &[
                ("keywords", keywords.to_string()),
                ("type", "100".to_string()),
                ("limit", limit.to_string()),
                ("offset", offset.to_string()),
            ],
        )?;
        let artists = envelope
            .result
            .and_then(|result| result.artists)
            .ok_or_else(|| NeteaseError::Api("搜索响应缺少艺人".to_string()))?;
        Ok(artists.into_iter().map(NeteaseArtist::from).collect())
    }

    pub fn subscribed_artists(
        &self,
        cookie: &str,
        limit: Option<u32>,
        offset: Option<u32>,
    ) -> Result<Vec<NeteaseArtist>> {
        let mut form = vec![("cookie", cookie.to_string()), ("timestamp", now_millis())];
        if let Some(limit) = limit {
            form.push(("limit", limit.to_string()));
        }
        if let Some(offset) = offset {
            form.push(("offset", offset.to_string()));
        }
        let envelope: ArtistSublistEnvelope = self.post_form_json("/artist/sublist", &form)?;
        Ok(envelope.data.into_iter().map(NeteaseArtist::from).collect())
    }

    pub fn subscribed_albums(
        &self,
        cookie: &str,
        limit: Option<u32>,
        offset: Option<u32>,
    ) -> Result<Vec<NeteaseAlbum>> {
        let mut form = vec![("cookie", cookie.to_string()), ("timestamp", now_millis())];
        if let Some(limit) = limit {
            form.push(("limit", limit.to_string()));
        }
        if let Some(offset) = offset {
            form.push(("offset", offset.to_string()));
        }
        let envelope: AlbumSublistEnvelope = self.post_form_json("/album/sublist", &form)?;
        Ok(envelope.data.into_iter().map(NeteaseAlbum::from).collect())
    }

    pub fn album_detail(&self, album_id: u64) -> Result<NeteaseAlbumDetail> {
        let envelope: AlbumDetailEnvelope =
            self.get_json("/album", &[("id", album_id.to_string())])?;
        let album = envelope
            .album
            .ok_or_else(|| NeteaseError::Api("专辑响应缺少 album".to_string()))?;
        Ok(NeteaseAlbumDetail {
            album: NeteaseAlbum::from(album),
            tracks: envelope.songs.into_iter().map(NeteaseTrack::from).collect(),
        })
    }

    pub fn artist_detail(&self, artist_id: u64) -> Result<NeteaseArtistDetail> {
        let envelope: ArtistDetailEnvelope =
            self.get_json("/artists", &[("id", artist_id.to_string())])?;
        let artist = envelope
            .artist
            .ok_or_else(|| NeteaseError::Api("艺人响应缺少 artist".to_string()))?;
        Ok(NeteaseArtistDetail {
            artist: NeteaseArtist::from(artist),
            tracks: map_artist_hot_songs(envelope.hot_songs),
        })
    }

    pub fn artist_top_songs(&self, artist_id: u64) -> Result<Vec<NeteaseTrack>> {
        let envelope: ArtistTopSongsEnvelope =
            self.get_json("/artist/top/song", &[("id", artist_id.to_string())])?;
        Ok(map_artist_top_songs(envelope.songs))
    }

    pub fn artist_albums(
        &self,
        artist_id: u64,
        limit: Option<u32>,
        offset: Option<u32>,
    ) -> Result<Vec<NeteaseAlbum>> {
        let mut query = vec![("id", artist_id.to_string())];
        if let Some(limit) = limit {
            query.push(("limit", limit.to_string()));
        }
        if let Some(offset) = offset {
            query.push(("offset", offset.to_string()));
        }
        let envelope: ArtistAlbumsEnvelope = self.get_json("/artist/album", &query)?;
        Ok(envelope
            .hot_albums
            .into_iter()
            .map(NeteaseAlbum::from)
            .collect())
    }

    pub fn song_detail(&self, song_ids: &[String]) -> Result<Vec<NeteaseTrack>> {
        if song_ids.is_empty() {
            return Ok(Vec::new());
        }
        let envelope: SongDetailEnvelope =
            self.get_json("/song/detail", &[("ids", song_ids.join(","))])?;
        Ok(envelope.songs.into_iter().map(NeteaseTrack::from).collect())
    }

    pub fn user_playlists(
        &self,
        uid: u64,
        cookie: &str,
        limit: Option<u32>,
        offset: Option<u32>,
    ) -> Result<Vec<NeteasePlaylist>> {
        let mut form = vec![
            ("uid", uid.to_string()),
            ("cookie", cookie.to_string()),
            ("timestamp", now_millis()),
        ];
        if let Some(limit) = limit {
            form.push(("limit", limit.to_string()));
        }
        if let Some(offset) = offset {
            form.push(("offset", offset.to_string()));
        }
        let envelope: UserPlaylistEnvelope = self.post_form_json("/user/playlist", &form)?;
        Ok(envelope
            .playlist
            .into_iter()
            .map(NeteasePlaylist::from)
            .collect())
    }

    pub fn playlist_tracks(
        &self,
        playlist_id: u64,
        cookie: Option<&str>,
        limit: Option<u32>,
        offset: Option<u32>,
    ) -> Result<Vec<NeteaseTrack>> {
        let envelope: PlaylistTracksEnvelope = match cookie.filter(|value| !value.trim().is_empty())
        {
            Some(cookie) => {
                let mut form = vec![
                    ("id", playlist_id.to_string()),
                    ("cookie", cookie.to_string()),
                    ("timestamp", now_millis()),
                ];
                if let Some(limit) = limit {
                    form.push(("limit", limit.to_string()));
                }
                if let Some(offset) = offset {
                    form.push(("offset", offset.to_string()));
                }
                self.post_form_json("/playlist/track/all", &form)?
            }
            None => {
                let mut query = vec![("id", playlist_id.to_string())];
                if let Some(limit) = limit {
                    query.push(("limit", limit.to_string()));
                }
                if let Some(offset) = offset {
                    query.push(("offset", offset.to_string()));
                }
                self.get_json("/playlist/track/all", &query)?
            }
        };
        Ok(envelope.songs.into_iter().map(NeteaseTrack::from).collect())
    }

    pub fn daily_recommendations(&self, cookie: Option<&str>) -> Result<Vec<NeteaseTrack>> {
        let envelope: DailyEnvelope = match cookie.filter(|value| !value.trim().is_empty()) {
            Some(cookie) => self.post_form_json(
                "/recommend/songs",
                &[("cookie", cookie.to_string()), ("timestamp", now_millis())],
            )?,
            None => self.get_json("/recommend/songs", &[])?,
        };
        let songs = envelope
            .data
            .map(|data| data.daily_songs)
            .ok_or_else(|| NeteaseError::Api("每日推荐响应缺少 data".to_string()))?;
        Ok(songs.into_iter().map(NeteaseTrack::from).collect())
    }

    pub fn song_url(
        &self,
        song_id: &str,
        level: &str,
        cookie: Option<&str>,
    ) -> Result<NeteaseStream> {
        let envelope: SongUrlEnvelope = match cookie.filter(|value| !value.trim().is_empty()) {
            Some(cookie) => self.post_form_json(
                "/song/url/v1",
                &[
                    ("id", song_id.to_string()),
                    ("level", level.to_string()),
                    ("cookie", cookie.to_string()),
                    ("timestamp", now_millis()),
                ],
            )?,
            None => self.get_json(
                "/song/url/v1",
                &[("id", song_id.to_string()), ("level", level.to_string())],
            )?,
        };
        let data = envelope
            .data
            .into_iter()
            .next()
            .ok_or_else(|| NeteaseError::Api("播放响应缺少 data".to_string()))?;
        let trial_end_seconds = data
            .free_trial_info
            .as_ref()
            .map(|trial| trial.end.max(0) as u64);
        Ok(NeteaseStream {
            url: data.url.filter(|value| !value.trim().is_empty()),
            bitrate: data.br,
            level: data.level,
            expires_in_seconds: data.expi,
            is_trial: data.free_trial_info.is_some(),
            trial_end_seconds,
            fee: data.fee,
            message: data.message,
        })
    }

    pub fn lyric(&self, song_id: &str) -> Result<NeteaseLyric> {
        let envelope: LyricEnvelope =
            self.get_json("/lyric/new", &[("id", song_id.to_string())])?;
        Ok(NeteaseLyric {
            lyric: envelope.lrc.and_then(|item| item.lyric).unwrap_or_default(),
            translated: envelope.tlyric.and_then(|item| item.lyric),
            word_by_word: envelope.yrc.and_then(|item| item.lyric),
        })
    }

    pub fn cover(&self, url: &str) -> Result<Vec<u8>> {
        let parsed =
            Url::parse(url).map_err(|error| NeteaseError::InvalidBaseUrl(error.to_string()))?;
        if !matches!(parsed.scheme(), "http" | "https") {
            return Err(NeteaseError::InvalidBaseUrl(
                "封面只支持 http/https".to_string(),
            ));
        }
        let response = self.http.get(parsed).send()?.error_for_status()?;
        Ok(response.bytes()?.to_vec())
    }

    fn get_json<T: DeserializeOwned>(&self, path: &str, query: &[(&str, String)]) -> Result<T> {
        let url = format!("{}{}", self.base_url, path);
        let response = self.http.get(url).query(query).send()?.error_for_status()?;
        let bytes = response.bytes()?;
        serde_json::from_slice(&bytes).map_err(NeteaseError::from)
    }

    fn post_form_json<T: DeserializeOwned>(
        &self,
        path: &str,
        form: &[(&str, String)],
    ) -> Result<T> {
        let url = format!("{}{}", self.base_url, path);
        let response = self.http.post(url).form(form).send()?.error_for_status()?;
        let bytes = response.bytes()?;
        serde_json::from_slice(&bytes).map_err(NeteaseError::from)
    }
}

fn now_millis() -> String {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis().to_string())
        .unwrap_or_else(|_| "0".to_string())
}

fn map_artist_hot_songs(songs: Vec<Song>) -> Vec<NeteaseTrack> {
    songs.into_iter().take(5).map(NeteaseTrack::from).collect()
}

fn map_artist_top_songs(songs: Vec<Song>) -> Vec<NeteaseTrack> {
    songs.into_iter().take(50).map(NeteaseTrack::from).collect()
}

impl From<Song> for NeteaseTrack {
    fn from(song: Song) -> Self {
        let artists = if song.ar.is_empty() {
            song.artists
        } else {
            song.ar
        };
        let album = song.al.or(song.album);
        let duration_ms = song.dt.or(song.duration).unwrap_or(0);
        let artist = artists
            .iter()
            .map(|artist| artist.name.as_str())
            .collect::<Vec<_>>()
            .join("、");
        let artist_id = artists.first().map(|artist| artist.id).unwrap_or(0);
        let album_id = album.as_ref().map(|album| album.id).unwrap_or(0);
        let album_name = album
            .as_ref()
            .map(|album| album.name.clone())
            .unwrap_or_default();
        let cover_url = album.and_then(|album| album.pic_url);
        let disc_number = song.cd.and_then(|value| value.parse::<u32>().ok());

        Self {
            id: song.id,
            title: song.name,
            artist,
            artist_id,
            album: album_name,
            album_id,
            cover_url,
            duration_ms,
            track_number: song.no,
            disc_number,
            fee: song.fee,
        }
    }
}

impl From<UserPlaylist> for NeteasePlaylist {
    fn from(playlist: UserPlaylist) -> Self {
        Self {
            id: playlist.id,
            name: playlist.name,
            cover_url: playlist.cover_img_url,
            track_count: playlist.track_count.unwrap_or(0),
            creator: playlist.creator.and_then(|creator| creator.nickname),
        }
    }
}

impl From<AlbumInfo> for NeteaseAlbum {
    fn from(album: AlbumInfo) -> Self {
        let artist = album.artist.as_ref().or_else(|| album.artists.first());
        Self {
            id: album.id,
            name: album.name,
            artist: artist.map(|artist| artist.name.clone()).unwrap_or_default(),
            artist_id: artist.map(|artist| artist.id).unwrap_or(0),
            cover_url: album.pic_url,
            track_count: album.size.unwrap_or(0),
            publish_time_ms: album.publish_time,
        }
    }
}

impl From<ArtistInfo> for NeteaseArtist {
    fn from(artist: ArtistInfo) -> Self {
        Self {
            id: artist.id,
            name: artist.name,
            cover_url: artist.pic_url,
            album_size: artist.album_size.unwrap_or(0),
            alias: artist.alias,
        }
    }
}

#[derive(Debug, Deserialize)]
struct LoginStatusEnvelope {
    data: Option<LoginStatusData>,
}

#[derive(Debug, Deserialize)]
struct LoginStatusData {
    code: Option<i32>,
    account: Option<Account>,
    profile: Option<Profile>,
}

#[derive(Debug, Deserialize)]
struct Account {
    id: Option<u64>,
}

#[derive(Debug, Deserialize)]
struct Profile {
    #[serde(rename = "userId")]
    user_id: Option<u64>,
    nickname: Option<String>,
    #[serde(rename = "avatarUrl")]
    avatar_url: Option<String>,
}

#[derive(Debug, Deserialize)]
struct SearchAlbumEnvelope {
    result: Option<SearchAlbumResult>,
}

#[derive(Debug, Deserialize)]
struct SearchAlbumResult {
    albums: Option<Vec<AlbumInfo>>,
}

#[derive(Debug, Deserialize)]
struct SearchArtistEnvelope {
    result: Option<SearchArtistResult>,
}

#[derive(Debug, Deserialize)]
struct SearchArtistResult {
    artists: Option<Vec<ArtistInfo>>,
}

#[derive(Debug, Deserialize)]
struct AlbumInfo {
    id: u64,
    name: String,
    #[serde(rename = "picUrl")]
    pic_url: Option<String>,
    #[serde(default)]
    artist: Option<Artist>,
    #[serde(default)]
    artists: Vec<Artist>,
    size: Option<u32>,
    #[serde(rename = "publishTime")]
    publish_time: Option<i64>,
}

#[derive(Debug, Deserialize)]
struct ArtistInfo {
    id: u64,
    name: String,
    #[serde(rename = "picUrl")]
    pic_url: Option<String>,
    #[serde(rename = "albumSize")]
    album_size: Option<u32>,
    #[serde(default)]
    alias: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct AlbumDetailEnvelope {
    album: Option<AlbumInfo>,
    #[serde(default)]
    songs: Vec<Song>,
}

#[derive(Debug, Deserialize)]
struct ArtistDetailEnvelope {
    artist: Option<ArtistInfo>,
    #[serde(rename = "hotSongs", default)]
    hot_songs: Vec<Song>,
}

#[derive(Debug, Deserialize)]
struct ArtistTopSongsEnvelope {
    #[serde(default)]
    songs: Vec<Song>,
}

#[derive(Debug, Deserialize)]
struct ArtistAlbumsEnvelope {
    #[serde(rename = "hotAlbums", default)]
    hot_albums: Vec<AlbumInfo>,
}

#[derive(Debug, Deserialize)]
struct ArtistSublistEnvelope {
    #[serde(default)]
    data: Vec<ArtistInfo>,
}

#[derive(Debug, Deserialize)]
struct AlbumSublistEnvelope {
    #[serde(default)]
    data: Vec<AlbumInfo>,
}

#[derive(Debug, Deserialize)]
struct QrKeyEnvelope {
    data: Option<QrKeyData>,
}

#[derive(Debug, Deserialize)]
struct QrKeyData {
    unikey: Option<String>,
}

#[derive(Debug, Deserialize)]
struct QrCreateEnvelope {
    data: Option<QrCreateData>,
}

#[derive(Debug, Deserialize)]
struct QrCreateData {
    qrurl: Option<String>,
    qrimg: Option<String>,
}

#[derive(Debug, Deserialize)]
struct QrCheckResponse {
    code: Option<i32>,
    message: Option<String>,
    cookie: Option<String>,
}

#[derive(Debug, Deserialize)]
struct ApiCodeResponse {
    code: Option<i32>,
    message: Option<String>,
}

#[derive(Debug, Deserialize)]
struct LoginResponse {
    code: Option<i32>,
    message: Option<String>,
    cookie: Option<String>,
    profile: Option<Profile>,
}

#[derive(Debug, Deserialize)]
struct UserPlaylistEnvelope {
    #[serde(default)]
    playlist: Vec<UserPlaylist>,
}

#[derive(Debug, Deserialize)]
struct UserPlaylist {
    id: u64,
    name: String,
    #[serde(rename = "coverImgUrl")]
    cover_img_url: Option<String>,
    #[serde(rename = "trackCount")]
    track_count: Option<u32>,
    creator: Option<PlaylistCreator>,
}

#[derive(Debug, Deserialize)]
struct PlaylistCreator {
    nickname: Option<String>,
}

#[derive(Debug, Deserialize)]
struct PlaylistTracksEnvelope {
    #[serde(default)]
    songs: Vec<Song>,
}

#[derive(Debug, Deserialize)]
struct SearchPlaylistEnvelope {
    result: Option<SearchPlaylistResult>,
}

#[derive(Debug, Deserialize)]
struct SearchPlaylistResult {
    playlists: Option<Vec<UserPlaylist>>,
}

#[derive(Debug, Deserialize)]
struct SearchEnvelope {
    result: Option<SearchResult>,
}

#[derive(Debug, Deserialize)]
struct SearchResult {
    songs: Option<Vec<Song>>,
}

#[derive(Debug, Deserialize)]
struct SongDetailEnvelope {
    #[serde(default)]
    songs: Vec<Song>,
}

#[derive(Debug, Deserialize)]
struct DailyEnvelope {
    data: Option<DailyData>,
}

#[derive(Debug, Deserialize)]
struct DailyData {
    #[serde(rename = "dailySongs", default)]
    daily_songs: Vec<Song>,
}

#[derive(Debug, Deserialize)]
struct SongUrlEnvelope {
    #[serde(default)]
    data: Vec<SongUrlData>,
}

#[derive(Debug, Deserialize)]
struct SongUrlData {
    url: Option<String>,
    br: Option<u64>,
    expi: Option<u64>,
    level: Option<String>,
    fee: Option<i64>,
    message: Option<String>,
    #[serde(rename = "freeTrialInfo")]
    free_trial_info: Option<FreeTrialInfo>,
}

#[derive(Debug, Deserialize)]
struct FreeTrialInfo {
    #[serde(default)]
    end: i64,
}

#[derive(Debug, Deserialize)]
struct LyricEnvelope {
    lrc: Option<LyricText>,
    tlyric: Option<LyricText>,
    yrc: Option<LyricText>,
}

#[derive(Debug, Deserialize)]
struct LyricText {
    lyric: Option<String>,
}

#[derive(Debug, Deserialize)]
struct Song {
    id: u64,
    name: String,
    #[serde(default)]
    ar: Vec<Artist>,
    #[serde(default)]
    artists: Vec<Artist>,
    al: Option<Album>,
    album: Option<Album>,
    dt: Option<u64>,
    duration: Option<u64>,
    fee: Option<i64>,
    no: Option<u32>,
    cd: Option<String>,
}

#[derive(Debug, Deserialize)]
struct Artist {
    #[serde(default)]
    id: u64,
    #[serde(default)]
    name: String,
}

#[derive(Debug, Deserialize)]
struct Album {
    #[serde(default)]
    id: u64,
    #[serde(default)]
    name: String,
    #[serde(rename = "picUrl")]
    pic_url: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn maps_daily_song_shape() {
        let song: Song = serde_json::from_str(
            r#"{
                "id": 2627048051,
                "name": "守护契约",
                "ar": [{"id": 1, "name": "茶鸳"}],
                "al": {"id": 2, "name": "猫七夜", "picUrl": "https://example.com/a.jpg"},
                "dt": 235250,
                "fee": 0,
                "no": 1,
                "cd": "01"
            }"#,
        )
        .expect("daily song json");
        let track = NeteaseTrack::from(song);
        assert_eq!(track.id, 2627048051);
        assert_eq!(track.artist, "茶鸳");
        assert_eq!(track.album, "猫七夜");
        assert_eq!(track.duration_ms, 235250);
        assert_eq!(track.disc_number, Some(1));
        assert_eq!(track.fee, Some(0));
    }

    #[test]
    fn maps_legacy_search_song_shape() {
        let song: Song = serde_json::from_str(
            r#"{
                "id": 5257138,
                "name": "屋顶",
                "artists": [{"id": 6452, "name": "周杰伦"}, {"id": 9612, "name": "温岚"}],
                "album": {"id": 512175, "name": "男女情歌对唱冠军全记录"},
                "duration": 319039,
                "fee": 8
            }"#,
        )
        .expect("legacy search song json");
        let track = NeteaseTrack::from(song);
        assert_eq!(track.artist, "周杰伦、温岚");
        assert_eq!(track.album, "男女情歌对唱冠军全记录");
        assert_eq!(track.duration_ms, 319039);
        assert_eq!(track.album_id, 512175);
    }

    #[test]
    fn maps_user_playlist_shape() {
        let envelope: UserPlaylistEnvelope = serde_json::from_str(
            r#"{
                "playlist": [{
                    "id": 123,
                    "name": "我喜欢的音乐",
                    "coverImgUrl": "https://example.com/p.jpg",
                    "trackCount": 42,
                    "creator": {"nickname": "tester"}
                }]
            }"#,
        )
        .expect("user playlist json");
        let playlist = NeteasePlaylist::from(envelope.playlist.into_iter().next().unwrap());
        assert_eq!(playlist.id, 123);
        assert_eq!(playlist.name, "我喜欢的音乐");
        assert_eq!(playlist.track_count, 42);
        assert_eq!(playlist.creator.as_deref(), Some("tester"));
    }

    #[test]
    fn limits_artist_hot_songs_to_five() {
        let songs: Vec<Song> = (0..8)
            .map(|id| {
                serde_json::from_value(serde_json::json!({
                    "id": id,
                    "name": format!("song-{id}"),
                }))
                .expect("artist hot song json")
            })
            .collect();

        assert_eq!(map_artist_hot_songs(songs).len(), 5);
    }

    #[test]
    fn limits_artist_top_songs_to_fifty() {
        let songs: Vec<Song> = (0..60)
            .map(|id| {
                serde_json::from_value(serde_json::json!({
                    "id": id,
                    "name": format!("song-{id}"),
                }))
                .expect("artist top song json")
            })
            .collect();

        assert_eq!(map_artist_top_songs(songs).len(), 50);
    }

    /// 手动联调测试：
    /// `LAETIBEAT_NETEASE_API=http://192.168.31.51:3000 cargo test -p laetibeat_netease live_probe -- --ignored`
    #[test]
    #[ignore]
    fn live_probe() {
        let base = std::env::var("LAETIBEAT_NETEASE_API")
            .expect("set LAETIBEAT_NETEASE_API to the Node API base URL");
        let client = NeteaseClient::new(base).expect("client");
        let status = client.status(None).expect("status");
        assert!(status.reachable);
        assert!(!status.logged_in, "this probe expects an anonymous API");

        let daily = client.daily_recommendations(None).expect("daily");
        assert!(!daily.is_empty());

        let free = daily
            .iter()
            .find(|track| track.fee == Some(0))
            .expect("daily should contain a free song");
        let stream = client
            .song_url(&free.id.to_string(), "exhigh", None)
            .expect("song url");
        assert!(stream.url.is_some());

        let search = client.search("海阔天空", 3, 0).expect("search");
        assert!(!search.is_empty());

        let playlists = client
            .search_playlists("周杰伦", 3, 0)
            .expect("search playlists");
        assert!(!playlists.is_empty());

        let albums = client.search_albums("周杰伦", 3, 0).expect("search albums");
        assert!(!albums.is_empty());
        let album = client.album_detail(albums[0].id).expect("album detail");
        assert!(!album.tracks.is_empty());

        let artists = client
            .search_artists("周杰伦", 3, 0)
            .expect("search artists");
        assert!(!artists.is_empty());
        let artist = client.artist_detail(artists[0].id).expect("artist detail");
        assert!(!artist.tracks.is_empty());
        let artist_albums = client
            .artist_albums(artists[0].id, Some(3), Some(0))
            .expect("artist albums");
        assert!(!artist_albums.is_empty());

        let lyric = client.lyric(&free.id.to_string()).expect("lyric");
        assert!(!lyric.lyric.is_empty());
    }

    /// 二维码接口联调：不扫码，只验证 key/create/check 形状。
    #[test]
    #[ignore]
    fn live_qr_probe() {
        let base = std::env::var("LAETIBEAT_NETEASE_API")
            .expect("set LAETIBEAT_NETEASE_API to the Node API base URL");
        let client = NeteaseClient::new(base).expect("client");
        let key = client.qr_key().expect("qr key");
        let qr = client.qr_create(&key).expect("qr create");
        assert!(!qr.qr_url.is_empty());
        assert!(qr.qr_image_base64.is_some());
        let check = client.qr_check(&key).expect("qr check");
        assert!(matches!(check.code, 800 | 801 | 802));
    }
}
