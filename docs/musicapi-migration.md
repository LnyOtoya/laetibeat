# Laetibeat 在线音源迁移设计

> 状态：**草案，待确认后实施**
> 目标：保留现有全部 UI，彻底移除对外部「网易云 Node API」的依赖，改为 `go-music-api` + 自建薄 host；洛雪（LX）继续作为用户可选的 fallback 解析器。
> 关联：`PLAN.md`、`TODO.md`、`reference/go-music-api/`、`reference/api-enhanced/`、`reference/neteaseapi.md`

---

## 0. 结论摘要

1. **不需要 fork `go-music-api`**。在 Laetibeat 仓库新增一个约 40 行的 Go `main`，把上游的 `router` / `service` 当库导入即可（已实测编译、启动、鉴权）。
2. **保留 UI 的关键是兼容层**：网易云专用页面（发现页、日推、艺人、收藏、私人 FM、心动模式、相似歌曲、首页 block）上游没有对应接口。我们在自己的 host 里按 `reference/api-enhanced/module/*.js` 移植约 20 个网易云接口，返回旧客户端已有的 JSON 形状，从而不改 UI。
3. **兼容层只需要 weapi**：已实测 `cloudsearch`、`personalized`、`radio/get`、`simiSong`、`playlist detail`、`song detail`、`lyric`、`artist top/albums`、`homepage block`、`recommend songs`、`QR key/check`、`login status` 全部可用 weapi；只有 `/song/url/v1` 走 `music-lib` 的 EAPI。因此不需要移植 eapi header、xeapi 反作弊或 neapi key。
4. **多平台聚合走上游原生 API**：搜索/歌单/专辑/直链/歌词/排行/换源使用 `/api/v1/*`；网易云专用能力走兼容层。两者最终由 Rust 的 `laetibeat_online` 统一抽象。
5. **HTTPS 强制**：远程服务只允许 `https://`；redirect 逐跳校验，禁止 `https → http`；内置服务只绑 `127.0.0.1` + 随机 Bearer token，作为受信任的本机传输例外。
6. **Android 内置可行但有两个硬约束**：
   - Go 二进制必须用 **NDK + CGO** 构建（Android 上纯 Go DNS 不可用，Go issue #10714）；已验证 NDK 28 可编译出 PIE + `/system/bin/linker64` + 16KB 对齐。
   - 必须打包为 `jniLibs/<abi>/lib*.so`，并设置 `extractNativeLibs=true` + `useLegacyPackaging=true`，才能从 `nativeLibraryDir` 执行。
7. **许可证**：host 模块以 AGPL-3.0 单独发布；Flutter/Rust 主应用通过 HTTP 边界调用，可继续保持 MIT。需要公开 host 源码并提供构建产物对应关系。

---

## 1. 现状盘点

### 1.1 当前链路

```text
Flutter 页面
  └─ netease_provider.dart / netease_session.dart / netease_settings.dart
        └─ Rust laetibeat_netease（HTTP 客户端）
              └─ 用户配置的 NeteaseCloudMusicApi Node 服务
                    └─ 网易云

播放：
PlayerNotifier._resolveTrack()
  ├─ source == "netease" → netease_song_url → 直链
  │     └─ 试听/无 URL 且 allowLxFallback → LX source "wy"
  ├─ source == "lx" → LX resolve
  ├─ source == "opensubsonic" → Subsonic stream URL
  └─ 本地文件
```

### 1.2 现有网易云接口清单（`laetibeat_netease/src/lib.rs`）

| 方法 | Node API 路径 | 用途 |
|---|---|---|
| `status` | `/login/status` | 登录状态/昵称/uid |
| `qr_key` / `qr_create` / `qr_check` | `/login/qr/key`、`/login/qr/create`、`/login/qr/check` | 二维码登录 |
| `send_captcha` / `login_cellphone` | `/captcha/sent`、`/login/cellphone` | 短信登录（当前 400，暂缓） |
| `search` | `/cloudsearch?type=1` | 歌曲搜索 |
| `search_playlists` | `/cloudsearch?type=1000` | 歌单搜索 |
| `search_albums` | `/cloudsearch?type=10` | 专辑搜索 |
| `search_artists` | `/cloudsearch?type=100` | 艺人搜索 |
| `subscribed_artists` | `/artist/sublist` | 收藏艺人 |
| `subscribed_albums` | `/album/sublist` | 收藏专辑 |
| `album_detail` | `/album?id=` | 专辑详情 |
| `artist_detail` | `/artists?id=` | 艺人详情 + 热门歌曲 |
| `artist_top_songs` | `/artist/top/song?id=` | 热门 50 首 |
| `artist_albums` | `/artist/album?id=` | 艺人专辑 |
| `song_detail` | `/song/detail?ids=` | 歌曲详情 |
| `user_playlists` | `/user/playlist` | 我的歌单 |
| `playlist_tracks` | `/playlist/track/all` | 歌单歌曲分页 |
| `daily_recommendations` | `/recommend/songs` | 每日推荐 |
| `personalized_playlists` | `/personalized` | 推荐歌单 |
| `personal_fm` / `personal_fm_mode` | `/personal_fm`、`/personal/fm/mode` | 私人 FM |
| `similar_songs` | `/simi/song` | 相似歌曲 |
| `liked_song_ids` | `/likelist` | 红心歌曲 id |
| `intelligence_list` | `/playmode/intelligence/list` | 心动模式 |
| `radar_playlists` | `/homepage/block/page` | 雷达歌单 |
| `liked_song_recommendations` | `/homepage/block/page` | 根据喜爱的歌曲推荐 |
| `homepage_sections` | `/homepage/block/page` | 发现页动态区块 |
| `song_url` | `/song/url/v1` | 播放直链 |
| `lyric` | `/lyric/new` | LRC + 翻译 + 逐字 |
| `cover` | 任意封面 URL | 封面下载 |

### 1.3 前端依赖

| 文件 | 作用 |
|---|---|
| `lib/widgets/settings/netease_provider.dart` | 全部网易云 Riverpod provider |
| `lib/widgets/settings/netease_session.dart` | Cookie 存 `flutter_secure_storage` |
| `lib/widgets/settings/netease_settings.dart` | base URL + `allowLxFallback` |
| `lib/pages/mobile/discover/mobile_discover_page.dart` | 发现页六卡 + 动态区块 |
| `lib/pages/mobile/library/netease/*` | 日推、歌单、收藏艺人/专辑、专辑/艺人详情 |
| `lib/pages/mobile/search/mobile_search_page.dart` | 网易云搜索分类 |
| `lib/pages/mobile/settings/sources/netease/*` | 服务配置与登录页 |
| `lib/widgets/player/player_provider.dart` | 直链解析 + LX fallback |
| `lib/widgets/player/lx_track.dart` | `neteaseLxMusicInfoFromTrack` |
| `lib/widgets/player/lyric_provider.dart` | 网易云歌词 |
| `lib/widgets/cache/netease_cover_cache.dart` | 封面内存/磁盘缓存 |
| `lib/core/playback/netease_audio_https_proxy.dart` | 网易云音源 HTTPS-only 转发 |

