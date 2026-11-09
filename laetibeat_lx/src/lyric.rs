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
        "tx" => fetch_tx(&client, &info.id),
        "wy" => fetch_wy(&client, &info.id),
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
    fn formats_lrc_timestamp() {
        assert_eq!(lrc_time(0.0), "[00:00.00]");
        assert_eq!(lrc_time(65.89), "[01:05.89]");
    }
}
