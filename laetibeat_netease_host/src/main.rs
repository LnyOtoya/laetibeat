use std::env;
use std::fs;
use std::io::Write;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use axum::extract::{DefaultBodyLimit, Path as AxumPath, Query, State};
use axum::http::{header::AUTHORIZATION, StatusCode};
use axum::middleware::{self, Next};
use axum::response::{IntoResponse, Response};
use axum::routing::{delete, get, post};
use axum::{Json, Router};
use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine;
use md5::{Digest, Md5};
use ncm_api_rs::util::device::generate_device_id;
use ncm_api_rs::{
    create_client, ApiClient, ApiResponse, CryptoType, NcmError, Query as NcmQuery, RequestOption,
};
use serde::Deserialize;
use serde_json::{json, Value};
use subtle::ConstantTimeEq;
use tokio::net::TcpListener;
use tokio::sync::Mutex;

const LISTEN_PREFIX: &str = "LAETIBEAT_MUSICAPI_LISTEN=";
const DEFAULT_ADDR: &str = "127.0.0.1:0";
const DEFAULT_DATA_DIR: &str = ".laetibeat-netease";

struct HostState {
    client: Mutex<ApiClient>,
    token: String,
    cookie_path: PathBuf,
    logged_in: AtomicBool,
}

type SharedState = Arc<HostState>;
type ApiResult = Result<Json<Value>, (StatusCode, Json<Value>)>;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "laetibeat_netease_host=info".into()),
        )
        .with_writer(std::io::stderr)
        .init();

    if let Err(error) = run().await {
        eprintln!("laetibeat netease host: {error}");
        std::process::exit(1);
    }
}

async fn run() -> Result<(), Box<dyn std::error::Error>> {
    let data_dir = PathBuf::from(
        env_first(&["LAETIBEAT_NETEASE_DATA_DIR", "LAETIBEAT_MUSICAPI_DATA_DIR"])
            .unwrap_or_else(|| DEFAULT_DATA_DIR.to_string()),
    );
    fs::create_dir_all(&data_dir)?;
    let cookie_path = data_dir.join("cookies.json");

    let cookie = fs::read_to_string(&cookie_path)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty());
    let logged_in = cookie.is_some();
    let mut client = create_client(cookie);
    if !logged_in {
        // NetEase 的部分匿名接口需要游客 MUSIC_A token。ncm-api-rs 自带的
        // register_anonimous 使用 weapi，当前服务端需要 eapi；这里用公开
        // request 接口做一次等价的 guest 注册。
        match register_guest(&mut client).await {
            Some(_) => tracing::info!("registered NetEase guest token"),
            None => tracing::warn!("guest login returned no cookie"),
        }
    }

    let token =
        env_first(&["LAETIBEAT_NETEASE_TOKEN", "LAETIBEAT_MUSICAPI_TOKEN"]).unwrap_or_default();
    let addr: SocketAddr = env_first(&["LAETIBEAT_NETEASE_ADDR", "LAETIBEAT_MUSICAPI_ADDR"])
        .unwrap_or_else(|| DEFAULT_ADDR.to_string())
        .parse()?;
    if token.is_empty() && !addr.ip().is_loopback() {
        return Err("refusing to listen on a non-loopback address without a token".into());
    }

    let state = Arc::new(HostState {
        client: Mutex::new(client),
        token,
        cookie_path,
        logged_in: AtomicBool::new(logged_in),
    });

    let app = Router::new()
        .route("/laetibeat/health", get(health))
        .route("/api/v1/music/search", get(search))
        .route("/api/v1/music/url", get(song_url))
        .route("/api/v1/music/lyric", get(lyric))
        .route("/api/v1/login/qr", get(qr_create))
        .route("/api/v1/login/qr/status", get(qr_status))
        .route("/api/v1/music/qualities", get(qualities))
        .route("/api/v1/system/qr_login/{source}", post(qr_create_compat))
        .route("/api/v1/system/qr_login/{source}", get(qr_status_compat))
        .route("/laetibeat/system/platforms", get(platforms))
        .route("/laetibeat/system/platforms/{source}", delete(logout))
        .route("/api/v1/home/feed", get(home_feed))
        .route("/api/v1/recommend/daily/songs", get(daily_songs))
        .route("/api/v1/recommend/daily/playlists", get(daily_playlists))
        .route("/api/v1/personal/fm", get(personal_fm))
        .route("/api/v1/recommend/intelligence", get(intelligence))
        .route("/api/v1/music/similar", get(similar_songs))
        .route("/api/v1/playlist/detail", get(playlist_detail))
        .route("/api/v1/album/detail", get(album_detail))
        .route("/api/v1/playlist/user", get(user_playlists))
        .route("/api/v1/playlist/radar", get(radar_playlists))
        .route("/api/v1/playlist/recommend", get(recommend_playlists))
        .route("/api/v1/ranking/toplists", get(top_lists))
        .route("/api/v1/ranking/toplist", get(top_list_songs))
        .route("/api/v1/ranking/hot", get(hot_songs))
        .layer(DefaultBodyLimit::max(4 * 1024 * 1024))
        .layer(middleware::from_fn(log_request))
        .layer(middleware::from_fn_with_state(
            Arc::clone(&state),
            authorize,
        ))
        .with_state(state);

    let listener = TcpListener::bind(addr).await?;
    let actual = listener.local_addr()?;
    println!("{LISTEN_PREFIX}{actual}");
    std::io::stdout().flush()?;
    tracing::info!("NetEase host listening on http://{actual}");

    spawn_parent_watchdog();
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    Ok(())
}