### 1.4 现有曲目身份

- 网易云：`source = "netease"`，`id = "netease:<songId>"`，`sourceId = base_url`，`sourceExtraJson = {songId, albumId, artistId, durationMs, fee}`。
- LX：`source = "lx"`，`sourceId = 平台 key`，`id = 平台内 id`。
- 这套身份已经进入队列快照、统计、歌单条目，迁移时必须保持兼容。

---

## 2. 目标架构

```text
┌─────────────────────────────────────────────────────────────┐
│ Flutter UI（现有页面保持不变）                                │
│   discover / library / search / player / settings            │
└───────────────────────────┬─────────────────────────────────┘
                            │ FRB
┌───────────────────────────▼─────────────────────────────────┐
│ Rust laetibeat_online                                        │
│  ├─ http.rs            HTTPS-only 客户端 + redirect policy   │
│  ├─ musicapi.rs        上游 /api/v1/* 多平台客户端            │
│  ├─ netease_compat.rs  旧 Node API 形状的网易云专用客户端      │
│  ├─ dto.rs             统一 UiTrack / UiPlaylist / Resolved  │
│  └─ error.rs           类型化错误                             │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTP（远程 HTTPS / 本机 loopback）
┌───────────────────────────▼─────────────────────────────────┐
│ laetibeat_musicapi_host（Go，AGPL-3.0）                       │
│  ├─ main.go              listen 127.0.0.1:0 / token / chdir   │
│  ├─ bearer.go            Bearer 鉴权中间件                    │
│  ├─ netease/*            兼容层：移植 api-enhanced 模块        │
│  └─ upstream             go-music-api router.SetupRouter()    │
│        ├─ /api/v1/music/*        搜索/直链/歌词/封面/音质     │
│        ├─ /api/v1/playlist/*     歌单                         │
│        ├─ /api/v1/album/*        专辑                         │
│        ├─ /api/v1/ranking/*      榜单                         │
│        └─ /api/v1/system/*       Cookie / QR（多平台）        │
│              └─ music-lib（13 平台逆向客户端，AGPL-3.0）       │
└───────────────────────────┬─────────────────────────────────┘
                            │
                     网易云 / QQ / 酷狗 / 酷我 / 咪咕 / ...
```

内置模式下 host 随 App 启动，远程模式下连接用户自己的 NAS/VPS。

---

## 3. 关键设计决策

### D1：零 fork host（已验证）

host 作为独立 Go module 导入上游：

```go
import (
    "github.com/guohuiyuan/go-music-api/router"
    "github.com/guohuiyuan/go-music-api/service"
)

service.CM.Load()
engine := router.SetupRouter()
```

上游 `main.go` 的问题由 host 外层解决：

| 上游问题 | host 方案 |
|---|---|
| `r.Run(":8080")` 固定端口、绑 0.0.0.0 | `net.Listen("tcp", addr)`，默认 `127.0.0.1:0`，打印实际端口 |
| `cookies.json` 相对 CWD | 启动前 `os.Chdir(dataDir)` |
| 无鉴权，`GET /api/v1/system/cookies` 泄露明文 Cookie | 外层 `http.Handler` 校验 Bearer token |
| Swagger 暴露 | 同一 token 中间件覆盖所有路由 |
| gin debug 日志 | `GIN_MODE=release` |

**实测结果**（本机）：

```text
go build -trimpath -ldflags '-s -w' → 33 MB
LAETIBEAT_MUSICAPI_ADDR=127.0.0.1:0 → 127.0.0.1:40319
GET /api/v1/system/cookies（无 token）→ 401
GET /api/v1/music/qualities?source=netease（带 token）→ 200
```

维护方式：`go.mod` 固定上游版本（tag 或 pseudo-version），上游更新只 bump 版本，不改代码。

### D2：兼容层保留 UI

上游没有的网易云接口，在 host 的 `netease/` 包内按 `reference/api-enhanced/module/*.js` 移植。返回形状以 `laetibeat_netease/src/lib.rs` 现有 serde 结构为准，因此：

- **不改** `netease_provider.dart`、发现页、艺人页、收藏页。
- **不改** `laetibeat_netease` 的 DTO/解析逻辑，只改 base URL、HTTPS 策略和少量错误类型。
- 迁移完成后，`laetibeat_netease` 的代码移入 `laetibeat_online::netease_compat`，作为内部模块保留；对外部 Node 服务的依赖彻底消失。

兼容层端点（与 §1.2 一一对应）：

| 兼容路由 | 上游网易云 API | 加密 | 备注 |
|---|---|---|---|
| `/login/status` | `/api/w/nuser/account/get` | weapi | 返回 `{data:{...}}` |
| `/login/qr/key` | `/api/login/qrcode/unikey` | weapi | `type=3` |
| `/login/qr/create` | 本地构造 `https://music.163.com/login?codekey=` | — | 必须按 `qrimg=true` 生成 data URL（`skip2/go-qrcode`，MIT） |
| `/login/qr/check` | `/api/login/qrcode/client/login` | weapi | 映射 800/801/802/803，成功时返回 `cookie` |
| `/captcha/sent` | `/api/sms/captcha/sent` | weapi | `secrete=music_middleuser_pclogin` |
| `/login/cellphone` | `/api/w/login/cellphone` | weapi | 可选，当前已知 400 |
| `/cloudsearch` | `/api/cloudsearch/pc` | weapi | 歌曲/歌单/专辑/艺人 |
| `/artist/sublist` | `/api/artist/sublist` | weapi | 收藏艺人 |
| `/album/sublist` | `/api/album/sublist` | weapi | 收藏专辑 |
| `/album` | `/api/v1/album/{id}` | weapi | 专辑详情 |
| `/artists` | `/api/v1/artist/{id}` | weapi | 艺人详情 |
| `/artist/top/song` | `/api/artist/top/song` | weapi | 热门 50 |
| `/artist/album` | `/api/artist/albums/{id}` | weapi | 艺人专辑 |
| `/song/detail` | `/api/v3/song/detail` | weapi | 批量详情 |
| `/user/playlist` | `/api/user/playlist` | weapi | 我的歌单 |
| `/playlist/track/all` | `/api/v6/playlist/detail` + `/api/v3/song/detail` | weapi | 两步 |
| `/recommend/songs` | `/api/v3/discovery/recommend/songs` | weapi | 日推 |
| `/personalized` | `/api/personalized/playlist` | weapi | 推荐歌单 |
| `/personal_fm` | `/api/v1/radio/get` | weapi | 私人 FM |
| `/personal/fm/mode` | `/api/v1/radio/get` | weapi | 模式 |
| `/simi/song` | `/api/v1/discovery/simiSong` | weapi | 相似歌曲 |
| `/likelist` | `/api/song/like/get` | weapi | 红心 id |
| `/playmode/intelligence/list` | `/api/playmode/intelligence/list` | weapi | 心动模式 |
| `/homepage/block/page` | `/api/homepage/block/page` | weapi | 发现页 blocks |
| `/lyric/new` | `/api/song/lyric/v1` | weapi | LRC + 翻译 + 逐字 |
| `/song/url/v1` | EAPI `/api/song/enhance/player/url/v1` | EAPI | Node 原版用 xeapi；host 用 `music-lib` 的 `EncryptEApi` 发起 EAPI，解析完整 `data[0]`（保留 `freeTrialInfo`/`fee`/`size`/`br`/`level`）；`GetDownloadURLWithQuality` 可作兜底 |

