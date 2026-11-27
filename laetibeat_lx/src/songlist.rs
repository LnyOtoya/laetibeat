use std::collections::BTreeMap;
use std::time::{Duration, Instant};

use reqwest::blocking::Client;
use serde_json::{json, Value};

use crate::error::{LxError, Result};
use crate::search::{
    eapi_json, insert_quality_types, kw_quality_types, mg_quality_types, mg_sign,
    ordered_quality_types, tx_quality_types, wy_quality_types, LxSearchTrack, MG_DEVICE_ID,
};
use crate::utils::decode_text;

const USER_AGENT: &str = "Mozilla/5.0 (Linux; U; Android 11.0.0; zh-cn; MI 11) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30";
const MAX_RESPONSE_BYTES: usize = 5 * 1024 * 1024;
const MAX_LIMIT: u32 = 100;
/// QQ occasionally answers `code != 0` (anti-bot / transient upstream error).
/// The reference client retries up to 5 times; three attempts is enough here.
const TX_SEARCH_ATTEMPTS: u32 = 3;
/// Platforms with a playlist search implementation.
pub const PLAYLIST_SEARCH_PLATFORMS: &[&str] = &["kw", "kg", "tx", "wy", "mg"];
const MG_UA: &str = "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) \
AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1";
const MG_REFERER: &str = "https://m.music.migu.cn/";
const MG_PLAYLIST_SWITCH: &str = r#"{"song":0,"album":0,"singer":0,"tagSong":0,"mvSong":0,"bestShow":0,"songlist":1,"lyricSong":0}"#;
/// NetEase returns only 10 tracks from the playlist detail API, so the remaining
/// ids are fetched in batches from `/api/v3/song/detail`.
const WY_TRACK_BATCH: usize = 200;
/// Migu silently caps `pageSize` at 50, so ask for exactly that.
const MG_PLAYLIST_PAGE_SIZE: u32 = 50;

/// Page size used when fetching a whole playlist. Migu needs its smaller cap so
/// that page numbers line up with what the server actually returns.
fn playlist_all_page_limit(platform: &str) -> u32 {
    if platform == "mg" {
        MG_PLAYLIST_PAGE_SIZE
    } else {
        1000
    }
}