async fn health(State(state): State<SharedState>) -> ApiResult {
    Ok(Json(json!({
        "status": "ok",
        "source": "netease",
        "logged_in": state.logged_in.load(Ordering::Relaxed),
    })))
}

#[derive(Debug, Deserialize)]
struct SearchParams {
    q: String,
    #[serde(rename = "type")]
    kind: Option<String>,
    limit: Option<i64>,
    offset: Option<i64>,
}

async fn search(State(state): State<SharedState>, Query(params): Query<SearchParams>) -> ApiResult {
    let search_type = match params.kind.as_deref().unwrap_or("song") {
        "song" => "1",
        "playlist" => "1000",
        "album" => "10",
        "artist" => "100",
        other => {
            return Err(api_error(
                StatusCode::BAD_REQUEST,
                format!("unsupported type: {other}"),
            ))
        }
    };
    let query = NcmQuery::new()
        .param("keywords", &params.q)
        .param("type", search_type)
        .param(
            "limit",
            &params.limit.unwrap_or(10).clamp(1, 50).to_string(),
        )
        .param("offset", &params.offset.unwrap_or(0).max(0).to_string());

    let client = state.client.lock().await;
    let response = client.cloudsearch(&query).await.map_err(ncm_error)?;
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": map_search_body(&response.body),
    })))
}

#[derive(Debug, Deserialize)]
struct UrlParams {
    id: String,
    quality: Option<String>,
}

async fn song_url(State(state): State<SharedState>, Query(params): Query<UrlParams>) -> ApiResult {
    let requested = params.quality.as_deref().unwrap_or("standard");
    let level = match requested {
        "auto" => "standard",
        "high" => "exhigh",
        "standard" => "standard",
        "lossless" => "lossless",
        "hires" | "master" => "hires",
        other => other,
    };
    let client = state.client.lock().await;
    // v1 使用较新的接口；部分曲目/匿名状态下会拒绝，回退到旧 br 接口。
    let (response, used_quality) = match client
        .song_url_v1(
            &NcmQuery::new()
                .param("id", &params.id)
                .param("level", level),
        )
        .await
    {
        Ok(response) => (response, level),
        Err(v1_error) => {
            let legacy = client
                .song_url(
                    &NcmQuery::new()
                        .param("id", &params.id)
                        .param("br", "999000"),
                )
                .await;
            match legacy {
                Ok(response) => (response, "auto"),
                Err(_) => return Err(ncm_error(v1_error)),
            }
        }
    };
    let item = response
        .body
        .get("data")
        .and_then(Value::as_array)
        .and_then(|items| items.first())
        .ok_or_else(|| api_error(StatusCode::NOT_FOUND, "empty song URL response"))?;
    let url = item.get("url").and_then(Value::as_str).unwrap_or("");
    if url.is_empty() {
        return Err(api_error(
            StatusCode::NOT_FOUND,
            "no playable URL (VIP, copyright or unavailable)",
        ));
    }
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": {
            "url": url,
            "quality": used_quality,
            "br": item.get("br").cloned().unwrap_or(Value::Null),
            "size": item.get("size").cloned().unwrap_or(Value::Null),
            "ext": item.get("type").and_then(Value::as_str).unwrap_or(""),
            "source": "netease",
        }
    })))
}

#[derive(Debug, Deserialize)]
struct LyricParams {
    id: String,
}

async fn lyric(State(state): State<SharedState>, Query(params): Query<LyricParams>) -> ApiResult {
    let query = NcmQuery::new().param("id", &params.id);
    let client = state.client.lock().await;
    let response = client.lyric(&query).await.map_err(ncm_error)?;
    let lyric = response
        .body
        .pointer("/lrc/lyric")
        .and_then(Value::as_str)
        .unwrap_or("");
    let trans = response
        .body
        .pointer("/tlyric/lyric")
        .and_then(Value::as_str)
        .unwrap_or("");
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": {
            "lyric": lyric,
            "trans": trans,
            "source": "netease",
        }
    })))
}

async fn qr_create(State(state): State<SharedState>) -> ApiResult {
    let (key, qrurl, qrimg) = create_qr_data(&state).await?;
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": {
            "key": key,
            "qrurl": qrurl,
            "qrimg": qrimg,
            "source": "netease",
        }
    })))
}

async fn create_qr_data(
    state: &SharedState,
) -> Result<(String, String, String), (StatusCode, Json<Value>)> {
    let client = state.client.lock().await;
    let key_response = client
        .login_qr_key(&NcmQuery::new())
        .await
        .map_err(ncm_error)?;
    let key = extract_str(&key_response.body, &["/data/unikey", "/unikey"])
        .ok_or_else(|| api_error(StatusCode::BAD_GATEWAY, "missing QR key"))?;
    let create_response = client
        .login_qr_create(&NcmQuery::new().param("key", &key).param("qrimg", "true"))
        .await
        .map_err(ncm_error)?;
    let qrurl = extract_str(&create_response.body, &["/data/qrurl", "/qrurl"])
        .unwrap_or_else(|| format!("https://music.163.com/login?codekey={key}"));
    let qrimg = extract_str(&create_response.body, &["/data/qrimg", "/qrimg"]).unwrap_or_default();
    Ok((key, qrurl, qrimg))
}

async fn qr_create_compat(
    State(state): State<SharedState>,
    AxumPath(_source): AxumPath<String>,
) -> ApiResult {
    let (key, qrurl, qrimg) = create_qr_data(&state).await?;
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": {
            "source": "netease",
            "key": key,
            "url": qrurl,
            "image_url": qrimg,
            "expires_at": null,
        }
    })))
}

