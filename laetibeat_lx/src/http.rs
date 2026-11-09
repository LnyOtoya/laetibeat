use std::time::Duration;

use base64::engine::general_purpose::STANDARD;
use base64::Engine;

use reqwest::blocking::Client;
use reqwest::header::{HeaderMap, HeaderName, HeaderValue};
use reqwest::Method;
use serde::Deserialize;
use serde_json::{json, Map, Value};

const DEFAULT_TIMEOUT_MS: u64 = 13_000;
const MAX_TIMEOUT_MS: u64 = 60_000;
const MAX_BODY_BYTES: usize = 20 * 1024 * 1024;

#[derive(Debug, Default, Deserialize)]
struct RequestOptions {
    method: Option<String>,
    timeout: Option<u64>,
    headers: Option<Map<String, Value>>,
    body: Option<Value>,
    form: Option<Map<String, Value>>,
    #[serde(rename = "formData")]
    form_data: Option<Value>,
    binary: Option<bool>,
}

/// Execute the synchronous HTTP portion of `lx.request`.
///
/// The JS adapter invokes this on the source thread. Keeping it synchronous
/// makes the first bridge simple; a later revision can move it to an async
/// request broker without changing the JS-facing `lx.request` contract.
pub fn execute(url: &str, options_json: &str) -> String {
    match run(url, options_json) {
        Ok(response) => json!({ "ok": true, "response": response }).to_string(),
        Err(error) => json!({ "ok": false, "error": error }).to_string(),
    }
}

fn run(url: &str, options_json: &str) -> std::result::Result<Value, String> {
    if url.len() > 8192 || !(url.starts_with("http://") || url.starts_with("https://")) {
        return Err("invalid request URL".to_string());
    }
    let options: RequestOptions =
        serde_json::from_str(options_json).map_err(|error| format!("invalid options: {error}"))?;
    if options.form_data.is_some() {
        return Err("formData is not implemented yet".to_string());
    }

    let binary = options.binary.unwrap_or(false);
    let timeout = options
        .timeout
        .unwrap_or(DEFAULT_TIMEOUT_MS)
        .clamp(1, MAX_TIMEOUT_MS);
    let client = Client::builder()
        .no_proxy()
        .timeout(Duration::from_millis(timeout))
        .build()
        .map_err(|error| error.to_string())?;

    let method = options
        .method
        .as_deref()
        .unwrap_or("GET")
        .parse::<Method>()
        .map_err(|error| format!("invalid method: {error}"))?;

    let headers = build_headers(options.headers)?;
    let mut request = client.request(method, url).headers(headers);

    if let Some(form) = options.form {
        let pairs = form
            .into_iter()
            .filter(|(_, value)| !value.is_null())
            .map(|(key, value)| (key, value_as_string(&value)))
            .collect::<Vec<_>>();
        request = request.form(&pairs);
    } else if let Some(body) = options.body {
        match body {
            Value::String(text) => request = request.body(text),
            other => request = request.json(&other),
        }
    }

    let response = request.send().map_err(|error| error.to_string())?;
    let status = response.status();
    let final_url = response.url().to_string();
    let response_headers = response
        .headers()
        .iter()
        .filter_map(|(name, value)| {
            value
                .to_str()
                .ok()
                .map(|value| (name.as_str().to_string(), Value::String(value.to_string())))
        })
        .collect::<Map<String, Value>>();

    let bytes = response.bytes().map_err(|error| error.to_string())?;
    if bytes.len() > MAX_BODY_BYTES {
        return Err("response body is too large".to_string());
    }
    if binary {
        return Ok(json!({
            "statusCode": status.as_u16(),
            "statusMessage": status.canonical_reason().unwrap_or(""),
            "headers": response_headers,
            "body": null,
            "bodyBase64": STANDARD.encode(&bytes),
            "binary": true,
            "url": final_url,
            "ok": status.is_success(),
        }));
    }

    let text = String::from_utf8_lossy(&bytes);
    let body =
        serde_json::from_str::<Value>(&text).unwrap_or_else(|_| Value::String(text.to_string()));

    Ok(json!({
        "statusCode": status.as_u16(),
        "statusMessage": status.canonical_reason().unwrap_or(""),
        "headers": response_headers,
        "body": body,
        "binary": false,
        "url": final_url,
        "ok": status.is_success(),
    }))
}

fn build_headers(headers: Option<Map<String, Value>>) -> std::result::Result<HeaderMap, String> {
    let mut result = HeaderMap::new();
    let Some(headers) = headers else {
        return Ok(result);
    };
    for (name, value) in headers {
        let name = HeaderName::from_bytes(name.as_bytes())
            .map_err(|error| format!("invalid header name: {error}"))?;
        let value = value_as_string(&value);
        let value = HeaderValue::from_str(&value)
            .map_err(|error| format!("invalid header value: {error}"))?;
        result.insert(name, value);
    }
    Ok(result)
}

fn value_as_string(value: &Value) -> String {
    match value {
        Value::String(value) => value.clone(),
        other => other.to_string(),
    }
}
