use flutter_rust_bridge::frb;
use laetibeat_netease::{
    NeteaseAlbum, NeteaseArtist, NeteaseCaptchaResult, NeteaseClient, NeteaseLoginResult,
    NeteaseLyric, NeteasePlaylist, NeteaseQrCheck, NeteaseQrCode, NeteaseStatus, NeteaseStream,
    NeteaseTrack,
};

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

#[frb(non_opaque)]
pub struct UiNeteasePlaylist {
    pub id: u64,
    pub name: String,
    pub cover_url: Option<String>,
    pub track_count: u32,
    pub creator: Option<String>,
    pub play_count: Option<u64>,
    pub special_type: Option<i32>,
}

#[frb(non_opaque)]
pub struct UiNeteaseAlbum {
    pub id: u64,
    pub name: String,
    pub artist: String,
    pub artist_id: u64,
    pub cover_url: Option<String>,
    pub track_count: u32,
    pub publish_time_ms: Option<i64>,
}

#[frb(non_opaque)]
pub struct UiNeteaseArtist {
    pub id: u64,
    pub name: String,
    pub cover_url: Option<String>,
    pub album_size: u32,
    pub alias: Vec<String>,
}

#[frb(non_opaque)]
pub struct UiNeteaseAlbumDetail {
    pub album: UiNeteaseAlbum,
    pub tracks: Vec<UiTrack>,
}

#[frb(non_opaque)]
pub struct UiNeteaseArtistDetail {
    pub artist: UiNeteaseArtist,
    pub tracks: Vec<UiTrack>,
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

#[frb(non_opaque)]
pub struct UiNeteaseQrCode {
    pub key: String,
    pub qr_url: String,
    pub qr_image_base64: Option<String>,
}

#[frb(non_opaque)]
pub struct UiNeteaseQrCheck {
    pub code: i32,
    pub message: String,
    pub cookie: Option<String>,
}

#[frb(non_opaque)]
pub struct UiNeteaseLoginResult {
    pub cookie: String,
    pub nickname: Option<String>,
    pub user_id: Option<u64>,
}

#[frb(non_opaque)]
pub struct UiNeteaseCaptchaResult {
    pub code: i32,
    pub message: String,
}

fn client(base_url: &str) -> Result<NeteaseClient, String> {
    NeteaseClient::new(base_url).map_err(|error| error.to_string())
}

/// 测试 API 是否可达，以及当前是否已登录。
pub fn netease_status(base_url: String, cookie: Option<String>) -> Result<UiNeteaseStatus, String> {
    let status = client(&base_url)?
        .status(cookie.as_deref())
        .map_err(|error| error.to_string())?;
    Ok(map_status(status))
}

/// 生成二维码登录 key 与二维码图片。
pub fn netease_qr_create(base_url: String) -> Result<UiNeteaseQrCode, String> {
    let client = client(&base_url)?;
    let key = client.qr_key().map_err(|error| error.to_string())?;
    let qr = client.qr_create(&key).map_err(|error| error.to_string())?;
    Ok(map_qr_code(qr))
}

/// 轮询二维码登录状态。
pub fn netease_qr_check(base_url: String, key: String) -> Result<UiNeteaseQrCheck, String> {
    let check = client(&base_url)?
        .qr_check(&key)
        .map_err(|error| error.to_string())?;
    Ok(map_qr_check(check))
}

/// 发送手机验证码。
pub fn netease_send_captcha(
    base_url: String,
    phone: String,
    countrycode: Option<String>,
) -> Result<UiNeteaseCaptchaResult, String> {
    let result = client(&base_url)?
        .send_captcha(&phone, countrycode.as_deref().unwrap_or("86"))
        .map_err(|error| error.to_string())?;
    Ok(map_captcha_result(result))
}

/// 手机验证码登录，成功后返回 Cookie。
pub fn netease_login_cellphone(
    base_url: String,
    phone: String,
    captcha: String,
    countrycode: Option<String>,
) -> Result<UiNeteaseLoginResult, String> {
    let result = client(&base_url)?
        .login_cellphone(&phone, &captcha, countrycode.as_deref().unwrap_or("86"))
        .map_err(|error| error.to_string())?;
    Ok(map_login_result(result))
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

/// 搜索歌单。
pub fn netease_search_playlists(
    base_url: String,
    keywords: String,
    limit: Option<u32>,
    offset: Option<u32>,
) -> Result<Vec<UiNeteasePlaylist>, String> {
    let playlists = client(&base_url)?
        .search_playlists(&keywords, limit.unwrap_or(30), offset.unwrap_or(0))
        .map_err(|error| error.to_string())?;
    Ok(playlists.into_iter().map(map_playlist).collect())
}

/// 搜索专辑。
pub fn netease_search_albums(
    base_url: String,
    keywords: String,
    limit: Option<u32>,
    offset: Option<u32>,
) -> Result<Vec<UiNeteaseAlbum>, String> {
    let albums = client(&base_url)?
        .search_albums(&keywords, limit.unwrap_or(30), offset.unwrap_or(0))
        .map_err(|error| error.to_string())?;
    Ok(albums.into_iter().map(map_album).collect())
}

/// 搜索艺人。
pub fn netease_search_artists(
    base_url: String,
    keywords: String,
    limit: Option<u32>,
    offset: Option<u32>,
) -> Result<Vec<UiNeteaseArtist>, String> {
    let artists = client(&base_url)?
        .search_artists(&keywords, limit.unwrap_or(30), offset.unwrap_or(0))
        .map_err(|error| error.to_string())?;
    Ok(artists.into_iter().map(map_artist).collect())
}

/// 当前用户收藏的艺人。
pub fn netease_subscribed_artists(
    base_url: String,
    cookie: String,
    limit: Option<u32>,
    offset: Option<u32>,
) -> Result<Vec<UiNeteaseArtist>, String> {
    let artists = client(&base_url)?
        .subscribed_artists(&cookie, limit, offset)
        .map_err(|error| error.to_string())?;
    Ok(artists.into_iter().map(map_artist).collect())
}

/// 当前用户收藏的专辑。
pub fn netease_subscribed_albums(
    base_url: String,
    cookie: String,
    limit: Option<u32>,
    offset: Option<u32>,
) -> Result<Vec<UiNeteaseAlbum>, String> {
    let albums = client(&base_url)?
        .subscribed_albums(&cookie, limit, offset)
        .map_err(|error| error.to_string())?;
    Ok(albums.into_iter().map(map_album).collect())
}

/// 专辑详情与歌曲。
pub fn netease_album_detail(
    base_url: String,
    album_id: u64,
) -> Result<UiNeteaseAlbumDetail, String> {
    let detail = client(&base_url)?
        .album_detail(album_id)
        .map_err(|error| error.to_string())?;
    Ok(UiNeteaseAlbumDetail {
        album: map_album(detail.album),
        tracks: detail
            .tracks
            .into_iter()
            .map(|track| map_track(&base_url, track))
            .collect(),
    })
}

/// 艺人详情与热门歌曲。
pub fn netease_artist_detail(
    base_url: String,
    artist_id: u64,
) -> Result<UiNeteaseArtistDetail, String> {
    let detail = client(&base_url)?
        .artist_detail(artist_id)
        .map_err(|error| error.to_string())?;
    Ok(UiNeteaseArtistDetail {
        artist: map_artist(detail.artist),
        tracks: detail
            .tracks
            .into_iter()
            .map(|track| map_track(&base_url, track))
            .collect(),
    })
}

/// 艺人热门歌曲，最多返回 50 首。
pub fn netease_artist_top_songs(base_url: String, artist_id: u64) -> Result<Vec<UiTrack>, String> {
    let tracks = client(&base_url)?
        .artist_top_songs(artist_id)
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&base_url, track))
        .collect())
}

