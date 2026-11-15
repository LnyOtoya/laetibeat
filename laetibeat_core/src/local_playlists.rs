use std::sync::{Mutex, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

use rusqlite::{params, Connection, OptionalExtension};

const SCHEMA_VERSION: i64 = 1;

const SCHEMA_V1: &str = r#"
CREATE TABLE IF NOT EXISTS local_playlists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS local_playlist_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    playlist_id INTEGER NOT NULL REFERENCES local_playlists(id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    source TEXT NOT NULL,
    source_id TEXT NOT NULL,
    track_id TEXT NOT NULL,
    relative_path TEXT,
    title TEXT NOT NULL,
    artist TEXT NOT NULL DEFAULT '',
    album TEXT NOT NULL DEFAULT '',
    duration_seconds INTEGER NOT NULL DEFAULT 0,
    added_at INTEGER NOT NULL,
    UNIQUE(playlist_id, source, source_id, track_id)
);

CREATE INDEX IF NOT EXISTS idx_local_playlist_items_playlist
    ON local_playlist_items(playlist_id, position);
"#;

static STORE: OnceLock<Mutex<LocalPlaylistStore>> = OnceLock::new();

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LocalPlaylistSummary {
    pub id: i64,
    pub name: String,
    pub item_count: i64,
    pub duration_seconds: i64,
    pub created_at: i64,
    pub updated_at: i64,
    pub cover_source: Option<String>,
    pub cover_source_id: Option<String>,
    pub cover_track_id: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LocalPlaylistItem {
    pub id: i64,
    pub position: i64,
    pub source: String,
    pub source_id: String,
    pub track_id: String,
    pub relative_path: Option<String>,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration_seconds: i64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LocalPlaylistDetail {
    pub playlist: LocalPlaylistSummary,
    pub items: Vec<LocalPlaylistItem>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlaylistTrackInput {
    pub source: String,
    pub source_id: String,
    pub track_id: String,
    pub relative_path: Option<String>,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration_seconds: i64,
}

pub struct LocalPlaylistStore {
    conn: Connection,
}

impl LocalPlaylistStore {
    pub fn open(path: &str) -> Result<Self, String> {
        let conn = Connection::open(path).map_err(map_err)?;
        Self::from_connection(conn)
    }

    #[cfg(test)]
    fn open_in_memory() -> Result<Self, String> {
        let conn = Connection::open_in_memory().map_err(map_err)?;
        Self::from_connection(conn)
    }

    fn from_connection(conn: Connection) -> Result<Self, String> {
        conn.execute_batch(
            "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA foreign_keys=ON;",
        )
        .map_err(map_err)?;
        let version: i64 = conn
            .query_row("PRAGMA user_version", [], |row| row.get(0))
            .map_err(map_err)?;
        if version < SCHEMA_VERSION {
            conn.execute_batch(SCHEMA_V1).map_err(map_err)?;
            conn.pragma_update(None, "user_version", SCHEMA_VERSION)
                .map_err(map_err)?;
        }
        Ok(Self { conn })
    }

    pub fn list(&self) -> Result<Vec<LocalPlaylistSummary>, String> {
        let mut stmt = self
            .conn
            .prepare(
                "SELECT id, name, created_at, updated_at
                 FROM local_playlists
                 ORDER BY updated_at DESC, id DESC",
            )
            .map_err(map_err)?;
        let rows = stmt
            .query_map([], |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, i64>(2)?,
                    row.get::<_, i64>(3)?,
                ))
            })
            .map_err(map_err)?;
        let mut result = Vec::new();
        for row in rows {
            let (id, name, created_at, updated_at) = row.map_err(map_err)?;
            result.push(self.summary_basic(id, name, created_at, updated_at)?);
        }
        Ok(result)
    }

    pub fn get(&self, id: i64) -> Result<Option<LocalPlaylistDetail>, String> {
        let Some(playlist) = self.summary_by_id(id)? else {
            return Ok(None);
        };
        let mut stmt = self
            .conn
            .prepare(
                "SELECT id, position, source, source_id, track_id, relative_path,
                        title, artist, album, duration_seconds
                 FROM local_playlist_items
                 WHERE playlist_id = ?1
                 ORDER BY position, id",
            )
            .map_err(map_err)?;
        let rows = stmt
            .query_map(params![id], |row| {
                Ok(LocalPlaylistItem {
                    id: row.get(0)?,
                    position: row.get(1)?,
                    source: row.get(2)?,
                    source_id: row.get(3)?,
                    track_id: row.get(4)?,
                    relative_path: row.get(5)?,
                    title: row.get(6)?,
                    artist: row.get(7)?,
                    album: row.get(8)?,
                    duration_seconds: row.get(9)?,
                })
            })
            .map_err(map_err)?;
        let items = collect(rows)?;
        Ok(Some(LocalPlaylistDetail { playlist, items }))
    }

    pub fn create(&mut self, name: &str) -> Result<LocalPlaylistSummary, String> {
        let name = clean_name(name)?;
        let now = now_ms();
        self.conn
            .execute(
                "INSERT INTO local_playlists(name, created_at, updated_at)
                 VALUES(?1, ?2, ?2)",
                params![name, now],
            )
            .map_err(map_err)?;
        let id = self.conn.last_insert_rowid();
        self.summary_by_id(id)?
            .ok_or_else(|| "创建歌单后无法读取记录".to_string())
    }

    pub fn rename(&mut self, id: i64, name: &str) -> Result<(), String> {
        let name = clean_name(name)?;
        let now = now_ms();
        let changed = self
            .conn
            .execute(
                "UPDATE local_playlists SET name = ?1, updated_at = ?2 WHERE id = ?3",
                params![name, now, id],
            )
            .map_err(map_err)?;
        if changed == 0 {
            return Err("歌单不存在".to_string());
        }
        Ok(())
    }

    pub fn delete(&mut self, id: i64) -> Result<bool, String> {
        let changed = self
            .conn
            .execute("DELETE FROM local_playlists WHERE id = ?1", params![id])
            .map_err(map_err)?;
        Ok(changed > 0)
    }

    pub fn add_tracks(
        &mut self,
        playlist_id: i64,
        tracks: &[PlaylistTrackInput],
    ) -> Result<usize, String> {
        if tracks.is_empty() {
            return Ok(0);
        }
        let tx = self.conn.transaction().map_err(map_err)?;
        let exists: Option<i64> = tx
            .query_row(
                "SELECT id FROM local_playlists WHERE id = ?1",
                params![playlist_id],
                |row| row.get(0),
            )
            .optional()
            .map_err(map_err)?;
        if exists.is_none() {
            return Err("歌单不存在".to_string());
        }

        let mut position: i64 = tx
            .query_row(
                "SELECT COALESCE(MAX(position), -1) + 1
                 FROM local_playlist_items WHERE playlist_id = ?1",
                params![playlist_id],
                |row| row.get(0),
            )
            .map_err(map_err)?;
        let now = now_ms();
        let mut added = 0usize;
        for track in tracks {
            let changed = tx
                .execute(
                    "INSERT OR IGNORE INTO local_playlist_items(
                        playlist_id, position, source, source_id, track_id,
                        relative_path, title, artist, album, duration_seconds, added_at
                     ) VALUES(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
                    params![
                        playlist_id,
                        position,
                        track.source,
                        track.source_id,
                        track.track_id,
                        track.relative_path,
                        track.title,
                        track.artist,
                        track.album,
                        track.duration_seconds,
                        now,
                    ],
                )
                .map_err(map_err)?;
            if changed > 0 {
                position += 1;
                added += 1;
            }
        }
        touch(&tx, playlist_id, now)?;
        tx.commit().map_err(map_err)?;
        Ok(added)
    }

    pub fn remove_item(&mut self, playlist_id: i64, item_id: i64) -> Result<bool, String> {
        let tx = self.conn.transaction().map_err(map_err)?;
        let changed = tx
            .execute(
                "DELETE FROM local_playlist_items
                 WHERE id = ?1 AND playlist_id = ?2",
                params![item_id, playlist_id],
            )
            .map_err(map_err)?;
        if changed > 0 {
            normalize_positions(&tx, playlist_id)?;
            touch(&tx, playlist_id, now_ms())?;
        }
        tx.commit().map_err(map_err)?;
        Ok(changed > 0)
    }

    pub fn reorder(&mut self, playlist_id: i64, item_ids: &[i64]) -> Result<(), String> {
        let tx = self.conn.transaction().map_err(map_err)?;
        for (position, item_id) in item_ids.iter().enumerate() {
            tx.execute(
                "UPDATE local_playlist_items SET position = ?1
                 WHERE id = ?2 AND playlist_id = ?3",
                params![position as i64, item_id, playlist_id],
            )
            .map_err(map_err)?;
        }
        normalize_positions(&tx, playlist_id)?;
        touch(&tx, playlist_id, now_ms())?;
        tx.commit().map_err(map_err)
    }

    fn summary_by_id(&self, id: i64) -> Result<Option<LocalPlaylistSummary>, String> {
        let row = self
            .conn
            .query_row(
                "SELECT id, name, created_at, updated_at FROM local_playlists WHERE id = ?1",
                params![id],
                |row| {
                    Ok((
                        row.get::<_, i64>(0)?,
                        row.get::<_, String>(1)?,
                        row.get::<_, i64>(2)?,
                        row.get::<_, i64>(3)?,
                    ))
                },
            )
            .optional()
            .map_err(map_err)?;
        row.map(|(id, name, created_at, updated_at)| {
            self.summary_basic(id, name, created_at, updated_at)
        })
        .transpose()
    }

    fn summary_basic(
        &self,
        id: i64,
        name: String,
        created_at: i64,
        updated_at: i64,
    ) -> Result<LocalPlaylistSummary, String> {
        let (item_count, duration_seconds): (i64, i64) = self
            .conn
            .query_row(
                "SELECT COUNT(*), COALESCE(SUM(duration_seconds), 0)
                 FROM local_playlist_items WHERE playlist_id = ?1",
                params![id],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .map_err(map_err)?;
        let cover = self
            .conn
            .query_row(
                "SELECT source, source_id, track_id
                 FROM local_playlist_items
                 WHERE playlist_id = ?1
                 ORDER BY position, id LIMIT 1",
                params![id],
                |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, String>(1)?,
                        row.get::<_, String>(2)?,
                    ))
                },
            )
            .optional()
            .map_err(map_err)?;
        Ok(LocalPlaylistSummary {
            id,
            name,
            item_count,
            duration_seconds,
            created_at,
            updated_at,
            cover_source: cover.as_ref().map(|item| item.0.clone()),
            cover_source_id: cover.as_ref().map(|item| item.1.clone()),
            cover_track_id: cover.as_ref().map(|item| item.2.clone()),
        })
    }
}

