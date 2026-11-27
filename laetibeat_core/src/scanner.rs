use crate::model::{MusicLibrary, SourceType, Track, make_album_id, make_artist_id};
use lofty::file::{AudioFile, TaggedFile, TaggedFileExt};
use lofty::read_from;
use lofty::tag::{Accessor, ItemKey};
use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::time::{Instant, UNIX_EPOCH};
use walkdir::WalkDir;

/// 一次扫描的统计结果
#[derive(Debug, Clone, Default)]
pub struct ScanStats {
    /// 本次目录中找到的音频文件总数
    pub total_files: u32,
    /// 实际解析标签的文件数(新增/修改)
    pub parsed_files: u32,
    /// 命中 mtime/size 缓存、直接复用的文件数
    pub reused_files: u32,
    /// 上次存在、本次目录中已不存在的文件数
    pub removed_files: u32,
    /// 扫描耗时(毫秒)
    pub elapsed_ms: u64,
}

/// 解析单个音频文件（普通路径）。
pub fn parse_audio_track(
    file_path: &Path,
    id: String,
    relative_path: Option<String>,
    fallback_title: Option<&str>,
    modified_ms: Option<u64>,
    file_size: Option<u64>,
) -> Track {
    let tagged_file = std::fs::File::open(file_path)
        .ok()
        .and_then(|mut file| read_from(&mut file).ok());
    parse_audio_track_with_tagged(
        tagged_file,
        Some(file_path),
        id,
        relative_path,
        fallback_title,
        modified_ms,
        file_size,
    )
}

/// 解析已打开的音频文件（Android SAF fd）。
pub fn parse_audio_track_from_file(
    file: std::fs::File,
    id: String,
    relative_path: Option<String>,
    fallback_title: Option<&str>,
    modified_ms: Option<u64>,
    file_size: Option<u64>,
) -> Track {
    let mut file = file;
    let tagged_file = read_from(&mut file).ok();
    parse_audio_track_with_tagged(
        tagged_file,
        None,
        id,
        relative_path,
        fallback_title,
        modified_ms,
        file_size,
    )
}

fn parse_audio_track_with_tagged(
    tagged_file: Option<TaggedFile>,
    file_path: Option<&Path>,
    id: String,
    relative_path: Option<String>,
    fallback_title: Option<&str>,
    modified_ms: Option<u64>,
    file_size: Option<u64>,
) -> Track {
    let fallback_title = fallback_title
        .map(str::to_string)
        .or_else(|| {
            file_path
                .and_then(|path| path.file_stem())
                .and_then(|s| s.to_str())
                .map(str::to_string)
        })
        .unwrap_or_else(|| "未知歌曲".to_string());

    let fallback_title = clean_fallback_title(&fallback_title);
    let mut title = fallback_title.clone();
    let mut artist = "未知艺术家".to_string();
    let mut album = "本地音乐".to_string();
    let mut duration = 0;

    let mut track_number = None;
    let mut disc_number = None;
    let mut album_artist: Option<String> = None;
    let mut year = None;
    let mut genre = None;
    let mut bitrate = None;
    let mut sample_rate = None;
    let mut channels = None;

    if let Some(tagged_file) = tagged_file {
        let properties = tagged_file.properties();
        duration = properties.duration().as_secs();
        bitrate = properties.audio_bitrate();
        sample_rate = properties.sample_rate();
        channels = properties.channels();

        // 同一文件可能同时有 ID3v2 与 Vorbis Comments；不能只看 primary_tag，
        // 否则艺术家/专辑等字段可能落在另一个 tag 里而显示为未知。
        for tag in tagged_file.tags() {
            if title == fallback_title {
                if let Some(track_title) = tag.title() {
                    let value = track_title.trim();
                    if !value.is_empty() {
                        title = value.to_string();
                    }
                }
            }
            if artist == "未知艺术家" {
                if let Some(track_artist) = tag.artist() {
                    let value = track_artist.trim();
                    if !value.is_empty() {
                        artist = value.to_string();
                    }
                }
            }
            if album == "本地音乐" {
                if let Some(track_album) = tag.album() {
                    let value = track_album.trim();
                    if !value.is_empty() {
                        album = value.to_string();
                    }
                }
            }
            if track_number.is_none() {
                track_number = tag.track();
            }
            if disc_number.is_none() {
                disc_number = tag.disk();
            }
            if year.is_none() {
                year = tag.date().map(|d| d.year as u32);
            }
            if genre.is_none() {
                genre = tag.genre().map(|g| g.to_string());
            }
            if album_artist.is_none() {
                album_artist = tag.get_string(ItemKey::AlbumArtist).map(str::to_string);
            }
        }
    }

    let album_artist = album_artist.unwrap_or_else(|| artist.clone());
    let album_id = make_album_id(&album_artist, &album);
    let artist_id = make_artist_id(&artist);
    let source_path = file_path
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from(&id));

    Track {
        id,
        relative_path,
        title,
        artist,
        album,
        album_artist,
        album_id,
        artist_id,
        track_number,
        disc_number,
        year,
        genre,
        duration,
        bitrate,
        sample_rate,
        channels,
        modified_ms,
        file_size,
        source_type: SourceType::LocalFile(source_path),
    }
}

