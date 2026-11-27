use std::collections::HashMap;
use std::env;
use std::fs;
use std::io::Write;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
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
use qqmusic_api::models::base::{CoverSize, Song};
use qqmusic_api::models::login::{QrCode, QrCodeLoginEvent, QrLoginType};
use qqmusic_api::modules::search::{SearchOptions, SearchType};
use qqmusic_api::modules::song::Quality;
use qqmusic_api::{Client, Credential};
use serde::Deserialize;
use serde_json::{json, Value};
use subtle::ConstantTimeEq;
use tokio::net::TcpListener;
use tokio::sync::Mutex;

const LISTEN_PREFIX: &str = "LAETIBEAT_MUSICAPI_LISTEN=";
const DEFAULT_ADDR: &str = "127.0.0.1:0";
const DEFAULT_DATA_DIR: &str = ".laetibeat-qq";

struct HostState {
    client: Client,
    token: String,
    credential_path: PathBuf,
    qr_sessions: Mutex<HashMap<String, QrCode>>,
}

type SharedState = Arc<HostState>;
type ApiResult = Result<Json<Value>, (StatusCode, Json<Value>)>;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "laetibeat_qq_host=info".into()),
        )
        .with_writer(std::io::stderr)
        .init();

    if let Err(error) = run().await {
        eprintln!("laetibeat qq host: {error}");
        std::process::exit(1);
    }
}

