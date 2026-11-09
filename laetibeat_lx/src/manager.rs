use std::collections::HashMap;
use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::error::{LxError, Result};
use crate::models::{LxMusicInfo, LxSourceDeclaration};
use crate::runtime::LxRuntime;
use crate::store::{LxSourceRecord, LxSourceStore};

/// Runtime state of one source. The durable script/metadata remains in the
/// store; this state is owned by the manager and can be recreated on startup.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "state", content = "message", rename_all = "snake_case")]
pub enum LxSourceStatus {
    Uninitialized,
    Initializing,
    Ready,
    Failed(String),
}

impl Default for LxSourceStatus {
    fn default() -> Self {
        Self::Uninitialized
    }
}

/// A source record plus its current runtime state and declared capabilities.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct LxSourceEntry {
    pub record: LxSourceRecord,
    pub status: LxSourceStatus,
    pub declaration: Option<LxSourceDeclaration>,
}

/// Coordinates persistent source records with loaded QuickJS runtimes.
///
/// This type deliberately stays independent from Flutter/FRB. A future facade
/// can expose snapshots and actions without changing the core manager.
pub struct LxSourceManager {
    store: LxSourceStore,
    runtimes: HashMap<String, LxRuntime>,
    statuses: HashMap<String, LxSourceStatus>,
    declarations: HashMap<String, LxSourceDeclaration>,
}

impl LxSourceManager {
    pub fn open(root: impl Into<PathBuf>) -> Result<Self> {
        Ok(Self {
            store: LxSourceStore::open(root)?,
            runtimes: HashMap::new(),
            statuses: HashMap::new(),
            declarations: HashMap::new(),
        })
    }

    pub fn import_script(&mut self, script: &str) -> Result<LxSourceRecord> {
        let record = self.store.import_script(script)?;
        self.statuses
            .insert(record.id.clone(), LxSourceStatus::Uninitialized);
        Ok(record)
    }

    pub fn list(&self) -> Vec<LxSourceEntry> {
        let mut records = self.store.list().to_vec();
        records.sort_by(|left, right| {
            right
                .priority
                .cmp(&left.priority)
                .then_with(|| left.manifest.name.cmp(&right.manifest.name))
        });
        records
            .into_iter()
            .map(|record| LxSourceEntry {
                status: self.status_of(&record.id),
                declaration: self.declarations.get(&record.id).cloned(),
                record,
            })
            .collect()
    }

    pub fn get(&self, id: &str) -> Option<LxSourceEntry> {
        self.store.get(id).map(|record| LxSourceEntry {
            status: self.status_of(id),
            declaration: self.declarations.get(id).cloned(),
            record: record.clone(),
        })
    }

    pub fn load_source(&mut self, id: &str) -> Result<()> {
        let script = self.store.load_script(id)?;
        self.statuses
            .insert(id.to_string(), LxSourceStatus::Initializing);
        self.runtimes.remove(id);
        self.declarations.remove(id);

        match LxRuntime::load(&script) {
            Ok(runtime) => {
                let declaration = runtime.declaration().clone();
                self.runtimes.insert(id.to_string(), runtime);
                self.declarations.insert(id.to_string(), declaration);
                self.statuses.insert(id.to_string(), LxSourceStatus::Ready);
                Ok(())
            }
            Err(error) => {
                self.statuses
                    .insert(id.to_string(), LxSourceStatus::Failed(error.to_string()));
                Err(error)
            }
        }
    }

    pub fn unload_source(&mut self, id: &str) {
        self.runtimes.remove(id);
        self.declarations.remove(id);
        self.statuses
            .insert(id.to_string(), LxSourceStatus::Uninitialized);
    }

    pub fn load_enabled_sources(&mut self) {
        let ids = self
            .store
            .list()
            .iter()
            .filter(|record| record.enabled)
            .map(|record| record.id.clone())
            .collect::<Vec<_>>();
        for id in ids {
            let _ = self.load_source(&id);
        }
    }

    pub fn set_enabled(&mut self, id: &str, enabled: bool) -> Result<()> {
        self.store.set_enabled(id, enabled)?;
        if enabled {
            self.load_source(id)?;
        } else {
            self.unload_source(id);
        }
        Ok(())
    }

    pub fn set_priority(&mut self, id: &str, priority: i32) -> Result<()> {
        self.store.set_priority(id, priority)
    }

    pub fn set_allow_update_alert(&mut self, id: &str, allow: bool) -> Result<()> {
        self.store.set_allow_update_alert(id, allow)
    }

    pub fn remove(&mut self, id: &str) -> Result<bool> {
        self.unload_source(id);
        self.statuses.remove(id);
        self.store.remove(id)
    }

