# Native Modes Migration

> 状态：native 分支已实现；go-music-api 实现保留在 `gomusic` 分支。
> 最后更新：2026-11-27

## 1. 结论

新分支不再使用 go-music-api、Python QQMusicApi 或 Node api-enhanced。

在线音源改为两个 **Rust 原生 sidecar**：

| 模式 | 后端 | 许可证 | 形态 |
|---|---|---|---|
| QQ 音乐 | `reference/QQMusicApi-rs` | GPL-3.0-only | Rust sidecar |
| 网易云音乐 | `reference/ncm-api-rs` | WTFPL | Rust sidecar |
| Subsonic | 现有 `laetibeat_remote` | MIT | 进程内 Rust |
| 本地 | 现有本地音乐库 | MIT | 进程内 Rust |

目标：

- 不需要 Docker
- 不需要 NAS
- 不需要 Node / Python 运行时
- Android / Linux 都能内置
- 每个模式独立启动/停止，Cookie/Credential 持久化

## 2. 分支策略

```text
main       当前稳定线（保留，暂时指向 gomusic 同等内容）
gomusic    完整保留 go-music-api 实现与 v1.0.2 tag
native     新分支：删除 go-music-api，使用 Rust 原生后端
```

长期目标是把 `native` 验证稳定后合入 `main`；在验证前不删除 `gomusic`。

### 2.1 合并与版本策略

`native` 是集成分支，不会自动变成 `main`；需要显式走 PR / merge。

合并前必须满足：

- [x] `laetibeat_qq_host` 可用
- [x] `laetibeat_netease_host` 可用
- [ ] 本地 / Subsonic / QQ / 网易云模式切换正常
- [ ] 切换模式停止 sidecar，Cookie / Credential 可恢复
- [x] Android / Linux 构建通过
- [x] go-music-api 已从 `native` 删除
- [ ] CI `test` / `host` 通过
- [ ] 真机验证：搜索、播放、登录、后台、模式切换

合并方式：

```text
native → main
```

- 优先使用 GitHub PR，确保 CI 跑在合并前
- 不使用 `git push --force` 覆盖 `main`
- 建议 merge commit，保留 native 的阶段历史
- 合并后 `main` 指向 native 最新提交
- `gomusic` 保持原提交，不随合并移动
- `v1.0.2` 等旧 tag 保持在原提交
- `native` 合并后可保留一个版本周期，确认无回退需求再删除

版本建议：

| 方案 | 适用 |
|---|---|
| `v2.0.0`（推荐） | 后端形态、模式行为、数据目录均变化 |
| `v1.1.0` | 仅当希望保持 1.x 兼容叙事 |

发布前需要重新走 `docs/release-checklist.md`，不能沿用 1.0.2 的检查结果。

`gomusic` 的维护策略：

- 只接受必要的 1.0.x 修复
- 修复后按需 cherry-pick 到 `native`
- 不把 native 的新功能反向合入 gomusic

## 3. 模式定义

```dart
enum AppMode {
  local,
  subsonic,
  qq,
  netease,
}
```

持久化键建议：

```text
app.mode = local | subsonic | qq | netease
```

不同模式显示不同内容：

- `local`：本地音乐、最近加入、本地统计
- `subsonic`：Subsonic 浏览/搜索/播放
- `qq`：QQ 搜索、推荐、歌单、我的、登录
- `netease`：网易云搜索、推荐、歌单、我的、登录

搜索页不再默认混合所有在线源；在线源由当前模式决定。

## 4. 运行时架构

```text
Flutter
  └─ ModeController
      ├─ local       → 无 sidecar
      ├─ subsonic    → laetibeat_remote（进程内）
      ├─ qq          → laetibeat_qq_host（Rust sidecar）
      └─ netease     → laetibeat_netease_host（Rust sidecar）
```

Sidecar 与 App 的约定沿用当前 host 思路：

- 仅绑定 `127.0.0.1`
- 随机端口
- 随机 Bearer token
- stdout 打印：

```text
LAETIBEAT_MUSICAPI_LISTEN=127.0.0.1:PORT
```

- 数据目录由 App 传入
- 关闭 CORS
- 请求体上限
- 访问日志只记录 method/path/status/duration

远程模式如果保留，必须 HTTPS + token；第一版 native 分支可以只做内置模式。

