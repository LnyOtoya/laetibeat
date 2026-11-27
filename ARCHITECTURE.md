# Laetibeat Architecture

> 最后更新：2026-11-27
> 分支状态：`main` / `gomusic` 使用当前 go-music-api host；`native` 分支目标为两个 Rust sidecar。
> 在线音源当前实现见 `docs/musicapi-migration.md`；native 目标见 `docs/native-modes-migration.md`；当前计划见 `PLAN.md`。

## 0. 分支状态与目标（2026-11-27）

```text
main       当前稳定线
gomusic    保留 go-music-api 实现（v1.0.2）
native     新分支：删除 go-music-api，改用 Rust 原生 sidecar
```

`native` 目标：

| 模式 | 后端 | 形态 |
|---|---|---|
| 本地 | 现有本地库 | 进程内 Rust |
| Subsonic | `laetibeat_remote` | 进程内 Rust |
| QQ 音乐 | `QQMusicApi-rs` | Rust sidecar |
| 网易云音乐 | `ncm-api-rs` | Rust sidecar |

- 模式切换时停止当前 sidecar，不删除数据目录
- Cookie / Credential 按模式保存，切回时读取
- 不需要 Docker / NAS / Node / Python
- Android / Linux 都使用原生二进制

> 下文描述当前 `main` / `gomusic` 的 Go host 架构；native 分支会替换其中的
> `laetibeat_musicapi_host` 和 `laetibeat_online` 的 Go 专用部分。

## 1. 总览（当前 gomusic）

```text
Flutter UI
  ├─ 本地音乐 / 播放器 / 设置 / 统计
  ├─ OpenSubsonic 客户端
  ├─ LX 音源（QuickJS）
  └─ 在线音源（网易云 / QQ）
        │ Riverpod providers
        ▼
Rust workspace
  ├─ laetibeat_core       本地音乐库、元数据、播放
  ├─ laetibeat_remote     OpenSubsonic
  ├─ laetibeat_lx         LX 运行时与解析
  └─ laetibeat_online     go-music-api 客户端
        │ loopback HTTP + Bearer
        ▼
laetibeat_musicapi_host (Go, AGPL-3.0)
  ├─ go-music-api router/service
  └─ music-lib providers (netease / qq)
```

在线音源 host 是**独立进程**，不链接进 Flutter/Dart/Rust 进程。

## 2. Flutter 层

### 启动装配

`lib/app/bootstrap.dart`：

1. 初始化窗口、Rust、SQLite、LX、SharedPreferences。
2. 注册嵌入式 AGPL 许可证条目。
3. 构建 `ProviderContainer`。
4. `runApp` 后启动 `OnlineHostController`（内置模式）。
5. 后台预热 LX 运行时与缓存。

### 设置与运行时

- `lib/widgets/settings/online_settings.dart`
  - `OnlineMode { builtin, remote }`
  - 持久化 `online.mode` / `online.base_url` / `online.default_quality` / `online.allow_lx_fallback`
  - `onlineRuntimeOverridesProvider`：内置 host 运行时的动态 base URL / token 覆盖
  - `onlineBaseUrlProvider` / `onlineTokenProvider` 对上层统一暴露
- `lib/widgets/settings/online_host.dart`
  - `OnlineHostController`：进程启动、stdout listen 行、健康检查、异常重启、父进程退出
  - 随机 loopback 端口 + 随机 token
  - 数据目录：应用支持目录下 `musicapi/`

### UI

- 搜索：`lib/pages/mobile/search/`
- 发现：`lib/pages/mobile/discover/`
- 在线歌单/专辑/榜单详情：`lib/pages/mobile/library/online/`
- 在线设置/扫码登录：`lib/pages/mobile/settings/online/`

## 3. Rust 层

### `laetibeat_online`

