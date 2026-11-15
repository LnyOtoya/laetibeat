use std::collections::BTreeMap;
use std::time::Duration;

use reqwest::blocking::Client;
use serde_json::Value;

use crate::error::{LxError, Result};
use crate::search::LxSearchTrack;

const USER_AGENT: &str = "Mozilla/5.0 (Linux; U; Android 11.0.0; zh-cn; MI 11) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30";
const MAX_RESPONSE_BYTES: usize = 5 * 1024 * 1024;
const MAX_LIMIT: u32 = 100;

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

pub fn search_playlists(
    platform: &str,
    keyword: &str,
    page: u32,
    limit: u32,
) -> Result<Vec<LxPlaylistSummary>> {
    if platform != "kw" {
        return Err(LxError::Request(format!(
            "playlist search is not implemented: {platform}"
        )));
    }
    let keyword = keyword.trim();
    if keyword.is_empty() {
        return Ok(Vec::new());
    }
    let page = page.max(1);
    let limit = limit.clamp(1, MAX_LIMIT);
    let client = client()?;
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

pub fn get_playlist_detail(
    platform: &str,
    playlist_id: &str,
    page: u32,
    limit: u32,
) -> Result<LxPlaylistDetail> {
    if platform != "kw" {
        return Err(LxError::Request(format!(
            "playlist detail is not implemented: {platform}"
        )));
    }
    let page = page.max(1);
    let limit = limit.clamp(1, 1000);
    let client = client()?;
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
            result.tracks = all_tracks;
            result.has_more = false;
            return Ok(result);
        }
        page += 1;
    }
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
        .timeout(Duration::from_secs(15))
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
    String::from_utf8(bytes.to_vec())
        .map_err(|error| LxError::Request(format!("playlist response is not UTF-8: {error}")))
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
    value
        .replace("&nbsp;", " ")
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&#39;", "'")
        .replace("&quot;", "\"")
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
