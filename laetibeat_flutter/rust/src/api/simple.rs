use flutter_rust_bridge::frb;

#[frb(sync)]
pub fn scan_test_music() -> Vec<String> {
    vec![
        "Demo_track.flac".to_string(),
        "Laetibeat_audio.mp3".to_string(),
        "Cyberpunk_2077.wav".to_string(),
    ]
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}