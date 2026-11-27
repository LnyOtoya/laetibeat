use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::error::{LxError, Result};
use crate::import::parse_source_manifest;
use crate::models::{LxSourceDeclaration, LxSourceManifest};
use crate::utils::md5_hex;

const INDEX_FILE: &str = "index.json";
const SCRIPTS_DIR: &str = "scripts";
const MAX_SCRIPT_BYTES: usize = 4 * 1024 * 1024;

/// Persisted source metadata. The script body stays in its own file so the
/// index remains small and scripts are never embedded in normal snapshots.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct LxSourceRecord {
    pub id: String,
    pub manifest: LxSourceManifest,
    pub script_file: String,
    /// Full script hash. This is a version field only; the id is derived from
    /// the manifest identity so updating a script keeps the same source id.
    #[serde(default)]
    pub script_hash: String,
    pub enabled: bool,
    /// User-selected source. At most one record should be active.
    #[serde(default)]
    pub active: bool,
    pub priority: i32,
    pub allow_update_alert: bool,
    /// Cached `inited` declaration from the last successful load.
    ///
    /// The JS runtime itself cannot outlive the process, but its declared
    /// capabilities can: this lets the UI answer "can this platform play?"
    /// without starting QuickJS on every launch.
    #[serde(default)]
    pub declaration: Option<LxSourceDeclaration>,
    /// Script hash the cached declaration was produced from.
    #[serde(default)]
    pub declaration_hash: String,
    /// Unix seconds when the declaration was cached (diagnostics).
    #[serde(default)]
    pub declaration_at: i64,
}

fn normalized(value: &str) -> String {
    value.trim().to_lowercase()
}

/// Stable identity for a source. Version and script body are intentionally
/// excluded, so updating a script does not create a new source.
fn manifest_identity(manifest: &LxSourceManifest) -> String {
    let name = normalized(&manifest.name);
    let author = normalized(&manifest.author);
    if author.is_empty() {
        format!("{name}\u{0}{}", normalized(&manifest.homepage))
    } else {
        format!("{name}\u{0}{author}")
    }
}

fn stable_source_id(manifest: &LxSourceManifest) -> String {
    let digest = md5_hex(&manifest_identity(manifest));
    format!("lx_{}", &digest[..16])
}

/// Filesystem-backed source store. The caller supplies an application-private
/// directory; this type never chooses a public/Android storage path itself.
pub struct LxSourceStore {
    root: PathBuf,
    records: Vec<LxSourceRecord>,
}

impl LxSourceStore {
    pub fn open(root: impl Into<PathBuf>) -> Result<Self> {
        let root = root.into();
        fs::create_dir_all(root.join(SCRIPTS_DIR))
            .map_err(|error| LxError::InvalidSource(format!("create store: {error}")))?;
        let index_path = root.join(INDEX_FILE);
        let records = if index_path.exists() {
            let raw = fs::read_to_string(&index_path)
                .map_err(|error| LxError::InvalidSource(format!("read index: {error}")))?;
            serde_json::from_str::<Vec<LxSourceRecord>>(&raw)
                .map_err(|error| LxError::InvalidSource(format!("parse index: {error}")))?
        } else {
            Vec::new()
        };
        let mut store = Self { root, records };
        store.migrate_legacy_ids()?;
        Ok(store)
    }

    pub fn list(&self) -> &[LxSourceRecord] {
        &self.records
    }

    pub fn get(&self, id: &str) -> Option<&LxSourceRecord> {
        self.records.iter().find(|record| record.id == id)
    }

