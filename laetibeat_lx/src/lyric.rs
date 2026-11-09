use std::io::Read;

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use std::time::Duration;

use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::error::{LxError, Result};
use crate::models::LxMusicInfo;
use crate::utils::{aes_ecb_pkcs7_hex, md5_hex};

const USER_AGENT: &str = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36";

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct LxLyric {
    pub lyric: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tlyric: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rlyric: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub lxlyric: Option<String>,
}

/// Fetch lyrics from the platform itself. Online custom sources generally
/// only provide `musicUrl`, so lyrics must not be routed through the source
/// script when it does not declare the `lyric` action.
pub fn fetch(platform: &str, info: &LxMusicInfo) -> Result<LxLyric> {
    let client = Client::builder()
        .no_proxy()
        .timeout(Duration::from_secs(15))
        .user_agent(USER_AGENT)
        .build()
        .map_err(|error| LxError::Request(error.to_string()))?;
    match platform {
        "kw" => fetch_kw(&client, &info.id),
        "kg" => fetch_kg(&client, info),
        "tx" => fetch_tx(&client, &info.id),
        "wy" => fetch_wy(&client, &info.id),
        "mg" => fetch_mg(&client, info),
        other => Err(LxError::Request(format!(
            "platform lyric is not implemented: {other}"
        ))),
    }
}

fn fetch_kw(client: &Client, song_mid: &str) -> Result<LxLyric> {
    let body = get_json(
        client
            .get("http://m.kuwo.cn/newh5/singles/songinfoandlrc")
            .query(&[("musicId", song_mid)])
            .header("Referer", "https://www.kuwo.cn/"),
    )?;
    let mut lines = body
        .get("data")
        .and_then(|data| data.get("lrclist"))
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|line| {
            let time = line.get("time").and_then(value_f64).or_else(|| {
                line.get("time")
                    .and_then(|value| value.as_str())
                    .and_then(|value| value.parse().ok())
            })?;
            let text = line
                .get("lineLyric")
                .and_then(Value::as_str)
                .map(clean)
                .unwrap_or_default();
            Some((time, text))
        })
        .collect::<Vec<_>>();
    if lines.is_empty() {
        return Err(LxError::Request("no lyrics found".to_string()));
    }
    lines.sort_by(|left, right| left.0.total_cmp(&right.0));
    let lyric = lines
        .into_iter()
        .map(|(time, text)| format!("{}{}", lrc_time(time), text))
        .collect::<Vec<_>>()
        .join("\n");
    Ok(LxLyric {
        lyric,
        ..Default::default()
    })
}

fn fetch_tx(client: &Client, song_mid: &str) -> Result<LxLyric> {
    let body = get_json(
        client
            .get("https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg")
            .query(&[
                ("songmid", song_mid),
                ("format", "json"),
                ("nobase64", "1"),
                ("g_tk", "5381"),
            ])
            .header("Referer", "https://y.qq.com/"),
    )?;
    let lyric = body
        .get("lyric")
        .and_then(Value::as_str)
        .map(clean)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| LxError::Request("no lyrics found".to_string()))?;
    let tlyric = body
        .get("trans")
        .and_then(Value::as_str)
        .map(clean)
        .filter(|value| !value.is_empty());
    Ok(LxLyric {
        lyric,
        tlyric,
        ..Default::default()
    })
}

fn fetch_kg(client: &Client, info: &LxMusicInfo) -> Result<LxLyric> {
    let hash = extra_string(info, "hash")
        .ok_or_else(|| LxError::Request("kg lyric requires hash".to_string()))?;
    let search = get_json(
        client
            .get("http://lyrics.kugou.com/search")
            .query(&[
                ("ver", "1"),
                ("man", "yes"),
                ("client", "pc"),
                ("keyword", &info.name),
                ("hash", &hash),
                ("timelength", &info.interval.to_string()),
                ("lrctxt", "1"),
            ])
            .header("KG-RC", "1")
            .header("KG-THash", "expand_search_manager.cpp:852736169:451")
            .header("User-Agent", "KuGou2012-9020-ExpandSearchManager"),
    )?;
    let candidate = search
        .get("candidates")
        .and_then(Value::as_array)
        .and_then(|items| items.first())
        .ok_or_else(|| LxError::Request("no kg lyric candidate".to_string()))?;
    let id = candidate
        .get("id")
        .and_then(value_text)
        .ok_or_else(|| LxError::Request("no kg lyric id".to_string()))?;
    let access_key = candidate
        .get("accesskey")
        .and_then(Value::as_str)
        .ok_or_else(|| LxError::Request("no kg lyric accesskey".to_string()))?;
    let format = if candidate.get("krctype").and_then(value_i64) == Some(1)
        && candidate.get("contenttype").and_then(value_i64) != Some(1)
    {
        "krc"
    } else {
        "lrc"
    };
    let download = get_json(
        client
            .get("http://lyrics.kugou.com/download")
            .query(&[
                ("ver", "1"),
                ("client", "pc"),
                ("id", &id),
                ("accesskey", access_key),
                ("fmt", format),
                ("charset", "utf8"),
            ])
            .header("KG-RC", "1")
            .header("KG-THash", "expand_search_manager.cpp:852736169:451")
            .header("User-Agent", "KuGou2012-9020-ExpandSearchManager"),
    )?;
    let content = download
        .get("content")
        .and_then(Value::as_str)
        .ok_or_else(|| LxError::Request("no kg lyric content".to_string()))?;
    let bytes = STANDARD
        .decode(content)
        .map_err(|error| LxError::Request(format!("kg lyric base64: {error}")))?;
    if format == "krc" {
        return parse_krc(&decode_krc(&bytes)?);
    }
    let lyric = String::from_utf8_lossy(&bytes).trim().to_string();
    if lyric.is_empty() {
        return Err(LxError::Request("empty kg lyric".to_string()));
    }
    Ok(LxLyric {
        lyric,
        ..Default::default()
    })
}