/// Whether playlist search/detail is implemented for `platform`.
pub fn supports_playlist_search(platform: &str) -> bool {
    PLAYLIST_SEARCH_PLATFORMS.contains(&platform)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LxPlaylistSummary {
    pub source: String,
    pub id: String,
    pub name: String,
    pub author: String,
    pub cover_url: Option<String>,
    pub play_count: String,
    pub total: u64,
    pub description: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LxPlaylistDetail {
    pub info: LxPlaylistSummary,
    pub tracks: Vec<LxSearchTrack>,
    pub page: u32,
    pub limit: u32,
    pub total: u64,
    pub has_more: bool,
}

/// Search playlists on one platform.
///
/// Every attempt is logged with platform / page / keyword length / result count
/// and elapsed time, so a silent "no results" can be told apart from a request
/// failure when debugging on device.
pub fn search_playlists(
    platform: &str,
    keyword: &str,
    page: u32,
    limit: u32,
) -> Result<Vec<LxPlaylistSummary>> {
    let started = Instant::now();
    let page = page.max(1);
    let limit = limit.clamp(1, MAX_LIMIT);
    let keyword_len = keyword.trim().chars().count();
    let result = search_playlists_inner(platform, keyword, page, limit);
    match &result {
        Ok(items) => log::info!(
            "lx.playlist.search platform={platform} page={page} limit={limit} \
             keyword_len={keyword_len} items={} elapsed={}ms",
            items.len(),
            started.elapsed().as_millis()
        ),
        Err(error) => log::warn!(
            "lx.playlist.search platform={platform} page={page} limit={limit} \
             keyword_len={keyword_len} failed in {}ms: {error}",
            started.elapsed().as_millis()
        ),
    }
    result
}

fn search_playlists_inner(
    platform: &str,
    keyword: &str,
    page: u32,
    limit: u32,
) -> Result<Vec<LxPlaylistSummary>> {
    let keyword = keyword.trim();
    if keyword.is_empty() {
        return Ok(Vec::new());
    }
    let page = page.max(1);
    let limit = limit.clamp(1, MAX_LIMIT);
    let client = client()?;
    match platform {
        "kg" => return search_kg_playlists(&client, keyword, page, limit),
        "tx" => return search_tx_playlists(&client, keyword, page, limit),
        "wy" => return search_wy_playlists(&client, keyword, page, limit),
        "mg" => return search_mg_playlists(&client, keyword, page, limit),
        // kw is handled inline below.
        "kw" => {}
        other => {
            return Err(LxError::Request(format!(
                "playlist search is not implemented: {other}"
            )));
        }
    }
    let body = get_text(client.get("http://search.kuwo.cn/r.s").query(&[
        ("all", keyword),
        ("pn", &(page - 1).to_string()),
        ("rn", &limit.to_string()),
        ("rformat", "json"),
        ("encoding", "utf8"),
        ("ver", "mbox"),
        ("vipver", "MUSIC_8.7.7.0_BCS37"),
        ("plat", "pc"),
        ("devid", "28156413"),
        ("ft", "playlist"),
        ("pay", "0"),
        ("needliveshow", "0"),
    ]))?;
    let parsed: Value = serde_json::from_str(&js_object_to_json(&body))
        .map_err(|error| LxError::Request(format!("parse kw playlists: {error}")))?;
    let mut result = Vec::new();
    for item in parsed
        .get("abslist")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        if item.get("DC_TARGETTYPE").and_then(Value::as_str) != Some("songlist") {
            continue;
        }
        let Some(id) = item.get("playlistid").and_then(value_string) else {
            continue;
        };
        let Some(name) = item.get("name").and_then(Value::as_str) else {
            continue;
        };
        result.push(LxPlaylistSummary {
            source: "kw".to_string(),
            id,
            name: clean(name),
            author: clean(item.get("nickname").and_then(Value::as_str).unwrap_or("")),
            cover_url: item
                .get("pic")
                .or_else(|| item.get("hts_pic"))
                .and_then(Value::as_str)
                .map(str::to_string),
            play_count: item
                .get("playcnt")
                .and_then(value_string)
                .unwrap_or_default(),
            total: item.get("songnum").and_then(value_u64).unwrap_or(0),
            description: clean(item.get("intro").and_then(Value::as_str).unwrap_or("")),
        });
    }
    Ok(result)
}

/// Load one page of a playlist's tracks.
pub fn get_playlist_detail(
    platform: &str,
    playlist_id: &str,
    page: u32,
    limit: u32,
) -> Result<LxPlaylistDetail> {
    let started = Instant::now();
    let page = page.max(1);
    let limit = limit.clamp(1, 1000);
    let result = get_playlist_detail_inner(platform, playlist_id, page, limit);
    match &result {
        Ok(detail) => log::info!(
            "lx.playlist.detail platform={platform} id={playlist_id} page={page} \
             tracks={} total={} elapsed={}ms",
            detail.tracks.len(),
            detail.total,
            started.elapsed().as_millis()
        ),
        Err(error) => log::warn!(
            "lx.playlist.detail platform={platform} id={playlist_id} page={page} \
             failed in {}ms: {error}",
            started.elapsed().as_millis()
        ),
    }
    result
}

fn get_playlist_detail_inner(
    platform: &str,
    playlist_id: &str,
    page: u32,
    limit: u32,
) -> Result<LxPlaylistDetail> {
    let page = page.max(1);
    let limit = limit.clamp(1, 1000);
    let client = client()?;
    match platform {
        "kg" => return get_kg_playlist_detail(&client, playlist_id, page, limit),
        "tx" => return get_tx_playlist_detail(&client, playlist_id),
        "wy" => return get_wy_playlist_detail(&client, playlist_id, page, limit),
        "mg" => return get_mg_playlist_detail(&client, playlist_id, page, limit),
        // kw is handled inline below.
        "kw" => {}
        other => {
            return Err(LxError::Request(format!(
                "playlist detail is not implemented: {other}"
            )));
        }
    }
    let body = get_json(client.get("http://nplserver.kuwo.cn/pl.svc").query(&[
        ("op", "getlistinfo"),
        ("pid", playlist_id),
        ("pn", &(page - 1).to_string()),
        ("rn", &limit.to_string()),
        ("encode", "utf8"),
        ("keyset", "pl2012"),
        ("identity", "kuwo"),
        ("pcmp4", "1"),
        ("vipver", "MUSIC_9.0.5.0_W1"),
        ("newver", "1"),
    ]))?;
    if body.get("result").and_then(Value::as_str) != Some("ok") {
        return Err(LxError::Request("kw playlist request failed".to_string()));
    }
    let total = body.get("total").and_then(value_u64).unwrap_or(0);
    let tracks = body
        .get("musiclist")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(parse_kw_track)
        .collect::<Vec<_>>();
    Ok(LxPlaylistDetail {
        info: LxPlaylistSummary {
            source: "kw".to_string(),
            id: playlist_id.to_string(),
            name: clean(body.get("title").and_then(Value::as_str).unwrap_or("")),
            author: clean(body.get("uname").and_then(Value::as_str).unwrap_or("")),
            cover_url: body.get("pic").and_then(Value::as_str).map(str::to_string),
            play_count: body
                .get("playnum")
                .and_then(value_string)
                .unwrap_or_default(),
            total,
            description: clean(body.get("info").and_then(Value::as_str).unwrap_or("")),
        },
        has_more: ((page * limit) as u64) < total,
        tracks,
        page,
        limit,
        total,
    })
}

pub fn get_playlist_all(platform: &str, playlist_id: &str) -> Result<LxPlaylistDetail> {
    let mut page = 1u32;
    let page_limit = playlist_all_page_limit(platform);
    let mut all_tracks = Vec::new();
    let mut first: Option<LxPlaylistDetail> = None;
    loop {
        let detail = get_playlist_detail(platform, playlist_id, page, page_limit)?;
        all_tracks.extend(detail.tracks.clone());
        let has_more = detail.has_more;
        if first.is_none() {
            first = Some(detail.clone());
        }
        if !has_more || page >= 20 {
            let mut result = first.unwrap_or(detail);
            let fetched_pages = page;
            result.tracks = all_tracks;
            result.has_more = false;
            log::info!(
                "lx.playlist.all platform={platform} id={playlist_id} \
                 tracks={} pages={fetched_pages}",
                result.tracks.len()
            );
            return Ok(result);
        }
        page += 1;
    }
}

fn search_tx_playlists(
    client: &Client,
    keyword: &str,
    page: u32,
    limit: u32,
) -> Result<Vec<LxPlaylistSummary>> {
    let mut last_error = None;
    for attempt in 1..=TX_SEARCH_ATTEMPTS {
        match search_tx_playlists_once(client, keyword, page, limit) {
            Ok(items) => return Ok(items),
            Err(error) => {
                log::warn!(
                    "lx.playlist.search tx attempt {attempt}/{TX_SEARCH_ATTEMPTS} failed: {error}"
                );
                last_error = Some(error);
                if attempt < TX_SEARCH_ATTEMPTS {
                    std::thread::sleep(Duration::from_millis(200 * u64::from(attempt)));
                }
            }
        }
    }
    Err(last_error.unwrap_or_else(|| LxError::Request("tx playlist search failed".to_string())))
}

fn search_tx_playlists_once(
    client: &Client,
    keyword: &str,
    page: u32,
    limit: u32,
) -> Result<Vec<LxPlaylistSummary>> {
    let page_no = (page - 1).to_string();
    let page_size = limit.to_string();
    let body = get_json(
        client
            .get("https://c.y.qq.com/soso/fcgi-bin/client_music_search_songlist")
            .query(&[
                ("page_no", page_no.as_str()),
                ("num_per_page", page_size.as_str()),
                ("format", "json"),
                ("query", keyword),
                ("remoteplace", "txt.yqq.playlist"),
                ("inCharset", "utf8"),
                ("outCharset", "utf-8"),
            ])
            .header(
                "User-Agent",
                "Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36",
            )
            .header("Referer", "https://y.qq.com/")
            .header("Origin", "https://y.qq.com"),
    )?;
    if body.get("code").and_then(Value::as_i64) != Some(0) {
        return Err(LxError::Request("tx playlist search failed".to_string()));
    }
    Ok(parse_tx_playlist_summaries(&body))
}

fn get_tx_playlist_detail(client: &Client, playlist_id: &str) -> Result<LxPlaylistDetail> {
    let body = get_json(
        client
            .get("https://c.y.qq.com/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg")
            .query(&[
                ("type", "1"),
                ("json", "1"),
                ("utf8", "1"),
                ("onlysong", "0"),
                ("new_format", "1"),
                ("disstid", playlist_id),
                ("loginUin", "0"),
                ("hostUin", "0"),
                ("format", "json"),
                ("inCharset", "utf8"),
                ("outCharset", "utf-8"),
                ("notice", "0"),
                ("platform", "yqq.json"),
                ("needNewCode", "0"),
            ])
            .header("Origin", "https://y.qq.com")
            .header(
                "Referer",
                format!("https://y.qq.com/n/yqq/playsquare/{playlist_id}.html"),
            ),
    )?;
    if body.get("code").and_then(Value::as_i64) != Some(0) {
        return Err(LxError::Request("tx playlist detail failed".to_string()));
    }
    let Some(cdlist) = body
        .get("cdlist")
        .and_then(Value::as_array)
        .and_then(|items| items.first())
    else {
        return Err(LxError::Request("tx playlist detail is empty".to_string()));
    };
    let tracks = cdlist
        .get("songlist")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(parse_tx_track)
        .collect::<Vec<_>>();
    let total = cdlist
        .get("songnum")
        .and_then(value_u64)
        .unwrap_or(tracks.len() as u64);
    Ok(LxPlaylistDetail {
        info: LxPlaylistSummary {
            source: "tx".to_string(),
            id: playlist_id.to_string(),
            name: clean(cdlist.get("dissname").and_then(Value::as_str).unwrap_or("")),
            author: clean(cdlist.get("nickname").and_then(Value::as_str).unwrap_or("")),
            cover_url: cdlist
                .get("logo")
                .and_then(Value::as_str)
                .map(str::to_string),
            play_count: cdlist
                .get("visitnum")
                .and_then(value_string)
                .unwrap_or_default(),
            total,
            description: clean(cdlist.get("desc").and_then(Value::as_str).unwrap_or("")),
        },
        tracks,
        page: 1,
        limit: total as u32,
        total,
        has_more: false,
    })
}

// ---------------------------------------------------------------------------
// Kugou (kg)
// ---------------------------------------------------------------------------

fn search_kg_playlists(
    client: &Client,
    keyword: &str,
    page: u32,
    limit: u32,
) -> Result<Vec<LxPlaylistSummary>> {
    let body = get_json(
        client
            .get("http://msearchretry.kugou.com/api/v3/search/special")
            .query(&[
                ("keyword", keyword),
                ("page", &page.to_string()),
                ("pagesize", &limit.to_string()),
                ("showtype", "10"),
                ("filter", "0"),
                ("version", "7910"),
                ("sver", "2"),
            ]),
    )?;
    if body.get("errcode").and_then(value_i64) != Some(0) {
        return Err(LxError::Request("kg playlist search failed".to_string()));
    }
    Ok(parse_kg_playlist_summaries(&body))
}

fn parse_kg_playlist_summaries(body: &Value) -> Vec<LxPlaylistSummary> {
    let mut result = Vec::new();
    for item in body
        .get("data")
        .and_then(|value| value.get("info"))
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        let Some(id) = item.get("specialid").and_then(value_string) else {
            continue;
        };
        let Some(name) = item.get("specialname").and_then(Value::as_str) else {
            continue;
        };
        result.push(LxPlaylistSummary {
            source: "kg".to_string(),
            id,
            name: clean(name),
            author: clean(item.get("nickname").and_then(Value::as_str).unwrap_or("")),
            cover_url: kg_image_url(item.get("imgurl").and_then(Value::as_str)),
            play_count: item
                .get("playcount")
                .and_then(value_string)
                .unwrap_or_default(),
            total: item.get("songcount").and_then(value_u64).unwrap_or(0),
            description: clean(item.get("intro").and_then(Value::as_str).unwrap_or("")),
        });
    }
    result
}

