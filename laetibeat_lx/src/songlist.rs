use std::collections::BTreeMap;
use std::time::{Duration, Instant};

use reqwest::blocking::Client;
use serde_json::Value;

use crate::error::{LxError, Result};
use crate::search::LxSearchTrack;
use crate::utils::decode_text;

const USER_AGENT: &str = "Mozilla/5.0 (Linux; U; Android 11.0.0; zh-cn; MI 11) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30";
const MAX_RESPONSE_BYTES: usize = 5 * 1024 * 1024;
const MAX_LIMIT: u32 = 100;
/// QQ occasionally answers `code != 0` (anti-bot / transient upstream error).
/// The reference client retries up to 5 times; three attempts is enough here.
const TX_SEARCH_ATTEMPTS: u32 = 3;

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
    if platform == "tx" {
        return search_tx_playlists(&client, keyword, page, limit);
    }
    if platform != "kw" {
        return Err(LxError::Request(format!(
            "playlist search is not implemented: {platform}"
        )));
    }
    let body = get_text(
        client
            .get("http://search.kuwo.cn/r.s")
            .query(&[
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
            ]),
    )?;
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
    if platform == "tx" {
        return get_tx_playlist_detail(&client, playlist_id);
    }
    if platform != "kw" {
        return Err(LxError::Request(format!(
            "playlist detail is not implemented: {platform}"
        )));
    }
    let body = get_json(
        client
            .get("http://nplserver.kuwo.cn/pl.svc")
            .query(&[
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
            ]),
    )?;
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
    let mut all_tracks = Vec::new();
    let mut first: Option<LxPlaylistDetail> = None;
    loop {
        let detail = get_playlist_detail(platform, playlist_id, page, 1000)?;
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
    Err(last_error
        .unwrap_or_else(|| LxError::Request("tx playlist search failed".to_string())))
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
            .header("User-Agent", "Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36")
            .header("Referer", "https://y.qq.com/")
            .header("Origin", "https://y.qq.com"),
    )?;
    if body.get("code").and_then(Value::as_i64) != Some(0) {
        return Err(LxError::Request("tx playlist search failed".to_string()));
    }
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
            cover_url: item.get("imgurl").and_then(Value::as_str).map(str::to_string),
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
    Ok(result)
}

fn get_tx_playlist_detail(
    client: &Client,
    playlist_id: &str,
) -> Result<LxPlaylistDetail> {
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
            .header("Referer", format!("https://y.qq.com/n/yqq/playsquare/{playlist_id}.html")),
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
            cover_url: cdlist.get("logo").and_then(Value::as_str).map(str::to_string),
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
    if let Some(media_mid) = file.and_then(|value| value.get("media_mid")).and_then(Value::as_str) {
        extra.insert("strMediaMid".to_string(), Value::String(media_mid.to_string()));
    }
    if let Some(song_id) = item.get("id").and_then(value_u64) {
        extra.insert("songId".to_string(), Value::String(song_id.to_string()));
    }
    if !album_id.is_empty() {
        extra.insert("albumMid".to_string(), Value::String(album_id.clone()));
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
        extra: BTreeMap::new(),
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
        return Err(LxError::Request("playlist response is too large".to_string()));
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
    fn converts_kw_object_literal() {
        let raw = "{'TOTAL':'2','abslist':[{'playlistid':'1','name':'A','intro':'it\\'s ok'}]}";
        let parsed: Value = serde_json::from_str(&js_object_to_json(raw)).unwrap();
        assert_eq!(parsed["TOTAL"], "2");
        assert_eq!(parsed["abslist"][0]["name"], "A");
        assert_eq!(parsed["abslist"][0]["intro"], "it's ok");
    }
}