fn decode_krc(bytes: &[u8]) -> Result<String> {
    const KEY: [u8; 16] = [
        0x40, 0x47, 0x61, 0x77, 0x5e, 0x32, 0x74, 0x47, 0x51, 0x36, 0x31, 0x2d, 0xce, 0xd2, 0x6e,
        0x69,
    ];
    if bytes.len() <= 4 {
        return Err(LxError::Request("invalid krc payload".to_string()));
    }
    let mut payload = bytes[4..].to_vec();
    for (index, byte) in payload.iter_mut().enumerate() {
        *byte ^= KEY[index % KEY.len()];
    }
    let mut decoder = flate2::read::ZlibDecoder::new(&payload[..]);
    let mut text = String::new();
    decoder
        .read_to_string(&mut text)
        .map_err(|error| LxError::Request(format!("krc inflate: {error}")))?;
    Ok(text)
}

fn parse_krc(text: &str) -> Result<LxLyric> {
    let mut lrc_lines = Vec::new();
    let mut lx_lines = Vec::new();
    for raw_line in text.lines() {
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with("[language:") || line.starts_with("[id:") {
            continue;
        }
        let Some(close) = line.find(']') else {
            lrc_lines.push(line.to_string());
            lx_lines.push(line.to_string());
            continue;
        };
        let header = &line[1..close];
        let Some((start, _duration)) = header.split_once(',') else {
            lrc_lines.push(line.to_string());
            lx_lines.push(line.to_string());
            continue;
        };
        let Ok(start_ms) = start.parse::<f64>() else {
            continue;
        };
        let rest = &line[close + 1..];
        let mut words = String::new();
        let mut lx_words = String::new();
        let mut cursor = 0;
        while cursor < rest.len() {
            let Some(tag_start_rel) = rest[cursor..].find('<') else {
                words.push_str(&rest[cursor..]);
                lx_words.push_str(&rest[cursor..]);
                break;
            };
            let tag_start = cursor + tag_start_rel;
            words.push_str(&rest[cursor..tag_start]);
            lx_words.push_str(&rest[cursor..tag_start]);
            let Some(tag_end_rel) = rest[tag_start..].find('>') else {
                words.push_str(&rest[tag_start..]);
                lx_words.push_str(&rest[tag_start..]);
                break;
            };
            let tag_end = tag_start + tag_end_rel;
            let tag = &rest[tag_start + 1..tag_end];
            let mut parts = tag.split(',');
            let offset = parts.next().and_then(|value| value.parse::<i64>().ok());
            let during = parts.next().and_then(|value| value.parse::<i64>().ok());
            if let (Some(offset), Some(during)) = (offset, during) {
                lx_words.push_str(&format!("<{offset},{during}>"));
            }
            cursor = tag_end + 1;
        }
        let timestamp = lrc_time(start_ms / 1000.0);
        if !words.trim().is_empty() {
            lrc_lines.push(format!(
                "{timestamp}{}",
                html_escape::decode_html_entities(&words)
            ));
            lx_lines.push(format!(
                "{timestamp}{}",
                html_escape::decode_html_entities(&lx_words)
            ));
        }
    }
    if lrc_lines.is_empty() {
        return Err(LxError::Request("empty krc lyric".to_string()));
    }
    Ok(LxLyric {
        lyric: lrc_lines.join("\n"),
        lxlyric: Some(lx_lines.join("\n")),
        ..Default::default()
    })
}

fn fetch_mg(client: &Client, info: &LxMusicInfo) -> Result<LxLyric> {
    if let Some(url) = extra_string(info, "lrcUrl") {
        let lyric = get_text(client.get(&url))?.trim().to_string();
        if !lyric.is_empty() {
            return Ok(LxLyric {
                lyric,
                ..Default::default()
            });
        }
    }
    if let Some(url) = extra_string(info, "mrcUrl") {
        let _ = url;
        return Err(LxError::Request(
            "mg mrc lyric decoder is not implemented yet".to_string(),
        ));
    }
    Err(LxError::Request("no mg lyric url".to_string()))
}