fn kg_image_url(value: Option<&str>) -> Option<String> {
    value
        .filter(|value| !value.is_empty())
        .map(|value| value.replace("{size}", "480"))
}

fn get_kg_playlist_detail(
    client: &Client,
    playlist_id: &str,
    page: u32,
    limit: u32,
) -> Result<LxPlaylistDetail> {
    // The song list endpoint does not carry the playlist metadata, so ask the
    // info endpoint too (no signature needed either way).
    let info = get_json(
        client
            .get("http://mobilecdn.kugou.com/api/v5/special/info")
            .query(&[("specialid", playlist_id)]),
    )
    .ok()
    .and_then(|body| body.get("data").cloned())
    .unwrap_or(Value::Null);

    let page_str = page.to_string();
    let limit_str = limit.to_string();
    let body = get_json(
        client
            .get("http://mobilecdn.kugou.com/api/v3/special/song")
            .query(&[
                ("page", page_str.as_str()),
                ("pagesize", limit_str.as_str()),
                ("specialid", playlist_id),
                ("showtype", "1"),
                ("version", "7910"),
            ]),
    )?;
    let data = body.get("data").unwrap_or(&Value::Null);
    let total = data
        .get("total")
        .and_then(value_u64)
        .or_else(|| info.get("songcount").and_then(value_u64))
        .unwrap_or(0);
    let tracks = data
        .get("info")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(parse_kg_playlist_track)
        .collect::<Vec<_>>();
    Ok(LxPlaylistDetail {
        info: LxPlaylistSummary {
            source: "kg".to_string(),
            id: playlist_id.to_string(),
            name: clean(
                info.get("specialname")
                    .and_then(Value::as_str)
                    .unwrap_or(""),
            ),
            author: clean(info.get("nickname").and_then(Value::as_str).unwrap_or("")),
            cover_url: kg_image_url(info.get("imgurl").and_then(Value::as_str)),
            play_count: info
                .get("playcount")
                .and_then(value_string)
                .unwrap_or_default(),
            total,
            description: clean(info.get("intro").and_then(Value::as_str).unwrap_or("")),
        },
        has_more: ((u64::from(page) - 1) * u64::from(limit) + tracks.len() as u64) < total,
        tracks,
        page,
        limit,
        total,
    })
}