    /// Import or replace a source. The id comes from the manifest identity, so
    /// updating the script body/version keeps the same source id.
    pub fn import_script(&mut self, script: &str) -> Result<LxSourceRecord> {
        if script.len() > MAX_SCRIPT_BYTES {
            return Err(LxError::InvalidSource("script is too large".to_string()));
        }
        let manifest = parse_source_manifest(script)
            .ok_or_else(|| LxError::InvalidSource("missing metadata header".to_string()))?;
        let id = stable_source_id(&manifest);
        let identity = manifest_identity(&manifest);
        let script_hash = md5_hex(script);
        let script_file = format!("{id}.js");
        let script_path = self.root.join(SCRIPTS_DIR).join(&script_file);

        write_atomic(&script_path, script.as_bytes())?;

        let existing_index = self
            .records
            .iter()
            .position(|record| record.id == id || manifest_identity(&record.manifest) == identity);
        if let Some(index) = existing_index {
            let mut existing = self.records.remove(index);
            // If a previous import already used the stable id, merge the stale
            // duplicate into the record we keep.
            if let Some(duplicate_index) = self.records.iter().position(|record| record.id == id) {
                let duplicate = self.records.remove(duplicate_index);
                existing.enabled |= duplicate.enabled;
                existing.active |= duplicate.active;
                existing.allow_update_alert |= duplicate.allow_update_alert;
                if duplicate.priority > existing.priority {
                    existing.priority = duplicate.priority;
                }
                self.remove_script_file(&duplicate.script_file);
            }

            let old_script_file = existing.script_file.clone();
            existing.id = id;
            existing.manifest = manifest;
            existing.script_file = script_file;
            existing.script_hash = script_hash;
            self.records.push(existing.clone());
            if old_script_file != existing.script_file {
                self.remove_script_file(&old_script_file);
            }
            self.save_index()?;
            return Ok(existing);
        }

        let priority = self
            .records
            .iter()
            .map(|record| record.priority)
            .max()
            .unwrap_or(0)
            + 1;
        let record = LxSourceRecord {
            id,
            manifest,
            script_file,
            script_hash,
            enabled: false,
            active: false,
            priority,
            allow_update_alert: true,
            declaration: None,
            declaration_hash: String::new(),
            declaration_at: 0,
        };
        self.records.push(record.clone());
        self.save_index()?;
        Ok(record)
    }

    pub fn load_script(&self, id: &str) -> Result<String> {
        let record = self
            .get(id)
            .ok_or_else(|| LxError::InvalidSource(format!("source not found: {id}")))?;
        let path = self.safe_script_path(record)?;
        fs::read_to_string(path)
            .map_err(|error| LxError::InvalidSource(format!("read script: {error}")))
    }

    pub fn remove(&mut self, id: &str) -> Result<bool> {
        let Some(index) = self.records.iter().position(|record| record.id == id) else {
            return Ok(false);
        };
        let record = self.records.remove(index);
        let path = self.safe_script_path(&record)?;
        if path.exists() {
            fs::remove_file(path)
                .map_err(|error| LxError::InvalidSource(format!("remove script: {error}")))?;
        }
        self.save_index()?;
        Ok(true)
    }

    pub fn set_enabled(&mut self, id: &str, enabled: bool) -> Result<()> {
        let record = self
            .records
            .iter_mut()
            .find(|record| record.id == id)
            .ok_or_else(|| LxError::InvalidSource(format!("source not found: {id}")))?;
        record.enabled = enabled;
        self.save_index()
    }

    /// Cache the declaration produced by a successful load.
    pub fn set_declaration(
        &mut self,
        id: &str,
        declaration: LxSourceDeclaration,
        script_hash: &str,
        at: i64,
    ) -> Result<()> {
        let record = self
            .records
            .iter_mut()
            .find(|record| record.id == id)
            .ok_or_else(|| LxError::InvalidSource(format!("source not found: {id}")))?;
        record.declaration = Some(declaration);
        record.declaration_hash = script_hash.to_string();
        record.declaration_at = at;
        self.save_index()
    }

    /// Drop the cached declaration (load failed, or the script changed).
    pub fn clear_declaration(&mut self, id: &str) -> Result<()> {
        let record = self
            .records
            .iter_mut()
            .find(|record| record.id == id)
            .ok_or_else(|| LxError::InvalidSource(format!("source not found: {id}")))?;
        if record.declaration.is_none()
            && record.declaration_hash.is_empty()
            && record.declaration_at == 0
        {
            return Ok(());
        }
        record.declaration = None;
        record.declaration_hash.clear();
        record.declaration_at = 0;
        self.save_index()
    }

    pub fn set_active(&mut self, id: &str, active: bool) -> Result<()> {
        if !self.records.iter().any(|record| record.id == id) {
            return Err(LxError::InvalidSource(format!("source not found: {id}")));
        }
        for record in &mut self.records {
            record.active = active && record.id == id;
        }
        self.save_index()
    }

    pub fn active_id(&self) -> Option<String> {
        self.records
            .iter()
            .find(|record| record.active)
            .map(|record| record.id.clone())
    }

    pub fn set_priority(&mut self, id: &str, priority: i32) -> Result<()> {
        let record = self
            .records
            .iter_mut()
            .find(|record| record.id == id)
            .ok_or_else(|| LxError::InvalidSource(format!("source not found: {id}")))?;
        record.priority = priority;
        self.save_index()
    }

    pub fn set_allow_update_alert(&mut self, id: &str, allow: bool) -> Result<()> {
        let record = self
            .records
            .iter_mut()
            .find(|record| record.id == id)
            .ok_or_else(|| LxError::InvalidSource(format!("source not found: {id}")))?;
        record.allow_update_alert = allow;
        self.save_index()
    }