#[derive(Debug, Deserialize)]
struct QrStatusParams {
    key: String,
}

async fn qr_status(
    State(state): State<SharedState>,
    Query(params): Query<QrStatusParams>,
) -> ApiResult {
    let (status, message, saved) = check_qr_data(&state, &params.key).await?;
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": {
            "status": status,
            "message": message,
            "cookie_saved": saved,
            "source": "netease",
        }
    })))
}

async fn qr_status_compat(
    State(state): State<SharedState>,
    AxumPath(_source): AxumPath<String>,
    Query(params): Query<QrStatusParams>,
) -> ApiResult {
    let (status, message, saved) = check_qr_data(&state, &params.key).await?;
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": {
            "source": "netease",
            "status": status,
            "message": message,
            "extra": {
                "cookie_saved": if saved { "true" } else { "false" },
            }
        }
    })))
}

async fn check_qr_data(
    state: &SharedState,
    key: &str,
) -> Result<(String, String, bool), (StatusCode, Json<Value>)> {
    let query = NcmQuery::new().param("key", key);
    let mut client = state.client.lock().await;
    let response = client.login_qr_check(&query).await.map_err(ncm_error)?;
    let code = response
        .body
        .get("code")
        .and_then(Value::as_i64)
        .unwrap_or(0);
    let (status, message, saved): (&str, String, bool) = match code {
        800 => ("expired", "二维码已过期".to_string(), false),
        801 => ("waiting", "等待扫码".to_string(), false),
        802 => ("scanned", "已扫码，请在手机上确认".to_string(), false),
        803 => {
            let cookie = extract_cookie(&response);
            if let Some(cookie) = cookie {
                save_cookie(&state.cookie_path, &cookie)?;
                client.set_cookie(cookie);
                state.logged_in.store(true, Ordering::Relaxed);
                ("success", "登录成功".to_string(), true)
            } else {
                ("success", "登录成功，但未收到 Cookie".to_string(), false)
            }
        }
        other => ("failed", format!("登录状态异常: {other}"), false),
    };
    Ok((status.to_string(), message, saved))
}

async fn platforms(State(state): State<SharedState>) -> ApiResult {
    Ok(Json(json!([
        {
            "source": "netease",
            "has_cookie": state.logged_in.load(Ordering::Relaxed),
        }
    ])))
}

async fn logout(State(state): State<SharedState>, AxumPath(source): AxumPath<String>) -> ApiResult {
    if source != "netease" {
        return Err(api_error(StatusCode::NOT_FOUND, "unknown NetEase source"));
    }
    if state.cookie_path.exists() {
        fs::remove_file(&state.cookie_path).map_err(|error| {
            api_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("failed to remove cookies: {error}"),
            )
        })?;
    }
    let mut client = state.client.lock().await;
    *client = create_client(None);
    let _ = register_guest(&mut client).await;
    state.logged_in.store(false, Ordering::Relaxed);
    Ok(Json(json!({ "code": 200, "msg": "ok", "data": null })))
}

async fn qualities() -> ApiResult {
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": {
            "qualities": [
                { "value": "standard", "label": "标准", "format": "mp3", "bitrate": 128000, "vip": false },
                { "value": "high", "label": "高品质", "format": "mp3", "bitrate": 320000, "vip": false },
                { "value": "lossless", "label": "无损", "format": "flac", "bitrate": 900000, "vip": true },
                { "value": "hires", "label": "Hi-Res", "format": "flac", "bitrate": 1500000, "vip": true }
            ]
        }
    })))
}

#[derive(Debug, Deserialize)]
struct DailyParams {
    refresh: Option<String>,
}

async fn daily_songs(
    State(state): State<SharedState>,
    Query(params): Query<DailyParams>,
) -> ApiResult {
    let refresh = matches!(
        params.refresh.as_deref(),
        Some("1" | "true" | "True" | "yes")
    );
    let data = if refresh {
        json!({"afresh": true})
    } else {
        json!({})
    };
    let client = state.client.lock().await;
    let response = client
        .request(
            "/api/v3/discovery/recommend/songs",
            data,
            RequestOption {
                crypto: CryptoType::Weapi,
                ..Default::default()
            },
        )
        .await
        .map_err(ncm_error)?;
    let songs = songs_at(&response.body, &["/data/dailySongs", "/dailySongs"]);
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": {
            "refreshed": refresh,
            "songs": songs.into_iter().map(|item| map_ne_song(&item)).collect::<Vec<_>>(),
        }
    })))
}

async fn daily_playlists(State(state): State<SharedState>) -> ApiResult {
    let client = state.client.lock().await;
    let response = client
        .recommend_resource(&NcmQuery::new())
        .await
        .map_err(ncm_error)?;
    let playlists = array_at(&response.body, "/recommend");
    let playlists = if playlists.is_empty() {
        array_at(&response.body, "/data/recommend")
    } else {
        playlists
    };
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": {
            "playlists": playlists.into_iter().map(|item| map_ne_playlist(&item)).collect::<Vec<_>>(),
        }
    })))
}

#[derive(Debug, Deserialize)]
struct FmParams {
    mode: Option<String>,
    submode: Option<String>,
    limit: Option<i64>,
}

