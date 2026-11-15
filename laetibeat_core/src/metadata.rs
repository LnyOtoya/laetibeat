use std::fs::{self, File};
use std::path::Path;

use lofty::file::{TaggedFile, TaggedFileExt};
use lofty::picture::PictureType;
use lofty::tag::ItemKey;

/// 按文件内容而不是扩展名读取音频标签。
fn read_tagged_from_file(mut file: File) -> Option<TaggedFile> {
    lofty::read_from(&mut file).ok()
}

fn read_tagged_file(path: &str) -> Option<TaggedFile> {
    read_tagged_from_file(File::open(path).ok()?)
}

/// 复制 Android SAF 传入的 fd，包装成 Rust 独占的 File。
///
/// 不能重新打开 `/proc/self/fd/N`：SAF 授权的是 fd，普通路径可能仍被
/// scoped storage 拒绝。dup 后由 Rust 负责关闭，原 fd 仍由 Flutter 插件关闭。
#[cfg(unix)]
pub fn file_from_fd(fd: i32) -> Option<File> {
    use std::os::fd::FromRawFd;

    let duplicated = unsafe { libc::dup(fd) };
    if duplicated < 0 {
        return None;
    }
    Some(unsafe { File::from_raw_fd(duplicated) })
}

#[cfg(not(unix))]
pub fn file_from_fd(_fd: i32) -> Option<File> {
    None
}

fn cover_bytes_from_tagged(tagged: &TaggedFile) -> Option<Vec<u8>> {
    // 部分文件同时带 ID3v2 与 Vorbis Comments；封面可能只在其中一个 tag 里。
    let mut fallback = None;
    for tag in tagged.tags() {
        for picture in tag.pictures() {
            if picture.pic_type() == PictureType::CoverFront {
                return Some(picture.data().to_vec());
            }
            if fallback.is_none() {
                fallback = Some(picture.data().to_vec());
            }
        }
    }
    fallback
}

fn lyrics_from_tagged(tagged: &TaggedFile) -> Option<String> {
    for tag in tagged.tags() {
        // ID3v2 的 USLT 映射到 UnsyncLyrics,其它格式多为 Lyrics
        for key in [ItemKey::Lyrics, ItemKey::UnsyncLyrics] {
            if let Some(text) = tag.get_string(key) {
                let trimmed = text.trim();
                if !trimmed.is_empty() {
                    return Some(trimmed.to_string());
                }
            }
        }
    }
    None
}

/// 读取音频文件内嵌封面字节。
/// 优先前置封面(CoverFront),没有则取第一张;解析失败或无封面返回 None。
pub fn read_cover_bytes(path: &str) -> Option<Vec<u8>> {
    cover_bytes_from_tagged(&read_tagged_file(path)?)
}

/// 从 SAF fd 读取内嵌封面。
pub fn read_cover_bytes_from_fd(fd: i32) -> Option<Vec<u8>> {
    cover_bytes_from_tagged(&read_tagged_from_file(file_from_fd(fd)?)?)
}

/// 读取歌词文本。
/// 优先内嵌标签(Lyrics/UnsyncLyrics),其次同目录同名 .lrc/.txt。
/// 解析失败或无歌词返回 None。
pub fn read_lyrics_text(path: &str) -> Option<String> {
    if let Some(tagged) = read_tagged_file(path) {
        if let Some(text) = lyrics_from_tagged(&tagged) {
            return Some(text);
        }
    }
    read_sidecar_lyrics(path)
}

/// 从 SAF fd 读取内嵌歌词（不做同目录 sidecar 查找）。
pub fn read_lyrics_text_from_fd(fd: i32) -> Option<String> {
    lyrics_from_tagged(&read_tagged_from_file(file_from_fd(fd)?)?)
}

/// 读取音频同目录的同名 .lrc / .txt sidecar 歌词
fn read_sidecar_lyrics(path: &str) -> Option<String> {
    let audio = Path::new(path);
    for ext in ["lrc", "txt"] {
        let candidate = audio.with_extension(ext);
        if let Ok(content) = fs::read_to_string(candidate) {
            let trimmed = content.trim();
            if !trimmed.is_empty() {
                return Some(trimmed.to_string());
            }
        }
    }
    None
}