/// Kugou playlist items only expose `filename` as "artist - title".
fn parse_kg_playlist_track(item: &Value) -> Option<LxSearchTrack> {
    let filename = item.get("filename").and_then(Value::as_str)?;
    let (singer, name) = match filename.split_once(" - ") {
        Some((singer, name)) => (singer, name),
        None => ("", filename),
    };
    // `songmid` for kg is `Audioid`, which the playlist API calls `album_audio_id`.
    let id = item
        .get("album_audio_id")
        .or_else(|| item.get("audio_id"))
        .and_then(value_string)
        .unwrap_or_default();
    if id.is_empty() {
        return None;
    }
    let hash = item.get("hash").and_then(Value::as_str).unwrap_or("");
    let mut extra = BTreeMap::new();
    if !hash.is_empty() {
        extra.insert("hash".to_string(), Value::String(hash.to_string()));
    }
    // 歌单详情接口用的是小写字段名，且只给到 flac。
    let has = |key: &str| item.get(key).and_then(value_u64).unwrap_or(0) > 0;
    insert_quality_types(
        &mut extra,
        ordered_quality_types(
            has("filesize"),
            has("320filesize"),
            has("sqfilesize"),
            false,
        ),
    );
    Some(LxSearchTrack {
        source: "kg".to_string(),
        id,
        name: clean(name),
        singer: split_singers(singer),
        album: clean(item.get("remark").and_then(Value::as_str).unwrap_or("")),
        album_id: item
            .get("album_id")
            .and_then(value_string)
            .unwrap_or_default(),
        interval: item
            .get("duration")
            .and_then(value_i64)
            .map(normalize_seconds)
            .unwrap_or(0),
        img: None,
        extra,
    })
}

// ---------------------------------------------------------------------------
// NetEase (wy)
// ---------------------------------------------------------------------------

fn search_wy_playlists(
    client: &Client,
    keyword: &str,
    page: u32,
    limit: u32,
) -> Result<Vec<LxPlaylistSummary>> {
    let payload = json!({
        "s": keyword,
        "type": 1000,
        "limit": limit,
        "total": page == 1,
        "offset": limit * (page - 1),
    });
    let body = eapi_json(client, "/api/cloudsearch/pc", &payload)?;
    if body.get("code").and_then(value_i64) != Some(200) {
        return Err(LxError::Request("wy playlist search failed".to_string()));
    }
    Ok(parse_wy_playlist_summaries(&body))
}

fn parse_wy_playlist_summaries(body: &Value) -> Vec<LxPlaylistSummary> {
    let mut result = Vec::new();
    for item in body
        .get("result")
        .and_then(|value| value.get("playlists"))
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        let Some(id) = item.get("id").and_then(value_string) else {
            continue;
        };
        let Some(name) = item.get("name").and_then(Value::as_str) else {
            continue;
        };
        result.push(LxPlaylistSummary {
            source: "wy".to_string(),
            id,
            name: clean(name),
            author: clean(
                item.get("creator")
                    .and_then(|value| value.get("nickname"))
                    .and_then(Value::as_str)
                    .unwrap_or(""),
            ),
            cover_url: item
                .get("coverImgUrl")
                .and_then(Value::as_str)
                .filter(|value| !value.is_empty())
                .map(str::to_string),
            play_count: item
                .get("playCount")
                .and_then(value_string)
                .unwrap_or_default(),
            total: item.get("trackCount").and_then(value_u64).unwrap_or(0),
            description: String::new(),
        });
    }
    result
}

fn get_wy_playlist_detail(
    client: &Client,
    playlist_id: &str,
    page: u32,
    limit: u32,
) -> Result<LxPlaylistDetail> {
    let body = eapi_json(
        client,
        "/api/v6/playlist/detail",
        &json!({ "id": wy_id_value(playlist_id), "n": 100000, "s": 0 }),
    )?;
    if body.get("code").and_then(value_i64) != Some(200) {
        return Err(LxError::Request("wy playlist detail failed".to_string()));
    }
    let playlist = body
        .get("playlist")
        .ok_or_else(|| LxError::Request("wy playlist detail is empty".to_string()))?;
    let ids = playlist
        .get("trackIds")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(|item| item.get("id").and_then(value_string))
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    let total = playlist
        .get("trackCount")
        .and_then(value_u64)
        .unwrap_or(ids.len() as u64);
    let start = (page as usize)
        .saturating_sub(1)
        .saturating_mul(limit as usize);
    let end = start.saturating_add(limit as usize).min(ids.len());
    let tracks = if start < end {
        fetch_wy_tracks(client, &ids[start..end])?
    } else {
        Vec::new()
    };
    Ok(LxPlaylistDetail {
        info: LxPlaylistSummary {
            source: "wy".to_string(),
            id: playlist_id.to_string(),
            name: clean(playlist.get("name").and_then(Value::as_str).unwrap_or("")),
            author: clean(
                playlist
                    .get("creator")
                    .and_then(|value| value.get("nickname"))
                    .and_then(Value::as_str)
                    .unwrap_or(""),
            ),
            cover_url: playlist
                .get("coverImgUrl")
                .and_then(Value::as_str)
                .filter(|value| !value.is_empty())
                .map(str::to_string),
            play_count: playlist
                .get("playCount")
                .and_then(value_string)
                .unwrap_or_default(),
            total,
            description: clean(
                playlist
                    .get("description")
                    .and_then(Value::as_str)
                    .unwrap_or(""),
            ),
        },
        has_more: end < ids.len(),
        tracks,
        page,
        limit,
        total,
    })
}

fn fetch_wy_tracks(client: &Client, ids: &[String]) -> Result<Vec<LxSearchTrack>> {
    let mut tracks = Vec::new();
    for chunk in ids.chunks(WY_TRACK_BATCH) {
        let c = serde_json::to_string(
            &chunk
                .iter()
                .map(|id| json!({ "id": wy_id_value(id) }))
                .collect::<Vec<_>>(),
        )
        .map_err(|error| LxError::Request(error.to_string()))?;
        let body = eapi_json(client, "/api/v3/song/detail", &json!({ "c": c }))?;
        tracks.extend(parse_wy_song_list(&body));
    }
    Ok(tracks)
}