async fn personal_fm(
    State(state): State<SharedState>,
    Query(params): Query<FmParams>,
) -> ApiResult {
    let limit = params.limit.unwrap_or(10).clamp(1, 30);
    let limit_text = limit.to_string();
    let client = state.client.lock().await;
    let response = if let Some(mode) = params.mode.as_deref() {
        client
            .personal_fm_mode(
                &NcmQuery::new()
                    .param("mode", mode)
                    .param("submode", params.submode.as_deref().unwrap_or(""))
                    .param("limit", &limit_text),
            )
            .await
            .map_err(ncm_error)?
    } else {
        client
            .personal_fm(&NcmQuery::new().param("limit", &limit_text))
            .await
            .map_err(ncm_error)?
    };
    let songs = songs_at(&response.body, &["/data", "/songs", "/data/songs"]);
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": { "songs": songs.into_iter().take(limit as usize).map(|item| map_ne_song(&item)).collect::<Vec<_>>() }
    })))
}

#[derive(Debug, Deserialize)]
struct IntelligenceParams {
    id: Option<String>,
    pid: Option<String>,
    sid: Option<String>,
    count: Option<i64>,
}

async fn intelligence(
    State(state): State<SharedState>,
    Query(params): Query<IntelligenceParams>,
) -> ApiResult {
    let id = params.id.as_deref().unwrap_or("0");
    let count = params.count.unwrap_or(10).clamp(1, 50).to_string();
    let client = state.client.lock().await;
    let response = client
        .playmode_intelligence_list(
            &NcmQuery::new()
                .param("id", id)
                .param("pid", params.pid.as_deref().unwrap_or("0"))
                .param("sid", params.sid.as_deref().unwrap_or(id))
                .param("count", &count),
        )
        .await
        .map_err(ncm_error)?;
    let songs = songs_at(
        &response.body,
        &["/data", "/data/songs", "/data/songList", "/songs"],
    );
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": { "songs": songs.into_iter().map(|item| map_ne_song(&item)).collect::<Vec<_>>() }
    })))
}

#[derive(Debug, Deserialize)]
struct SimilarParams {
    id: String,
    limit: Option<i64>,
    offset: Option<i64>,
}

async fn similar_songs(
    State(state): State<SharedState>,
    Query(params): Query<SimilarParams>,
) -> ApiResult {
    let limit = params.limit.unwrap_or(30).clamp(1, 100);
    let offset = params.offset.unwrap_or(0).max(0);
    let limit_text = limit.to_string();
    let offset_text = offset.to_string();
    let client = state.client.lock().await;
    let response = client
        .simi_song(
            &NcmQuery::new()
                .param("id", &params.id)
                .param("limit", &limit_text)
                .param("offset", &offset_text),
        )
        .await
        .map_err(ncm_error)?;
    let songs = songs_at(&response.body, &["/songs", "/data/songs", "/data"]);
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": { "songs": songs.into_iter().map(|item| map_ne_song(&item)).collect::<Vec<_>>() }
    })))
}

fn songs_at(body: &Value, paths: &[&str]) -> Vec<Value> {
    for path in paths {
        let songs = array_at(body, path);
        if !songs.is_empty() {
            return songs;
        }
    }
    Vec::new()
}

#[derive(Debug, Deserialize)]
struct HomeFeedParams {
    refresh: Option<String>,
    cursor: Option<String>,
}

async fn home_feed(
    State(state): State<SharedState>,
    Query(params): Query<HomeFeedParams>,
) -> ApiResult {
    let refresh = matches!(
        params.refresh.as_deref(),
        Some("1" | "true" | "True" | "yes")
    );
    let cursor = params.cursor.unwrap_or_default();
    let query = NcmQuery::new()
        .param("refresh", if refresh { "true" } else { "false" })
        .param("cursor", &cursor);
    let client = state.client.lock().await;
    let response = client
        .homepage_block_page(&query)
        .await
        .map_err(ncm_error)?;
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": map_home_feed(&response.body),
    })))
}

fn map_home_feed(body: &Value) -> Value {
    let data = body.get("data").unwrap_or(body);
    let cursor = data.get("cursor").and_then(|value| {
        if value.is_null() {
            None
        } else {
            let text = value_string(value);
            if text.is_empty() {
                None
            } else {
                Some(text)
            }
        }
    });
    let blocks = data
        .get("blocks")
        .and_then(Value::as_array)
        .map(|items| items.iter().map(map_home_block).collect::<Vec<_>>())
        .unwrap_or_default();
    json!({ "cursor": cursor, "blocks": blocks })
}

