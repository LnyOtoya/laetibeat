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
pub mod models;
pub mod runtime;
pub mod utils;

pub use error::{LxError, Result};
pub use import::parse_source_manifest;
pub use models::{LxMusicInfo, LxSourceCapability, LxSourceDeclaration, LxSourceManifest};
pub use runtime::LxRuntime;
