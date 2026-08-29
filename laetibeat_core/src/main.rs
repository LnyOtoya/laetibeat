use std::io::{self, Write};
use laetibeat_core::scanner::scan_directory;
use laetibeat_core::model::MusicLibrary;

fn main() {
    let mut library = MusicLibrary::new();

    println!("本地音乐扫描测试: ");

    loop {
        print!("> 请输入要扫描的音乐文件夹路径 (按 q 退出): ");
        io::stdout().flush().unwrap();

        let mut input = String::new();
        io::stdin().read_line(&mut input).expect("读取输入失败");
        // 去掉多余的换行符和空格
        let path = input.trim();

        if path == "q" || path == "Q" {
            println!("再见");
            break;
        }

        if path.is_empty() {
            continue;
        }

        println!("正在扫描路径: {} ...", path);

        match scan_directory(&mut library, path) {
            Ok(()) => {
                println!("扫描成功");

                for track in &library.tracks {
                    let time_str = format_duration(track.duration);
                    println!(
                        " 歌名: {} | 艺术家: {} | 专辑: {} | 时长: {}", 
                        track.title, track.artist, track.album, time_str);
                }
            }
            Err(e) => {
                println!("扫描出错：{}", e);
            }
        }

        println!("----------------------------------------------")


    }
}

// 歌曲时长格式化 mm:ss
fn format_duration(seconds: u64) -> String {
    let mins = seconds / 60;
    let secs = seconds % 60;
    format!("{:02}:{:02}", mins,secs)
}