fn map_home_block(block: &Value) -> Value {
    let code = first_string(block, &["blockCode"]);
    let show_type = first_string(block, &["showType"]);
    let ui = block.get("uiElement");
    let title = ui
        .and_then(|value| value.pointer("/subTitle/title"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let action = block
        .get("action")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let mut items = Vec::new();
    if let Some(creatives) = block.get("creatives").and_then(Value::as_array) {
        for creative in creatives {
            let section = creative
                .pointer("/uiElement/mainTitle/title")
                .and_then(Value::as_str)
                .unwrap_or("");
            if let Some(resources) = creative.get("resources").and_then(Value::as_array) {
                for resource in resources {
                    items.push(map_home_resource(resource, section));
                }
            }
        }
    }
    if items.is_empty() {
        if let Some(banners) = block.pointer("/extInfo/banners").and_then(Value::as_array) {
            items.extend(banners.iter().map(map_home_banner));
        }
    }
    json!({
        "code": code,
        "showType": show_type,
        "title": title,
        "action": action,
        "items": items,
    })
}

fn map_home_resource(resource: &Value, section: &str) -> Value {
    let kind = first_string(resource, &["resourceType"]);
    let id = resource
        .get("resourceId")
        .map(value_string)
        .unwrap_or_default();
    let ui = resource.get("uiElement");
    let title = ui
        .and_then(|value| value.pointer("/mainTitle/title"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let subtitle = ui
        .and_then(|value| value.pointer("/subTitle/title"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let cover = ui
        .and_then(|value| value.pointer("/image/imageUrl"))
        .and_then(Value::as_str)
        .map(normalize_https)
        .unwrap_or_default();
    let action = resource
        .get("action")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let ext = resource.get("resourceExtInfo");
    let artists = ext
        .and_then(|value| value.get("artists"))
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(|item| item.get("name").and_then(Value::as_str))
                .collect::<Vec<_>>()
                .join("/")
        })
        .unwrap_or_default();
    let song = ext.and_then(|value| value.get("song"));
    let album = song.and_then(|value| value.get("al"));
    let album_name = album
        .and_then(|value| value.get("name"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let album_id = album
        .and_then(|value| value.get("id"))
        .map(value_string)
        .unwrap_or_default();
    let duration = song
        .and_then(|value| value.get("dt").or_else(|| value.get("duration")))
        .and_then(Value::as_i64)
        .map(|value| if value > 1000 { value / 1000 } else { value })
        .unwrap_or(0);
    let play_count = ext
        .and_then(|value| value.get("playCount"))
        .and_then(Value::as_i64)
        .unwrap_or(0);
    let track_count = ext
        .and_then(|value| {
            value
                .get("songCount")
                .or_else(|| value.get("trackCount"))
                .or_else(|| value.get("songnum"))
        })
        .and_then(Value::as_i64)
        .unwrap_or(0);
    json!({
        "kind": kind,
        "id": id,
        "title": title,
        "subtitle": subtitle,
        "cover": cover,
        "section": section,
        "artists": artists,
        "album": album_name,
        "album_id": album_id,
        "duration": duration,
        "play_count": play_count,
        "track_count": track_count,
        "action": action,
        "source": "netease",
    })
}

fn map_home_banner(banner: &Value) -> Value {
    let id = banner.get("targetId").map(value_string).unwrap_or_default();
    let cover = banner
        .get("pic")
        .and_then(Value::as_str)
        .map(normalize_https)
        .unwrap_or_default();
    let title = banner
        .get("typeTitle")
        .and_then(Value::as_str)
        .or_else(|| banner.get("mainTitle").and_then(Value::as_str))
        .unwrap_or("")
        .to_string();
    json!({
        "kind": "banner",
        "id": id,
        "title": title,
        "subtitle": "",
        "cover": cover,
        "section": "",
        "artists": "",
        "album": "",
        "album_id": "",
        "duration": 0,
        "play_count": 0,
        "track_count": 0,
        "action": banner.get("url").and_then(Value::as_str).unwrap_or(""),
        "source": "netease",
    })
}

#[derive(Debug, Deserialize)]
struct ListParams {
    id: Option<String>,
    page: Option<u32>,
    limit: Option<i64>,
    toplist_id: Option<String>,
}

async fn playlist_detail(
    State(state): State<SharedState>,
    Query(params): Query<ListParams>,
) -> ApiResult {
    let id = params
        .id
        .as_deref()
        .ok_or_else(|| api_error(StatusCode::BAD_REQUEST, "missing playlist id"))?;
    let client = state.client.lock().await;
    let response = client
        .playlist_detail(&NcmQuery::new().param("id", id))
        .await
        .map_err(ncm_error)?;
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": array_at(&response.body, "/playlist/tracks")
            .into_iter()
            .map(|item| map_ne_song(&item))
            .collect::<Vec<_>>(),
    })))
}

async fn album_detail(
    State(state): State<SharedState>,
    Query(params): Query<ListParams>,
) -> ApiResult {
    let id = params
        .id
        .as_deref()
        .ok_or_else(|| api_error(StatusCode::BAD_REQUEST, "missing album id"))?;
    let client = state.client.lock().await;
    let response = client
        .album(&NcmQuery::new().param("id", id))
        .await
        .map_err(ncm_error)?;
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": array_at(&response.body, "/songs")
            .into_iter()
            .map(|item| map_ne_song(&item))
            .collect::<Vec<_>>(),
    })))
}

async fn radar_playlists(
    State(state): State<SharedState>,
    Query(params): Query<ListParams>,
) -> ApiResult {
    let limit = params.limit.unwrap_or(30).clamp(1, 50);
    let limit_text = limit.to_string();
    let client = state.client.lock().await;
    let response = client
        .search(
            &NcmQuery::new()
                .param("keywords", "雷达")
                .param("type", "1000")
                .param("limit", &limit_text)
                .param("offset", "0"),
        )
        .await
        .map_err(ncm_error)?;
    let mut playlists = array_at(&response.body, "/result/playlists");
    // 部分官方雷达在通用“雷达”搜索中会排在 50 条之后，逐个补搜。
    for keyword in ["会员雷达", "怀旧雷达", "时光雷达", "云村高分雷达"] {
        if let Ok(extra) = client
            .search(
                &NcmQuery::new()
                    .param("keywords", keyword)
                    .param("type", "1000")
                    .param("limit", "8")
                    .param("offset", "0"),
            )
            .await
        {
            let mut seen = playlists
                .iter()
                .filter_map(|item| item.get("id").map(value_string))
                .collect::<std::collections::HashSet<_>>();
            for item in array_at(&extra.body, "/result/playlists") {
                if let Some(id) = item.get("id") {
                    if seen.insert(value_string(id)) {
                        playlists.push(item);
                    }
                }
            }
        }
    }
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": {
            "playlists": playlists
                .into_iter()
                .map(|item| map_ne_playlist(&item))
                .collect::<Vec<_>>(),
        }
    })))
}