## 5. 模式切换

切换流程：

1. 暂停/停止当前播放（避免旧 sidecar 停止后音频流中断）
2. `stop()` 当前模式 sidecar
3. 不删除任何数据目录
4. 保存 `app.mode`
5. 启动目标模式 sidecar
6. 读取目标模式已保存的 Cookie / Credential
7. 重建目标模式的 Riverpod providers
8. 显示目标模式内容

原则：

- 停止服务 ≠ 退出登录
- 切换模式不清理 Cookie
- 只有用户主动“退出登录”才删除凭证
- 本地 / Subsonic 模式不启动在线 sidecar

## 6. 数据目录

```text
app_support/
  modes/
    qq/
      device.json
      credential.json
      cache/
    netease/
      device.json
      cookies.json
      cache/
    subsonic/
      existing config
```

### QQ

`QQMusicApi-rs` 已有：

- `Device` / `device.json`
- `Credential`
- `Client::builder().credential(...)`
- `Client::builder().device_path(...)`

登录成功后保存 `Credential`，下次启动读取。

### 网易云

`ncm-api-rs`：

- 登录接口返回 `ApiResponse.cookie: Vec<String>`
- 保存 join 后的 Cookie 字符串
- 启动时 `ApiClient::set_cookie(...)`
- `login_status` 校验
- 二维码登录：`login_qr_key` / `login_qr_create` / `login_qr_check`

## 7. Host 设计

### 7.1 `laetibeat_qq_host`

依赖：

```toml
qqmusic-api = { path = "../reference/QQMusicApi-rs/crates/qqmusic-api" }
```

职责：

- 搜索
- 歌曲详情 / 播放 URL
- 歌单 / 专辑 / 歌手 / 排行榜
- 推荐 / 用户
- QQ / 微信 / App 扫码登录
- Credential 持久化

`QQMusicApi-rs` 没有现成 HTTP server，需要自定义薄 Axum/axum-like wrapper。

### 7.2 `laetibeat_netease_host`

依赖：

```toml
ncm-api-rs = { git = "https://github.com/SPlayer-Dev/ncm-api-rs", rev = "133b65bfe482e41ebccf018870d3fce07bf58eb3" }
```

不使用 `ncm-server` 默认配置：

- 默认 `0.0.0.0:3000`
- 默认 CORS 全开
- 默认无 Bearer token
- 默认不限流

正确做法：

- 使用 `ncm-api-rs` 的库能力
- 自己绑定 `127.0.0.1:0`
- 外层加 token / CORS / 请求体限制
- 用 App 数据目录保存 Cookie

### 7.3 共享 wrapper

两个 host 应共享：

- listen 行输出
- token 鉴权
- 随机端口
- 优雅退出
- 父进程 watchdog
- 脱敏访问日志
- 请求体上限

可以抽成 workspace 内的 `laetibeat_online_host_common` crate。

## 8. API 映射

### 网易云 `ncm-api-rs`

返回原始 `serde_json::Value`，适合直接映射：

- `cloudsearch`
- `song_url_v1`
- `lyric`
- `playlist_detail`
- `album`
- `artists`
- `toplist`
- `recommend_songs`
- `personal_fm`
- `homepage_block_page`
- `user_playlist`
- `likelist`
- `artist_sublist`
- `album_sublist`
- `login_qr_*`

### QQ `QQMusicApi-rs`

强类型模型，直接映射：

- `Client.search()`
- `Client.song()`
- `Client.songlist()`
- `Client.recommend()`
- `Client.user()`
- `Client.login()`

### Flutter 模型

两个 host 都映射到现有：

```text
OnlineTrack
OnlinePlaylist
OnlineAlbum
OnlineTopList
OnlineResolvedAudio
OnlineLyric
```

模式只影响 provider 选择和页面内容，不改变曲目身份。

## 9. 构建与打包

### Android

- 删除 Go host 的 Gradle `buildMusicApiHost*` 任务
- 改为 cargo 构建两个 Rust host：

```text
jniLibs/<abi>/liblaetibeat_qq_host.so
jniLibs/<abi>/liblaetibeat_netease_host.so
```

- 每个模式只启动对应二进制
- 保持 `extractNativeLibs=true` 和 `useLegacyPackaging=true`
- arm64 第一优先；armv7 / x86_64 后续评估