fn fetch_wy(client: &Client, song_mid: &str) -> Result<LxLyric> {
    let path = "/api/song/lyric/v1";
    let id = song_mid.parse::<u64>().unwrap_or(0);
    let payload = json!({
        "id": id,
        "lv": -1,
        "tv": -1,
        "rv": -1,
        "kv": -1
    });
    let text =
        serde_json::to_string(&payload).map_err(|error| LxError::Request(error.to_string()))?;
    let digest = md5_hex(&format!("nobody{path}use{text}md5forencrypt"));
    let data = format!("{path}-36cd479b6b5-{text}-36cd479b6b5-{digest}");
    let params =
        aes_ecb_pkcs7_hex(data.as_bytes(), b"e82ckenh8dichen8").map_err(LxError::Request)?;
    let body = get_json(
        client
            .post("https://interface3.music.163.com/eapi/song/lyric/v1")
            .header("origin", "https://music.163.com")
            .form(&[("params", params)]),
    )?;
    let lyric = body
        .get("lrc")
        .and_then(|value| value.get("lyric"))
        .and_then(Value::as_str)
        .map(clean)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| LxError::Request("no lyrics found".to_string()))?;
    let tlyric = body
        .get("tlyric")
        .and_then(|value| value.get("lyric"))
        .and_then(Value::as_str)
        .map(clean)
        .filter(|value| !value.is_empty());
    let rlyric = body
        .get("romalrc")
        .and_then(|value| value.get("lyric"))
        .and_then(Value::as_str)
        .map(clean)
        .filter(|value| !value.is_empty());
    Ok(LxLyric {
        lyric,
        tlyric,
        rlyric,
        ..Default::default()
    })
}

fn get_text(request: reqwest::blocking::RequestBuilder) -> Result<String> {
    let response = request
        .send()
        .map_err(|error| LxError::Request(error.to_string()))?;
    if !response.status().is_success() {
        return Err(LxError::Request(format!(
            "lyric HTTP {}",
            response.status()
        )));
    }
    let bytes = response
        .bytes()
        .map_err(|error| LxError::Request(error.to_string()))?;
    if bytes.len() > 5 * 1024 * 1024 {
        return Err(LxError::Request("lyric response is too large".to_string()));
    }
    Ok(String::from_utf8_lossy(&bytes).to_string())
}

fn extra_string(info: &LxMusicInfo, key: &str) -> Option<String> {
    info.extra
        .get(key)
        .and_then(Value::as_str)
        .map(ToString::to_string)
}

fn value_text(value: &Value) -> Option<String> {
    value
        .as_str()
        .map(ToString::to_string)
        .or_else(|| value.as_i64().map(|number| number.to_string()))
        .or_else(|| value.as_u64().map(|number| number.to_string()))
}

fn value_i64(value: &Value) -> Option<i64> {
    value
        .as_i64()
        .or_else(|| value.as_str().and_then(|value| value.parse().ok()))
}

fn get_json(request: reqwest::blocking::RequestBuilder) -> Result<Value> {
    let response = request
        .send()
        .map_err(|error| LxError::Request(error.to_string()))?;
    if !response.status().is_success() {
        return Err(LxError::Request(format!(
            "lyric HTTP {}",
            response.status()
        )));
    }
    let bytes = response
        .bytes()
        .map_err(|error| LxError::Request(error.to_string()))?;
    if bytes.len() > 5 * 1024 * 1024 {
        return Err(LxError::Request("lyric response is too large".to_string()));
    }
    serde_json::from_slice(&bytes)
        .map_err(|error| LxError::Request(format!("invalid lyric response: {error}")))
}

fn lrc_time(seconds: f64) -> String {
    let minutes = (seconds / 60.0).floor() as i64;
    let rest = seconds - minutes as f64 * 60.0;
    format!("[{minutes:02}:{rest:05.2}]")
}

fn clean(value: &str) -> String {
    html_escape::decode_html_entities(value.trim())
        .replace("\r", "")
        .trim()
        .to_string()
}

fn value_f64(value: &Value) -> Option<f64> {
    value
        .as_f64()
        .or_else(|| value.as_str().and_then(|value| value.parse().ok()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_krc_lines() {
        let lyric = parse_krc("[ti:Test]\n[1000,2000]<0,100,0>你<100,100,0>好").unwrap();
        assert!(lyric.lyric.contains("[00:01.00]你好"));
        assert!(lyric.lxlyric.unwrap().contains("<0,100>你"));
    }

    #[test]
    fn formats_lrc_timestamp() {
        assert_eq!(lrc_time(0.0), "[00:00.00]");
        assert_eq!(lrc_time(65.89), "[01:05.89]");
    }
}