> **实测结论（2026-11-27）**：上述除 `/song/url/v1` 外的端点均可用 **weapi** 直接调用；`music-lib/netease.EncryptWeApi` 已导出，无需移植 `api-enhanced` 的 eapi header、xeapi 反作弊或 neapi key。未登录时依赖账号的端点返回 `code:301`，与现有 Rust 错误处理一致。

实现要点：

- `music-lib/netease` 已导出 `EncryptWeApi`、`CreateQRLogin`、`CheckQRLogin`、`GetDownloadURLWithQuality`，可直接复用；`/song/url/v1` 使用 `EncryptEApi` 自行发起 EAPI 以保留 `freeTrialInfo`/`fee`，`GetDownloadURLWithQuality` 作为兜底。
- `song/url/v1` 不移植 Node API 的 `xeapi` 反作弊链路，使用 `music-lib` 已验证的 EAPI 路径；返回兼容的 `{data:[{id,url,br,size,level,freeTrialInfo,fee,...}]}`。
- 兼容层只依赖 `reference/api-enhanced` 的**接口路径与参数**，不复制其 Node 代码；响应字段以现有 Rust 解析器为准。

### D3：多平台聚合走上游原生 API

| 能力 | 上游路由 | 阶段 |
|---|---|---|
| 歌曲/歌单/专辑搜索 | `/api/v1/music/search` | M2 |
| 用户歌单 | `/api/v1/playlist/user` | M2 |
| 歌单详情 | `/api/v1/playlist/detail` | M2 |
| 专辑详情 | `/api/v1/album/detail` | M2 |
| 直链 | `/api/v1/music/url` | M2 |
| 流代理（汽水解密） | `/api/v1/music/stream` | M3 |
| 歌词 | `/api/v1/music/lyric` | M2 |
| 封面 | `/api/v1/music/cover` | M2 |
| 音质档位 | `/api/v1/music/qualities` | M2 |
| 智能换源 | `/api/v1/music/switch` | M3 |
| 榜单/热门 | `/api/v1/ranking/*` | M3 |
| 多平台扫码登录 | `/api/v1/system/qr_login/*` | M3 |

已知限制：

- 上游搜索每个平台固定 10 条（`music-lib` 内部 `limit: 10`），没有 offset。网易云走兼容层可支持 `limit/offset`；其他平台第一阶段只展示 10 条。
- 上游 `Playlist` 不包含歌曲列表，详情需二次请求。
- 上游没有艺人相关接口；非网易云平台的艺人能力标记为 `Unsupported`，UI 隐藏对应入口。

### D4：HTTPS 强制

分三层：

1. **配置层**
   - 远程模式：`baseUrl` 必须 `https://`，否则拒绝保存。
   - 内置模式：允许 `http://127.0.0.1:<port>`，但必须同时满足 loopback + 随机 token。
   - 禁止 userinfo、空 host、非 `http(s)` scheme。

2. **请求层**（`laetibeat_online/src/http.rs`）
   ```rust
   let https_client = reqwest::Client::builder()
       .https_only(true)
       .redirect(reqwest::redirect::Policy::custom(|attempt| {
           if attempt.previous().len() >= 5 {
               attempt.stop()
           } else if attempt.url().scheme() != "https" {
               attempt.error("blocked non-HTTPS redirect")
           } else {
               attempt.follow()
           }
       }))
       .timeout(Duration::from_secs(20))
       .build()?;

   let loopback_client = reqwest::Client::builder()
       .redirect(reqwest::redirect::Policy::custom(|attempt| {
           let url = attempt.url();
           let loopback = matches!(url.host_str(), Some("127.0.0.1" | "::1" | "localhost"));
           if attempt.previous().len() >= 5 {
               attempt.stop()
           } else if url.scheme() != "https" && !(url.scheme() == "http" && loopback) {
               attempt.error("blocked non-HTTPS redirect")
           } else {
               attempt.follow()
           }
       }))
       .build()?;
   ```
   - TLS 继续使用 `rustls` + `rustls-platform-verifier`（项目已有）。
   - 远程模式下，redirect 目标 host 必须与配置 host 一致。

3. **音频层**
   - 现有 `NeteaseAudioHttpsProxy` 泛化为 `OnlineAudioHttpsProxy`：
     - `http://` 源升级为 `https://`；
     - 逐跳拒绝 HTTPS 降级；
     - 保留 Range / If-Range / 必要请求头；
     - 仅绑 `127.0.0.1`，路径带随机 token。
   - 需要 Referer/UA 的源，通过 `PlaybackTrack.headers` 传入代理。
   - 汽水等必须服务端解密的源走 `/api/v1/music/stream`；此时 host→CDN 不受 App 控制，UI 标注「经服务端代理」，第一阶段不做。

### D5：Cookie 模型

| 场景 | Cookie 归属 | 说明 |
|---|---|---|
| 网易云兼容层 | **客户端**（`flutter_secure_storage`） | 每次请求随 `Cookie` header 或 `cookie` 表单字段传给 host；host 无状态使用 `netease.New(cookie)` |
| 网易云扫码登录 | host 返回 Cookie 给客户端 | 不写服务端文件，保持现有安全模型 |
| 上游多平台（QQ/酷狗等） | **host 服务端** `cookies.json` | 上游 `service.CM` 全局；内置模式每设备一份，远程模式每服务一份 |
| 远程服务 Token | 客户端安全存储 | `Authorization: Bearer <token>` |