async fn user_playlists(
    State(state): State<SharedState>,
    Query(params): Query<ListParams>,
) -> ApiResult {
    let client = state.client.lock().await;
    let status = match client.login_status(&NcmQuery::new()).await {
        Ok(response) => response,
        Err(_) => return Ok(empty_playlists()),
    };
    let Some(uid) = status
        .body
        .pointer("/profile/userId")
        .and_then(Value::as_i64)
    else {
        return Ok(empty_playlists());
    };
    let limit = params.limit.unwrap_or(30).clamp(1, 100);
    let page = params.page.unwrap_or(1).max(1);
    let offset = (page as i64 - 1) * limit;
    let uid_text = uid.to_string();
    let limit_text = limit.to_string();
    let offset_text = offset.to_string();
    let response = client
        .user_playlist(
            &NcmQuery::new()
                .param("uid", &uid_text)
                .param("limit", &limit_text)
                .param("offset", &offset_text),
        )
        .await
        .map_err(ncm_error)?;
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": {
            "playlists": array_at(&response.body, "/playlist")
                .into_iter()
                .map(|item| map_ne_playlist(&item))
                .collect::<Vec<_>>()
        }
    })))
}

async fn recommend_playlists(
    State(state): State<SharedState>,
    Query(_params): Query<ListParams>,
) -> ApiResult {
    let client = state.client.lock().await;
    let response = client
        .personalized(&NcmQuery::new().param("limit", "20"))
        .await
        .map_err(ncm_error)?;
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": array_at(&response.body, "/result")
            .into_iter()
            .map(|item| map_ne_playlist(&item))
            .collect::<Vec<_>>()
    })))
}

async fn top_lists(
    State(state): State<SharedState>,
    Query(_params): Query<ListParams>,
) -> ApiResult {
    let client = state.client.lock().await;
    let response = client.toplist(&NcmQuery::new()).await.map_err(ncm_error)?;
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": {
            "toplists": array_at(&response.body, "/list")
                .into_iter()
                .map(|item| map_ne_toplist(&item))
                .collect::<Vec<_>>()
        }
    })))
}

async fn top_list_songs(
    State(state): State<SharedState>,
    Query(params): Query<ListParams>,
) -> ApiResult {
    let id = params
        .toplist_id
        .as_deref()
        .or(params.id.as_deref())
        .ok_or_else(|| api_error(StatusCode::BAD_REQUEST, "missing toplist id"))?;
    let client = state.client.lock().await;
    let response = client
        .playlist_detail(&NcmQuery::new().param("id", id))
        .await
        .map_err(ncm_error)?;
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": {
            "songs": array_at(&response.body, "/playlist/tracks")
                .into_iter()
                .map(|item| map_ne_song(&item))
                .collect::<Vec<_>>()
        }
    })))
}

async fn hot_songs(
    State(state): State<SharedState>,
    Query(params): Query<ListParams>,
) -> ApiResult {
    let limit = params.limit.unwrap_or(20).clamp(1, 100);
    let client = state.client.lock().await;
    let response = client
        .top_song(&NcmQuery::new().param("type", "0"))
        .await
        .map_err(ncm_error)?;
    let songs = array_at(&response.body, "/data")
        .into_iter()
        .take(limit as usize)
        .map(|item| map_ne_song(&item))
        .collect::<Vec<_>>();
    Ok(Json(json!({
        "code": 200,
        "msg": "ok",
        "data": { "songs": songs }
    })))
}

fn empty_playlists() -> Json<Value> {
    Json(json!({
        "code": 200,
        "msg": "ok",
        "data": { "playlists": [] }
    }))
}

fn array_at(value: &Value, path: &str) -> Vec<Value> {
    value
        .pointer(path)
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
}

fn map_search_body(body: &Value) -> Value {
    let result = body.get("result").unwrap_or(body);
    let mut data = serde_json::Map::new();
    if let Some(songs) = result.get("songs").and_then(Value::as_array) {
        data.insert(
            "songs".to_string(),
            Value::Array(songs.iter().map(map_ne_song).collect()),
        );
    }
    if let Some(playlists) = result.get("playlists").and_then(Value::as_array) {
        data.insert(
            "playlists".to_string(),
            Value::Array(playlists.iter().map(map_ne_playlist).collect()),
        );
    }
    if let Some(albums) = result.get("albums").and_then(Value::as_array) {
        data.insert(
            "albums".to_string(),
            Value::Array(albums.iter().map(map_ne_album).collect()),
        );
    }
    Value::Object(data)
}