/// NetEase ids are numeric; send them as numbers when possible.
fn wy_id_value(id: &str) -> Value {
    match id.parse::<i64>() {
        Ok(number) => json!(number),
        Err(_) => json!(id),
    }
}

fn parse_wy_song_list(body: &Value) -> Vec<LxSearchTrack> {
    let mut tracks = Vec::new();
    for song in body
        .get("songs")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        let Some(id) = song.get("id").and_then(value_string) else {
            continue;
        };
        let Some(name) = song.get("name").and_then(Value::as_str) else {
            continue;
        };
        let album = song.get("al");
        let singer = song
            .get("ar")
            .and_then(Value::as_array)
            .map(|items| {
                items
                    .iter()
                    .filter_map(|item| item.get("name").and_then(Value::as_str))
                    .map(clean)
                    .filter(|value| !value.is_empty())
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();
        tracks.push(LxSearchTrack {
            source: "wy".to_string(),
            id,
            name: clean(name),
            singer,
            album: clean(
                album
                    .and_then(|value| value.get("name"))
                    .and_then(Value::as_str)
                    .unwrap_or(""),
            ),
            album_id: album
                .and_then(|value| value.get("id"))
                .and_then(value_string)
                .unwrap_or_default(),
            interval: song
                .get("dt")
                .and_then(value_i64)
                .map(normalize_seconds)
                .unwrap_or(0),
            img: album
                .and_then(|value| value.get("picUrl"))
                .and_then(Value::as_str)
                .map(str::to_string),
            extra: {
                let mut extra = BTreeMap::new();
                insert_quality_types(&mut extra, wy_quality_types(song));
                extra
            },
        });
    }
    tracks
}

// ---------------------------------------------------------------------------
// Migu (mg)
// ---------------------------------------------------------------------------

fn search_mg_playlists(
    client: &Client,
    keyword: &str,
    page: u32,
    limit: u32,
) -> Result<Vec<LxPlaylistSummary>> {
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|error| LxError::Request(error.to_string()))?
        .as_millis()
        .to_string();
    let sign = mg_sign(keyword, MG_DEVICE_ID, &timestamp);
    let body = get_json(
        client
            .get("https://jadeite.migu.cn/music_search/v3/search/searchAll")
            .query(&[
                ("isCorrect", "1"),
                ("isCopyright", "1"),
                ("searchSwitch", MG_PLAYLIST_SWITCH),
                ("pageSize", &limit.to_string()),
                ("text", keyword),
                ("pageNo", &page.to_string()),
                ("sort", "0"),
                ("sid", "USS"),
            ])
            .header("uiVersion", "A_music_3.6.1")
            .header("deviceId", MG_DEVICE_ID)
            .header("timestamp", &timestamp)
            .header("sign", sign)
            .header("channel", "0146921")
            .header("User-Agent", MG_UA),
    )?;
    if body.get("code").and_then(Value::as_str) != Some("000000") {
        return Err(LxError::Request("mg playlist search failed".to_string()));
    }
    Ok(parse_mg_playlist_summaries(&body))
}

fn parse_mg_playlist_summaries(body: &Value) -> Vec<LxPlaylistSummary> {
    let mut result = Vec::new();
    let data = body.get("songListResultData").unwrap_or(&Value::Null);
    for item in data
        .get("result")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        let Some(id) = item.get("id").and_then(value_string) else {
            continue;
        };
        let Some(name) = item.get("name").and_then(Value::as_str) else {
            continue;
        };
        result.push(LxPlaylistSummary {
            source: "mg".to_string(),
            id,
            name: clean(name),
            author: clean(item.get("userName").and_then(Value::as_str).unwrap_or("")),
            cover_url: item
                .get("musicListPicUrl")
                .and_then(Value::as_str)
                .filter(|value| !value.is_empty())
                .map(str::to_string),
            play_count: item
                .get("playNum")
                .and_then(value_string)
                .unwrap_or_default(),
            total: item.get("musicNum").and_then(value_u64).unwrap_or(0),
            description: clean(item.get("intro").and_then(Value::as_str).unwrap_or("")),
        });
    }
    result
}

fn get_mg_playlist_detail(
    client: &Client,
    playlist_id: &str,
    page: u32,
    limit: u32,
) -> Result<LxPlaylistDetail> {
    let info_body = get_json(
        client
            .get("https://c.musicapp.migu.cn/MIGUM3.0/resource/playlist/v2.0")
            .query(&[("playlistId", playlist_id)])
            .header("User-Agent", MG_UA)
            .header("Referer", MG_REFERER),
    )?;
    if info_body.get("code").and_then(Value::as_str) != Some("000000") {
        return Err(LxError::Request("mg playlist detail failed".to_string()));
    }
    let info = info_body.get("data").unwrap_or(&Value::Null);

    // The server caps pageSize at 50; clamping keeps page numbers meaningful.
    let limit = limit.clamp(1, MG_PLAYLIST_PAGE_SIZE);
    let page_str = page.to_string();
    let limit_str = limit.to_string();
    let songs_body = get_json(
        client
            .get("https://app.c.nf.migu.cn/MIGUM3.0/resource/playlist/song/v2.0")
            .query(&[
                ("pageNo", page_str.as_str()),
                ("pageSize", limit_str.as_str()),
                ("playlistId", playlist_id),
            ])
            .header("User-Agent", MG_UA)
            .header("Referer", MG_REFERER),
    )?;
    let songs = songs_body.get("data").unwrap_or(&Value::Null);
    let total = songs
        .get("totalCount")
        .and_then(value_u64)
        .or_else(|| info.get("musicNum").and_then(value_u64))
        .unwrap_or(0);
    let tracks = songs
        .get("songList")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(parse_mg_playlist_track)
        .collect::<Vec<_>>();
    Ok(LxPlaylistDetail {
        info: LxPlaylistSummary {
            source: "mg".to_string(),
            id: playlist_id.to_string(),
            name: clean(info.get("title").and_then(Value::as_str).unwrap_or("")),
            author: clean(info.get("ownerName").and_then(Value::as_str).unwrap_or("")),
            cover_url: info
                .get("imgItem")
                .and_then(|value| value.get("img"))
                .and_then(Value::as_str)
                .map(str::to_string),
            play_count: info
                .get("opNumItem")
                .and_then(|value| value.get("playNum"))
                .and_then(value_string)
                .unwrap_or_default(),
            total,
            description: clean(info.get("summary").and_then(Value::as_str).unwrap_or("")),
        },
        has_more: ((u64::from(page) - 1) * u64::from(limit) + tracks.len() as u64) < total,
        tracks,
        page,
        limit,
        total,
    })
}

