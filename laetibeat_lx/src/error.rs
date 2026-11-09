use thiserror::Error;

#[derive(Debug, Error)]
pub enum LxError {
    #[error("JavaScript runtime error: {0}")]
    Js(String),
    #[error("source initialization failed: {0}")]
    Init(String),
    #[error("source is not initialized")]
    NotInitialized,
    #[error("source does not support action: {0}")]
    UnsupportedAction(String),
    #[error("source returned an invalid response: {0}")]
    InvalidResponse(String),
    #[error("source request failed: {0}")]
    Request(String),
    #[error("source metadata is invalid: {0}")]
    InvalidSource(String),
}

impl From<rquickjs::Error> for LxError {
    fn from(value: rquickjs::Error) -> Self {
        Self::Js(value.to_string())
    }
}

pub type Result<T> = std::result::Result<T, LxError>;
