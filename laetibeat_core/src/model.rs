use serde::{Serialize, Deserialize};
use std::path::PathBuf;

// 总结构体
// Serialize, Deserialize对接前端时将结构体转换成json或字节流，传入后再解开
// 也即时所谓的序列化和反序列化
#[derive(Debug, Clone, Serialize, Deserialize)]

// Vec:动态数组/列表
pub struct MusicLibrary {
    pub tracks: Vec<Track>,
    pub albums: Vec<Album>,
    pub artists: Vec<Artist>,
}
// 定义结构体的行为方法
impl MusicLibrary {
    pub fn new() -> Self {
        Self {
            tracks: Vec::new(),
            albums: Vec::new(),
            artists: Vec::new(),
        }
    }

    pub fn add_track(&mut self, track: Track) {
        self.tracks.push(track);
    }

}


// 单曲结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Track {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration: u64,
    pub source_type: SourceType,
}

// 专辑结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Album {
    pub id: String,
    pub title: String,
    pub artist: String,
}

// 艺术家结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Artist{
    pub id: String,
    pub name: String,
}


// 播放状态枚举
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PlayState {
    Stopped,
    Playing,
    Paused,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum SourceType {
    LocalFile(PathBuf),
    Opensubsonic { id: String},
}

// 统一音源抽象接口
pub trait AudioSource: Send + Sync {
    fn id(&self) -> String;
    fn get_stream_uri(&self) -> Result<String, String>;
    fn get_track_info(&self) -> Track;
}