这样：

- 网易云账号态仍然是「每设备」，不会因为多人共用 NAS 而串号。
- 多平台 Cookie 暂时接受「每服务一份」的单用户模型；后续如需多用户，再给上游加 per-request cookie（属于较大的 fork 改动）。

### D6：内置 host

#### Android

已验证事实：

```text
CGO_ENABLED=1 GOOS=android GOARCH=arm64 \
  CC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang \
  go build -buildmode=pie -trimpath -ldflags '-s -w'
→ ELF PIE, interpreter /system/bin/linker64, LOAD Align 0x4000, 34 MB
```

- **必须用 CGO**：Go 源码 `src/net/conf.go` 明确写着「DNS requests don't work on Android, so prefer the cgo resolver. Issue #10714」。`CGO_ENABLED=0` 会走纯 Go resolver，Android 上无法解析域名。
- NDK 版本固定（当前 `28.2.13676358`），CI 使用同一版本。
- 产物命名 `liblaetibeat_musicapi.so`，放入：
  ```
  android/app/src/main/jniLibs/arm64-v8a/liblaetibeat_musicapi.so
  android/app/src/main/jniLibs/armeabi-v7a/liblaetibeat_musicapi.so
  android/app/src/main/jniLibs/x86_64/liblaetibeat_musicapi.so
  ```
- Gradle：
  ```kotlin
  android {
      packaging {
          jniLibs { useLegacyPackaging = true }
      }
  }
  ```
- Manifest：
  ```xml
  <application android:extractNativeLibs="true" ...>
  ```
- 运行时路径：`context.applicationInfo.nativeLibraryDir + "/liblaetibeat_musicapi.so"`。
- 通过一个轻量 MethodChannel 把 `nativeLibraryDir` 传给 Dart（或直接在 Kotlin 启动进程）。
- 16KB 页：NDK 28 默认产出 `0x4000` 对齐，满足 Android 16；x86_64 构建需额外验证。
- 若未来上架 Google Play 且 AAB 不抽取 `.so`，增加 `memfd_create` fallback（本项目当前 GitHub Release 分发，不阻塞）。

#### Linux 桌面

- `CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build` 即可（纯 Go DNS 在 Linux 正常）。
- 二进制放 `bundle/laetibeat_musicapi_host`，通过 `linux/CMakeLists.txt` 安装。
- Dart 用 `File(Platform.resolvedExecutable).parent` 定位。
- Windows/macOS 后续同样方式，只需补打包路径。

#### 进程生命周期（Dart）

新增 `lib/core/online/musicapi_host_process.dart`：

```dart
class MusicApiHostProcess {
  Process? _process;
  String? _baseUrl;
  String? _token;

  Future<Uri> start() async {
    final token = _randomToken();
    final dataDir = await _dataDir();
    final binary = await _binaryPath();
    _process = await Process.start(binary, const [], environment: {
      'LAETIBEAT_MUSICAPI_ADDR': '127.0.0.1:0',
      'LAETIBEAT_MUSICAPI_TOKEN': token,
      'LAETIBEAT_MUSICAPI_DATA_DIR': dataDir,
      'GIN_MODE': 'release',
    }, workingDirectory: dataDir);
    final listen = await _readListenLine(_process!.stdout).timeout(const Duration(seconds: 5));
    _baseUrl = 'http://$listen';
    _token = token;
    await _healthCheck();
    return Uri.parse(_baseUrl!);
  }
}
```

- 启动超时 5s，失败回退到远程配置或提示。
- 崩溃后指数退避重启（1s/2s/4s，最多 3 次）。
- App 生命周期结束时 `kill()`。
- host 的 stdout/stderr 接入现有日志（debug 构建）。

---

## 4. Host 详细设计

### 4.1 目录结构

```text
laetibeat_musicapi_host/
├── go.mod                 module github.com/LnyOtoya/laetibeat/laetibeat_musicapi_host
├── go.sum
├── main.go                env / listen / token / chdir
├── bearer.go              Bearer 中间件
├── host_test.go           token、addr、data dir、健康检查
├── netease/
│   ├── client.go          weapi/eapi 请求封装
│   ├── compat.go          兼容路由注册
│   ├── dto.go             响应结构
│   ├── login.go           状态 / 二维码
│   ├── search.go          cloudsearch
│   ├── playlist.go        user playlist / track all
│   ├── album_artist.go    album / artists / top / albums
│   ├── discovery.go       recommend / personalized / fm / simi / likelist / intelligence / homepage
│   ├── lyric.go           lyric/new
│   ├── song_url.go        song/url/v1（复用 music-lib）
│   └── compat_test.go     golden JSON 形状测试
├── build/
│   ├── build-android.sh
│   └── build-linux.sh
├── LICENSE                AGPL-3.0
└── README.md              构建、部署、许可证
```

`go.mod` 固定：

```go
require (
    github.com/guohuiyuan/go-music-api v1.0.2
    github.com/guohuiyuan/music-lib v1.1.3-0.20261116162321-90b29428b646
    github.com/skip2/go-qrcode v0.0.0-20200617195104-da1b6568686e
)
```

### 4.2 main.go 约定

环境变量：

| 变量 | 默认 | 说明 |
|---|---|---|
| `LAETIBEAT_MUSICAPI_ADDR` | `127.0.0.1:0` | 监听地址；远程部署可 `0.0.0.0:8080` |
| `LAETIBEAT_MUSICAPI_TOKEN` | 空 | 为空则不鉴权；内置/远程都建议设置 |
| `LAETIBEAT_MUSICAPI_DATA_DIR` | 当前目录 | `cookies.json` 等写入目录 |
| `GIN_MODE` | `release` | 由 host 设置默认值 |

启动顺序：

1. `os.MkdirAll(dataDir, 0o700)` + `os.Chdir(dataDir)`。
2. `gin.SetMode(gin.ReleaseMode)`。
3. `service.CM.Load()`。
4. `engine := router.SetupRouter()`。
5. 注册兼容路由到独立 `http.ServeMux`：`/laetibeat/*` → 兼容 handler，其余 → `engine`。
6. `net.Listen` + 打印 `LAETIBEAT_MUSICAPI_LISTEN=<addr>`。
7. `http.Serve`。

### 4.3 鉴权中间件

```go
func withBearer(next http.Handler, token string) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if token != "" {
            got := r.Header.Get("Authorization")
            if got != "Bearer "+token {
                http.Error(w, "unauthorized", http.StatusUnauthorized)
                return
            }
        }
        next.ServeHTTP(w, r)
    })
}
```

- 覆盖 `/api/v1/*`、`/music/*`、`/swagger/*`、`/laetibeat/*`。
- 远程部署必须置于 HTTPS 反代之后，并设置 token。