    /// Resolve `musicUrl` from enabled, ready sources ordered by priority.
    /// A failing source is skipped so another enabled source can be tried.
    pub fn resolve_music_url(
        &mut self,
        source: &str,
        info: &LxMusicInfo,
        quality: &str,
    ) -> Result<String> {
        let candidates = self.candidates_for(source, "musicUrl");
        if candidates.is_empty() {
            return Err(LxError::Request(format!(
                "no enabled source supports musicUrl for {source}"
            )));
        }

        let mut request_info = info.clone();
        request_info.source = source.to_string();
        let mut last_error = None;

        for id in candidates {
            if !self.runtimes.contains_key(&id) {
                if let Err(error) = self.load_source(&id) {
                    last_error = Some(error);
                    continue;
                }
            }
            let Some(runtime) = self.runtimes.get(&id) else {
                continue;
            };
            match runtime.resolve_music_url(&request_info, quality) {
                Ok(url) => return Ok(url),
                Err(error) => last_error = Some(error),
            }
        }

        Err(last_error.unwrap_or_else(|| {
            LxError::Request(format!("no source resolved musicUrl for {source}"))
        }))
    }

    pub fn resolve_lyric(&mut self, source: &str, info: &LxMusicInfo) -> Result<serde_json::Value> {
        self.resolve_action(source, "lyric", info, "")
    }

    pub fn resolve_pic(&mut self, source: &str, info: &LxMusicInfo) -> Result<serde_json::Value> {
        self.resolve_action(source, "pic", info, "")
    }

    fn resolve_action(
        &mut self,
        source: &str,
        action: &str,
        info: &LxMusicInfo,
        quality: &str,
    ) -> Result<serde_json::Value> {
        let candidates = self.candidates_for(source, action);
        if candidates.is_empty() {
            return Err(LxError::Request(format!(
                "no enabled source supports {action} for {source}"
            )));
        }
        let mut request_info = info.clone();
        request_info.source = source.to_string();
        let mut last_error = None;
        for id in candidates {
            if !self.runtimes.contains_key(&id) {
                if let Err(error) = self.load_source(&id) {
                    last_error = Some(error);
                    continue;
                }
            }
            let Some(runtime) = self.runtimes.get(&id) else {
                continue;
            };
            match runtime.resolve_action(action, &request_info, quality) {
                Ok(value) => return Ok(value),
                Err(error) => last_error = Some(error),
            }
        }
        Err(last_error.unwrap_or_else(|| {
            LxError::Request(format!("no source resolved {action} for {source}"))
        }))
    }

    fn candidates_for(&self, source: &str, action: &str) -> Vec<String> {
        let mut records = self
            .store
            .list()
            .iter()
            .filter(|record| record.enabled)
            .filter(|record| {
                self.declarations
                    .get(&record.id)
                    .and_then(|declaration| declaration.sources.get(source))
                    .map(|capability| {
                        capability.source_type == "music"
                            && capability.actions.iter().any(|item| item == action)
                    })
                    .unwrap_or(true)
            })
            .cloned()
            .collect::<Vec<_>>();
        records.sort_by(|left, right| right.priority.cmp(&left.priority));
        records.into_iter().map(|record| record.id).collect()
    }

    fn status_of(&self, id: &str) -> LxSourceStatus {
        self.statuses
            .get(id)
            .cloned()
            .unwrap_or(LxSourceStatus::Uninitialized)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::time::{SystemTime, UNIX_EPOCH};

    const SCRIPT: &str = r#"/**
 * @name Manager Test
 * @description Manager source
 * @version 1.0.0
 * @author laetibeat
 */
const { EVENT_NAMES, on, send } = globalThis.lx;
on(EVENT_NAMES.request, ({ source, action }) => {
  if (action !== 'musicUrl') return Promise.reject(new Error('unsupported'));
  return Promise.resolve('https://example.com/manager.mp3');
});
send(EVENT_NAMES.inited, {
  sources: {
    kw: { type: 'music', actions: ['musicUrl'], qualitys: ['128k'] }
  }
});
"#;

    fn temp_root() -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!(
            "laetibeat_lx_manager_{}_{}",
            std::process::id(),
            nonce
        ))
    }

    #[test]
    fn enable_load_and_resolve() {
        let root = temp_root();
        let mut manager = LxSourceManager::open(&root).unwrap();
        let record = manager.import_script(SCRIPT).unwrap();
        assert_eq!(
            manager.get(&record.id).unwrap().status,
            LxSourceStatus::Uninitialized
        );

        manager.set_enabled(&record.id, true).unwrap();
        let entry = manager.get(&record.id).unwrap();
        assert_eq!(entry.status, LxSourceStatus::Ready);
        assert!(entry.declaration.is_some());

        let info = LxMusicInfo {
            source: "kw".to_string(),
            id: "123".to_string(),
            name: "Song".to_string(),
            singer: vec!["Artist".to_string()],
            album: String::new(),
            album_id: String::new(),
            interval: 0,
            img: None,
        };
        assert_eq!(
            manager.resolve_music_url("kw", &info, "128k").unwrap(),
            "https://example.com/manager.mp3"
        );

        manager.set_priority(&record.id, 99).unwrap();
        assert_eq!(manager.get(&record.id).unwrap().record.priority, 99);
        manager.remove(&record.id).unwrap();
        assert!(manager.list().is_empty());
        let _ = fs::remove_dir_all(root);
    }
}