### Linux

- 删除 Go host 的 CMake 构建
- 改为 cargo 构建：
  - `bundle/lib/laetibeat_qq_host`
  - `bundle/lib/laetibeat_netease_host`
- 只启动当前模式对应进程

## 10. 许可证

| 项目 | 许可证 | 处理 |
|---|---|---|
| `QQMusicApi-rs` | GPL-3.0-only | 独立 sidecar；发布附源码/许可证 |
| `ncm-api-rs` | WTFPL | 宽松；仍保留 LICENSE |
| 主应用 | MIT | 不直接链接 GPL QQ 代码 |

建议：

- QQ host 独立进程，避免 GPL 链接进主应用
- NetEase host 也独立进程，保持架构一致
- 更新 `THIRD_PARTY_NOTICES.md` 与关于页源码入口

## 11. 分阶段实施

### N0：分支与文档

- [x] 新增本文件
- [x] 创建并推送 `gomusic`
- [x] 创建并推送 `native`
- [x] 更新 PLAN/TODO/ARCHITECTURE

### N1：QQ host spike（已完成主体）

- [x] `laetibeat_qq_host` crate
- [x] 搜索 / 播放 URL / 歌词
- [x] 二维码创建/轮询（QQ / 微信；mobile 未接）
- [x] Credential 保存/加载代码
- [x] Linux release + Android arm64 构建
- [x] Android 真机 health/search 验证
- [ ] 真实扫码成功并验证 credential 持久化

### N2：NetEase host spike（已完成主体）

- [x] `laetibeat_netease_host` crate
- [x] 搜索 / 播放 URL / 歌词
- [x] 二维码登录 + 游客 token 注册
- [x] Cookie 保存/加载代码
- [x] Linux + Android arm64 构建
- [x] Android 真机 health/search/url 验证
- [ ] 真实扫码成功并验证 cookies.json 持久化

### N3：模式控制器（已完成主体）

- [x] `AppMode` provider + `app.mode` 持久化
- [x] `ModeHostController` start / stop / restart / switch
- [x] 数据目录按模式隔离：`modes/{qq,netease}`
- [x] 切换时暂停播放
- [x] 启动时按已保存模式自动拉起 sidecar
- [x] 设置页「音源模式」入口与状态卡
- [x] 开发期 `--dart-define=LAETIBEAT_QQ_HOST_PATH=...` 路径覆盖
- [ ] 页面实际消费 `modeRuntimeProvider`（N4）
- [ ] Android / Linux host 打包后的真机切换验证（N5）

### N4：页面与在线 API（核心链路完成）

- [x] `onlineBaseUrlProvider` / `onlineTokenProvider` 跟随模式 sidecar
- [x] 现有 Rust 在线客户端兼容 QQ / 网易云 host
- [x] 搜索、播放 URL、歌词
- [x] 歌单 / 专辑详情
- [x] 推荐歌单 / 排行榜 / 热门歌曲
- [x] 二维码登录 / 状态 / 退出 / 平台状态
- [x] 发现页平台跟随当前模式
- [x] 搜索默认源跟随当前模式
- [x] 账号列表按模式只显示对应平台
- [ ] 首页内容按模式区分
- [ ] 本地 / Subsonic 专属页面
- [ ] Android / Linux host 打包后真机端到端（N5）

### N5：打包（已完成主体）

- [x] Android 双 host jniLibs（Go host 暂留到 N6）
- [x] Linux 双 host bundle
- [x] Gradle / CMake cargo build task
- [x] CI host matrix
- [x] release assets / licenses
- [x] debug APK 真机启动 QQ / NetEase sidecar
- [x] 16 KB / 4 KB LOAD 对齐
- [x] signed release split APK 构建（arm64 / armv7 / x86_64）
- [ ] signed release split APK 实机安装验证（发布时执行）
- [ ] 应用内运行中切换模式的自动化/人工验收

### N6：删除 go-music-api（已完成）

- [x] 删除 `laetibeat_musicapi_host`
- [x] 删除 `third_party/music-lib`
- [x] 删除 Go 相关 Gradle/CMake/CI
- [x] 删除旧 `onlineHostProvider` Go builtin 逻辑
- [x] 保留 `laetibeat_online` 作为 native host 统一客户端
- [x] 更新文档与许可证