### 4.4 网易云兼容层请求封装

```go
type Client struct {
    http   *http.Client
    cookie string
    ua     string
}

func (c *Client) weapi(path string, payload map[string]any) ([]byte, error) {
    body, _ := json.Marshal(payload)
    params, encSecKey := netease.EncryptWeApi(string(body))
    form := url.Values{"params": {params}, "encSecKey": {encSecKey}}
    req, _ := http.NewRequest("POST", "https://music.163.com"+path, strings.NewReader(form.Encode()))
    req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
    req.Header.Set("Referer", "https://music.163.com/")
    req.Header.Set("User-Agent", c.ua)
    if c.cookie != "" {
        req.Header.Set("Cookie", c.cookie)
    }
    resp, err := c.http.Do(req)
    // 限制 body 大小、检查状态码、返回 JSON
}

// 注意：/song/url/v1 不经过本封装，直接调用
// EncryptEApi + EAPI /eapi/song/enhance/player/url/v1；
// 需要完整 data[0] 时不要只用 GetDownloadURLWithQuality。
```

> 因为所有兼容端点都已实测可用 weapi，host **不需要**实现 eapi header 对象、xeapi 反作弊、neapi key 或 `X-antiCheatToken`。这是本方案能把 host 控制在千行左右的关键。

Cookie 来源优先级：

1. `Cookie` header；
2. 表单/query 的 `cookie` 字段（兼容旧客户端）；
3. 空。

**绝不写入日志**；错误信息只保留路径和状态码。

### 4.5 兼容层响应形状

以现有 Rust serde 结构为准，核心几类：

```jsonc
// /cloudsearch
{ "code": 200, "result": { "songs": [...], "songCount": 100 } }

// /login/status
{ "data": { "code": 200, "account": {...}, "profile": {...} } }

// /login/qr/key
{ "code": 200, "data": { "unikey": "..." } }

// /login/qr/create
{ "code": 200, "data": { "qrurl": "...", "qrimg": "data:image/png;base64,..." } }

// /login/qr/check
{ "code": 803, "message": "授权登陆成功", "cookie": "MUSIC_U=..." }

// /song/url/v1
{ "code": 200, "data": [{ "id": 123, "url": "...", "br": 320000, "size": 0, "level": "exhigh", "freeTrialInfo": null, "fee": 0 }] }

// /lyric/new
{ "lrc": {"lyric": "..."}, "tlyric": {"lyric": "..."}, "yrc": {"lyric": "..."}, "code": 200 }
```

实现后用 `reference/neteaseapi.md` 的示例和现有 Rust 单元测试做对照。

### 4.6 上游原生 API

- `/api/v1/*` 由 `router.SetupRouter()` 提供，host 不包装、不改写。
- 网易云搜索如果上游仍为空，Rust 客户端对 `source=netease` 改走 `/laetibeat/netease/cloudsearch`；其他平台走上游。
- 上游 `service.CM` 的 Cookie 通过 `/api/v1/system/cookies` 管理；内置模式下由设置页写入。

### 4.7 构建矩阵

```bash
# host 本机（开发）
cd laetibeat_musicapi_host && go build -o /tmp/host .

# Linux 桌面
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -trimpath -ldflags '-s -w' -o build/linux-amd64/laetibeat_musicapi_host .

# Android arm64
NDK=$ANDROID_SDK/ndk/28.2.13676358
CC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang
CGO_ENABLED=1 GOOS=android GOARCH=arm64 CC=$CC \
  go build -buildmode=pie -trimpath -ldflags '-s -w' \
  -o ../../laetibeat_flutter/android/app/src/main/jniLibs/arm64-v8a/liblaetibeat_musicapi.so .

# Android armv7
CC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi24-clang
CGO_ENABLED=1 GOOS=android GOARCH=arm CC=$CC \
  go build -buildmode=pie -trimpath -ldflags '-s -w' -o .../armeabi-v7a/liblaetibeat_musicapi.so .

# Android x86_64
CC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/x86_64-linux-android24-clang
CGO_ENABLED=1 GOOS=android GOARCH=amd64 CC=$CC \
  go build -buildmode=pie -trimpath -ldflags '-s -w' -o .../x86_64/liblaetibeat_musicapi.so .
```

CI 增加 `musicapi-host` job，产物缓存给 Flutter 构建；Release workflow 把二进制打进 APK / Linux bundle。

---

## 5. Rust 设计

### 5.1 Crate 结构

```text
laetibeat_online/
├── Cargo.toml
└── src/
    ├── lib.rs
    ├── http.rs            strict_https_client / loopback_client
    ├── error.rs           OnlineError
    ├── model.rs           UiTrack / UiPlaylist / ResolvedAudio / Capability
    ├── musicapi.rs        上游 /api/v1/*
    ├── netease_compat.rs  旧 Node API 形状（从 laetibeat_netease 迁移）
    └── registry.rs        source → 能力、LX 平台映射
```

FRB 门面新增 `laetibeat_flutter/rust/src/api/online.rs`，Dart 生成 `lib/src/rust/api/online.dart`。

### 5.2 统一模型

```rust
pub struct TrackRef {
    pub source: String,   // netease / qq / kugou / ...
    pub id: String,       // 平台内 id
    pub extra: BTreeMap<String, String>,
}

pub struct ResolvedAudio {
    pub url: String,
    pub quality: String,
    pub ext: String,
    pub headers: BTreeMap<String, String>,
    pub expires_at: Option<i64>,
    pub is_preview: bool,
    pub source: String,
}

pub struct Capability {
    pub search_songs: bool,
    pub search_playlists: bool,
    pub search_albums: bool,
    pub artist_detail: bool,
    pub daily_recommend: bool,
    pub user_playlists: bool,
    pub ranking: bool,
    pub qr_login: bool,
}

pub trait OnlineBackend {
    fn capabilities(&self, source: &str) -> Capability;
    fn search(&self, q: &str, source: &str, kind: SearchKind, limit: u32, offset: u32) -> Result<Vec<UiTrack>>;
    fn playlist_tracks(&self, id: &str, source: &str, limit: u32, offset: u32) -> Result<Vec<UiTrack>>;
    fn album_tracks(&self, id: &str, source: &str) -> Result<Vec<UiTrack>>;
    fn user_playlists(&self, source: &str, page: u32, limit: u32) -> Result<Vec<UiPlaylist>>;
    fn resolve_audio(&self, track: &TrackRef, quality: &str) -> Result<ResolvedAudio>;
    fn lyric(&self, track: &TrackRef) -> Result<OnlineLyric>;
    fn cover(&self, url: &str) -> Result<Vec<u8>>;
}
```

