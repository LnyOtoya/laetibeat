use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// Metadata parsed from the leading `/* ... */` block of an LX source script.
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct LxSourceManifest {
    pub name: String,
    pub description: String,
    pub version: String,
    pub author: String,
    pub homepage: String,
}

/// A source entry declared by `lx.send(EVENT_NAMES.inited, ...)`.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct LxSourceCapability {
    #[serde(rename = "type")]
    pub source_type: String,
    #[serde(default)]
    pub actions: Vec<String>,
    #[serde(default)]
    pub qualitys: Vec<String>,
}

/// The `inited` payload, reduced to the part the host needs.
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct LxSourceDeclaration {
    #[serde(default)]
    pub sources: BTreeMap<String, LxSourceCapability>,
}

/// Minimal music info passed to a source for `musicUrl` resolution.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct LxMusicInfo {
    pub source: String,
    pub id: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub singer: Vec<String>,
    #[serde(default)]
    pub album: String,
    #[serde(default)]
    pub album_id: String,
    #[serde(default)]
    pub interval: i64,
    #[serde(default)]
    pub img: Option<String>,
}

impl LxMusicInfo {
    /// Stable identity used by the host/UI.
    pub fn key(&self) -> String {
        format!("{}:{}", self.source, self.id)
    }
}
