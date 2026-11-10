use std::collections::BTreeMap;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use base64::engine::general_purpose::STANDARD;
use base64::Engine;

use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha1::{Digest, Sha1};

use crate::error::{LxError, Result};
use crate::utils::{aes_ecb_pkcs7_hex, md5_hex};

const USER_AGENT: &str = "Mozilla/5.0 (Linux; U; Android 11.0.0; zh-cn; MI 11) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30";
const MAX_RESPONSE_BYTES: usize = 5 * 1024 * 1024;
const MAX_LIMIT: u32 = 50;

/// Platforms with a standalone search implementation in this milestone.
pub const SUPPORTED_PLATFORMS: &[&str] = &["kw", "kg", "tx", "wy", "mg"];

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct LxSearchTrack {
    /// Platform key, e.g. kw / kg / mg.
    pub source: String,
    /// Platform song id consumed by `musicUrl`.
    pub id: String,
    pub name: String,
    pub singer: Vec<String>,
    pub album: String,
    pub album_id: String,
    /// Seconds.
    pub interval: i64,
    pub img: Option<String>,
    /// Platform-specific fields required by source scripts, e.g. kg hash,
    /// mg copyrightId, tx strMediaMid.
    pub extra: BTreeMap<String, Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct LxSearchPage {
    pub tracks: Vec<LxSearchTrack>,
    pub total: u64,
    pub page: u32,
    pub limit: u32,
    pub has_more: bool,
}

/// Search an independent platform without requiring a local library or
/// Subsonic server. The returned ids are suitable for a later `musicUrl`
/// resolution through an enabled LX source.
pub fn search(platform: &str, keyword: &str, page: u32, limit: u32) -> Result<LxSearchPage> {
    let keyword = keyword.trim();
    if keyword.is_empty() {
        return Ok(LxSearchPage {
            tracks: Vec::new(),
            total: 0,
            page: page.max(1),
            limit: limit.clamp(1, MAX_LIMIT),
            has_more: false,
        });
    }
    if keyword.chars().count() > 100 {
        return Err(LxError::Request("search keyword is too long".to_string()));
    }
    let page = page.max(1);
    let limit = limit.clamp(1, MAX_LIMIT);
    let client = Client::builder()
        .no_proxy()
        .timeout(Duration::from_secs(15))
        .user_agent(USER_AGENT)
        .build()
        .map_err(|error| LxError::Request(error.to_string()))?;

    let (tracks, total) = match platform {
        "kw" => search_kw(&client, keyword, page, limit)?,
        "kg" => search_kg(&client, keyword, page, limit)?,
        "tx" => search_tx(&client, keyword, page, limit)?,
        "wy" => search_wy(&client, keyword, page, limit)?,
        "mg" => search_mg(&client, keyword, page, limit)?,
        other => {
            return Err(LxError::Request(format!(
                "platform search is not implemented: {other}"
            )))
        }
    };

    // Some platforms (notably QQ) omit a reliable total. When total is
    // unknown, a full page means there may be another page.
    let has_more = if total == 0 {
        tracks.len() as u32 >= limit
    } else {
        (page as u64 * limit as u64) < total
    };
    Ok(LxSearchPage {
        has_more,
        tracks,
        total,
        page,
        limit,
    })
}

fn search_kw(
    client: &Client,
    keyword: &str,
    page: u32,
    limit: u32,
) -> Result<(Vec<LxSearchTrack>, u64)> {
    let body = get_json(client.get("http://search.kuwo.cn/r.s").query(&[
        ("client", "kt"),
        ("all", keyword),
        ("pn", &(page - 1).to_string()),
        ("rn", &limit.to_string()),
        ("uid", "794762570"),
        ("ver", "kwplayer_ar_9.2.2.1"),
        ("vipver", "1"),
        ("show_copyright_off", "1"),
        ("newver", "1"),
        ("ft", "music"),
        ("cluster", "0"),
        ("strategy", "2012"),
        ("encoding", "utf8"),
        ("rformat", "json"),
        ("vermerge", "1"),
        ("mobi", "1"),
        ("issubtitle", "1"),
    ]))?;
    Ok(parse_kw(&body))
}

fn search_kg(
    client: &Client,
    keyword: &str,
    page: u32,
    limit: u32,
) -> Result<(Vec<LxSearchTrack>, u64)> {
    let body = get_json(
        client
            .get("https://songsearch.kugou.com/song_search_v2")
            .query(&[
                ("keyword", keyword),
                ("page", &page.to_string()),
                ("pagesize", &limit.to_string()),
                ("userid", "0"),
                ("clientver", ""),
                ("platform", "WebFilter"),
                ("filter", "2"),
                ("iscorrection", "1"),
                ("privilege_filter", "0"),
                ("area_code", "1"),
            ]),
    )?;
    Ok(parse_kg(&body))
}

fn search_tx(
    client: &Client,
    keyword: &str,
    page: u32,
    limit: u32,
) -> Result<(Vec<LxSearchTrack>, u64)> {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|error| LxError::Request(error.to_string()))?
        .as_nanos();
    let search_id = format!("{nanos:032X}{:05}", nanos % 100_000);
    let payload = json!({
        "comm": {
            "_channelid": "0",
            "_os_version": "6.2.9200-2",
            "ct": "19",
            "cv": "2151",
            "guid": "1F70E520B2EAA7D25E11760783C53CA9",
            "patch": "118",
            "psrf_access_token_expiresAt": 0,
            "psrf_qqaccess_token": "",
            "psrf_qqopenid": "",
            "psrf_qqunionid": "",
            "tmeAppID": "qqmusic",
            "tmeLoginType": 0,
            "uin": "0",
            "wid": "7223299733393904640"
        },
        "music.search.SearchCgiService": {
            "module": "music.search.SearchCgiService",
            "method": "DoSearchForQQMusicDesktop",
            "param": {
                "grp": 1,
                "num_per_page": limit,
                "page_num": page,
                "query": keyword,
                "remoteplace": "txt.newclient.top",
                "search_type": 0,
                "searchid": search_id
            }
        }
    });
    let text =
        serde_json::to_string(&payload).map_err(|error| LxError::Request(error.to_string()))?;
    let sign = zzc_sign(&text);
    let body = get_json(
        client
            .post("https://u.y.qq.com/cgi-bin/musics.fcg")
            .query(&[("sign", sign)])
            .header("User-Agent", "QQMusic 14090508(android 12)")
            .header("Content-Type", "application/json")
            .body(text),
    )?;
    Ok(parse_tx(&body))
}