/// Initialize the process-wide playlist database. Safe to call more than once.
pub fn init_db(path: &str) -> Result<(), String> {
    if STORE.get().is_some() {
        return Ok(());
    }
    let store = LocalPlaylistStore::open(path)?;
    STORE
        .set(Mutex::new(store))
        .map_err(|_| "歌单库已初始化".to_string())
}

fn with_store<T>(f: impl FnOnce(&mut LocalPlaylistStore) -> Result<T, String>) -> Result<T, String> {
    let mut guard = STORE
        .get()
        .ok_or_else(|| "歌单库尚未初始化".to_string())?
        .lock()
        .map_err(|_| "歌单库锁失败".to_string())?;
    f(&mut guard)
}

pub fn list() -> Result<Vec<LocalPlaylistSummary>, String> {
    with_store(|store| store.list())
}

pub fn get(id: i64) -> Result<Option<LocalPlaylistDetail>, String> {
    with_store(|store| store.get(id))
}

pub fn create(name: &str) -> Result<LocalPlaylistSummary, String> {
    with_store(|store| store.create(name))
}

pub fn rename(id: i64, name: &str) -> Result<(), String> {
    with_store(|store| store.rename(id, name))
}

pub fn delete(id: i64) -> Result<bool, String> {
    with_store(|store| store.delete(id))
}