## 12. 已验证事实

- `ncm-api-rs` 在临时副本中通过：

```bash
cargo check --target aarch64-linux-android --features server
```

- release 构建产物：

```text
target/aarch64-linux-android/release/ncm-server
18 MB
ELF 64-bit LSB pie executable, ARM aarch64
interpreter /system/bin/linker64
Android 24
NDK r28c
```

- `ncm-api-rs` 在 Android arm64 的依赖链通过编译；`laetibeat_netease_host`
  Linux release 7.7 MB，Android arm64 release 7.9 MB。
- NetEase 未登录时会通过 eapi 游客注册获取 `MUSIC_A`；`song_url_v1` 失败时
  host 回退到旧的 `br=999000` URL 接口。
- `laetibeat_netease_host` Linux/Android live：health / search / url / lyric /
  QR 创建与 `waiting` 轮询均通过。
- `QQMusicApi-rs` 默认纯 Rust（`tls-graviola`），aarch64 / x86_64 不需要 C 工具链。
- `laetibeat_qq_host`：
  - Linux release：13 MB
  - Android arm64 release：13 MB，PIE，Android 24，NDK r28c
  - Linux live：health / search / url / lyric / QR 创建均 200
  - Android 真机：host 启动、health、QQ 搜索通过
  - QR 轮询已返回 waiting/scanned；真实扫码与 credential 持久化待人工验证
- N3/N4 Flutter 检查：`flutter analyze` 0 error；`flutter test` 29 passed。
  - N6 已删除 `onlineHostProvider` 与 Go host；现在只由 `modeHostProvider` 管理
    两个 Rust sidecar。
  - N5 已完成 Android / Linux host 打包；真机已按 `app.mode` 分别启动 QQ / 网易云 host。
- N4 兼容层验证：同一个 `laetibeat_online` 客户端分别指向 QQ / 网易云 host，
  搜索、歌词、推荐歌单、歌单详情、排行榜、榜单歌曲、热门歌曲、专辑详情、
  播放 URL、平台状态、二维码创建/轮询均通过。
- Android arm64 release：`laetibeat_qq_host` 13 MB；`laetibeat_netease_host` 9.7 MB。
- Android 真机：最新兼容层 host 启动、QQ/网易云搜索与 URL 解析通过。
- N5 打包：
  - Gradle task `buildRustOnlineHosts<Abi>` 将两个 host 写入 jniLibs
  - Android 打包后 arm64：QQ 8.8 MB / NetEase 6.3 MB（strip）
  - Linux bundle：QQ 9.6 MB / NetEase 5.8 MB（strip）
  - debug APK 真机：`app.mode=qq` 启动 `liblaetibeat_qq_host.so`；
    `app.mode=netease` 启动 `liblaetibeat_netease_host.so`；force-stop 后无残留
  - arm64 / x86_64 LOAD 对齐 0x4000，armv7 0x1000
  - CI 增加 Rust Linux / Android 三 ABI 构建；release 资产增加 host 许可证
  - release split APK：armv7 70.1 MB / arm64 71.9 MB / x86_64 74.1 MB
    （含暂留的 Go host；N6 删除后预计显著缩小）
  - release APK 已签名、`extractNativeLibs=true`、versionCode 1002002（arm64）
- N6 清理后：
  - 删除 Go host、`third_party/music-lib`、Go Gradle/CMake/CI
  - Android APK 只包含 `liblaetibeat_qq_host.so` / `liblaetibeat_netease_host.so`
  - release arm64 从 71.9 MB 降到 60.3 MB；armv7 57.8 MB；x86_64 61.5 MB
  - Linux bundle 只包含两个 Rust host
  - debug APK 真机启动后只有对应模式 sidecar，无 Go 进程
  - local 模式启动后没有 sidecar 进程
  - `laetibeat_online` 保留为两个 host 的统一客户端
- N6 Flutter 检查：`flutter analyze` 0 error；`flutter test` 29 passed。

## 13. 相关文档

- `reference/QQMusicApi-rs/README.md`
- `reference/ncm-api-rs/README.md`
- `reference/ncm-api-rs/docs/API.md`
- `docs/musicapi-migration.md`（仅适用于 gomusic 分支）
- `ARCHITECTURE.md`
