//! 在线音源统一客户端：兼容 laetibeat_qq_host / laetibeat_netease_host。
//!
//! 只负责 HTTP/JSON 与 DTO 映射；不包含网易云/QQ 的平台专属逻辑。
//! 所有请求都经过 [`http::HttpClient`] 的 HTTPS-only 策略。

mod error;
mod http;
mod model;
mod musicapi;

pub use error::{OnlineError, Result};
pub use http::validate_base_url;
pub use model::{
    OnlineAlbum, OnlineLyric, OnlinePlatformStatus, OnlinePlaylist, OnlineQrResult,
    OnlineQrSession, OnlineQuality, OnlineResolvedAudio, OnlineSearchResult, OnlineTopList,
    OnlineTrack,
};
pub use musicapi::OnlineClient;
