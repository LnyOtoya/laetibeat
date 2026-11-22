use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::time::Instant;

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
        self.prune_orphan_runtime_state();
        // Same-id updates must unload the old runtime so the next use loads
        // the new script instead of continuing with stale declarations.
        self.runtimes.remove(&record.id);
        self.declarations.remove(&record.id);
        self.statuses
            .insert(record.id.clone(), LxSourceStatus::Uninitialized);
        Ok(record)
    }

    fn prune_orphan_runtime_state(&mut self) {
        let known: HashSet<String> = self
            .store
            .list()
            .iter()
            .map(|record| record.id.clone())
            .collect();
        self.runtimes.retain(|id, _| known.contains(id));
        self.statuses.retain(|id, _| known.contains(id));
        self.declarations.retain(|id, _| known.contains(id));
    }

    pub fn list(&self) -> Vec<LxSourceEntry> {
        let mut records = self.store.list().to_vec();
        records.sort_by(|left, right| {
            right
                .active
                .cmp(&left.active)
                .then_with(|| right.priority.cmp(&left.priority))
                .then_with(|| left.manifest.name.cmp(&right.manifest.name))
        });
        records
            .into_iter()
            .map(|record| LxSourceEntry {
                status: self.status_of(&record.id),
                declaration: self.resolved_declaration(&record),
                record,
            })
            .collect()
    }

    pub fn get(&self, id: &str) -> Option<LxSourceEntry> {
        self.store.get(id).map(|record| LxSourceEntry {
            status: self.status_of(id),
            declaration: self.resolved_declaration(record),
            record: record.clone(),
        })
    }

    /// 本次进程加载的声明优先；否则回退到持久化缓存，但只在脚本未变
    /// （hash 一致）时可信。
    fn resolved_declaration(&self, record: &LxSourceRecord) -> Option<LxSourceDeclaration> {
        self.declarations.get(&record.id).cloned().or_else(|| {
            if !record.script_hash.is_empty() && record.declaration_hash == record.script_hash {
                record.declaration.clone()
            } else {
                None
            }
        })
    }

    pub fn load_source(&mut self, id: &str) -> Result<()> {
        let script = self.store.load_script(id)?;
        let script_hash = self
            .store
            .get(id)
            .map(|record| record.script_hash.clone())
            .unwrap_or_default();
        self.statuses
            .insert(id.to_string(), LxSourceStatus::Initializing);
        self.runtimes.remove(id);
        self.declarations.remove(id);

        match LxRuntime::load(&script) {
            Ok(runtime) => {
                let declaration = runtime.declaration().clone();
                self.runtimes.insert(id.to_string(), runtime);
                self.declarations
                    .insert(id.to_string(), declaration.clone());
                self.statuses.insert(id.to_string(), LxSourceStatus::Ready);
                // 把声明持久化：下次启动判断"能不能播放"不必再跑一次 JS。
                let at = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .map(|elapsed| elapsed.as_secs() as i64)
                    .unwrap_or(0);
                if let Err(error) = self.store.set_declaration(id, declaration, &script_hash, at)
                {
                    log::warn!("lx.store cache declaration failed id={id}: {error}");
                }
                Ok(())
            }
            Err(error) => {
                // 加载失败：丢掉旧缓存，免得用过期能力误导界面。
                let _ = self.store.clear_declaration(id);
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

    /// Load only enabled sources that do not already have a live runtime.
    /// This is called lazily from list/search paths instead of startup, so a
    /// slow script or network request cannot block bootstrap.
    pub fn load_enabled_sources(&mut self) {
        let ids = self
            .store
            .list()
            .iter()
            .filter(|record| record.enabled && !self.runtimes.contains_key(&record.id))
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
            if self.store.active_id().is_none() {
                self.store.set_active(id, true)?;
            }
        } else {
            self.store.set_active(id, false)?;
            self.unload_source(id);
        }
        Ok(())
    }

    pub fn set_priority(&mut self, id: &str, priority: i32) -> Result<()> {
        self.store.set_priority(id, priority)
    }

    pub fn set_active(&mut self, id: &str, active: bool) -> Result<()> {
        self.store.set_active(id, active)
    }

    pub fn active_id(&self) -> Option<String> {
        self.store.active_id()
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
        let total_started = Instant::now();
        let candidates = self.candidates_for(source, "musicUrl");
        if candidates.is_empty() {
            log::warn!(
                "lx.play source={source} songmid={} quality={quality}: no candidate sources",
                info.id
            );
            return Err(LxError::Request(format!(
                "no enabled source supports musicUrl for {source}"
            )));
        }
        let candidate_info = candidates
            .iter()
            .map(|id| {
                let priority = self
                    .store
                    .get(id)
                    .map(|record| record.priority)
                    .unwrap_or_default();
                format!("{id}(p{priority})")
            })
            .collect::<Vec<_>>();
        log::info!(
            "lx.play start source={source} songmid={} quality={quality} candidates={:?}",
            info.id,
            candidate_info
        );

        let mut request_info = info.clone();
        request_info.source = source.to_string();
        let mut last_error = None;

        for id in candidates {
            let load_started = Instant::now();
            if !self.runtimes.contains_key(&id) {
                if let Err(error) = self.load_source(&id) {
                    log::warn!(
                        "lx.play candidate={id}: load failed in {}ms: {error}",
                        load_started.elapsed().as_millis()
                    );
                    last_error = Some(error);
                    continue;
                }
                log::info!(
                    "lx.play candidate={id}: loaded in {}ms",
                    load_started.elapsed().as_millis()
                );
            }
            let Some(runtime) = self.runtimes.get(&id) else {
                continue;
            };
            let resolve_started = Instant::now();
            match runtime.resolve_music_url(&request_info, quality) {
                Ok(url) => {
                    log::info!(
                        "lx.play candidate={id}: ok in {}ms",
                        resolve_started.elapsed().as_millis()
                    );
                    log::info!(
                        "lx.play done source={source} songmid={} quality={quality} total={}ms",
                        info.id,
                        total_started.elapsed().as_millis()
                    );
                    return Ok(url);
                }
                Err(error) => {
                    log::warn!(
                        "lx.play candidate={id}: failed in {}ms: {error}",
                        resolve_started.elapsed().as_millis()
                    );
                    last_error = Some(error);
                }
            }
        }

        log::warn!(
            "lx.play failed source={source} songmid={} quality={quality} total={}ms",
            info.id,
            total_started.elapsed().as_millis()
        );
        Err(last_error.unwrap_or_else(|| {
            LxError::Request(format!("no source resolved musicUrl for {source}"))
        }))
    }

    pub fn resolve_lyric(&mut self, source: &str, info: &LxMusicInfo) -> Result<serde_json::Value> {
        match self.resolve_action(source, "lyric", info, "") {
            Ok(value) => Ok(value),
            Err(source_error) => {
                // Online platforms expose lyrics through their own API rather
                // than the custom source script. Fall back to the built-in
                // platform lyric client when no source handles `lyric`.
                let lyric = crate::lyric::fetch(source, info).map_err(|fallback_error| {
                    LxError::Request(format!(
                        "{source_error}; platform lyric failed: {fallback_error}"
                    ))
                })?;
                serde_json::to_value(lyric).map_err(|error| {
                    LxError::InvalidResponse(format!("lyric serialization failed: {error}"))
                })
            }
        }
    }

    pub fn resolve_pic(&mut self, source: &str, info: &LxMusicInfo) -> Result<serde_json::Value> {
        match self.resolve_action(source, "pic", info, "") {
            Ok(value) => Ok(value),
            Err(source_error) => {
                let url = crate::picture::fetch(source, info).map_err(|fallback_error| {
                    LxError::Request(format!(
                        "{source_error}; platform picture failed: {fallback_error}"
                    ))
                })?;
                Ok(serde_json::Value::String(url))
            }
        }
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
        records.sort_by(|left, right| {
            right
                .active
                .cmp(&left.active)
                .then_with(|| right.priority.cmp(&left.priority))
        });
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
    use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

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

    /// 重启后不跑 JS 也能知道能力（读持久化声明），只有真正用到才加载。
    #[test]
    fn reopens_with_cached_declaration() {
        let root = temp_root();
        let mut manager = LxSourceManager::open(&root).unwrap();
        let record = manager.import_script(SCRIPT).unwrap();
        manager.set_enabled(&record.id, true).unwrap();

        // 模拟进程重启：新 manager 只有磁盘上的状态。
        let mut reopened = LxSourceManager::open(&root).unwrap();
        let entry = reopened.get(&record.id).unwrap();
        assert_eq!(entry.status, LxSourceStatus::Uninitialized);
        let declaration = entry.declaration.expect("cached declaration");
        assert!(declaration.sources.contains_key("kw"));

        // 真正需要运行时才加载。
        let started = Instant::now();
        reopened.load_source(&record.id).unwrap();
        assert!(started.elapsed() < Duration::from_secs(5));
        assert_eq!(
            reopened.get(&record.id).unwrap().status,
            LxSourceStatus::Ready
        );

        let _ = fs::remove_dir_all(root);
    }

    /// 脚本变了以后，旧声明不能再被当作可用能力。
    #[test]
    fn script_change_invalidates_cached_declaration() {
        let root = temp_root();
        let mut manager = LxSourceManager::open(&root).unwrap();
        let record = manager.import_script(SCRIPT).unwrap();
        manager.set_enabled(&record.id, true).unwrap();

        let updated = format!("{SCRIPT}
// bumped
");
        let same = manager.import_script(&updated).unwrap();
        assert_eq!(same.id, record.id);
        let entry = manager.get(&record.id).unwrap();
        assert!(
            entry.declaration.is_none(),
            "stale declaration must not be exposed"
        );

        let _ = fs::remove_dir_all(root);
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
            singer: "Artist".to_string(),
            album: String::new(),
            album_id: String::new(),
            interval: 0,
            img: None,
            extra: Default::default(),
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

    #[test]
    fn reimport_keeps_id_and_reloads_runtime() {
        let root = temp_root();
        let mut manager = LxSourceManager::open(&root).unwrap();
        let first = manager.import_script(SCRIPT).unwrap();
        manager.set_enabled(&first.id, true).unwrap();

        let info = LxMusicInfo {
            source: "kw".to_string(),
            id: "123".to_string(),
            name: "Song".to_string(),
            singer: "Artist".to_string(),
            album: String::new(),
            album_id: String::new(),
            interval: 0,
            img: None,
            extra: Default::default(),
        };
        assert_eq!(
            manager.resolve_music_url("kw", &info, "128k").unwrap(),
            "https://example.com/manager.mp3"
        );

        let updated = SCRIPT.replace("manager.mp3", "manager-v2.mp3");
        let second = manager.import_script(&updated).unwrap();
        assert_eq!(first.id, second.id);
        assert_eq!(
            manager.get(&second.id).unwrap().status,
            LxSourceStatus::Uninitialized
        );
        assert!(manager.get(&second.id).unwrap().declaration.is_none());
        assert_eq!(
            manager.resolve_music_url("kw", &info, "128k").unwrap(),
            "https://example.com/manager-v2.mp3"
        );
        let _ = fs::remove_dir_all(root);
    }
}
