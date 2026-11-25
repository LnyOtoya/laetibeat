//! Client for a self-hosted NeteaseCloudMusicApi Enhanced instance.
//!
//! Laetibeat deliberately treats the Node service as an external provider
//! backend: this crate only knows HTTP/JSON, not NetEase's EAPI encryption.
//! That keeps the first implementation independent from the eventual native
//! Rust provider.

use std::time::Duration;

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

    pub fn status(&self) -> Result<NeteaseStatus> {
        let envelope: LoginStatusEnvelope = self.get_json("/login/status", &[])?;
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

    pub fn song_detail(&self, song_ids: &[String]) -> Result<Vec<NeteaseTrack>> {
        if song_ids.is_empty() {
            return Ok(Vec::new());
        }
        let envelope: SongDetailEnvelope =
            self.get_json("/song/detail", &[("ids", song_ids.join(","))])?;
        Ok(envelope.songs.into_iter().map(NeteaseTrack::from).collect())
    }

    pub fn daily_recommendations(&self) -> Result<Vec<NeteaseTrack>> {
        let envelope: DailyEnvelope = self.get_json("/recommend/songs", &[])?;
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
        let mut query = vec![("id", song_id.to_string()), ("level", level.to_string())];
        if let Some(cookie) = cookie.filter(|value| !value.trim().is_empty()) {
            query.push(("cookie", cookie.to_string()));
        }
        let envelope: SongUrlEnvelope = self.get_json("/song/url/v1", &query)?;
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

    /// 手动联调测试：
    /// `LAETIBEAT_NETEASE_API=http://192.168.31.51:3000 cargo test -p laetibeat_netease live_probe -- --ignored`
    #[test]
    #[ignore]
    fn live_probe() {
        let base = std::env::var("LAETIBEAT_NETEASE_API")
            .expect("set LAETIBEAT_NETEASE_API to the Node API base URL");
        let client = NeteaseClient::new(base).expect("client");
        let status = client.status().expect("status");
        assert!(status.reachable);
        assert!(!status.logged_in, "this probe expects an anonymous API");

        let daily = client.daily_recommendations().expect("daily");
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

        let lyric = client.lyric(&free.id.to_string()).expect("lyric");
        assert!(!lyric.lyric.is_empty());
    }
}
