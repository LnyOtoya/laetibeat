use std::time::Duration;

use reqwest::blocking::Client;
use serde_json::{json, Value};

use crate::error::{LxError, Result};
use crate::models::LxMusicInfo;

const USER_AGENT: &str = "KuGou2012-9020-ExpandSearchManager";

/// Fetch a cover URL from the platform itself. Online custom sources usually
/// only declare `musicUrl`; `pic` is a platform capability, not a script
/// capability.
pub fn fetch(platform: &str, info: &LxMusicInfo) -> Result<String> {
    match platform {
        "kg" => fetch_kg(info),
        other => Err(LxError::Request(format!(
            "platform picture is not implemented: {other}"
        ))),
    }
}

fn fetch_kg(info: &LxMusicInfo) -> Result<String> {
    let hash = info
        .extra
        .get("hash")
        .and_then(Value::as_str)
        .ok_or_else(|| LxError::Request("kg picture requires hash".to_string()))?;
    let client = Client::builder()
        .no_proxy()
        .timeout(Duration::from_secs(15))
        .user_agent(USER_AGENT)
        .build()
        .map_err(|error| LxError::Request(error.to_string()))?;
    let payload = json!({
        "appid": 1001,
        "area_code": "1",
        "behavior": "play",
        "clientver": "9020",
        "need_hash_offset": 1,
        "relate": 1,
        "resource": [{
            "album_audio_id": info.id,
            "album_id": info.album_id,
            "hash": hash,
            "id": 0,
            "name": format!("{} - {}.mp3", info.singer, info.name),
            "type": "audio"
        }],
        "token": "",
        "userid": 2626431536u64,
        "vip": 1
    });
    let body = client
        .post("http://media.store.kugou.com/v1/get_res_privilege")
        .header("KG-RC", "1")
        .header("KG-THash", "expand_search_manager.cpp:852736169:451")
        .header("Content-Type", "application/json")
        .json(&payload)
        .send()
        .map_err(|error| LxError::Request(error.to_string()))?
        .error_for_status()
        .map_err(|error| LxError::Request(error.to_string()))?
        .json::<Value>()
        .map_err(|error| LxError::Request(format!("invalid kg picture response: {error}")))?;

    if body.get("error_code").and_then(|value| value.as_i64()) != Some(0) {
        return Err(LxError::Request("kg picture request failed".to_string()));
    }
    let info_value = body
        .get("data")
        .and_then(Value::as_array)
        .and_then(|items| items.first())
        .and_then(|item| item.get("info"))
        .ok_or_else(|| LxError::Request("kg picture data missing".to_string()))?;
    let image = info_value
        .get("image")
        .and_then(Value::as_str)
        .ok_or_else(|| LxError::Request("kg picture url missing".to_string()))?;
    let size = info_value
        .get("imgsize")
        .and_then(Value::as_array)
        .and_then(|items| items.first())
        .and_then(|value| value.as_u64())
        .unwrap_or(480);
    let url = image.replace("{size}", &size.to_string());
    if !url.starts_with("http://") && !url.starts_with("https://") {
        return Err(LxError::Request("invalid kg picture url".to_string()));
    }
    Ok(url)
}