- `HttpClient`：reqwest blocking，HTTPS-only（loopback 例外）、最多 5 跳重定向、远程不跨 host、25s 超时。
- `model.rs`：go-music-api DTO → `OnlineTrack` / `OnlinePlaylist` / ...；封面 URL 统一升级 HTTPS。
- `musicapi.rs`：搜索、歌单、专辑、榜单、热门、直链、歌词、音质、扫码登录、平台状态、退出。
- `laetibeat_flutter/rust/src/api/online.rs`：FRB facade。

### 播放解析

`lib/widgets/player/player_provider.dart`：

1. `source == netease/qq` → `onlineResolveAudio`
2. 失败且开启 LX 后备 → `onlineLxPlatform(source)` 映射 `wy` / `tx`，调用 LX 解析
3. 返回 `PlaybackTrack(uri, headers, enforceHttps: true)`

音频 URL 经 `lib/core/playback/online_audio_https_proxy.dart`：

- 仅绑定 loopback
- 随机 token 路径
- 升 HTTP → HTTPS，拒绝 HTTPS → HTTP
- 支持 Range / If-Range / headers

## 4. Go host

`laetibeat_musicapi_host/`：

- `main.go`：env（ADDR / TOKEN / DATA_DIR / PARENT_PID）、listen 行、graceful shutdown
- `security.go`：Bearer 鉴权、路由屏蔽、CORS 移除、请求体上限、脱敏访问日志
- `system.go`：`/laetibeat/system/platforms` 状态与退出
- `third_party/music-lib/`：pinned 副本；`netease.cloudSearch` 单函数 weapi 补丁
- 数据：`cookies.json` 写入应用私有数据目录

## 5. 安全边界

| 边界 | 策略 |
|---|---|
| 远程 host | 必须 HTTPS + Bearer token |
| 本机 host | 仅 `127.0.0.1`；无 token 拒绝非 loopback 监听 |
| 重定向 | 最多 5 跳；不允许 HTTPS→HTTP；远程不跨 host |
| 屏蔽路由 | `/api/v1/music/cover`、`/api/v1/system/cookies`、`/music/*`、Swagger |
| Cookie | 仅 host 持久化；App 只读 `has_cookie` |
| 日志 | method/path/status/duration，不含 query/body |
| Token | 内置随机不落盘；远程存 secure storage |

## 6. 构建与打包

### Android

- `android/app/build.gradle.kts`：
  - `buildMusicApiHost*` 任务按 ABI 构建 Go host
  - arm64-v8a / armeabi-v7a / x86_64
  - NDK clang + CGO + `-buildmode=pie`
  - 输出 `jniLibs/<abi>/liblaetibeat_musicapi_host.so`
- `extractNativeLibs=true` + `useLegacyPackaging=true`
- `MainActivity` 通过 MethodChannel 提供 `nativeLibraryDir`

### Linux

- `linux/CMakeLists.txt`：
  - `go build`（`CGO_ENABLED=0`）
  - 安装到 `bundle/lib/laetibeat_musicapi_host`
- `OnlineHostController` 从 `Platform.resolvedExecutable` 推导路径

### Host 生命周期

- App 首帧后启动（内置模式）
- 读取 `LAETIBEAT_MUSICAPI_LISTEN=host:port`
- 健康检查 `/laetibeat/health`
- 异常退出自动重启最多 2 次
- `LAETIBEAT_MUSICAPI_PARENT_PID` watchdog：App 进程退出后 host 自动退出

## 7. 测试

- Flutter：`flutter analyze` / `flutter test`
- Rust：`cargo test --workspace`
- Go：`go test ./...`
- CI host 矩阵：Linux amd64/arm64 + Android arm64/armv7/x86_64
- 真机：DNS、搜索、发现页、播放、后台、自动重启、force-stop 清理

## 8. 相关文档

- `docs/musicapi-migration.md`：迁移设计、M0–M5、风险、验收
- `PLAN.md`：当前计划
- `TODO.md`：工程债（顶部有历史条目说明）
- `THIRD_PARTY_NOTICES.md`：第三方许可与 AGPL 源码入口
