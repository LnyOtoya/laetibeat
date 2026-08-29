use flutter_rust_bridge::frb;
use laetibeat_core::model::MusicLibrary;
use laetibeat_core::scan_directory;

// 简化版单曲结构体
#[frb(non_opaque)]
pub struct  UiTrack {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration: String,
}

#[frb(sync)]
pub fn scan_local_music_folder(dir_path: String) -> Result<Vec<UiTrack>, String> {
    let mut library = MusicLibrary::new();

    scan_directory(&mut library, &dir_path)?;

    let ui_tracks = library.tracks.into_iter().map(|track| UiTrack {
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: format_duration(track.duration),
    }).collect();
    Ok(ui_tracks)
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

// 歌曲时长格式化 mm:ss
fn format_duration(seconds: u64) -> String {
    let mins = seconds / 60;
    let secs = seconds % 60;
    format!("{:02}:{:02}", mins,secs)
}