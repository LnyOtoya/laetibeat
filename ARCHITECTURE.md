# Laetibeat Architecture

> 最后更新：2026-11-27
> 分支状态：`native` 已切换到两个 Rust sidecar；`gomusic` 保留 go-music-api 实现（v1.0.2），仅作回退。

## 0. 分支状态

```text
main       稳定线（native 通过 PR 合并后更新）
gomusic    保留 go-music-api 实现与 v1.0.2
native     当前在线音源实现：QQMusicApi-rs + ncm-api-rs
```

模式：

| 模式 | 后端 | 形态 |
|---|---|---|
| 本地 | 现有本地库 | 进程内 Rust |
| Subsonic | `laetibeat_remote` | 进程内 Rust |
| QQ 音乐 | `laetibeat_qq_host` + `QQMusicApi-rs` | Rust sidecar |
| 网易云音乐 | `laetibeat_netease_host` + `ncm-api-rs` | Rust sidecar |

- 切换模式时先暂停播放，再停止当前 sidecar；不删除数据目录。
- Cookie / Credential 按模式保存在 `modes/{qq,netease}/`。
- 不依赖 Docker / NAS / Node / Python。
- 仅 Android / Linux 支持内置 sidecar；iOS 尚未接入。

## 1. 总览

```text
Flutter UI
  ├─ 本地音乐 / 播放器 / 设置 / 统计
  ├─ OpenSubsonic 客户端
  ├─ LX 音源（QuickJS）
  └─ 在线音源（QQ / 网易云）
        │ Riverpod providers
        ▼
Rust workspace
  ├─ laetibeat_core       本地音乐库、元数据、播放
  ├─ laetibeat_remote     OpenSubsonic
  ├─ laetibeat_lx         LX 运行时与解析
  └─ laetibeat_online     两个 online host 的统一 HTTP/DTO 客户端
        │ loopback HTTP + Bearer
        ▼
laetibeat_qq_host (GPL-3.0-only)     laetibeat_netease_host (MIT)
  └─ QQMusicApi-rs                     └─ ncm-api-rs (WTFPL)
```

两个 host 都是**独立 PIE 进程**，不链接进 Flutter/Dart/Rust 进程。

## 2. Flutter 层

### 启动装配

`lib/app/bootstrap.dart`：

1. 初始化窗口、Rust、SQLite、LX、SharedPreferences。
2. 注册嵌入式 native host 许可证条目。
3. 构建 `ProviderContainer`。
4. `runApp` 后读取 `app.mode`，按模式启动 `ModeHostController`。
5. 后台预热 LX 运行时与缓存。

### 皮肤 / 设计语言

- `lib/app/skin/app_skin.dart`：`AppSkinId` 与 `AppSkin` 契约
- `lib/app/skin/app_skin_provider.dart`：持久化 `ui.skin`
- `lib/app/skin/app_skin_registry.dart`：皮肤实现注册表
- `lib/skins/expressive/`：当前默认 Material 3 Expressive 根 App、Shell 与页面
- 皮肤可拥有自己的导航外观和页面实现；移动端目的地、路由栈与返回规则由共享导航层管理
- 播放媒体集成位于皮肤外层，切换皮肤不会断开系统媒体会话
- 详细规划见 `docs/ui-skins.md`

### 模式与运行时

- `lib/app/app_mode.dart`
  - `AppMode { local, subsonic, qq, netease }`
  - 持久化键 `app.mode`
- `lib/widgets/settings/mode_host.dart`
  - `ModeHostController`：启动 / 停止 / 重启 / 切换
  - 切换前暂停播放
  - 读取 host stdout 的 `LAETIBEAT_MUSICAPI_LISTEN=host:port`
  - 随机 loopback 端口 + 随机 Bearer token
  - 健康检查、异常重启、父进程 watchdog
  - 数据目录：`<app_support>/modes/{qq,netease}/`
- `lib/widgets/settings/mode_runtime.dart`
  - `modeRuntimeProvider`：当前模式的 base URL / token
- `lib/widgets/settings/online_settings.dart`
  - 默认音质、LX 后备
  - `onlineBaseUrlProvider` / `onlineTokenProvider` 从 `modeRuntimeProvider` 取值；local / subsonic 为空

### 移动端导航

- `MaterialApp` 的 root Navigator 是唯一移动端页面栈；`MobileShell` 在 Navigator 外层持久显示底部导航和 MiniPlayer。
- 首页 / 媒体库是 Shell 内的目的地状态，不通过 push 在彼此之间切换；目的地集合与默认页由 `AppMode.mobileDestinations` / `mobileInitialDestination` 提供。
- 搜索、详情、设置、播放器等页面都 push 到同一 root Navigator。Tab 切换时先回到 Shell 根页面，再更新选中目的地。
- `MobileNavigatorObserver` 观察 root 页面栈并驱动 Shell chrome 显示；未知命名路由不再回退成首页。
- 后续 UI 皮肤可以改变导航栏和页面外观，但必须复用相同的目的地状态、root 路由栈和返回语义，不创建第二套移动端 Navigator。