fn map_ne_song(song: &Value) -> Value {
    let id = first_value(song, &["id"]);
    let name = first_string(song, &["name"]);
    let artists = song
        .get("ar")
        .or_else(|| song.get("artists"))
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(|item| item.get("name").and_then(Value::as_str))
                .collect::<Vec<_>>()
                .join("/")
        })
        .unwrap_or_default();
    let album = song.get("al").or_else(|| song.get("album"));
    let album_name = album
        .and_then(|value| value.get("name"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let album_id = album
        .and_then(|value| value.get("id"))
        .map(value_string)
        .unwrap_or_default();
    let cover = album
        .and_then(|value| value.get("picUrl"))
        .and_then(Value::as_str)
        .map(normalize_https)
        .unwrap_or_default();
    let dt = first_i64(song, &["dt", "duration"]).unwrap_or(0);
    let duration = if dt > 1000 { dt / 1000 } else { dt };
    let quality = song
        .get("h")
        .or_else(|| song.get("m"))
        .or_else(|| song.get("l"));
    let bitrate = quality
        .and_then(|value| value.get("br"))
        .and_then(Value::as_i64)
        .map(|value| value / 1000)
        .unwrap_or(0);
    let size = quality
        .and_then(|value| value.get("size"))
        .and_then(Value::as_i64)
        .unwrap_or(0);
    let fee = first_i64(song, &["fee"])
        .or_else(|| song.pointer("/privilege/fee").and_then(Value::as_i64))
        .unwrap_or(0);
    let platform_id = value_string(&id);
    json!({
        "id": platform_id,
        "name": name,
        "artist": artists,
        "album": album_name,
        "album_id": album_id,
        "duration": duration,
        "size": size,
        "bitrate": bitrate,
        "source": "netease",
        "cover": cover,
        "link": format!("https://music.163.com/song?id={}", value_string(&id)),
        "is_vip": fee == 1 || fee == 4,
        "extra": {
            "platformId": value_string(&id),
            "songId": value_string(&id),
            "source": "netease",
        }
    })
}

fn map_ne_playlist(item: &Value) -> Value {
    json!({
        "id": first_string(item, &["id"]),
        "name": first_string(item, &["name", "title"]),
        "cover": normalize_https(
            &first_string(item, &["coverImgUrl", "coverUrl", "picUrl", "pic"])
        ),
        "track_count": first_i64(item, &["trackCount", "songCount", "songnum"]).unwrap_or(0),
        "play_count": first_i64(item, &["playCount", "playcount", "listennum"]).unwrap_or(0),
        "creator": item.pointer("/creator/nickname")
            .and_then(Value::as_str)
            .unwrap_or(""),
        "description": first_string(item, &["description", "desc"]),
        "source": "netease",
        "link": format!("https://music.163.com/playlist?id={}", first_string(item, &["id"])),
    })
}

fn map_ne_album(item: &Value) -> Value {
    json!({
        "id": first_string(item, &["id"]),
        "name": first_string(item, &["name"]),
        "cover": normalize_https(
            &first_string(item, &["picUrl", "coverImgUrl", "coverUrl", "blurPicUrl"])
        ),
        "track_count": first_i64(item, &["trackCount", "size", "songCount"]).unwrap_or(0),
        "play_count": 0,
        "creator": item.pointer("/artist/name")
            .and_then(Value::as_str)
            .unwrap_or(""),
        "description": first_string(item, &["description"]),
        "source": "netease",
    })
}

fn map_ne_toplist(item: &Value) -> Value {
    json!({
        "id": first_string(item, &["id"]),
        "name": first_string(item, &["name"]),
        "cover": normalize_https(
            &first_string(item, &["coverImgUrl", "picUrl", "coverUrl"])
        ),
        "description": first_string(item, &["description"]),
        "update_frequency": first_string(item, &["updateFrequency"]),
        "track_count": first_i64(item, &["trackCount", "songCount"]).unwrap_or(0),
        "play_count": first_i64(item, &["playCount", "playcount"]).unwrap_or(0),
        "source": "netease",
    })
}

fn first_value(value: &Value, keys: &[&str]) -> Value {
    for key in keys {
        if let Some(item) = value.get(*key) {
            return item.clone();
        }
    }
    Value::Null
}

fn value_string(value: &Value) -> String {
    match value {
        Value::String(text) => text.clone(),
        Value::Number(number) => number.to_string(),
        _ => String::new(),
    }
}

fn first_string(value: &Value, keys: &[&str]) -> String {
    for key in keys {
        if let Some(item) = value.get(*key) {
            let result = value_string(item);
            if !result.is_empty() {
                return result;
            }
        }
    }
    String::new()
}

fn first_i64(value: &Value, keys: &[&str]) -> Option<i64> {
    keys.iter().find_map(|key| {
        value.get(*key).and_then(|item| {
            item.as_i64()
                .or_else(|| item.as_str().and_then(|text| text.parse().ok()))
        })
    })
}

fn normalize_https(value: &str) -> String {
    value
        .strip_prefix("http://")
        .map(|rest| format!("https://{rest}"))
        .unwrap_or_else(|| value.to_string())
}

const DEVICE_XOR_KEY: &str = "3go8&$8*3*3h0k(2)2";

async fn register_guest(client: &mut ApiClient) -> Option<String> {
    let device_id = generate_device_id();
    let encoded =
        BASE64.encode(format!("{} {}", device_id, cloudmusic_dll_encode_id(&device_id)).as_bytes());
    let response = client
        .request(
            "/api/register/anonimous",
            json!({ "username": encoded }),
            RequestOption::default(),
        )
        .await
        .ok()?;
    let cookie = extract_cookie(&response)?;
    client.set_cookie(cookie.clone());
    client.set_anonymous_token(cookie.clone());
    Some(cookie)
}

fn cloudmusic_dll_encode_id(device_id: &str) -> String {
    let key = DEVICE_XOR_KEY.as_bytes();
    let xored: Vec<u8> = device_id
        .bytes()
        .enumerate()
        .map(|(index, byte)| byte ^ key[index % key.len()])
        .collect();
    BASE64.encode(Md5::digest(&xored))
}

fn extract_str(value: &Value, paths: &[&str]) -> Option<String> {
    paths.iter().find_map(|path| {
        value
            .pointer(path)
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_string)
    })
}

fn extract_cookie(response: &ApiResponse) -> Option<String> {
    let mut pairs = Vec::new();
    for cookie in &response.cookie {
        let pair = cookie.split(';').next().unwrap_or("").trim();
        if !pair.is_empty() {
            pairs.push(pair.to_string());
        }
    }
    if !pairs.is_empty() {
        return Some(pairs.join("; "));
    }
    response
        .body
        .get("cookie")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
}