pub fn add_tracks(playlist_id: i64, tracks: &[PlaylistTrackInput]) -> Result<usize, String> {
    with_store(|store| store.add_tracks(playlist_id, tracks))
}

pub fn remove_item(playlist_id: i64, item_id: i64) -> Result<bool, String> {
    with_store(|store| store.remove_item(playlist_id, item_id))
}

pub fn reorder(playlist_id: i64, item_ids: &[i64]) -> Result<(), String> {
    with_store(|store| store.reorder(playlist_id, item_ids))
}

fn clean_name(name: &str) -> Result<String, String> {
    let name = name.trim();
    if name.is_empty() {
        return Err("歌单名不能为空".to_string());
    }
    if name.chars().count() > 80 {
        return Err("歌单名过长".to_string());
    }
    Ok(name.to_string())
}

fn touch(conn: &Connection, playlist_id: i64, now: i64) -> Result<(), String> {
    conn.execute(
        "UPDATE local_playlists SET updated_at = ?1 WHERE id = ?2",
        params![now, playlist_id],
    )
    .map_err(map_err)?;
    Ok(())
}

fn normalize_positions(conn: &Connection, playlist_id: i64) -> Result<(), String> {
    let mut stmt = conn
        .prepare(
            "SELECT id FROM local_playlist_items
             WHERE playlist_id = ?1 ORDER BY position, id",
        )
        .map_err(map_err)?;
    let ids = collect(
        stmt.query_map(params![playlist_id], |row| row.get::<_, i64>(0))
            .map_err(map_err)?,
    )?;
    for (position, id) in ids.iter().enumerate() {
        conn.execute(
            "UPDATE local_playlist_items SET position = ?1 WHERE id = ?2",
            params![position as i64, id],
        )
        .map_err(map_err)?;
    }
    Ok(())
}