fn search_mg(
    client: &Client,
    keyword: &str,
    page: u32,
    limit: u32,
) -> Result<(Vec<LxSearchTrack>, u64)> {
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|error| LxError::Request(error.to_string()))?
        .as_millis()
        .to_string();
    let device_id = "963B7AA0D21511ED807EE5846EC87D20";
    let sign = md5_hex(&format!(
        "{keyword}6cdc72a439cef99a3418d2a78aa28c73yyapp2d16148780a1dcc7408e06336b98cfd50{device_id}{timestamp}"
    ));
    let body = get_json(
        client
            .get("https://jadeite.migu.cn/music_search/v3/search/searchAll")
            .query(&[
                ("isCorrect", "0"),
                ("isCopyright", "1"),
                ("searchSwitch", r#"{"song":1,"album":0,"singer":0,"tagSong":1,"mvSong":0,"bestShow":1,"songlist":0,"lyricSong":0}"#),
                ("pageSize", &limit.to_string()),
                ("text", keyword),
                ("pageNo", &page.to_string()),
                ("sort", "0"),
                ("sid", "USS"),
            ])
            .header("uiVersion", "A_music_3.6.1")
            .header("deviceId", device_id)
            .header("timestamp", timestamp)
            .header("sign", sign)
            .header("channel", "0146921"),
    )?;
    Ok(parse_mg(&body))
}