/// Migu's playlist song list uses `songName` instead of `name`.
fn parse_mg_playlist_track(item: &Value) -> Option<LxSearchTrack> {
    let id = item.get("songId").and_then(Value::as_str)?;
    let name = item
        .get("songName")
        .or_else(|| item.get("name"))
        .and_then(Value::as_str)?;
    let singer = item
        .get("singerList")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(|item| item.get("name").and_then(Value::as_str))
                .map(clean)
                .filter(|value| !value.is_empty())
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    let mut img = item
        .get("img3")
        .or_else(|| item.get("img2"))
        .or_else(|| item.get("img1"))
        .and_then(Value::as_str)
        .map(ToString::to_string);
    if let Some(value) = img.as_mut() {
        if value.starts_with('/') {
            *value = format!("http://d.musicapp.migu.cn{value}");
        }
    }
    let mut extra = BTreeMap::new();
    if let Some(value) = item.get("copyrightId").and_then(Value::as_str) {
        extra.insert("copyrightId".to_string(), Value::String(value.to_string()));
    }
    for (key, aliases) in [
        ("lrcUrl", &["lrcUrl", "lyricUrl"][..]),
        ("mrcUrl", &["mrcUrl", "mrcurl"][..]),
        ("trcUrl", &["trcUrl", "trcurl"][..]),
    ] {
        if let Some(value) = aliases
            .iter()
            .find_map(|alias| item.get(*alias).and_then(Value::as_str))
        {
            extra.insert(key.to_string(), Value::String(value.to_string()));
        }
    }
    insert_quality_types(&mut extra, mg_quality_types(item));
    Some(LxSearchTrack {
        source: "mg".to_string(),
        id: id.to_string(),
        name: clean(name),
        singer,
        album: clean(item.get("album").and_then(Value::as_str).unwrap_or("")),
        album_id: item
            .get("albumId")
            .and_then(value_string)
            .unwrap_or_default(),
        interval: item
            .get("duration")
            .and_then(value_i64)
            .map(normalize_seconds)
            .unwrap_or(0),
        img,
        extra,
    })
}

fn parse_tx_playlist_summaries(body: &Value) -> Vec<LxPlaylistSummary> {
    let mut result = Vec::new();
    for item in body
        .get("data")
        .and_then(|value| value.get("list"))
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        let Some(id) = item.get("dissid").and_then(value_string) else {
            continue;
        };
        let Some(name) = item.get("dissname").and_then(Value::as_str) else {
            continue;
        };
        result.push(LxPlaylistSummary {
            source: "tx".to_string(),
            id,
            name: clean(name),
            author: clean(
                item.get("creator")
                    .and_then(|value| value.get("name"))
                    .and_then(Value::as_str)
                    .unwrap_or(""),
            ),
            cover_url: item
                .get("imgurl")
                .and_then(Value::as_str)
                .filter(|value| !value.is_empty())
                .map(str::to_string),
            play_count: item
                .get("listennum")
                .and_then(value_string)
                .unwrap_or_default(),
            total: item.get("song_count").and_then(value_u64).unwrap_or(0),
            description: clean(
                item.get("introduction")
                    .and_then(Value::as_str)
                    .unwrap_or(""),
            ),
        });
    }
    result
}