async fn run() -> Result<(), Box<dyn std::error::Error>> {
    let data_dir = PathBuf::from(
        env_first(&["LAETIBEAT_QQ_DATA_DIR", "LAETIBEAT_MUSICAPI_DATA_DIR"])
            .unwrap_or_else(|| DEFAULT_DATA_DIR.to_string()),
    );
    fs::create_dir_all(&data_dir)?;

    let credential_path = data_dir.join("credential.json");
    let device_path = data_dir.join("device.json");

    let mut builder = Client::builder().device_path(device_path);
    if let Ok(text) = fs::read_to_string(&credential_path) {
        match Credential::from_json_str(&text) {
            Ok(credential) => {
                tracing::info!("loaded QQ credential for musicid={}", credential.musicid);
                builder = builder.credential(credential);
            }
            Err(error) => tracing::warn!("cannot parse credential.json: {error}"),
        }
    }
    let client = builder.build()?;

    let token = env_first(&["LAETIBEAT_QQ_TOKEN", "LAETIBEAT_MUSICAPI_TOKEN"]).unwrap_or_default();
    let addr: SocketAddr = env_first(&["LAETIBEAT_QQ_ADDR", "LAETIBEAT_MUSICAPI_ADDR"])
        .unwrap_or_else(|| DEFAULT_ADDR.to_string())
        .parse()?;
    if token.is_empty() && !addr.ip().is_loopback() {
        return Err("refusing to listen on a non-loopback address without a token".into());
    }

    let state = Arc::new(HostState {
        client,
        token,
        credential_path,
        qr_sessions: Mutex::new(HashMap::new()),
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
    tracing::info!("QQ host listening on http://{actual}");

    spawn_parent_watchdog();
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    Ok(())
}

async fn health(State(state): State<SharedState>) -> ApiResult {
    Ok(Json(json!({
        "status": "ok",
        "source": "qq",
        "logged_in": state.client.credential().musicid > 0,
    })))
}

#[derive(Debug, Deserialize)]
struct SearchParams {
    q: String,
    #[serde(rename = "type")]
    kind: Option<String>,
    limit: Option<i64>,
    page: Option<i64>,
}

async fn search(State(state): State<SharedState>, Query(params): Query<SearchParams>) -> ApiResult {
    let kind = params.kind.as_deref().unwrap_or("song");
    let search_type = match kind {
        "song" => SearchType::Song,
        "playlist" => SearchType::SongList,
        "album" => SearchType::Album,
        other => {
            return Err(api_error(
                StatusCode::BAD_REQUEST,
                format!("unsupported type: {other}"),
            ))
        }
    };
    let options = SearchOptions {
        search_type,
        num: params.limit.unwrap_or(10).clamp(1, 50),
        page: params.page.unwrap_or(1).max(1),
        ..SearchOptions::default()
    };
    let page = state
        .client
        .search()
        .search_by_type_with(&params.q, options)
        .await
        .map_err(upstream_error)?;

    let data = match search_type {
        SearchType::Song => json!({
            "songs": page.song.iter().map(|item| map_song(&item.song)).collect::<Vec<_>>(),
        }),
        SearchType::SongList => json!({
            "playlists": page.songlist.iter().map(map_playlist).collect::<Vec<_>>(),
        }),
        SearchType::Album => json!({
            "albums": page.album.iter().map(map_album).collect::<Vec<_>>(),
        }),
        _ => unreachable!(),
    };
    Ok(Json(json!({ "code": 0, "msg": "ok", "data": data })))
}

#[derive(Debug, Deserialize)]
struct UrlParams {
    mid: String,
    quality: Option<String>,
}

async fn song_url(State(state): State<SharedState>, Query(params): Query<UrlParams>) -> ApiResult {
    let quality = params
        .quality
        .as_deref()
        .and_then(Quality::parse)
        .unwrap_or(Quality::High);
    let resolved = state
        .client
        .song()
        .playable_url(&params.mid, None, quality)
        .await
        .map_err(upstream_error)?;
    match resolved {
        Some(item) => {
            let ext = item
                .filename
                .rsplit_once('.')
                .map(|(_, ext)| ext)
                .unwrap_or("");
            Ok(Json(json!({
                "code": 0,
                "msg": "ok",
                "data": {
                    "url": item.url,
                    "quality": item.quality.as_str(),
                    "filename": item.filename,
                    "ext": ext,
                    "source": "qq",
                }
            })))
        }
        None => Err(api_error(
            StatusCode::NOT_FOUND,
            "no playable URL (VIP, copyright or unavailable)",
        )),
    }
}

#[derive(Debug, Deserialize)]
struct LyricParams {
    mid: String,
}

async fn lyric(State(state): State<SharedState>, Query(params): Query<LyricParams>) -> ApiResult {
    let response = state
        .client
        .lyric()
        .get_lyric(params.mid.as_str())
        .await
        .map_err(upstream_error)?;
    Ok(Json(json!({
        "code": 0,
        "msg": "ok",
        "data": {
            "lyric": response.lyric,
            "trans": response.trans,
            "roma": response.roma,
            "source": "qq",
        }
    })))
}

#[derive(Debug, Deserialize)]
struct QrParams {
    #[serde(rename = "type")]
    kind: Option<String>,
}

async fn qr_create(State(state): State<SharedState>, Query(params): Query<QrParams>) -> ApiResult {
    let login_type = parse_login_type(params.kind.as_deref().unwrap_or("qq"))?;
    let qr = state
        .client
        .login()
        .get_qrcode(login_type)
        .await
        .map_err(upstream_error)?;
    let identifier = qr.identifier.clone();
    state
        .qr_sessions
        .lock()
        .await
        .insert(identifier.clone(), qr.clone());
    Ok(Json(json!({
        "code": 0,
        "msg": "ok",
        "data": {
            "identifier": identifier,
            "mimetype": qr.mimetype,
            "image_base64": BASE64.encode(&qr.data),
            "source": "qq",
            "login_type": login_type.as_str(),
        }
    })))
}

#[derive(Debug, Deserialize)]
struct QrStatusParams {
    identifier: String,
}

async fn qr_status(
    State(state): State<SharedState>,
    Query(params): Query<QrStatusParams>,
) -> ApiResult {
    let qr = state
        .qr_sessions
        .lock()
        .await
        .get(&params.identifier)
        .cloned()
        .ok_or_else(|| api_error(StatusCode::NOT_FOUND, "QR session not found"))?;
    if qr.qr_type == QrLoginType::Mobile {
        return Err(api_error(
            StatusCode::BAD_REQUEST,
            "mobile QR polling is not wired yet",
        ));
    }

    let result = state
        .client
        .login()
        .check_qrcode(&qr)
        .await
        .map_err(upstream_error)?;
    let (status, message, saved) = match result.event {
        QrCodeLoginEvent::Done => {
            let credential = result.credential.ok_or_else(|| {
                api_error(
                    StatusCode::BAD_GATEWAY,
                    "login succeeded without credential",
                )
            })?;
            save_credential(&state.credential_path, &credential)?;
            state.client.set_credential(credential);
            state.qr_sessions.lock().await.remove(&params.identifier);
            ("success", "登录成功", true)
        }
        QrCodeLoginEvent::Scan => ("scanned", "已扫码，请在手机上确认", false),
        QrCodeLoginEvent::Conf => ("confirmed", "已确认，正在登录", false),
        QrCodeLoginEvent::Timeout => ("expired", "二维码已过期", false),
        QrCodeLoginEvent::Refuse => ("failed", "登录被拒绝", false),
    };
    Ok(Json(json!({
        "code": 0,
        "msg": "ok",
        "data": {
            "status": status,
            "message": message,
            "cookie_saved": saved,
            "source": "qq",
        }
    })))
}

fn map_song(song: &Song) -> Value {
    let (size, bitrate) = if song.file.size_flac > 0 {
        (song.file.size_flac, 900)
    } else if song.file.size_320mp3 > 0 {
        (song.file.size_320mp3, 320)
    } else {
        (song.file.size_128mp3, 128)
    };
    json!({
        "id": song.mid,
        "name": song.name,
        "artist": song.singer_names(),
        "album": song.album.name,
        "album_id": song.album.mid,
        "duration": song.interval,
        "size": size,
        "bitrate": bitrate,
        "source": "qq",
        "cover": song.cover_url(CoverSize::S300),
        "is_vip": song.requires_vip(),
        "extra": {
            "songmid": song.mid,
            "media_mid": song.file.media_mid,
            "song_id": song.id,
            "source": "qq",
        }
    })
}

fn map_playlist(item: &qqmusic_api::models::search::SongListSearch) -> Value {
    json!({
        "id": item.songlist.id.to_string(),
        "name": item.songlist.title,
        "cover": item.songlist.picurl,
        "track_count": item.songlist.songnum,
        "play_count": item.songlist.listennum,
        "creator": item.nickname,
        "description": item.songlist.desc,
        "source": "qq",
        "extra": {
            "dirid": item.songlist.dirid,
            "source": "qq",
        }
    })
}

fn map_album(item: &qqmusic_api::models::search::AlbumSearch) -> Value {
    let artist = if !item.singer.is_empty() {
        item.singer.clone()
    } else {
        item.singer_list
            .iter()
            .map(|singer| singer.name.as_str())
            .collect::<Vec<_>>()
            .join("/")
    };
    json!({
        "id": item.album.mid,
        "name": item.album.name,
        "artist": artist,
        "cover": item.album.cover_url(CoverSize::S300),
        "track_count": 0,
        "description": item.description,
        "source": "qq",
        "extra": {
            "album_id": item.album.id,
            "source": "qq",
        }
    })
}

fn parse_login_type(value: &str) -> Result<QrLoginType, (StatusCode, Json<Value>)> {
    match value.to_ascii_lowercase().as_str() {
        "qq" => Ok(QrLoginType::Qq),
        "wx" | "wechat" => Ok(QrLoginType::Wx),
        "mobile" | "app" => Ok(QrLoginType::Mobile),
        other => Err(api_error(
            StatusCode::BAD_REQUEST,
            format!("unsupported login type: {other}"),
        )),
    }
}

fn save_credential(path: &Path, credential: &Credential) -> Result<(), (StatusCode, Json<Value>)> {
    let text = credential.to_json_string();
    fs::write(path, text).map_err(|error| {
        api_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to save credential: {error}"),
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

fn upstream_error(error: qqmusic_api::Error) -> (StatusCode, Json<Value>) {
    api_error(
        StatusCode::BAD_GATEWAY,
        format!("QQ upstream error: {error}"),
    )
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