fn get_json(request: reqwest::blocking::RequestBuilder) -> Result<Value> {
    let response = request
        .send()
        .map_err(|error| LxError::Request(error.to_string()))?;
    if !response.status().is_success() {
        return Err(LxError::Request(format!(
            "search HTTP {}",
            response.status()
        )));
    }
    let bytes = response
        .bytes()
        .map_err(|error| LxError::Request(error.to_string()))?;
    if bytes.len() > MAX_RESPONSE_BYTES {
        return Err(LxError::Request("search response is too large".to_string()));
    }
    serde_json::from_slice(&bytes)
        .map_err(|error| LxError::Request(format!("invalid search response: {error}")))
}

fn parse_kw(body: &Value) -> (Vec<LxSearchTrack>, u64) {
    let total = body
        .get("TOTAL")
        .and_then(value_u64)
        .or_else(|| body.get("HIT").and_then(value_u64))
        .unwrap_or(0);
    let mut tracks = Vec::new();
    for item in body
        .get("abslist")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        let Some(id) = item
            .get("MUSICRID")
            .and_then(Value::as_str)
            .and_then(|value| value.strip_prefix("MUSIC_"))
        else {
            continue;
        };
        let Some(name) = item
            .get("SONGNAME")
            .or_else(|| item.get("NAME"))
            .and_then(Value::as_str)
        else {
            continue;
        };
        tracks.push(LxSearchTrack {
            source: "kw".to_string(),
            id: id.to_string(),
            name: clean(name),
            singer: split_singers(item.get("ARTIST").and_then(Value::as_str).unwrap_or("")),
            album: clean(item.get("ALBUM").and_then(Value::as_str).unwrap_or("")),
            album_id: item
                .get("ALBUMID")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string(),
            interval: item
                .get("DURATION")
                .and_then(value_i64)
                .map(normalize_seconds)
                .unwrap_or(0),
            img: item
                .get("web_albumpic_short")
                .and_then(Value::as_str)
                .map(|value| {
                    let path = value.strip_prefix("120/").unwrap_or(value);
                    format!("http://img1.kwcdn.kuwo.cn/star/albumcover/500/{path}")
                }),
            extra: BTreeMap::new(),
        });
    }
    (tracks, total)
}

fn parse_kg(body: &Value) -> (Vec<LxSearchTrack>, u64) {
    let data = body.get("data").unwrap_or(&Value::Null);
    let total = data.get("total").and_then(value_u64).unwrap_or(0);
    let mut tracks = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for item in data
        .get("lists")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        push_kg_track(item, &mut tracks, &mut seen);
        for child in item
            .get("Grp")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
        {
            push_kg_track(child, &mut tracks, &mut seen);
        }
    }
    (tracks, total)
}

fn push_kg_track(
    item: &Value,
    tracks: &mut Vec<LxSearchTrack>,
    seen: &mut std::collections::HashSet<String>,
) {
    let id = item
        .get("Audioid")
        .or_else(|| item.get("ID"))
        .and_then(value_text)
        .unwrap_or_default();
    let hash = item.get("FileHash").and_then(Value::as_str).unwrap_or("");
    let key = format!("{id}{hash}");
    if id.is_empty() || !seen.insert(key) {
        return;
    }
    let Some(name) = item
        .get("OriSongName")
        .or_else(|| item.get("SongName"))
        .and_then(Value::as_str)
    else {
        return;
    };
    let suffix = item.get("Suffix").and_then(Value::as_str).unwrap_or("");
    let singer = item
        .get("Singers")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(|item| item.get("name").and_then(Value::as_str))
                .map(clean)
                .filter(|value| !value.is_empty())
                .collect::<Vec<_>>()
        })
        .filter(|items: &Vec<String>| !items.is_empty())
        .unwrap_or_else(|| {
            split_singers(item.get("SingerName").and_then(Value::as_str).unwrap_or(""))
        });
    let display_name = if suffix.is_empty() {
        name.to_string()
    } else {
        format!("{name} {suffix}")
    };
    let mut extra = BTreeMap::new();
    if !hash.is_empty() {
        extra.insert("hash".to_string(), Value::String(hash.to_string()));
    }
    tracks.push(LxSearchTrack {
        source: "kg".to_string(),
        id,
        name: clean(&display_name),
        singer,
        album: clean(item.get("AlbumName").and_then(Value::as_str).unwrap_or("")),
        album_id: item.get("AlbumID").and_then(value_text).unwrap_or_default(),
        interval: item
            .get("Duration")
            .and_then(value_i64)
            .map(normalize_seconds)
            .unwrap_or(0),
        img: item
            .get("Image")
            .and_then(Value::as_str)
            .filter(|value| !value.is_empty())
            .map(|value| value.replace("{size}", "480")),
        extra,
    });
}