### UI

- 设置 → 音源模式：本地 / Subsonic / QQ / 网易云切换与 sidecar 状态
- 设置 → 在线音源：当前模式 sidecar 状态、账号登录/退出、音质、LX 后备
- 搜索：在线源跟随当前 `AppMode`
- 在线歌单 / 专辑 / 榜单详情：`lib/pages/mobile/library/online/`

## 3. Rust 层

### `laetibeat_online`

统一在线客户端，保留给两个 host 使用：

- `HttpClient`：reqwest blocking，HTTPS-only（loopback 例外）、最多 5 跳重定向、远程不跨 host、25s 超时。
- `model.rs`：兼容 DTO → `OnlineTrack` / `OnlinePlaylist` / ...；封面 URL 统一升级 HTTPS。
- `musicapi.rs`：搜索、歌单、专辑、榜单、热门、直链、歌词、音质、扫码登录、平台状态、退出。
- `laetibeat_flutter/rust/src/api/online.rs`：FRB facade。
- `native_mode_probe`：可分别指向两个 host 做本地联调。

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

## 4. Online hosts

### `laetibeat_qq_host`

- 依赖 `QQMusicApi-rs`（GPL-3.0-only）
- 搜索 / URL / 歌词 / 二维码登录 / Credential
- 兼容端点：歌单、专辑、推荐、榜单、热门、平台状态、退出

### `laetibeat_netease_host`

- 依赖 `ncm-api-rs`（WTFPL）
- 搜索 / URL / 歌词 / 二维码登录 / Cookie
- eapi 游客 token 注册；`song_url_v1` 失败时回退旧 `br` 接口
- 兼容端点同上

两个 host 都：

- 仅绑定 loopback
- Bearer token 常量时间比较
- 请求体上限 4 MiB
- 无 CORS
- 访问日志只记录 method/path/status/duration
- 父进程退出后自动退出

## 5. 安全边界

| 边界 | 策略 |
|---|---|
| 本机 host | 仅 `127.0.0.1`；无 token 拒绝非 loopback 监听 |
| 重定向 | 最多 5 跳；不允许 HTTPS→HTTP；远程不跨 host |
| Cookie / Credential | 仅 host 持久化；App 只读 `has_cookie` |
| 日志 | method/path/status/duration，不含 query/body |
| Token | 每次启动随机，不落盘 |

## 6. 构建与打包

### Android

`android/app/build.gradle.kts`：

- `buildRustOnlineHosts*` 按 ABI 构建两个 host
- arm64-v8a / armeabi-v7a / x86_64
- NDK clang，PIE，strip
- 输出 `jniLibs/<abi>/liblaetibeat_qq_host.so` / `liblaetibeat_netease_host.so`
- 16KB / 4KB LOAD 对齐
- `extractNativeLibs=true` + `useLegacyPackaging=true`
- `MainActivity` 通过 MethodChannel 提供 `nativeLibraryDir`

### Linux

`linux/CMakeLists.txt`：

- cargo 构建两个 host
- 安装到 `bundle/lib/laetibeat_qq_host` / `laetibeat_netease_host`
- `ModeHostController` 从 `Platform.resolvedExecutable` 推导路径

### Host 生命周期

- App 首帧后按 `app.mode` 启动
- 读取 `LAETIBEAT_MUSICAPI_LISTEN=host:port`
- 健康检查 `/laetibeat/health`
- 异常退出自动重启最多 2 次
- `LAETIBEAT_MUSICAPI_PARENT_PID` watchdog：App 进程退出后 host 自动退出

## 7. 测试

- Flutter：`flutter analyze` / `flutter test`
- Rust：`cargo test --workspace`
- Native 联调：`native_mode_probe` 分别指向 QQ / 网易云 host
- CI host 矩阵：Linux + Android arm64/armv7/x86_64
- 真机：模式启动、DNS、搜索、播放、force-stop 清理

## 8. 相关文档

- `docs/native-modes-migration.md`：native 设计、N0–N6、验收
- `docs/ui-skins.md`：皮肤架构与 Spotify / Apple Music 后续计划
- `docs/mode-pages.md`：各音源模式的导航与页面内容矩阵
- `docs/musicapi-migration.md`：gomusic 分支历史
- `PLAN.md`：当前计划
- `TODO.md`：工程债
- `THIRD_PARTY_NOTICES.md`：第三方许可与 native host 源码入口
