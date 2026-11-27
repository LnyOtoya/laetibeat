use std::env;
use std::fs;
use std::io::Write;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use axum::extract::{DefaultBodyLimit, Query, State};
use axum::http::{header::AUTHORIZATION, StatusCode};
use axum::middleware::{self, Next};
use axum::response::{IntoResponse, Response};
use axum::routing::get;
use axum::{Json, Router};
use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine;
use md5::{Digest, Md5};
use ncm_api_rs::util::device::generate_device_id;
use ncm_api_rs::{
    create_client, ApiClient, ApiResponse, NcmError, Query as NcmQuery, RequestOption,
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
        "code": 0,
        "msg": "ok",
        "data": response.body,
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
        "high" => "exhigh",
        "standard" => "standard",
        "lossless" => "lossless",
        "hires" => "hires",
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
        "code": 0,
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
        "code": 0,
        "msg": "ok",
        "data": {
            "lyric": lyric,
            "trans": trans,
            "source": "netease",
        }
    })))
}

async fn qr_create(State(state): State<SharedState>) -> ApiResult {
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
    Ok(Json(json!({
        "code": 0,
        "msg": "ok",
        "data": {
            "key": key,
            "qrurl": qrurl,
            "qrimg": qrimg,
            "source": "netease",
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
    let query = NcmQuery::new().param("key", &params.key);
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
    Ok(Json(json!({
        "code": 0,
        "msg": "ok",
        "data": {
            "status": status,
            "message": message,
            "cookie_saved": saved,
            "source": "netease",
        }
    })))
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
