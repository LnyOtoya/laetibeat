use laetibeat_core::metadata::{
    read_cover_bytes, read_cover_bytes_from_fd, read_lyrics_text, read_lyrics_text_from_fd,
};

/// 读取音频文件内嵌封面字节(供 Dart 侧封面展示/取色)。
pub fn read_cover(path: String) -> Option<Vec<u8>> {
    read_cover_bytes(&path)
}

/// 从 Android SAF fd 读取内嵌封面。
pub fn read_cover_fd(fd: i32) -> Option<Vec<u8>> {
    read_cover_bytes_from_fd(fd)
}

/// 读取歌词文本(内嵌标签优先,其次同目录 .lrc/.txt)。
pub fn read_lyrics(path: String) -> Option<String> {
    read_lyrics_text(&path)
}

/// 从 Android SAF fd 读取内嵌歌词。
pub fn read_lyrics_fd(fd: i32) -> Option<String> {
    read_lyrics_text_from_fd(fd)
}
