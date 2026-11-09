//! Independent LX custom-source host for Laetibeat.
//!
//! This crate deliberately does not depend on Flutter, FRB, or the reference
//! LX mobile project. The first milestone provides:
//! - source metadata parsing
//! - QuickJS runtime bootstrapping
//! - `inited` handshake
//! - a minimal `musicUrl` dispatch
//!
//! HTTP proxying, source persistence, and the Flutter facade are later stages.

pub mod error;
pub mod http;
pub mod import;
pub mod lyric;
pub mod manager;
pub mod models;
pub mod picture;
pub mod runtime;
pub mod search;
pub mod store;
pub mod utils;

pub use error::{LxError, Result};
pub use import::parse_source_manifest;
pub use lyric::LxLyric;
pub use manager::{LxSourceEntry, LxSourceManager, LxSourceStatus};
pub use models::{LxMusicInfo, LxSourceCapability, LxSourceDeclaration, LxSourceManifest};
pub use runtime::LxRuntime;
pub use search::{LxSearchPage, LxSearchTrack, SUPPORTED_PLATFORMS};
pub use store::{LxSourceRecord, LxSourceStore};