### 5.3 曲目身份

```rust
pub fn to_ui_track(source: &str, song: &MusicApiSong) -> UiTrack {
    UiTrack {
        id: format!("{source}:{}", song.id),
        source: source.to_string(),
        source_id: instance_id(),              // "musicapi:remote:..." / "musicapi:embedded"
        source_extra_json: Some(serde_json::json!({
            "song_id": song.id,
            "album_id": song.album_id,
            "size": song.size,
            "bitrate": song.bitrate,
            "fee": song.is_vip,
            "extra": song.extra,
        }).to_string()),
        ..map_common(song)
    }
}
```

- 网易云：`netease:<songId>` 与旧数据完全一致，历史队列/统计无需迁移。
- 其他平台：`qq:<songmid>`、`kugou:<hash>` 等。
- `sourceId` 改为服务实例标识，不再承担平台语义；LX 缓存 key 相应调整。

### 5.4 错误模型

```rust
pub enum OnlineError {
    NotConfigured,
    AuthRequired,          // 不进入 LX fallback
    Unsupported,
    PreviewOnly { trial_end: Option<u64> },
    Unavailable(String),   // 可进入 LX fallback
    Upstream(String),
    Network(String),
    Tls(String),
    Timeout,
}
```

Dart 侧负责本地化；`AuthRequired` 不触发 fallback，`PreviewOnly`/`Unavailable`/`Upstream` 可按设置触发。

### 5.5 与旧 crate 的关系

- M1 先把 `laetibeat_netease` 的代码整体移入 `laetibeat_online::netease_compat`，FRB 函数名先保持不变，Dart 零改动。
- M2 增加 `musicapi` 模块和统一的 `online_*` FRB API。
- M4/M5 逐步让 Dart provider 从 `netease_*` 切到 `online_*`；兼容模块保留给网易云专用页面。
- 最终删除 `laetibeat_netease` crate，`Cargo.toml` workspace 同步更新。

---

## 6. Flutter 设计

### 6.1 设置页

把「网易云在线音源」改为「在线音源服务」：

| 项 | 说明 |
|---|---|
| 模式 | 内置服务 / 远程服务 |
| 远程地址 | `https://...`；严格校验 |
| 服务 Token | 安全存储；可选 |
| 测试连接 | 调用 `/api/v1/music/qualities?source=netease` |
| 登录 | 二维码 / 手机号（走 host） |
| 退出登录 | 清除本地网易云 Cookie；远程模式可选清理服务端 |
| LX 后备 | 保留 `allowLxFallback`，文案说明「非会员/无版权时尝试洛雪」 |
| 默认音质 | 保留现有 |

存储键：

```text
online.mode            = embedded | remote
online.base_url        = https://...
online.token           = (secure storage)
online.allow_lx_fallback = true | false
netease.cookie         = (secure storage, 兼容层使用)
```

迁移：读取旧的 `netease.api_base_url` / `netease.allow_lx_fallback`，写入新键后删除旧键。

### 6.2 Provider 调整

- `netease_provider.dart`：
  - base URL 改为 `onlineBaseUrlProvider`（内置模式返回 host 地址，远程模式返回配置地址）。
  - 网易云专用 provider 继续调用 `rust_online.neteaseCompat*`，签名不变。
  - 新增 `onlineSearchProvider`、`onlinePlaylistProvider` 等。
- 新增 `online_provider.dart`：多平台搜索、歌单、专辑、榜单、音质、换源。
- `netease_session.dart`：
  - 保留 Cookie 安全存储；远程/内置模式都通过请求头传给 host。
  - 登录成功后保存 host 返回的 Cookie。
- `netease_settings.dart` → `online_settings.dart`，兼容旧键迁移。

### 6.3 播放链路

`PlayerNotifier._resolveTrack` 改为：

```dart
if (t.source == 'netease') {
  final resolved = await rust_online.neteaseCompatSongUrl(
    baseUrl: onlineBaseUrl, songId: neteaseSongIdFromTrack(t),
    level: 'exhigh', cookie: cookie,
  );
  if (needsFallback(resolved) && allowLxFallback) {
    final fallback = await _resolveOnlineLxFallback(t);
    if (fallback != null) return fallback;
  }
  return PlaybackTrack(
    uri: resolved.url!,
    headers: resolved.headers,
    isPreview: resolved.isTrial,
    enforceHttps: true,
    fallbackDuration: _durationOf(t),
  );
}

if (isOnlineSource(t.source)) {
  try {
    final resolved = await rust_online.resolveOnlineAudio(
      baseUrl: onlineBaseUrl, token: onlineToken,
      source: t.source, id: onlineTrackId(t), quality: preferredQuality,
    );
    return PlaybackTrack(uri: resolved.url, headers: resolved.headers, enforceHttps: true, ...);
  } on OnlineError catch (e) {
    if (allowLxFallback && e.canFallback) {
      final fallback = await _resolveOnlineLxFallback(t);
      if (fallback != null) return fallback;
      rethrow;
    }
    rethrow;
  }
}
```

`PlaybackTrack`（`lib/widgets/player/playback_backend.dart`）增加 `headers`，并修改：

- `lib/core/playback/just_audio_backend.dart`：`ja.AudioSource.uri(Uri.parse(uri), headers: headers)`。
- `lib/widgets/player/playback_backend.dart`（media_kit 实现）：`mk.Media(uri, httpHeaders: headers)`。

### 6.4 LX fallback 泛化

```dart
Future<PlaybackTrack?> _resolveOnlineLxFallback(rust.UiTrack track) async {
  final platform = lxPlatformForSource(track.source); // netease→wy, qq→tx, kugou→kg, kuwo→kw
  if (platform == null) return null;
  final ready = await ref.read(lxRuntimeProvider.notifier)
      .ensurePlayable(platform)
      .timeout(const Duration(seconds: 12), onTimeout: () => false);
  if (!ready) return null;
  final music = lxMusicInfoForOnlineTrack(track); // 使用 sourceExtraJson 构建
  for (final quality in <String>{preferred, '320k', '128k'}) {
    try {
      final url = await rust_lx.resolveLxMusicUrl(source: platform, music: music, quality: quality);
      if (url.isEmpty) continue;
      return PlaybackTrack(uri: url, fallbackDuration: _durationOf(track), enforceHttps: true);
    } catch (_) {}
  }
  return null;
}
```

平台映射：

| 在线 source | LX source | 需要的字段 |
|---|---|---|
| `netease` | `wy` | `songmid` = songId |
| `qq` | `tx` | `songmid` = songmid，`strMediaMid`/`albumMid` 来自 extra |
| `kugou` | `kg` | `hash`、`albumId` |
| `kuwo` | `kw` | `songmid` = rid |
| `migu` | `mg` | `songmid` = copyrightId |
| 其他 | 不支持 | — |