fn save_cookie(path: &Path, cookie: &str) -> Result<(), (StatusCode, Json<Value>)> {
    fs::write(path, cookie).map_err(|error| {
        api_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to save cookies: {error}"),
        )
    })?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(path, fs::Permissions::from_mode(0o600));
    }
    Ok(())
}

fn api_error(status: StatusCode, message: impl Into<String>) -> (StatusCode, Json<Value>) {
    (
        status,
        Json(json!({
            "code": status.as_u16(),
            "msg": message.into(),
        })),
    )
}

fn ncm_error(error: NcmError) -> (StatusCode, Json<Value>) {
    match error {
        NcmError::AuthRequired(message) => api_error(StatusCode::UNAUTHORIZED, message),
        NcmError::InvalidParam(message) => api_error(StatusCode::BAD_REQUEST, message),
        NcmError::RateLimited(message) => api_error(StatusCode::TOO_MANY_REQUESTS, message),
        NcmError::Timeout(message) => api_error(StatusCode::GATEWAY_TIMEOUT, message),
        NcmError::Api { code, msg } => {
            let status = StatusCode::from_u16(code as u16).unwrap_or(StatusCode::BAD_GATEWAY);
            api_error(status, msg)
        }
        other => api_error(StatusCode::BAD_GATEWAY, other.to_string()),
    }
}

async fn authorize(
    State(state): State<SharedState>,
    request: axum::extract::Request,
    next: Next,
) -> Response {
    if !state.token.is_empty() {
        let provided = request
            .headers()
            .get(AUTHORIZATION)
            .and_then(|value| value.to_str().ok())
            .and_then(|value| value.strip_prefix("Bearer "))
            .unwrap_or("");
        let matches = bool::from(provided.as_bytes().ct_eq(state.token.as_bytes()));
        if !matches {
            return (
                StatusCode::UNAUTHORIZED,
                Json(json!({"code": 401, "msg": "unauthorized"})),
            )
                .into_response();
        }
    }
    next.run(request).await
}

async fn log_request(request: axum::extract::Request, next: Next) -> Response {
    let method = request.method().clone();
    let path = request.uri().path().to_string();
    let started = Instant::now();
    let response = next.run(request).await;
    tracing::info!(
        "{} {} -> {} ({:.1?})",
        method,
        path,
        response.status().as_u16(),
        started.elapsed()
    );
    response
}

fn spawn_parent_watchdog() {
    let Ok(raw) = env::var("LAETIBEAT_MUSICAPI_PARENT_PID") else {
        return;
    };
    let Ok(parent_pid) = raw.trim().parse::<u32>() else {
        return;
    };
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(Duration::from_secs(3)).await;
            if current_ppid() != Some(parent_pid) {
                tracing::warn!("parent process disappeared, exiting");
                std::process::exit(0);
            }
        }
    });
}

fn current_ppid() -> Option<u32> {
    let stat = fs::read_to_string("/proc/self/stat").ok()?;
    let rest = stat.rsplit_once(')')?.1;
    rest.split_whitespace().nth(1)?.parse().ok()
}

async fn shutdown_signal() {
    #[cfg(unix)]
    {
        let mut terminate =
            tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
                .expect("install SIGTERM handler");
        tokio::select! {
            _ = tokio::signal::ctrl_c() => {}
            _ = terminate.recv() => {}
        }
    }
    #[cfg(not(unix))]
    {
        let _ = tokio::signal::ctrl_c().await;
    }
}

fn env_first(names: &[&str]) -> Option<String> {
    names.iter().find_map(|name| {
        env::var(name)
            .ok()
            .map(|value| value.trim().to_string())
            .filter(|value| !value.is_empty())
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn maps_home_feed_blocks_and_resources() {
        let body = json!({
            "data": {
                "cursor": "next-page",
                "blocks": [
                    {
                        "blockCode": "HOMEPAGE_BLOCK_MGC_PLAYLIST",
                        "showType": "HOMEPAGE_SLIDE_PLAYLIST",
                        "uiElement": {"subTitle": {"title": "网易云音乐的雷达歌单"}},
                        "creatives": [
                            {
                                "uiElement": {"mainTitle": {"title": ""}},
                                "resources": [
                                    {
                                        "resourceType": "list",
                                        "resourceId": "123",
                                        "uiElement": {
                                            "mainTitle": {"title": "华语私人雷达"},
                                            "subTitle": {"title": "每日更新"},
                                            "image": {"imageUrl": "http://example.com/cover.jpg"}
                                        },
                                        "resourceExtInfo": {"playCount": 42, "songCount": 30}
                                    }
                                ]
                            }
                        ]
                    }
                ]
            }
        });

        let mapped = map_home_feed(&body);
        assert_eq!(mapped["cursor"], "next-page");
        assert_eq!(mapped["blocks"][0]["code"], "HOMEPAGE_BLOCK_MGC_PLAYLIST");
        assert_eq!(mapped["blocks"][0]["title"], "网易云音乐的雷达歌单");
        assert_eq!(mapped["blocks"][0]["items"][0]["kind"], "list");
        assert_eq!(mapped["blocks"][0]["items"][0]["id"], "123");
        assert_eq!(
            mapped["blocks"][0]["items"][0]["cover"],
            "https://example.com/cover.jpg"
        );
        assert_eq!(mapped["blocks"][0]["items"][0]["play_count"], 42);
    }
}
