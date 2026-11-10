use std::fs;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::error::{LxError, Result};
use crate::import::parse_source_manifest;
use crate::models::LxSourceManifest;
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
    pub enabled: bool,
    /// User-selected source. At most one record should be active.
    #[serde(default)]
    pub active: bool,
    pub priority: i32,
    pub allow_update_alert: bool,
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
        Ok(Self { root, records })
    }

    pub fn list(&self) -> &[LxSourceRecord] {
        &self.records
    }

    pub fn get(&self, id: &str) -> Option<&LxSourceRecord> {
        self.records.iter().find(|record| record.id == id)
    }

    /// Import or replace a source. The id is derived from the script content,
    /// so importing the same script again updates it instead of duplicating it.
    pub fn import_script(&mut self, script: &str) -> Result<LxSourceRecord> {
        if script.len() > MAX_SCRIPT_BYTES {
            return Err(LxError::InvalidSource("script is too large".to_string()));
        }
        let manifest = parse_source_manifest(script)
            .ok_or_else(|| LxError::InvalidSource("missing metadata header".to_string()))?;
        let id = format!("lx_{}", &md5_hex(script)[..16]);
        let script_file = format!("{id}.js");
        let script_path = self.root.join(SCRIPTS_DIR).join(&script_file);

        write_atomic(&script_path, script.as_bytes())?;

        if let Some(existing) = self.records.iter_mut().find(|record| record.id == id) {
            existing.manifest = manifest;
            existing.script_file = script_file;
            let record = existing.clone();
            self.save_index()?;
            return Ok(record);
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
            enabled: false,
            active: false,
            priority,
            allow_update_alert: true,
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
}