    /// Migrate legacy content-hash ids to manifest-identity ids, fill script
    /// hashes, and merge duplicates that now share the same stable id.
    fn migrate_legacy_ids(&mut self) -> Result<()> {
        let mut changed = false;
        let mut migrated: Vec<(LxSourceRecord, Option<String>)> =
            Vec::with_capacity(self.records.len());
        for mut record in std::mem::take(&mut self.records) {
            let script = self
                .safe_script_path(&record)
                .ok()
                .and_then(|path| fs::read_to_string(path).ok());
            let Some(script) = script else {
                migrated.push((record, None));
                continue;
            };
            let Some(manifest) = parse_source_manifest(&script) else {
                migrated.push((record, Some(script)));
                continue;
            };

            let stable_id = stable_source_id(&manifest);
            let script_hash = md5_hex(&script);
            let script_file = format!("{stable_id}.js");
            if record.id != stable_id
                || record.script_file != script_file
                || record.script_hash != script_hash
            {
                changed = true;
            }
            record.id = stable_id;
            record.script_file = script_file;
            record.manifest = manifest;
            record.script_hash = script_hash;
            migrated.push((record, Some(script)));
        }

        let mut by_id: HashMap<String, (LxSourceRecord, Option<String>)> = HashMap::new();
        for (record, script) in migrated {
            if let Some((existing, existing_script)) = by_id.get_mut(&record.id) {
                changed = true;
                existing.enabled |= record.enabled;
                existing.active |= record.active;
                existing.allow_update_alert |= record.allow_update_alert;
                if record.priority >= existing.priority {
                    *existing = record;
                    *existing_script = script;
                }
            } else {
                by_id.insert(record.id.clone(), (record, script));
            }
        }

        // Write the winning script back to its stable filename after merging,
        // so a lower-priority duplicate cannot overwrite the chosen content.
        for (record, script) in by_id.values() {
            if let Some(script) = script {
                let path = self.root.join(SCRIPTS_DIR).join(&record.script_file);
                write_atomic(&path, script.as_bytes())?;
            }
        }
        let kept_files: std::collections::HashSet<String> = by_id
            .values()
            .map(|(record, _)| record.script_file.clone())
            .collect();

        // Best-effort cleanup for script files belonging to discarded records.
        if let Ok(entries) = fs::read_dir(self.root.join(SCRIPTS_DIR)) {
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().to_string();
                if name.ends_with(".js") && !kept_files.contains(&name) {
                    // Only delete files whose records are gone; avoid touching
                    // unrelated files by only considering .js files.
                    let _ = fs::remove_file(entry.path());
                }
            }
        }

        self.records = by_id.into_values().map(|(record, _)| record).collect();
        if changed {
            self.save_index()?;
        }
        Ok(())
    }

    fn remove_script_file(&self, script_file: &str) {
        let path = Path::new(script_file);
        if path.components().count() != 1 {
            return;
        }
        let path = self.root.join(SCRIPTS_DIR).join(path);
        if path.exists() {
            let _ = fs::remove_file(path);
        }
    }

    fn safe_script_path(&self, record: &LxSourceRecord) -> Result<PathBuf> {
        let file = Path::new(&record.script_file);
        if file.components().count() != 1 {
            return Err(LxError::InvalidSource(
                "invalid source script filename".to_string(),
            ));
        }
        Ok(self.root.join(SCRIPTS_DIR).join(file))
    }

    fn save_index(&self) -> Result<()> {
        let raw = serde_json::to_vec_pretty(&self.records)
            .map_err(|error| LxError::InvalidSource(format!("serialize index: {error}")))?;
        write_atomic(&self.root.join(INDEX_FILE), &raw)
    }
}

