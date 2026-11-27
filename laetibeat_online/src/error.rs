#[derive(Debug, thiserror::Error)]
pub enum OnlineError {
    #[error("服务地址无效: {0}")]
    InvalidBaseUrl(String),
    #[error("网络请求失败: {0}")]
    Network(#[from] reqwest::Error),
    #[error("服务返回异常: {0}")]
    Api(String),
    #[error("解析响应失败: {0}")]
    Decode(#[from] serde_json::Error),
    #[error("需要登录在线音源")]
    Unauthorized,
    #[error("在线音源未配置")]
    NotConfigured,
}

pub type Result<T> = std::result::Result<T, OnlineError>;