/// 全量扫描(保留给命令行/测试使用)
pub fn scan_directory<P: AsRef<Path>>(
    library: &mut MusicLibrary,
    dir_path: P,
) -> Result<(), String> {
    scan_directory_incremental(library, dir_path, &[]).map(|_| ())
}

/// 增量扫描:对 mtime + 文件大小未变化的曲目直接复用 known_tracks 中的数据,
/// 只对新增/修改的文件重新读取 lofty 标签。
pub fn scan_directory_incremental<P: AsRef<Path>>(
    library: &mut MusicLibrary,
    dir_path: P,
    known_tracks: &[Track],
) -> Result<ScanStats, String> {
    let started = Instant::now();
    let path = dir_path.as_ref();
    if !path.is_dir() {
        return Err(format!("路径不存在或不是文件夹: {:?}", path));
    }

    // 以上次的曲目 id(本地文件即路径)为键,后续按路径复用
    let known: HashMap<String, &Track> = known_tracks
        .iter()
        .map(|track| (track.id.clone(), track))
        .collect();
    let mut seen: HashSet<String> = HashSet::new();
    let mut stats = ScanStats::default();

    // walkdir替代
    for entry in WalkDir::new(path).into_iter().filter_map(|e| e.ok()) {
        let file_path = entry.path();
        // 判断文件再查后缀
        if !file_path.is_file() {
            continue;
        }
        let Some(ext) = file_path.extension().and_then(|e| e.to_str()) else {
            continue;
        };
        let ext_lower = ext.to_lowercase();
        if ext_lower != "mp3" && ext_lower != "flac" && ext_lower != "m4a" && ext_lower != "wav" {
            continue;
        }

        let path_str = file_path.to_string_lossy().to_string();
        seen.insert(path_str.clone());
        stats.total_files += 1;

        // 文件时间戳与大小:作为"是否需要重新解析"的判据
        let metadata = std::fs::metadata(file_path).ok();
        let modified_ms = metadata
            .as_ref()
            .and_then(|m| m.modified().ok())
            .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
            .map(|d| d.as_millis() as u64);
        let file_size = metadata.as_ref().map(|m| m.len());

        // 未变化则直接复用上次解析结果
        if let Some(cached) = known.get(&path_str) {
            if modified_ms.is_some()
                && cached.modified_ms == modified_ms
                && cached.file_size == file_size
            {
                library.add_track((**cached).clone());
                stats.reused_files += 1;
                continue;
            }
        }

        let relative_path = file_path
            .strip_prefix(path)
            .ok()
            .map(|p| p.to_string_lossy().to_string());
        library.add_track(parse_audio_track(
            file_path,
            path_str,
            relative_path,
            None,
            modified_ms,
            file_size,
        ));
        stats.parsed_files += 1;
    }

    stats.removed_files = known.keys().filter(|id| !seen.contains(*id)).count() as u32;
    stats.elapsed_ms = started.elapsed().as_millis() as u64;
    Ok(stats)
}

/// 标签缺失时从文件名推导标题，尽量去掉音轨号前缀。
fn clean_fallback_title(value: &str) -> String {
    let trimmed = value.trim();
    let digit_end = trimmed
        .find(|character: char| !character.is_ascii_digit())
        .unwrap_or(trimmed.len());
    if digit_end > 0 && digit_end < trimmed.len() {
        let rest = trimmed[digit_end..].trim_start_matches(|character: char| {
            character == '.'
                || character == '-'
                || character == '_'
                || character == ' '
                || character == '、'
                || character == '　'
        });
        if !rest.is_empty() {
            return rest.trim().to_string();
        }
    }
    trimmed.to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::PathBuf;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn temp_dir() -> PathBuf {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let dir =
            std::env::temp_dir().join(format!("laetibeat_scan_{}_{}", std::process::id(), stamp));
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn incremental_scan_reuses_unchanged_and_counts_removed() {
        let dir = temp_dir();
        let file = dir.join("song.wav");
        // 内容不重要:解析失败也会生成一条兜底曲目,足以验证增量复用逻辑
        fs::write(&file, b"not a real wav").unwrap();

        let mut first_library = MusicLibrary::new();
        let first = scan_directory_incremental(&mut first_library, &dir, &[]).unwrap();
        assert_eq!(first.total_files, 1);
        assert_eq!(first.parsed_files, 1);
        assert_eq!(first.reused_files, 0);
        assert_eq!(first.removed_files, 0);
        assert_eq!(first_library.tracks.len(), 1);
        assert!(first_library.tracks[0].modified_ms.is_some());

        // 第二次扫描:文件未变化,应直接复用
        let known = first_library.tracks.clone();
        let mut second_library = MusicLibrary::new();
        let second = scan_directory_incremental(&mut second_library, &dir, &known).unwrap();
        assert_eq!(second.total_files, 1);
        assert_eq!(second.parsed_files, 0);
        assert_eq!(second.reused_files, 1);
        assert_eq!(second_library.tracks.len(), 1);

        // 删除文件后:应统计为移除
        fs::remove_file(&file).unwrap();
        let mut third_library = MusicLibrary::new();
        let third = scan_directory_incremental(&mut third_library, &dir, &known).unwrap();
        assert_eq!(third.total_files, 0);
        assert_eq!(third.removed_files, 1);

        fs::remove_dir_all(&dir).unwrap();
    }
}