fn write_atomic(path: &Path, bytes: &[u8]) -> Result<()> {
    let temp = path.with_extension(format!(
        "{}.tmp",
        path.extension()
            .and_then(|extension| extension.to_str())
            .unwrap_or("")
    ));
    fs::write(&temp, bytes)
        .map_err(|error| LxError::InvalidSource(format!("write temporary file: {error}")))?;
    if path.exists() {
        fs::remove_file(path)
            .map_err(|error| LxError::InvalidSource(format!("replace file: {error}")))?;
    }
    fs::rename(&temp, path)
        .map_err(|error| LxError::InvalidSource(format!("rename temporary file: {error}")))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    const SCRIPT: &str = r#"/**
 * @name Store Test
 * @description Stored source
 * @version 1.0.0
 * @author laetibeat
 */
send({}, { sources: {} });
"#;

    fn temp_root() -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!(
            "laetibeat_lx_store_{}_{}",
            std::process::id(),
            nonce
        ))
    }

    /// 声明缓存要能跨进程存活，并且能被显式清掉。
    #[test]
    fn caches_declaration_across_reopen() {
        use crate::models::LxSourceCapability;
        use std::collections::BTreeMap;

        let root = temp_root();
        let mut store = LxSourceStore::open(&root).unwrap();
        let record = store.import_script(SCRIPT).unwrap();
        let declaration = LxSourceDeclaration {
            sources: BTreeMap::from([(
                "kw".to_string(),
                LxSourceCapability {
                    source_type: "music".to_string(),
                    actions: vec!["musicUrl".to_string()],
                    qualitys: vec!["128k".to_string()],
                },
            )]),
        };
        store
            .set_declaration(&record.id, declaration.clone(), "hash-a", 123)
            .unwrap();

        // 重新打开（模拟下次启动）：缓存应仍在。
        let reopened = LxSourceStore::open(&root).unwrap();
        let saved = reopened.get(&record.id).unwrap();
        assert_eq!(saved.declaration.as_ref(), Some(&declaration));
        assert_eq!(saved.declaration_hash, "hash-a");
        assert_eq!(saved.declaration_at, 123);

        // 加载失败/脚本变更时清空。
        let mut store = LxSourceStore::open(&root).unwrap();
        store.clear_declaration(&record.id).unwrap();
        let cleared = LxSourceStore::open(&root).unwrap();
        let cleared = cleared.get(&record.id).unwrap();
        assert!(cleared.declaration.is_none());
        assert!(cleared.declaration_hash.is_empty());
        assert_eq!(cleared.declaration_at, 0);

        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn imports_lists_loads_and_removes() {
        let root = temp_root();
        let mut store = LxSourceStore::open(&root).unwrap();
        let record = store.import_script(SCRIPT).unwrap();
        assert_eq!(record.manifest.name, "Store Test");
        assert!(!record.enabled);
        assert_eq!(store.list().len(), 1);
        assert_eq!(store.load_script(&record.id).unwrap(), SCRIPT);

        store.set_enabled(&record.id, true).unwrap();
        store.set_priority(&record.id, 42).unwrap();
        assert!(store.get(&record.id).unwrap().enabled);
        assert_eq!(store.get(&record.id).unwrap().priority, 42);

        assert!(store.remove(&record.id).unwrap());
        assert!(store.list().is_empty());
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn reimport_updates_same_source() {
        let root = temp_root();
        let mut store = LxSourceStore::open(&root).unwrap();
        let first = store.import_script(SCRIPT).unwrap();
        let second = store.import_script(SCRIPT).unwrap();
        assert_eq!(first.id, second.id);
        assert_eq!(store.list().len(), 1);
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn script_update_keeps_stable_id() {
        let root = temp_root();
        let mut store = LxSourceStore::open(&root).unwrap();
        let first = store.import_script(SCRIPT).unwrap();
        let updated = SCRIPT.replace("Stored source", "Stored source updated");
        assert_ne!(SCRIPT, updated);

        let second = store.import_script(&updated).unwrap();
        assert_eq!(first.id, second.id);
        assert_ne!(first.script_hash, second.script_hash);
        assert_eq!(store.list().len(), 1);
        assert_eq!(store.load_script(&second.id).unwrap(), updated);
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn migrates_legacy_content_id() {
        let root = temp_root();
        let scripts = root.join(SCRIPTS_DIR);
        fs::create_dir_all(&scripts).unwrap();
        fs::write(scripts.join("legacy.js"), SCRIPT).unwrap();

        let manifest = parse_source_manifest(SCRIPT).unwrap();
        let legacy = LxSourceRecord {
            id: "lx_legacy_content_hash".to_string(),
            manifest,
            script_file: "legacy.js".to_string(),
            script_hash: String::new(),
            enabled: true,
            active: true,
            priority: 7,
            declaration: None,
            declaration_hash: String::new(),
            declaration_at: 0,
            allow_update_alert: true,
        };
        fs::write(
            root.join(INDEX_FILE),
            serde_json::to_vec_pretty(&vec![legacy]).unwrap(),
        )
        .unwrap();

        let store = LxSourceStore::open(&root).unwrap();
        assert_eq!(store.list().len(), 1);
        let record = &store.list()[0];
        assert_ne!(record.id, "lx_legacy_content_hash");
        assert_eq!(record.id, stable_source_id(&record.manifest));
        assert_eq!(record.script_file, format!("{}.js", record.id));
        assert!(!record.script_hash.is_empty());
        assert!(record.enabled);
        assert!(record.active);
        assert_eq!(record.priority, 7);
        assert!(!scripts.join("legacy.js").exists());
        assert!(scripts.join(&record.script_file).exists());
        let _ = fs::remove_dir_all(root);
    }
}