fallback 不改变 `UiTrack` 身份；统计仍记在原 source。

### 6.5 搜索页

- `MobileSearchSourceFilter` 扩展：
  ```dart
  enum MobileSearchSourceFilter { all, local, subsonic, lx, online, netease }
  ```
  - `online`：多平台聚合；
  - `netease`：只搜网易云（兼容层，分页完整）；
- 新增二级来源选择（netease / qq / kugou / kuwo / migu）。
- 结果行显示来源 badge；点击播放使用统一解析。
- 去重键：`(source, id)`；同一首歌跨平台不合并，避免误判。

### 6.6 媒体库

- `OnlineMusicSource` 枚举扩展；按平台展示：
  - 网易云：我的歌单、日推、收藏艺人/专辑（兼容层）
  - QQ/酷狗/汽水/Spotify：我的歌单（上游 `/playlist/user`）
  - 其他平台：只保留搜索/专辑/歌单详情
- 能力不足时隐藏入口，不显示空占位。

### 6.7 封面与歌词缓存

- `NeteaseCoverProvider` 泛化为 `OnlineCoverProvider`：
  - key 带 `source`；
  - 磁盘目录按 source 拆分；
  - 缓存预算沿用现有「网易云 128MB」，后续可合并为「在线音源」总预算。
- `lyric_provider.dart`：
  - 网易云走兼容层（支持翻译/逐字）；
  - 其他平台走 `/api/v1/music/lyric`（纯 LRC，无翻译）；
  - 缓存 key 加 source。

---

## 7. 数据与兼容性

| 数据 | 兼容性 |
|---|---|
| 队列快照 | `netease:<songId>` 不变；新平台使用 `<source>:<id>` |
| 播放统计 | source + id 不变则历史数据保留 |
| 歌单条目 | `source_extra_json` 已存在，直接复用 |
| 网易云 Cookie | 继续存 `flutter_secure_storage`，不迁移 |
| 默认音质 | 保留现有 key |
| LX URL 缓存 | key 中 `sourceId` 语义变化，需要清空一次或加入版本号 |
| 封面磁盘缓存 | 网易云目录可复用；新平台新增目录 |

迁移时执行一次缓存版本升级（例如 `cache_schema = 2`），清空 LX URL 缓存，避免旧 `sourceId` 命中错误。

---

## 8. 分阶段实施

### M0：可行性与阻塞项（1–2 天）

- [ ] 用 NAS 实例确认网易云搜索为空的原因（Cookie / IP / 上游版本）。
- [ ] 在本仓库落地 `laetibeat_musicapi_host` 最小 main + Bearer + addr + data dir。
- [ ] 写 3 个兼容端点（`/login/status`、`/cloudsearch`、`/song/url/v1`），用现有 Rust 客户端跑通。
- [ ] 验证 Android NDK 构建与 `readelf` 属性。
- **验收**：现有 `laetibeat_netease` 指向 host，能登录状态、搜索、播放。

### M1：兼容层 + 远程模式（1–2 周）

- [ ] 移植 §3 D2 表内全部兼容端点。
- [ ] Golden JSON 测试：用现有 Rust 结构反序列化 host 响应。
- [ ] `laetibeat_online` crate 建立，迁移 `laetibeat_netease` 代码。
- [ ] HTTPS-only 客户端 + redirect policy。
- [ ] 设置页支持远程 base URL / token / 测试连接。
- [ ] 播放链路切换 base URL，LX fallback 保持。
- **验收**：发现页、日推、艺人、收藏、搜索、播放、歌词全部与现在一致；网络层拒绝 http 远程地址与降级重定向。

### M2：多平台客户端（1–2 周）

- [ ] `musicapi.rs`：search / user playlists / playlist detail / album detail / url / lyric / cover / qualities。
- [ ] 统一 DTO 与错误。
- [ ] 搜索页接入 `online` 来源；媒体库按平台分组。
- [ ] 播放链路支持非网易云 source + LX fallback 映射。
- **验收**：QQ/酷狗/酷我/咪咕至少各完成一次搜索 → 播放；无版权时可回退 LX。

### M3：内置 host（3–5 天）

- [ ] Android `jniLibs` 构建与 Gradle `useLegacyPackaging` / `extractNativeLibs`。
- [ ] Linux CMake 打包。
- [ ] Dart 进程管理器 + MethodChannel（Android nativeLibraryDir）。
- [ ] 设置页「内置/远程」切换、健康检查、崩溃重启。
- [ ] Android 真机验证 DNS、播放、长时间运行。
- **验收**：不配置 NAS 也能完整使用；离开局域网不受影响。

### M4：多平台能力补齐（1–2 周）

- [ ] 排行榜 / 热门歌曲页面（可新建）。
- [ ] 智能换源。
- [ ] 多平台扫码登录与 Cookie 管理。
- [ ] 汽水 `/stream` 解密链路（标注服务端代理）。
- [ ] 多平台封面/歌词缓存预算。

### M5：清理与合规（2–3 天）

- [ ] 删除旧 `laetibeat_netease` crate 与旧设置键。
- [ ] 更新 `PLAN.md` / `TODO.md` / `ARCHITECTURE.md`。
- [ ] `THIRD_PARTY_NOTICES.md` 增加 go-music-api、music-lib、host。
- [ ] 关于页增加「内置音乐服务源码」链接与 AGPL 文本。
- [ ] CI/Release 构建 host 矩阵并校验产物。
- **验收**：仓库内不再有 Node API 依赖；许可证声明完整；CI 全绿。

---

## 9. 测试计划

### Host（Go）

- `go test ./...`：
  - Bearer 401/200；
  - `LAETIBEAT_MUSICAPI_ADDR=127.0.0.1:0` 返回可用端口；
  - data dir 下生成 `cookies.json`；
  - 兼容端点 golden JSON（用固定 fixture，不打真实网络）。
- 真实联调（ignored test）：
  - `/login/status`、`/cloudsearch`、`/song/url/v1`、`/lyric/new`。

### Rust

- `cargo test --workspace`：
  - `https_only` 拒绝 http base URL；
  - redirect `https → http` 被拒绝；
  - loopback client 只允许 127.0.0.1；
  - 网易云 ID 映射与旧数据一致；
  - DTO 反序列化兼容测试。

### Flutter

- `flutter test`：
  - 设置页模式切换、URL 校验；
  - provider 在 host 未启动/启动失败时的错误态；
  - 搜索来源过滤；
  - LX fallback 触发条件。