/// 艺人专辑列表。
pub fn netease_artist_albums(
    base_url: String,
    artist_id: u64,
    limit: Option<u32>,
    offset: Option<u32>,
) -> Result<Vec<UiNeteaseAlbum>, String> {
    let albums = client(&base_url)?
        .artist_albums(artist_id, limit, offset)
        .map_err(|error| error.to_string())?;
    Ok(albums.into_iter().map(map_album).collect())
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

/// 当前登录用户的歌单列表。
pub fn netease_user_playlists(
    base_url: String,
    uid: u64,
    cookie: String,
    limit: Option<u32>,
    offset: Option<u32>,
) -> Result<Vec<UiNeteasePlaylist>, String> {
    let playlists = client(&base_url)?
        .user_playlists(uid, &cookie, limit, offset)
        .map_err(|error| error.to_string())?;
    Ok(playlists.into_iter().map(map_playlist).collect())
}

/// 歌单全部歌曲。
pub fn netease_playlist_tracks(
    base_url: String,
    playlist_id: u64,
    cookie: Option<String>,
    limit: Option<u32>,
    offset: Option<u32>,
) -> Result<Vec<UiTrack>, String> {
    let tracks = client(&base_url)?
        .playlist_tracks(playlist_id, cookie.as_deref(), limit, offset)
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&base_url, track))
        .collect())
}

/// 每日推荐。未登录时返回网易云提供的默认/匿名推荐。
pub fn netease_daily_recommendations(
    base_url: String,
    cookie: Option<String>,
) -> Result<Vec<UiTrack>, String> {
    let tracks = client(&base_url)?
        .daily_recommendations(cookie.as_deref())
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&base_url, track))
        .collect())
}