fn parse_tx(body: &Value) -> (Vec<LxSearchTrack>, u64) {
    let request = body
        .get("music.search.SearchCgiService")
        .or_else(|| body.get("req"));
    let data = request.and_then(|value| value.get("data"));
    let song = data.and_then(|value| value.get("song")).or_else(|| {
        data.and_then(|value| value.get("body"))
            .and_then(|value| value.get("song"))
    });
    let total = song
        .and_then(|value| value.get("total"))
        .and_then(value_u64)
        .unwrap_or(0);
    let mut tracks = Vec::new();
    for item in song
        .and_then(|value| value.get("list"))
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        let Some(file) = item.get("file") else {
            continue;
        };
        if file
            .get("media_mid")
            .and_then(Value::as_str)
            .unwrap_or("")
            .is_empty()
        {
            continue;
        }
        let Some(id) = item.get("mid").and_then(Value::as_str) else {
            continue;
        };
        let Some(name) = item
            .get("title")
            .or_else(|| item.get("name"))
            .and_then(Value::as_str)
        else {
            continue;
        };
        let album = item.get("album");
        let album_id = album
            .and_then(|value| value.get("mid"))
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string();
        let album_name = album
            .and_then(|value| value.get("name"))
            .and_then(Value::as_str)
            .unwrap_or("");
        let singer = item
            .get("singer")
            .and_then(Value::as_array)
            .map(|items| {
                items
                    .iter()
                    .filter_map(|item| item.get("name").and_then(Value::as_str))
                    .map(clean)
                    .filter(|value| !value.is_empty())
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();
        let img = if album_id.is_empty() || album_id == "空" {
            item.get("singer")
                .and_then(Value::as_array)
                .and_then(|items| items.first())
                .and_then(|item| item.get("mid"))
                .and_then(Value::as_str)
                .filter(|value| !value.is_empty())
                .map(|mid| format!("https://y.gtimg.cn/music/photo_new/T001R500x500M000{mid}.jpg"))
        } else {
            Some(format!(
                "https://y.gtimg.cn/music/photo_new/T002R500x500M000{album_id}.jpg"
            ))
        };
        let mut extra = BTreeMap::new();
        if let Some(media_mid) = file.get("media_mid").and_then(Value::as_str) {
            extra.insert(
                "strMediaMid".to_string(),
                Value::String(media_mid.to_string()),
            );
        }
        if let Some(song_id) = item.get("id").and_then(value_u64) {
            extra.insert("songId".to_string(), Value::String(song_id.to_string()));
        }
        if !album_id.is_empty() {
            extra.insert("albumMid".to_string(), Value::String(album_id.clone()));
        }
        tracks.push(LxSearchTrack {
            source: "tx".to_string(),
            id: id.to_string(),
            name: clean(name),
            singer,
            album: clean(album_name),
            album_id,
            interval: item
                .get("interval")
                .and_then(value_i64)
                .map(normalize_seconds)
                .unwrap_or(0),
            img,
            extra,
        });
    }
    let total = if total == 0 {
        tracks.len() as u64
    } else {
        total
    };
    (tracks, total)
}

fn zzc_sign(text: &str) -> String {
    const PART_1_INDEXES: [usize; 8] = [23, 14, 6, 36, 16, 40, 7, 19];
    const PART_2_INDEXES: [usize; 8] = [16, 1, 32, 12, 19, 27, 8, 5];
    const SCRAMBLE_VALUES: [u8; 20] = [
        89, 39, 179, 150, 218, 82, 58, 252, 177, 52, 186, 123, 120, 64, 242, 133, 143, 161, 121,
        179,
    ];

    let hash = format!("{:x}", Sha1::digest(text.as_bytes()));
    let part1 = PART_1_INDEXES
        .iter()
        .filter_map(|index| hash.get(*index..index + 1))
        .collect::<String>();
    let part2 = PART_2_INDEXES
        .iter()
        .filter_map(|index| hash.get(*index..index + 1))
        .collect::<String>();
    let part3 = SCRAMBLE_VALUES
        .iter()
        .enumerate()
        .map(|(index, value)| {
            let high = u8::from_str_radix(&hash[index * 2..index * 2 + 1], 16).unwrap_or(0);
            let low = u8::from_str_radix(&hash[index * 2 + 1..index * 2 + 2], 16).unwrap_or(0);
            value ^ ((high << 4) | low)
        })
        .collect::<Vec<u8>>();
    let encoded = STANDARD
        .encode(part3)
        .replace('/', "")
        .replace('+', "")
        .replace('=', "");
    format!("zzc{part1}{encoded}{part2}").to_lowercase()
}

fn search_wy(
    client: &Client,
    keyword: &str,
    page: u32,
    limit: u32,
) -> Result<(Vec<LxSearchTrack>, u64)> {
    let path = "/api/search/song/list/page";
    let payload = json!({
        "keyword": keyword,
        "needCorrect": "1",
        "channel": "typing",
        "offset": limit * (page - 1),
        "scene": "normal",
        "total": page == 1,
        "limit": limit
    });
    let text =
        serde_json::to_string(&payload).map_err(|error| LxError::Request(error.to_string()))?;
    let digest = md5_hex(&format!("nobody{path}use{text}md5forencrypt"));
    let data = format!("{path}-36cd479b6b5-{text}-36cd479b6b5-{digest}");
    let params =
        aes_ecb_pkcs7_hex(data.as_bytes(), b"e82ckenh8dichen8").map_err(LxError::Request)?;
    let body = get_json(
        client
            .post("http://interface.music.163.com/eapi/batch")
            .header(
                "User-Agent",
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36",
            )
            .header("origin", "https://music.163.com")
            .form(&[("params", params)]),
    )?;
    Ok(parse_wy(&body))
}

fn parse_wy(body: &Value) -> (Vec<LxSearchTrack>, u64) {
    let data = body.get("data").unwrap_or(&Value::Null);
    let total = data.get("totalCount").and_then(value_u64).unwrap_or(0);
    let mut tracks = Vec::new();
    for resource in data
        .get("resources")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        let Some(song) = resource
            .get("baseInfo")
            .and_then(|value| value.get("simpleSongData"))
        else {
            continue;
        };
        let Some(id) = song.get("id").and_then(value_u64) else {
            continue;
        };
        let Some(name) = song.get("name").and_then(Value::as_str) else {
            continue;
        };
        let album = song.get("al");
        let singer = song
            .get("ar")
            .and_then(Value::as_array)
            .map(|items| {
                items
                    .iter()
                    .filter_map(|item| item.get("name").and_then(Value::as_str))
                    .map(clean)
                    .filter(|value| !value.is_empty())
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();
        tracks.push(LxSearchTrack {
            source: "wy".to_string(),
            id: id.to_string(),
            name: clean(name),
            singer,
            album: clean(
                album
                    .and_then(|value| value.get("name"))
                    .and_then(Value::as_str)
                    .unwrap_or(""),
            ),
            album_id: album
                .and_then(|value| value.get("id"))
                .and_then(value_u64)
                .map(|value| value.to_string())
                .unwrap_or_default(),
            interval: song
                .get("dt")
                .and_then(value_i64)
                .map(normalize_seconds)
                .unwrap_or(0),
            img: album
                .and_then(|value| value.get("picUrl"))
                .and_then(Value::as_str)
                .map(ToString::to_string),
            extra: BTreeMap::new(),
        });
    }
    let total = if total == 0 {
        tracks.len() as u64
    } else {
        total
    };
    (tracks, total)
}

fn parse_mg(body: &Value) -> (Vec<LxSearchTrack>, u64) {
    let data = body.get("songResultData").unwrap_or(&Value::Null);
    let total = data.get("totalCount").and_then(value_u64).unwrap_or(0);
    let mut tracks = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for group in data
        .get("resultList")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
    {
        let items = group.as_array().map(Vec::as_slice).unwrap_or(&[]);
        for item in items {
            let Some(id) = item.get("songId").and_then(Value::as_str) else {
                continue;
            };
            let copyright = item
                .get("copyrightId")
                .and_then(Value::as_str)
                .unwrap_or(id);
            if !seen.insert(copyright.to_string()) {
                continue;
            }
            let Some(name) = item.get("name").and_then(Value::as_str) else {
                continue;
            };
            let singer = item
                .get("singerList")
                .and_then(Value::as_array)
                .map(|items| {
                    items
                        .iter()
                        .filter_map(|item| item.get("name").and_then(Value::as_str))
                        .map(clean)
                        .filter(|value| !value.is_empty())
                        .collect::<Vec<_>>()
                })
                .unwrap_or_default();
            let mut img = item
                .get("img3")
                .or_else(|| item.get("img2"))
                .or_else(|| item.get("img1"))
                .and_then(Value::as_str)
                .map(ToString::to_string);
            if let Some(value) = img.as_mut() {
                if value.starts_with('/') {
                    *value = format!("http://d.musicapp.migu.cn{value}");
                }
            }
            let mut extra = BTreeMap::new();
            if let Some(value) = item.get("copyrightId").and_then(Value::as_str) {
                extra.insert("copyrightId".to_string(), Value::String(value.to_string()));
            }
            for (key, aliases) in [
                ("lrcUrl", &["lrcUrl", "lyricUrl"][..]),
                ("mrcUrl", &["mrcUrl", "mrcurl"][..]),
                ("trcUrl", &["trcUrl", "trcurl"][..]),
            ] {
                if let Some(value) = aliases
                    .iter()
                    .find_map(|alias| item.get(*alias).and_then(Value::as_str))
                {
                    extra.insert(key.to_string(), Value::String(value.to_string()));
                }
            }
            tracks.push(LxSearchTrack {
                source: "mg".to_string(),
                id: id.to_string(),
                name: clean(name),
                singer,
                album: clean(item.get("album").and_then(Value::as_str).unwrap_or("")),
                album_id: item
                    .get("albumId")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .to_string(),
                interval: item
                    .get("duration")
                    .and_then(value_i64)
                    .map(normalize_seconds)
                    .unwrap_or(0),
                img,
                extra,
            });
        }
    }
    (tracks, total)
}

fn split_singers(value: &str) -> Vec<String> {
    value
        .split(|character| matches!(character, '&' | '、' | '/' | ';'))
        .map(clean)
        .filter(|value| !value.is_empty())
        .collect()
}

fn clean(value: &str) -> String {
    html_escape::decode_html_entities(value.trim())
        .trim()
        .to_string()
}

fn value_text(value: &Value) -> Option<String> {
    value
        .as_str()
        .map(ToString::to_string)
        .or_else(|| value.as_i64().map(|number| number.to_string()))
        .or_else(|| value.as_u64().map(|number| number.to_string()))
}

fn value_u64(value: &Value) -> Option<u64> {
    value
        .as_u64()
        .or_else(|| value.as_str().and_then(|value| value.parse().ok()))
}

fn value_i64(value: &Value) -> Option<i64> {
    value
        .as_i64()
        .or_else(|| value.as_str().and_then(|value| value.parse().ok()))
}

fn normalize_seconds(value: i64) -> i64 {
    if value > 10_000 {
        value / 1000
    } else {
        value
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parses_kw_results() {
        let body = json!({
            "TOTAL": "12",
            "abslist": [{
                "MUSICRID": "MUSIC_228908",
                "SONGNAME": "晴天 &amp; Test",
                "ARTIST": "周杰伦",
                "ALBUM": "叶惠美",
                "ALBUMID": "1293",
                "DURATION": "269"
            }]
        });
        let (tracks, total) = parse_kw(&body);
        assert_eq!(total, 12);
        assert_eq!(tracks[0].source, "kw");
        assert_eq!(tracks[0].id, "228908");
        assert_eq!(tracks[0].name, "晴天 & Test");
        assert_eq!(tracks[0].interval, 269);
    }

    #[test]
    fn parses_kg_results_and_children() {
        let body = json!({
            "data": {
                "total": 2,
                "lists": [{
                    "Audioid": 123,
                    "FileHash": "abc",
                    "OriSongName": "Song",
                    "Suffix": "Live",
                    "Singers": [{"name": "Artist"}],
                    "AlbumName": "Album",
                    "AlbumID": 7,
                    "Duration": 180,
                    "Grp": [{
                        "Audioid": "124",
                        "FileHash": "def",
                        "OriSongName": "Song 2",
                        "SingerName": "Artist B",
                        "Duration": 200
                    }]
                }]
            }
        });
        let (tracks, total) = parse_kg(&body);
        assert_eq!(total, 2);
        assert_eq!(tracks.len(), 2);
        assert_eq!(tracks[0].name, "Song Live");
        assert_eq!(tracks[1].source, "kg");
    }

    #[test]
    fn signs_tx_payload() {
        assert_eq!(
            zzc_sign("hello"),
            "zzcfa14dde89n1iwax0l5rimr0qwjexceiov4daaee8d6"
        );
    }

    #[test]
    fn parses_tx_results() {
        let body = json!({
            "music.search.SearchCgiService": {
                "data": {
                    "body": {
                        "song": {
                            "total": 1,
                            "list": [{
                                "mid": "003OUlho2HcRHC",
                                "title": "晴天",
                                "album": {"mid": "0024bjiL2aocxT", "name": "叶惠美"},
                                "singer": [{"name": "周杰伦", "mid": "0025NhlN2yWrP4"}],
                                "interval": 269,
                                "file": {"media_mid": "002A6j2q1tdUUP"}
                            }]
                        }
                    }
                }
            }
        });
        let (tracks, total) = parse_tx(&body);
        assert_eq!(total, 1);
        assert_eq!(tracks[0].source, "tx");
        assert_eq!(tracks[0].id, "003OUlho2HcRHC");
        assert_eq!(tracks[0].album_id, "0024bjiL2aocxT");
        assert_eq!(tracks[0].interval, 269);
    }

    #[test]
    fn parses_wy_results() {
        let body = json!({
            "code": 200,
            "data": {
                "totalCount": 5,
                "resources": [{
                    "baseInfo": {
                        "simpleSongData": {
                            "id": 509781655,
                            "name": "想你就写信",
                            "ar": [{"name": "周杰伦"}],
                            "al": {"id": 36412633, "name": "中国新歌声", "picUrl": "https://example.com/wy.jpg"},
                            "dt": 238698
                        }
                    }
                }]
            }
        });
        let (tracks, total) = parse_wy(&body);
        assert_eq!(total, 5);
        assert_eq!(tracks[0].source, "wy");
        assert_eq!(tracks[0].interval, 238);
        assert_eq!(tracks[0].singer, vec!["周杰伦"]);
    }

    #[test]
    fn parses_mg_results() {
        let body = json!({
            "songResultData": {
                "totalCount": "3",
                "resultList": [[{
                    "songId": "1140505222",
                    "copyrightId": "60054704965",
                    "name": "圣诞星",
                    "album": "圣诞星",
                    "albumId": "1140505221",
                    "duration": 180,
                    "singerList": [{"name": "周杰伦"}],
                    "img3": "https://example.com/a.jpg"
                }]]
            }
        });
        let (tracks, total) = parse_mg(&body);
        assert_eq!(total, 3);
        assert_eq!(tracks[0].id, "1140505222");
        assert_eq!(tracks[0].singer, vec!["周杰伦"]);
        assert_eq!(tracks[0].img.as_deref(), Some("https://example.com/a.jpg"));
    }
}
