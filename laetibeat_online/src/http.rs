use std::time::Duration;

use reqwest::blocking::{Client, RequestBuilder};
use reqwest::redirect::{Attempt, Policy};
use reqwest::{StatusCode, Url};
use serde::de::DeserializeOwned;
use serde::Deserialize;

use crate::error::{OnlineError, Result};

const MAX_REDIRECTS: usize = 5;
const REQUEST_TIMEOUT_SECS: u64 = 25;

#[derive(Debug, Deserialize)]
struct ApiResponse<D> {
    #[serde(default)]
    code: i32,
    #[serde(default)]
    msg: String,
    data: Option<D>,
}

pub(crate) struct HttpClient {
    base_url: String,
    token: Option<String>,
    client: Client,
}

/// 校验并规范化用户填写的服务地址。
pub fn validate_base_url(raw: &str) -> Result<String> {
    let (url, _) = parse_base_url(raw)?;
    Ok(normalized(url))
}

impl HttpClient {
    pub(crate) fn new(raw_base_url: &str, token: Option<&str>) -> Result<Self> {
        let (url, loopback) = parse_base_url(raw_base_url)?;
        let base_url = normalized(url.clone());
        let base_host = url.host_str().map(str::to_string);

        let policy = Policy::custom(move |attempt: Attempt<'_>| {
            if attempt.previous().len() >= MAX_REDIRECTS {
                return attempt.stop();
            }
            let target = attempt.url();
            if loopback {
                if !is_loopback_url(target) {
                    return attempt.error("blocked non-loopback redirect");
                }
                if !matches!(target.scheme(), "http" | "https") {
                    return attempt.error("blocked non-HTTP redirect");
                }
            } else {
                if target.scheme() != "https" {
                    return attempt.error("blocked non-HTTPS redirect");
                }
                if target.host_str() != base_host.as_deref() {
                    return attempt.error("blocked cross-host redirect");
                }
            }
            attempt.follow()
        });

        let client = Client::builder()
            .https_only(!loopback)
            .redirect(policy)
            .timeout(Duration::from_secs(REQUEST_TIMEOUT_SECS))
            .user_agent("Laetibeat/0.1")
            .build()?;

        let token = token
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_string);

        Ok(Self {
            base_url,
            token,
            client,
        })
    }

    pub(crate) fn base_url(&self) -> &str {
        &self.base_url
    }

    pub(crate) fn get_data<D: DeserializeOwned>(
        &self,
        path: &str,
        query: &[(&str, String)],
    ) -> Result<D> {
        self.get_data_opt(path, query)?
            .ok_or_else(|| OnlineError::Api("接口返回缺少 data".to_string()))
    }

    pub(crate) fn get_data_opt<D: DeserializeOwned>(
        &self,
        path: &str,
        query: &[(&str, String)],
    ) -> Result<Option<D>> {
        let response: ApiResponse<D> = self.get_json(path, query)?;
        if response.code != 200 {
            return Err(OnlineError::Api(if response.msg.is_empty() {
                format!("接口返回 code={}", response.code)
            } else {
                response.msg
            }));
        }
        Ok(response.data)
    }

    pub(crate) fn get_json<D: DeserializeOwned>(
        &self,
        path: &str,
        query: &[(&str, String)],
    ) -> Result<D> {
        let request = self.request(path).query(query);
        self.send(request)
    }

    fn request(&self, path: &str) -> RequestBuilder {
        let url = format!("{}{}", self.base_url, path);
        let request = self.client.get(url);
        match self.token.as_deref() {
            Some(token) => request.header("Authorization", format!("Bearer {token}")),
            None => request,
        }
    }

    fn send<D: DeserializeOwned>(&self, request: RequestBuilder) -> Result<D> {
        let response = request.send()?;
        let status = response.status();
        if matches!(status, StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN) {
            return Err(OnlineError::Unauthorized);
        }
        if !status.is_success() {
            return Err(OnlineError::Api(format!("HTTP {status}")));
        }
        Ok(response.json::<D>()?)
    }
}

fn parse_base_url(raw: &str) -> Result<(Url, bool)> {
    let trimmed = raw.trim().trim_end_matches('/');
    if trimmed.is_empty() {
        return Err(OnlineError::InvalidBaseUrl("地址为空".to_string()));
    }
    let url =
        Url::parse(trimmed).map_err(|error| OnlineError::InvalidBaseUrl(error.to_string()))?;
    if !url.username().is_empty() || url.password().is_some() {
        return Err(OnlineError::InvalidBaseUrl(
            "地址不能包含用户名或密码".to_string(),
        ));
    }
    let host = url
        .host_str()
        .ok_or_else(|| OnlineError::InvalidBaseUrl("缺少主机名".to_string()))?;
    let loopback = is_loopback_host(host);
    let scheme_ok = url.scheme() == "https" || (loopback && url.scheme() == "http");
    if !scheme_ok {
        return Err(OnlineError::InvalidBaseUrl(
            "远程服务必须使用 https，只有 loopback 允许 http".to_string(),
        ));
    }
    Ok((url, loopback))
}

fn normalized(url: Url) -> String {
    url.as_str().trim_end_matches('/').to_string()
}

fn is_loopback_url(url: &Url) -> bool {
    url.host_str().is_some_and(is_loopback_host)
}

fn is_loopback_host(host: &str) -> bool {
    if host.eq_ignore_ascii_case("localhost") {
        return true;
    }
    host.parse::<std::net::IpAddr>()
        .is_ok_and(|ip| ip.is_loopback())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_https_remote() {
        assert_eq!(
            validate_base_url("https://music.example.com/").unwrap(),
            "https://music.example.com"
        );
    }

    #[test]
    fn accepts_loopback_http() {
        assert_eq!(
            validate_base_url("http://127.0.0.1:8080").unwrap(),
            "http://127.0.0.1:8080"
        );
        assert_eq!(
            validate_base_url("http://localhost:8080").unwrap(),
            "http://localhost:8080"
        );
    }

    #[test]
    fn rejects_remote_http() {
        assert!(validate_base_url("http://music.example.com").is_err());
        assert!(validate_base_url("http://192.168.1.10:8080").is_err());
    }

    #[test]
    fn rejects_userinfo_and_empty() {
        assert!(validate_base_url("https://user:pass@example.com").is_err());
        assert!(validate_base_url("   ").is_err());
        assert!(validate_base_url("ftp://example.com").is_err());
    }
}