/// 推荐歌单。limit 默认 6，接口通常最多 30。
pub fn netease_personalized_playlists(
    base_url: String,
    limit: Option<u32>,
    cookie: Option<String>,
) -> Result<Vec<UiNeteasePlaylist>, String> {
    let playlists = client(&base_url)?
        .personalized_playlists(limit.unwrap_or(6), cookie.as_deref())
        .map_err(|error| error.to_string())?;
    Ok(playlists.into_iter().map(map_playlist).collect())
}

/// 首页雷达歌单。
pub fn netease_radar_playlists(
    base_url: String,
    cookie: Option<String>,
) -> Result<Vec<UiNeteasePlaylist>, String> {
    let playlists = client(&base_url)?
        .radar_playlists(cookie.as_deref())
        .map_err(|error| error.to_string())?;
    Ok(playlists.into_iter().map(map_playlist).collect())
}

/// “根据你喜爱的歌曲推荐”首页区块。需要登录。
pub fn netease_liked_song_recommendations(
    base_url: String,
    cookie: String,
) -> Result<Vec<UiTrack>, String> {
    let tracks = client(&base_url)?
        .liked_song_recommendations(&cookie)
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&base_url, track))
        .collect())
}

/// 私人 FM。接口每次返回 1 首。
pub fn netease_personal_fm(
    base_url: String,
    cookie: Option<String>,
) -> Result<Vec<UiTrack>, String> {
    let tracks = client(&base_url)?
        .personal_fm(cookie.as_deref())
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&base_url, track))
        .collect())
}

/// 私人 FM 模式。mode 可选 DEFAULT / FAMILIAR / EXPLORE / SCENE_RCMD 等。
pub fn netease_personal_fm_mode(
    base_url: String,
    mode: String,
    submode: Option<String>,
    cookie: Option<String>,
) -> Result<Vec<UiTrack>, String> {
    let tracks = client(&base_url)?
        .personal_fm_mode(&mode, submode.as_deref(), cookie.as_deref())
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&base_url, track))
        .collect())
}

/// 相似歌曲。接口通常返回 5 首。
pub fn netease_similar_songs(
    base_url: String,
    song_id: u64,
    cookie: Option<String>,
) -> Result<Vec<UiTrack>, String> {
    let tracks = client(&base_url)?
        .similar_songs(song_id, cookie.as_deref())
        .map_err(|error| error.to_string())?;
    Ok(tracks
        .into_iter()
        .map(|track| map_track(&base_url, track))
        .collect())
}

/// 当前用户红心歌曲 id。
pub fn netease_liked_song_ids(
    base_url: String,
    uid: u64,
    cookie: String,
) -> Result<Vec<u64>, String> {
    client(&base_url)?
        .liked_song_ids(uid, &cookie)
        .map_err(|error| error.to_string())
}

/// 心动模式/智能播放队列。
pub fn netease_intelligence_list(
    base_url: String,
    cookie: String,
    song_id: u64,
    playlist_id: u64,
    start_song_id: Option<u64>,
) -> Result<Vec<UiTrack>, String> {
    let tracks = client(&base_url)?
        .intelligence_list(song_id, playlist_id, start_song_id, &cookie)
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

fn map_qr_code(qr: NeteaseQrCode) -> UiNeteaseQrCode {
    UiNeteaseQrCode {
        key: qr.key,
        qr_url: qr.qr_url,
        qr_image_base64: qr.qr_image_base64,
    }
}

fn map_qr_check(check: NeteaseQrCheck) -> UiNeteaseQrCheck {
    UiNeteaseQrCheck {
        code: check.code,
        message: check.message,
        cookie: check.cookie,
    }
}

fn map_login_result(result: NeteaseLoginResult) -> UiNeteaseLoginResult {
    UiNeteaseLoginResult {
        cookie: result.cookie,
        nickname: result.nickname,
        user_id: result.user_id,
    }
}

fn map_captcha_result(result: NeteaseCaptchaResult) -> UiNeteaseCaptchaResult {
    UiNeteaseCaptchaResult {
        code: result.code,
        message: result.message,
    }
}

fn map_album(album: NeteaseAlbum) -> UiNeteaseAlbum {
    UiNeteaseAlbum {
        id: album.id,
        name: album.name,
        artist: album.artist,
        artist_id: album.artist_id,
        cover_url: album.cover_url,
        track_count: album.track_count,
        publish_time_ms: album.publish_time_ms,
    }
}

fn map_artist(artist: NeteaseArtist) -> UiNeteaseArtist {
    UiNeteaseArtist {
        id: artist.id,
        name: artist.name,
        cover_url: artist.cover_url,
        album_size: artist.album_size,
        alias: artist.alias,
    }
}

fn map_playlist(playlist: NeteasePlaylist) -> UiNeteasePlaylist {
    UiNeteasePlaylist {
        id: playlist.id,
        name: playlist.name,
        cover_url: playlist.cover_url,
        track_count: playlist.track_count,
        creator: playlist.creator,
        play_count: playlist.play_count,
        special_type: playlist.special_type,
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