fn collect<T>(
    rows: rusqlite::MappedRows<'_, impl FnMut(&rusqlite::Row<'_>) -> rusqlite::Result<T>>,
) -> Result<Vec<T>, String> {
    let mut result = Vec::new();
    for row in rows {
        result.push(row.map_err(map_err)?);
    }
    Ok(result)
}

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis() as i64)
        .unwrap_or(0)
}

fn map_err(error: impl std::fmt::Display) -> String {
    error.to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn track(id: &str) -> PlaylistTrackInput {
        PlaylistTrackInput {
            source: "local".to_string(),
            source_id: String::new(),
            track_id: id.to_string(),
            relative_path: Some(format!("{id}.flac")),
            title: format!("Track {id}"),
            artist: "Artist".to_string(),
            album: "Album".to_string(),
            duration_seconds: 180,
        }
    }

    #[test]
    fn creates_lists_renames_and_deletes() {
        let mut store = LocalPlaylistStore::open_in_memory().unwrap();
        let playlist = store.create("Night").unwrap();
        assert_eq!(playlist.name, "Night");
        assert_eq!(playlist.item_count, 0);

        let list = store.list().unwrap();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].id, playlist.id);

        store.rename(playlist.id, "Night Drive").unwrap();
        assert_eq!(store.get(playlist.id).unwrap().unwrap().playlist.name, "Night Drive");
        assert!(store.delete(playlist.id).unwrap());
        assert!(store.get(playlist.id).unwrap().is_none());
    }

    #[test]
    fn adds_deduplicates_removes_and_reorders() {
        let mut store = LocalPlaylistStore::open_in_memory().unwrap();
        let playlist = store.create("Mix").unwrap();
        assert_eq!(
            store
                .add_tracks(playlist.id, &[track("a"), track("b"), track("a")])
                .unwrap(),
            2
        );

        let detail = store.get(playlist.id).unwrap().unwrap();
        assert_eq!(detail.items.len(), 2);
        assert_eq!(detail.playlist.item_count, 2);
        assert_eq!(detail.playlist.duration_seconds, 360);
        assert_eq!(detail.playlist.cover_track_id.as_deref(), Some("a"));

        let first = detail.items[0].id;
        let second = detail.items[1].id;
        store.reorder(playlist.id, &[second, first]).unwrap();
        let reordered = store.get(playlist.id).unwrap().unwrap();
        assert_eq!(reordered.items[0].id, second);
        assert_eq!(reordered.items[0].position, 0);

        assert!(store.remove_item(playlist.id, second).unwrap());
        let after = store.get(playlist.id).unwrap().unwrap();
        assert_eq!(after.items.len(), 1);
        assert_eq!(after.items[0].position, 0);
    }
}
