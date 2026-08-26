use crate::model::{MusicLibrary, Track};
use std::fs;
use std::path::Path;

pub fn scan_directory<P: AsRef<Path>>(library: &mut MusicLibrary, dir_path: P) -> Result<(), String> {
    let path = dir_path.as_ref();
    if !path.is_dir() {
        return Err(format!("路径不存在或不是文件夹: {:?}", path));
    }
    // 此处也许是双重保险，玩意没权限，或者刚好被删除，没网了之类的
    let entries = fs::read_dir(path).map_err(|e| format!("读取文件夹失败: {}", e))?;

    for entry in entries {
        let entry = entry.map_err(|e| format!("读取文件条目失败: {}", e))?;
        let file_path = entry.path();

        // 递归扫描
        if file_path.is_dir() {
            // 如果子文件报错，忽略打印，防止整体崩溃
            let _ = scan_directory(library, &file_path);
        } else if file_path.is_file() {
            // 不确定是否有后缀
            if let Some(ext) = file_path.extension().and_then(|e| e.to_str()) {
                let ext_lower = ext.to_lowercase();
                if ext_lower == "mp3" || ext_lower == "flac" || ext_lower == "m4a" || ext_lower == "wav" {
                    let title = file_path
                        // 直接把读取到的路径的文件名剔除多余部分当成歌曲名存入title
                        .file_stem()
                        // 防止不同系统编码不同，所以转换为普通字符串
                        .and_then(|s| s.to_str())
                        // 保底
                        .unwrap_or("未知歌曲")
                        // 转换为真正的String
                        .to_string();

                    let track = Track {
                        // 直接把路径转换强行为标准的文本字符串
                        id: file_path.to_string_lossy().to_string(),
                        //把刚才存入的title作为单曲的title
                        title,
                        artist: "未知艺术家".to_string(),
                        album: "本地音乐".to_string(),
                        duration: 0,
                    };

                    library.add_track(track);

                }
            }
            
        }
    }
    Ok(())

}