- `flutter analyze` 0 error。
- 真机：
  - Android 内置模式冷启动、后台、杀进程重启；
  - Linux bundle 启动 host；
  - 远程模式 HTTPS + token；
  - 无 NAS 环境完整播放。

---

## 10. AGPL 合规清单

- [ ] `laetibeat_musicapi_host/LICENSE` 使用 AGPL-3.0。
- [ ] host 源码公开仓库，tag/commit 与二进制一致。
- [ ] 安装包内「开源许可」页展示 AGPL 文本与源码地址。
- [ ] `THIRD_PARTY_NOTICES.md` 记录 go-music-api、music-lib、host。
- [ ] 发布说明注明「内置音乐服务为 AGPL-3.0 独立程序，经 HTTP 调用」。
- [ ] 不分发未公开修改的 host 二进制。
- [ ] 上游 `music-lib` 的 LICENSE 随包保留。

> 说明：Flutter/Rust 主应用与 host 是独立进程、通过 loopback HTTP 通信，按常见理解属于独立程序；本文件不是法律意见，正式分发前建议复核。

---

## 11. 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| Android 纯 Go DNS 不可用 | 内置 host 无法联网 | 固定 NDK + CGO 构建；CI 校验 `NEEDED libc.so` |
| Android 不抽取 `.so` | exec 失败 | `useLegacyPackaging=true` + `extractNativeLibs=true`；真机验证；必要时 memfd fallback |
| 16KB 页对齐 | Android 16 无法加载 | NDK 28 默认 16KB；CI `readelf` 校验 |
| 体积 +34MB/ABI | APK 变大 | 只发 arm64/armv7；x86_64 可选；文档说明 |
| 兼容层与上游网易云变化 | 日推/艺人页失效 | 移植 `api-enhanced` 模块；固定参考版本；接口失败时 UI 显示空态 |
| 网易云风控 | 搜索/播放失败 | 复用 music-lib 随机 IP/UA；Cookie 优先；失败回退 LX |
| VIP 音质 | EAPI 与 xeapi 差异 | 先用 music-lib EAPI 验证；不足再评估 |
| 上游搜索固定 10 条 | 多平台结果少 | 网易云走兼容层分页；其他平台标注限制 |
| Cookie 模型分裂 | 用户困惑 | 设置页明确「网易云登录仅在当前设备」；多平台 Cookie 后续再做 |
| iOS | 无法内置 | 第一阶段仅远程模式，文档说明 |
| 桌面 Windows/macOS | 打包未开始 | 设计保持 Go 交叉编译，后续补 |

---

## 12. 待确认问题

1. 发现页/日推是否永远只属于网易云？（当前设计：是，其他平台没有等价接口）
2. 远程模式是否强制要求 Token？（建议：是）
3. Android 是否接受安装包增加约 34MB/ABI？
4. 是否需要 iOS？如果需要，内置模式不适用，只能远程。
5. 多平台搜索第一阶段是否只做「每平台 10 条」？
6. 旧 `laetibeat_netease` 是迁移为内部模块，还是希望彻底重写后再删除？

---

## 13. 附录：已验证事实与命令

```text
# 零 fork host
cd /tmp/gma-host
go build -trimpath -ldflags '-s -w' -o host .
# 33 MB
LAETIBEAT_MUSICAPI_ADDR=127.0.0.1:0 LAETIBEAT_MUSICAPI_TOKEN=secret ./host
# LISTEN=127.0.0.1:40319
curl -H 'Authorization: Bearer secret' \
  'http://127.0.0.1:40319/api/v1/music/qualities?source=netease'
# 200

# Android cgo
CGO_ENABLED=1 GOOS=android GOARCH=arm64 \
  CC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang \
  go build -buildmode=pie -trimpath -ldflags '-s -w' -o host-android-arm64 .
file host-android-arm64
# ELF 64-bit LSB pie executable, ARM aarch64, dynamically linked,
# interpreter /system/bin/linker64, for Android 24, 34 MB
readelf -lW host-android-arm64 | grep LOAD
# Align 0x4000（16KB）
readelf -d host-android-arm64 | grep NEEDED
# liblog.so / libdl.so / libc.so

# 上游网易云搜索实测（NAS）
curl 'http://192.168.31.51:8080/api/v1/music/search?q=稻香&type=song&sources=netease'
# {"code":200,...,"songs":null}  ← 需要兼容层自行实现 cloudsearch
curl 'http://192.168.31.51:8080/api/v1/music/url?id=1973665667&source=netease&quality=high'
# 正常返回直链

# 兼容层 weapi 实测（2026-11-27）
/weapi/cloudsearch/pc                 200 {"result":{"songs":[...
/weapi/personalized/playlist          200 {"hasTaste":false,"code":200,"result":[...]}
/weapi/v1/radio/get                   200 {"popAdjust":false,"data":[...]}
/weapi/v1/discovery/simiSong          200 {"songs":[...]}
/weapi/v6/playlist/detail             200 {"code":200,"playlist":{...}}
/weapi/v3/song/detail                 200 {"songs":[...]}
/weapi/song/lyric                     200 {"lrc":{"lyric":"..."},"tlyric":...}
/weapi/homepage/block/page            200 {"code":200,"data":{"blocks":[...]}}
/weapi/v3/discovery/recommend/songs   200 {"code":200,"data":{"dailySongs":[...]}}
/weapi/v1/artist/6452                 200 {"artist":{...},"hotSongs":[...]}
/weapi/artist/top/song                200 {"code":200,"songs":[...]}
/weapi/artist/albums/6452             200 {"code":200,"artist":{...},"hotAlbums":[...]}
/weapi/user/playlist                  200 {"playlist":[...]}
/weapi/w/nuser/account/get            200 {"code":200,"account":null,"profile":null}
/weapi/login/qrcode/unikey            200 {"code":200,"unikey":"..."}
/weapi/login/qrcode/client/login       200 {"code":800,...}
/weapi/song/like/get                  200 {"code":301}      # 未登录
/weapi/artist/sublist                 200 {"code":301,...}  # 未登录
/weapi/album/sublist                  200 {"code":301,...}  # 未登录
/weapi/playmode/intelligence/list     200 {"code":301}      # 未登录
```

```text
# Go 源码依据
/usr/lib/go/src/net/conf.go:
// DNS requests don't work on Android, so prefer the cgo resolver.
// Issue #10714.
case "android":
    return true
```

---

## 14. 一句话总结

**用「零 fork 的 Go host + 网易云兼容层」保住现有 UI，用「上游原生 API」扩展多平台，用「loopback + Bearer + HTTPS-only 策略」满足安全要求；Android 内置的关键是 NDK/CGO + jniLibs 打包。**