fn parse_tx_track(item: &Value) -> Option<LxSearchTrack> {
    let file = item.get("file");
    if file
        .and_then(|value| value.get("media_mid"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .is_empty()
    {
        return None;
    }
    let id = item.get("mid").and_then(Value::as_str)?;
    let name = item.get("title").or_else(|| item.get("name"))?.as_str()?;
    let album = item.get("album");
    let album_id = album
        .and_then(|value| value.get("mid"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let album_name = album
        .and_then(|value| value.get("name"))
        .and_then(Value::as_str)
        .unwrap_or("");
    let singer = item
        .get("singer")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(|item| item.get("name").and_then(Value::as_str))
                .map(clean)
                .filter(|value| !value.is_empty())
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    let img = if album_id.is_empty() || album_id == "空" {
        item.get("singer")
            .and_then(Value::as_array)
            .and_then(|items| items.first())
            .and_then(|item| item.get("mid"))
            .and_then(Value::as_str)
            .filter(|value| !value.is_empty())
            .map(|mid| format!("https://y.gtimg.cn/music/photo_new/T001R500x500M000{mid}.jpg"))
    } else {
        Some(format!(
            "https://y.gtimg.cn/music/photo_new/T002R500x500M000{album_id}.jpg"
        ))
    };
    let mut extra = BTreeMap::new();
    if let Some(media_mid) = file
        .and_then(|value| value.get("media_mid"))
        .and_then(Value::as_str)
    {
        extra.insert(
            "strMediaMid".to_string(),
            Value::String(media_mid.to_string()),
        );
    }
    if let Some(song_id) = item.get("id").and_then(value_u64) {
        extra.insert("songId".to_string(), Value::String(song_id.to_string()));
    }
    if !album_id.is_empty() {
        extra.insert("albumMid".to_string(), Value::String(album_id.clone()));
    }
    if let Some(file) = file {
        insert_quality_types(&mut extra, tx_quality_types(file));
    }
    Some(LxSearchTrack {
        source: "tx".to_string(),
        id: id.to_string(),
        name: clean(name),
        singer,
        album: clean(album_name),
        album_id,
        interval: item
            .get("interval")
            .and_then(value_i64)
            .map(normalize_seconds)
            .unwrap_or(0),
        img,
        extra,
    })
}

fn parse_kw_track(item: &Value) -> Option<LxSearchTrack> {
    let id = item.get("id").and_then(value_string)?;
    let name = item.get("name").and_then(Value::as_str)?;
    let album_id = item
        .get("albumid")
        .and_then(value_string)
        .unwrap_or_default();
    Some(LxSearchTrack {
        source: "kw".to_string(),
        id,
        name: clean(name),
        singer: split_singers(item.get("artist").and_then(Value::as_str).unwrap_or("")),
        album: clean(item.get("album").and_then(Value::as_str).unwrap_or("")),
        album_id,
        interval: item
            .get("duration")
            .and_then(value_i64)
            .map(normalize_seconds)
            .unwrap_or(0),
        img: None,
        extra: {
            let mut extra = BTreeMap::new();
            insert_quality_types(&mut extra, kw_quality_types(item));
            extra
        },
    })
}

fn client() -> Result<Client> {
    Client::builder()
        .no_proxy()
        .timeout(Duration::from_secs(10))
        .user_agent(USER_AGENT)
        .build()
        .map_err(|error| LxError::Request(error.to_string()))
}

fn get_text(request: reqwest::blocking::RequestBuilder) -> Result<String> {
    let response = request
        .send()
        .map_err(|error| LxError::Request(error.to_string()))?;
    if !response.status().is_success() {
        return Err(LxError::Request(format!(
            "playlist HTTP {}",
            response.status()
        )));
    }
    let bytes = response
        .bytes()
        .map_err(|error| LxError::Request(error.to_string()))?;
    if bytes.len() > MAX_RESPONSE_BYTES {
        return Err(LxError::Request(
            "playlist response is too large".to_string(),
        ));
    }
    // 部分老接口声明 charset=utf-8 但实际返回 GBK（如 QQ 歌单搜索），这里做宽松解码。
    Ok(decode_text(&bytes))
}

fn get_json(request: reqwest::blocking::RequestBuilder) -> Result<Value> {
    let text = get_text(request)?;
    serde_json::from_str(&text).map_err(|error| LxError::Request(error.to_string()))
}

/// Kuwo returns a JavaScript object literal using single-quoted keys/values.
fn js_object_to_json(input: &str) -> String {
    let mut out = String::with_capacity(input.len() + 16);
    let mut in_single = false;
    let mut escaped = false;
    for ch in input.chars() {
        if in_single {
            if escaped {
                match ch {
                    '\'' => out.push('\''),
                    '"' => out.push_str("\\\""),
                    _ => {
                        out.push('\\');
                        out.push(ch);
                    }
                }
                escaped = false;
                continue;
            }
            match ch {
                '\\' => {
                    escaped = true;
                }
                '"' => out.push_str("\\\""),
                '\'' => {
                    out.push('"');
                    in_single = false;
                }
                _ => out.push(ch),
            }
        } else {
            match ch {
                '\'' => {
                    out.push('"');
                    in_single = true;
                }
                _ => out.push(ch),
            }
        }
    }
    out
}

fn value_string(value: &Value) -> Option<String> {
    value
        .as_str()
        .map(str::to_string)
        .or_else(|| value.as_i64().map(|number| number.to_string()))
}

fn value_i64(value: &Value) -> Option<i64> {
    value
        .as_i64()
        .or_else(|| value.as_str().and_then(|text| text.parse().ok()))
}

fn value_u64(value: &Value) -> Option<u64> {
    value
        .as_u64()
        .or_else(|| value.as_str().and_then(|text| text.parse().ok()))
}

fn normalize_seconds(value: i64) -> i64 {
    if value > 86_400 {
        value / 1000
    } else {
        value
    }
}

fn split_singers(value: &str) -> Vec<String> {
    value
        .split(['&', '/', '、', ','])
        .map(str::trim)
        .filter(|item| !item.is_empty())
        .map(str::to_string)
        .collect()
}

fn clean(value: &str) -> String {
    // 与 search.rs 保持一致：QQ 会把换行/标点转义成 &#10; / &#46; 之类的实体。
    html_escape::decode_html_entities(value.trim())
        .trim()
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_kw_playlist_track_quality() {
        let item: Value = serde_json::from_str(
            r#"{"id":"2867496601","name":"Song","artist":"Singer","album":"Album",
                "albumid":"1","duration":200,
                "N_MINFO":"level:zpga201,bitrate:20201,format:mflac,size:33.34Mb;level:ff,bitrate:2000,format:flac,size:34.55Mb;level:p,bitrate:320,format:mp3,size:11.42Mb;"}"#,
        )
        .unwrap();
        let track = parse_kw_track(&item).unwrap();
        assert_eq!(
            track.extra.get("types"),
            Some(&serde_json::json!(["flac", "320k"]))
        );
    }

    #[test]
    fn supports_all_five_playlist_platforms() {
        for platform in ["kw", "kg", "tx", "wy", "mg"] {
            assert!(supports_playlist_search(platform), "{platform} missing");
        }
        assert!(!supports_playlist_search("local"));
    }

    #[test]
    fn parses_kg_playlist_search_and_tracks() {
        let search: Value = serde_json::from_str(
            r#"{"status":1,"errcode":0,"data":{"total":480,"info":[
                {"specialid":6409645,
                 "specialname":"周杰伦出道26周年｜播放属于我们的青春记忆",
                 "nickname":"酷乐推荐",
                 "imgurl":"http://imge.kugou.com/soft/collection/{size}/20261105/x.jpg",
                 "intro":"","playcount":38608532,"songcount":194}]}}"#,
        )
        .unwrap();
        let items = parse_kg_playlist_summaries(&search);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, "6409645");
        assert_eq!(items[0].author, "酷乐推荐");
        assert_eq!(items[0].total, 194);
        assert_eq!(items[0].play_count, "38608532");
        assert_eq!(
            items[0].cover_url.as_deref(),
            Some("http://imge.kugou.com/soft/collection/480/20261105/x.jpg")
        );

        let detail: Value = serde_json::from_str(
            r#"{"data":{"total":194,"info":[
                {"filename":"周杰伦 - 反方向的钟",
                 "hash":"A6049AAB184A305CAA906C6BBB8E8233",
                 "album_audio_id":64531905,"album_id":"978031",
                 "filesize":4570000,"320filesize":11420000,"sqfilesize":34550000,
                 "remark":"Jay","duration":258,"extname":"mp3"}]}}"#,
        )
        .unwrap();
        let track = parse_kg_playlist_track(&detail["data"]["info"][0]).unwrap();
        // kg `songmid` is Audioid == album_audio_id, same as song search.
        assert_eq!(track.id, "64531905");
        assert_eq!(track.name, "反方向的钟");
        assert_eq!(track.singer, vec!["周杰伦"]);
        assert_eq!(track.album, "Jay");
        assert_eq!(track.album_id, "978031");
        assert_eq!(track.interval, 258);
        assert_eq!(
            track.extra.get("hash").and_then(Value::as_str),
            Some("A6049AAB184A305CAA906C6BBB8E8233")
        );
        assert_eq!(
            track.extra.get("types"),
            Some(&serde_json::json!(["flac", "320k", "128k"]))
        );
    }

    #[test]
    fn parses_wy_playlist_search_and_songs() {
        let search: Value = serde_json::from_str(
            r#"{"code":200,"result":{"playlistCount":100,"playlists":[
                {"id":6792103822,"name":"周杰伦-Jay 『网易云精选』",
                 "coverImgUrl":"https://p1.music.126.net/x.jpg",
                 "creator":{"nickname":"Buradarrr"},
                 "trackCount":145,"playCount":34900416}]}}"#,
        )
        .unwrap();
        let items = parse_wy_playlist_summaries(&search);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, "6792103822");
        assert_eq!(items[0].author, "Buradarrr");
        assert_eq!(items[0].total, 145);

        let songs: Value = serde_json::from_str(
            r#"{"code":200,"songs":[
                {"id":5257138,"name":"屋顶","dt":319039,
                 "al":{"id":123,"name":"男女情歌对唱冠军全记录","picUrl":"https://p/x.jpg"},
                 "ar":[{"name":"周杰伦"},{"name":"温岚"}],
                 "l":{"br":128000},"h":{"br":320000},"sq":null,"hr":null}]}"#,
        )
        .unwrap();
        let tracks = parse_wy_song_list(&songs);
        assert_eq!(tracks.len(), 1);
        assert_eq!(tracks[0].id, "5257138");
        assert_eq!(tracks[0].name, "屋顶");
        assert_eq!(tracks[0].singer, vec!["周杰伦", "温岚"]);
        assert_eq!(tracks[0].album, "男女情歌对唱冠军全记录");
        assert_eq!(tracks[0].album_id, "123");
        // ms -> seconds
        assert_eq!(tracks[0].interval, 319);
        assert_eq!(
            tracks[0].extra.get("types"),
            Some(&serde_json::json!(["320k", "128k"]))
        );
    }

    #[test]
    fn parses_mg_playlist_search_and_tracks() {
        let search: Value = serde_json::from_str(
            r#"{"code":"000000","songListResultData":{"totalCount":"200","result":[
                {"id":"233754996","name":"周杰伦精选100首：青春百听不厌",
                 "userName":"山间啊","musicNum":"100",
                 "musicListPicUrl":"https://d.musicapp.migu.cn/x.png",
                 "intro":"desc","playNum":"2185854"}]}}"#,
        )
        .unwrap();
        let items = parse_mg_playlist_summaries(&search);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, "233754996");
        assert_eq!(items[0].author, "山间啊");
        assert_eq!(items[0].total, 100);

        let detail: Value = serde_json::from_str(
            r#"{"code":"000000","data":{"totalCount":100,"songList":[
                {"songName":"晴天","songId":"3790007","copyrightId":"60054701923",
                 "album":"叶惠美","albumId":"8592","duration":270,
                 "singerList":[{"name":"周杰伦"}],
                 "img3":"/data/oss/resource/00/x.webp",
                 "audioFormats":[{"formatType":"PQ"},{"formatType":"SQ"}],
                 "lrcUrl":"https://l/1","mrcUrl":"https://m/1"}]}}"#,
        )
        .unwrap();
        let track = parse_mg_playlist_track(&detail["data"]["songList"][0]).unwrap();
        assert_eq!(track.id, "3790007");
        assert_eq!(track.name, "晴天");
        assert_eq!(track.singer, vec!["周杰伦"]);
        assert_eq!(track.album, "叶惠美");
        assert_eq!(track.interval, 270);
        assert_eq!(
            track.img.as_deref(),
            Some("http://d.musicapp.migu.cn/data/oss/resource/00/x.webp")
        );
        assert_eq!(
            track.extra.get("copyrightId").and_then(Value::as_str),
            Some("60054701923")
        );
        assert_eq!(
            track.extra.get("mrcUrl").and_then(Value::as_str),
            Some("https://m/1")
        );
        assert_eq!(
            track.extra.get("types"),
            Some(&serde_json::json!(["flac", "128k"]))
        );
    }

    #[test]
    fn parses_tx_playlist_summaries() {
        let body: Value = serde_json::from_str(
            r#"{"code":0,"data":{"sum":47458,"list":[
                {"dissid":"3805603854","dissname":"周杰伦歌曲大全！一张歌单全听完",
                 "creator":{"name":"歌单狂魔"},
                 "imgurl":"http://p.qpic.cn/music_cover/x.jpg",
                 "listennum":909991805,"song_count":223,
                 "introduction":"“周杰伦”三个字是不变的信仰！&#10;歌单收集杰伦最全歌曲"}]}}"#,
        )
        .unwrap();
        let items = parse_tx_playlist_summaries(&body);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, "3805603854");
        assert_eq!(items[0].author, "歌单狂魔");
        assert_eq!(items[0].total, 223);
        assert_eq!(items[0].play_count, "909991805");
        // HTML entities are decoded (&#10; -> newline)
        assert!(items[0].description.contains('\n'));
        assert!(!items[0].description.contains("&#10;"));
    }

    #[test]
    fn converts_kw_object_literal() {
        let raw = "{'TOTAL':'2','abslist':[{'playlistid':'1','name':'A','intro':'it\\'s ok'}]}";
        let parsed: Value = serde_json::from_str(&js_object_to_json(raw)).unwrap();
        assert_eq!(parsed["TOTAL"], "2");
        assert_eq!(parsed["abslist"][0]["name"], "A");
        assert_eq!(parsed["abslist"][0]["intro"], "it's ok");
    }
}
