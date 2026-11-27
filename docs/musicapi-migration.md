# Laetibeat 在线音源迁移设计（最终方案）

> 最后更新：2026-11-27
> 决策：旧网易云 Node API 已从 `main` 删除；**不做 overlay / 兼容层**；网易云和 QQ 统一走 `go-music-api`；host 随 App 内置，不再需要 NAS/Docker；发现页暂时保留空壳。
> 旧实现完整保存在 `api` 分支；本文档只描述 `main` 的目标方案。

---

## 0. 决策摘要

| 项 | 决定 |
|---|---|
| 旧网易云 Node API | 删除，不再保留客户端、设置、Cookie、兼容层 |
| 网易云数据来源 | `go-music-api` 的 `/api/v1/*` |
| QQ 数据来源 | 同上 |
| 其他平台 | 暂不做，后续按同一套接口扩展 |
| 部署形态 | App 内置 Go host，跑在 `127.0.0.1`；NAS/Docker 仅作为可选远程模式 |
| 发现页 | 当前保留 UI 空壳；后续 AppBar 图标 + 弹窗切平台，展示两平台通用 section |
| 洛雪 LX | 保留，作为用户可选的 fallback 解析器 |
| 许可证 | host 模块 AGPL-3.0；Flutter/Rust 主应用保持 MIT |

---

## 1. 当前状态（2026-11-27）

`main` 已完成旧网易云清理：

- 删除 `laetibeat_netease` crate、FRB `api/netease.rs`、生成绑定。
- 删除网易云页面、provider、设置、Cookie 存储、封面缓存、HTTPS 代理。
- 删除发现页的网易云六卡与动态区块，只保留 UI 骨架（卡片占位 + 推荐占位 + “在线音源正在接入中”）。
- 删除搜索页网易云筛选与结果、媒体库在线分组、设置页在线音乐入口。
- `flutter analyze`：0 error；`flutter test`：14 passed；`cargo test --workspace`：通过。
- 旧实现保存在 `api` 分支。
- M1 已完成：Rust 客户端、设置页、搜索/播放/歌词、music-lib 网易云搜索修复。
- M2 已完成：发现页 AppBar 平台选择、推荐歌单/排行榜/热门歌曲、平台持久化。
- M3 已完成：网易云 / QQ / 微信扫码登录、host `cookies.json`、账号状态与退出、发现页「我的歌单」。
- M4 已完成：Android arm64 / Linux x64 内置 host、自动启动/健康检查/异常重启/父进程退出清理、内置/远程模式切换。

Android 真机已验证：内置 host 启动、DNS、网易云/QQ 搜索、发现页内容、播放、kill 后自动重启、force-stop 后 host 退出。

---

## 2. 目标架构

```text
Flutter UI
  ├─ 发现页（UI 骨架，后续 AppBar 平台选择）
  ├─ 搜索/媒体库（后续接入在线结果）
  └─ 播放器（本地 / Subsonic / LX / 在线）
        │ FRB
Rust laetibeat_online
  ├─ http.rs        HTTPS-only 客户端 + redirect policy
  ├─ musicapi.rs    /api/v1/* 统一客户端
  ├─ dto.rs         UiTrack / UiPlaylist / ResolvedAudio
  └─ error.rs       类型化错误
        │ HTTP（内置 loopback / 远程 HTTPS）
laetibeat_musicapi_host（Go，AGPL-3.0）
  ├─ main.go        listen / token / data dir
  ├─ bearer.go      Bearer 鉴权 + 路由屏蔽
  └─ go-music-api   router.SetupRouter()
        └─ music-lib（网易云 / QQ / ...）
```

**没有 overlay，没有网易云专用 Go 路由，没有旧 Node API 形状。**

---

## 3. Host 设计

### 3.1 零 fork

```go
import (
    "github.com/guohuiyuan/go-music-api/router"
    "github.com/guohuiyuan/go-music-api/service"
)

service.CM.Load()
engine := router.SetupRouter()
```

- 上游源码不改，不复制到 `reference/` 之外。
- `go.mod` 固定版本（当前 `v1.0.2`），提交 `go.sum`。
- 上游升级只 bump 版本；若导出 API 变化，只改 host 的 `main.go`（约 40 行）。

### 3.2 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `LAETIBEAT_MUSICAPI_ADDR` | `127.0.0.1:0` | 监听地址；远程部署可 `0.0.0.0:8080` |
| `LAETIBEAT_MUSICAPI_TOKEN` | 空 | Bearer token；内置/远程都建议设置 |
| `LAETIBEAT_MUSICAPI_DATA_DIR` | 当前目录 | `cookies.json` 等写入目录 |
| `GIN_MODE` | `release` | 由 host 设置默认值 |

### 3.3 安全加固（host 外层，不改上游）

默认屏蔽：

| 路由 | 原因 |
|---|---|
| `GET /api/v1/music/cover` | 接收任意 URL，SSRF |
| `GET /music/download_cover` | 同上 |
| `GET /api/v1/system/cookies` | 返回明文 Cookie |
| `GET /music/cookies` | 同上 |
| `/swagger/*` | 暴露接口结构 |
| `/music/*` 其余兼容路由 | App 不使用，减少攻击面 |

其他：

- 所有保留路由要求 `Authorization: Bearer <token>`，常量时间比较。
- 移除上游 `Access-Control-Allow-Origin: *`；原生 App 不需要 CORS。
- 请求体大小限制、读写超时、上游请求超时。
- 日志只记录 method/path/status/耗时，不记录 query、Cookie、音频 URL。
- 出站只访问固定平台域名，拒绝非 HTTPS 重定向。
- `cookies.json` 目录 0700、文件 0600。

### 3.4 构建

```bash
# Linux
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -trimpath -ldflags '-s -w' -o laetibeat_musicapi_host .

# Android arm64（必须 CGO + NDK：Android 上纯 Go DNS 不可用）
NDK=$ANDROID_SDK/ndk/28.2.13676358
CC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang
CGO_ENABLED=1 GOOS=android GOARCH=arm64 CC=$CC \
  go build -buildmode=pie -trimpath -ldflags '-s -w' \
  -o android/app/src/main/jniLibs/arm64-v8a/liblaetibeat_musicapi.so .
```

Android 打包条件：

- 命名 `liblaetibeat_musicapi.so`；
- `android:extractNativeLibs="true"`；
- `packaging { jniLibs { useLegacyPackaging = true } }`；
- 运行时从 `applicationInfo.nativeLibraryDir` 执行；
- NDK 28 默认 16KB 对齐，满足 Android 16。

体积：约 +34MB/ABI（arm64 74→~108MB，armv7 68→~102MB）。x86_64 可只在本地构建。

### 3.5 进程生命周期

- 内置模式：App 启动后按需启动 host，`127.0.0.1:0` 随机端口，读取 stdout 的 `LAETIBEAT_MUSICAPI_LISTEN=...`，健康检查 `/api/v1/music/qualities?source=netease`。
- 崩溃指数退避重启（1s/2s/4s，最多 3 次）。
- App 退出时 kill。
- 远程模式：设置页填写 HTTPS Base URL + token；host 部署在 NAS/VPS，必须 HTTPS 反代。

---

## 4. 网易云搜索的前提修复

纯 go-music-api 下，网易云搜索是唯一阻塞项：

- 上游 `music-lib/netease.cloudSearch` 使用 `linux/forward`，实测返回 **HTTP 502**。
- 已实测 `weapi /weapi/cloudsearch/pc` 正常。
- 已采用**单函数本地 fork**：`laetibeat_musicapi_host/third_party/music-lib/netease/netease.go` 的 `cloudSearch` 改为 `EncryptWeApi` + `POST https://music.163.com/weapi/cloudsearch/pc`；host `go.mod` 使用 `replace` 指到该目录。
- 其余 `music-lib` 代码不变；`third_party/music-lib/PATCH.md` 记录唯一改动。

删除路径：上游修复后，删除 `third_party/music-lib` 和 `replace`，bump `music-lib` 版本即可。

这不是 overlay，是修 `go-music-api` 的 provider bug。

---

## 5. Rust 客户端

### 5.1 Crate

```text
laetibeat_online/
├── Cargo.toml
└── src/
    ├── lib.rs
    ├── http.rs       strict_https_client / loopback_client
    ├── error.rs      OnlineError
    ├── model.rs      TrackRef / ResolvedAudio / Capability
    └── musicapi.rs   上游 /api/v1/*
```

FRB 门面：`laetibeat_flutter/rust/src/api/online.rs`。

### 5.2 HTTPS 策略

- 远程模式：只允许 `https://`；`https_only(true)`；redirect 最多 5 跳，禁止 `https → http`，禁止跳到非配置 host。
- 内置模式：只允许 `http://127.0.0.1:<port>`；同样校验 redirect，只允许 loopback。
- TLS：`rustls` + `rustls-platform-verifier`。
- 配置层拒绝 userinfo、空 host、非 http(s)。

### 5.3 统一模型

```rust
pub struct TrackRef {
    pub source: String, // netease / qq
    pub id: String,
    pub extra: BTreeMap<String, String>,
}

pub struct ResolvedAudio {
    pub url: String,
    pub quality: String,
    pub ext: String,
    pub headers: BTreeMap<String, String>,
    pub is_preview: bool,
}

pub struct Capability {
    pub search: bool,
    pub playlist_recommend: bool,
    pub playlist_category: bool,
    pub user_playlists: bool,
    pub ranking: bool,
    pub album_detail: bool,
    pub lyric: bool,
    pub qr_login: bool,
}
```

曲目身份：

- `id = "<source>:<platformId>"`；
- `source = "netease" | "qq"`；
- `sourceId = "musicapi:remote:<host>" | "musicapi:embedded"`；
- `sourceExtraJson` 保存上游 `extra`、`album_id`、`size`、`bitrate`。
- 网易云旧数据 `netease:<songId>` 与上游 songId 一致，历史队列/统计兼容。

### 5.4 错误

```rust
pub enum OnlineError {
    NotConfigured,
    AuthRequired,
    Unsupported,
    PreviewOnly,
    Unavailable(String),
    Upstream(String),
    Network(String),
    Tls(String),
    Timeout,
}
```

`AuthRequired` 不进入 LX fallback；`PreviewOnly` / `Unavailable` 可按设置进入。

---

## 6. Flutter 设计

### 6.1 发现页（当前空壳，后续平台选择）

- 当前：保留 AppBar + 卡片骨架 + 推荐占位，不请求任何数据。
- 后续：
  - AppBar `actionsBuilder` 增加平台切换 icon。
  - `M3EDialog.showSelectionScreen` 选项：`网易云音乐`、`QQ 音乐`（带登录状态）。
  - 选择持久化 `discover.platform`。
  - 两平台使用同一套通用 section：
    - 推荐歌单
    - 排行榜
    - 热门歌曲
    - 我的歌单（登录后）
  - 网易云没有日推/FM/雷达/首页 block；QQ 也没有，因此不再保留这些专属 UI。
- 每次只显示一个平台；后续如需“全部平台同时显示”，再扩展。

### 6.2 搜索页

- 当前：`MobileSearchSourceFilter { all, local, subsonic, lx }`。
- 后续增加 `netease`、`qq`（或统一 `online` + 二级平台选择）。
- 上游搜索每个平台固定 10 条；**不做假分页**。
- 真分页只用于上游支持 `page/limit` 的接口（我的歌单、分类歌单）。
- 并发上限 3，输入防抖 400–500ms，结果缓存 5–10 分钟。
- 结果行显示来源 badge。

### 6.3 媒体库

- 当前：只保留本地/私服入口。
- 后续在线分组重新加回：
  - 网易云音乐：我的歌单、推荐歌单、排行榜、热门
  - QQ 音乐：我的歌单、推荐歌单、排行榜、热门
- 不再有艺人、收藏、日推、专辑订阅等网易云专属入口。

### 6.4 播放

`PlayerNotifier._resolveTrack` 增加在线分支：

```dart
if (t.source == 'netease' || t.source == 'qq') {
  final resolved = await rust_online.resolveAudio(
    baseUrl: onlineBaseUrl,
    token: onlineToken,
    source: t.source,
    id: onlineTrackId(t),
    quality: preferredQuality,
  );
  return PlaybackTrack(
    uri: resolved.url,
    headers: resolved.headers,
    fallbackDuration: _durationOf(t),
    enforceHttps: true,
  );
}
```

- `PlaybackTrack` 重新加入 `headers` / `enforceHttps`（本轮清理时暂时删除）。
- 在线音频经 loopback HTTPS-only 转发器播放；`http://` 升级为 `https://`，拒绝降级。
- 需要 Referer/UA 的平台通过 `headers` 传入。

### 6.5 LX fallback

保留现有 `allowLxFallback` 开关：

- `netease` → `wy`
- `qq` → `tx`

触发条件：无 URL、试听、`Unavailable`、上游错误；`AuthRequired` 不触发。

QQ 的 `extra` 只有 `songmid` 和 `song_id`；先按 `songmid` 尝试 LX `tx`，失败则正常报错。需要真机验证。

### 6.6 设置

重新加回「在线音乐」入口：

| 项 | 说明 |
|---|---|
| 模式 | 内置服务 / 远程服务 |
| 远程地址 | 必须 `https://` |
| Token | 安全存储 |
| 服务状态 | 运行中 / 已停止 / 重启 |
| 网易云登录 | 扫码；Cookie 由 host 保存 |
| QQ 登录 | QQ 扫码 / 微信扫码；Cookie 由 host 保存 |
| LX 后备 | 保留现有开关 |
| 默认音质 | 保留 |

---

## 7. Cookie 与登录

- 网易云和 QQ 的 Cookie 都由 host 管理，存 `cookies.json`。
- 扫码登录走上游 `/api/v1/system/qr_login/:source`，成功后 host 自动写入。
- 客户端不再保存网易云 Cookie；`flutter_secure_storage` 只存 host token（可选）。
- 新增只读状态接口（host 外层）+ 路由：
  ```json
  GET /laetibeat/system/platforms
  [
    {"source":"netease","has_cookie":true},
    {"source":"qq","has_cookie":false}
  ]
  ```
  只返回布尔值，不返回 Cookie。
- 内置模式：每设备一份 Cookie；远程模式：每服务一份，单用户假设。

---

## 8. 功能取舍（已确认）

### 保留

- 搜索歌曲/歌单/专辑
- 推荐歌单、分类歌单
- 排行榜、热门歌曲
- 我的歌单
- 歌单详情、专辑详情
- 播放直链、音质
- 普通 LRC 歌词
- 扫码登录
- LX fallback

### 移除

- 每日推荐
- 私人 FM
- 雷达歌单
- 心动模式
- 相似歌曲
- 「根据你喜爱的歌曲推荐」
- 发现页动态区块
- 艺人搜索/详情/热门/专辑
- 收藏艺人/收藏专辑
- 歌词翻译/逐字

这些能力如果以后需要，应优先推动 `go-music-api` 上游增加，而不是在 App 内做兼容层。

---

## 9. 安全模型

| 风险 | 措施 |
|---|---|
| SSRF | 禁用 `music/cover`、`music/download_cover`；App 直接 HTTPS 下载封面 |
| Cookie 泄露 | 禁用 `GET /system/cookies`、`/music/cookies`；只提供布尔状态 |
| 未授权访问 | 随机 Bearer token；常量时间比较；内置只绑 loopback |
| 远程暴露 | 必须 HTTPS 反代 + token + 限流；禁止直接明文 `0.0.0.0` |
| CORS | 移除上游通配 CORS |
| Swagger | 生产禁用 |
| 日志 | 脱敏，不记录 Cookie/query/音频 URL |
| 体积/资源 | 请求体上限、超时、并发限制 |
| 供应链 | 固定版本 + `go.sum`；发布前 vendor 或镜像 |
| AGPL | host 单独 AGPL-3.0，公开源码与构建产物对应关系 |

---

## 10. 分阶段实施

### M0：Host 骨架（已完成）

- [x] `laetibeat_musicapi_host/` Go module
- [x] `main.go`：addr/token/data dir
- [x] `security.go`：鉴权 + 路由屏蔽 + CORS/日志/请求体限制
- [x] `go.mod`：`go-music-api v1.0.2` + 本地 patched `music-lib`
- [x] Linux 构建、启动、健康检查
- [x] 单元测试：401/200、随机端口、data dir、路由屏蔽

### M1：Rust 客户端 + 核心在线（已完成）

- [x] `laetibeat_online` crate + HTTPS 策略
- [x] search / playlist / album / user playlist / recommend / top / hot / url / lyric / qualities
- [x] 设置页：远程/本机地址、token、测试连接、默认音质、LX 后备
- [x] 网易云搜索 weapi 修复（本地 music-lib fork）
- [x] 搜索页接入网易云/QQ；播放链路 + HTTPS 代理 + LX fallback
- [x] 实机联调：网易云/QQ 搜索、QQ/网易云直链、网易云歌词
- **验收**：两个平台可搜索、播放、看 LRC。

### M2：发现页平台选择（已完成）

- [x] AppBar icon + 平台弹窗（网易云 / QQ）
- [x] 通用 section：推荐歌单、排行榜、热门歌曲
- [x] 选择持久化（`discover.platform`）
- [x] 下拉刷新、分 section 加载/错误/空态
- [ ] 我的歌单：等待 M3 登录后接入（当前显示登录提示）
- **验收**：切换平台后显示对应内容；两平台互不影响。

### M3：登录与 Cookie（已完成）

- [x] 网易云 QR、QQ QR、微信 QR
- [x] host `cookies.json`（数据目录内，重启后恢复）
- [x] `GET /laetibeat/system/platforms` 只返回 `has_cookie`
- [x] `DELETE /laetibeat/system/platforms/{source}` 退出登录
- [x] 设置页账号区：登录 / 退出 / 状态
- [x] 发现页「我的歌单」按登录状态显示
- **验收**：登录后可看我的歌单；重启后仍保持（二维码会话创建/轮询已自动化验证，扫码需人工）。

### M4：内置打包（已完成）

- [x] Android arm64 jniLibs + `extractNativeLibs` + `useLegacyPackaging`
- [x] Gradle 自动调用 NDK clang + CGO 构建 host
- [x] Linux CMake 自动构建并安装 host 到 bundle/lib
- [x] Dart 进程管理：随机端口/token、读 listen 行、健康检查、异常重启、父进程退出清理
- [x] 内置/远程模式切换与运行时地址覆盖
- [x] Android 真机验证 DNS、搜索、发现页、播放、kill 重启、force-stop 清理
- [x] Linux bundle host 二进制启动与健康检查
- **验收**：Android arm64 / Linux x64 无需 NAS/Docker 可完整使用。
- 备注：当前 Gradle 只构建 arm64 host；armv7/x86_64 设备请用远程模式。

### M5：清理与合规

- [ ] 移除远程/内置之外不再需要的兼容代码
- [ ] 更新 `PLAN.md` / `TODO.md` / `ARCHITECTURE.md`
- [ ] `THIRD_PARTY_NOTICES.md` 增加 go-music-api / music-lib
- [ ] 关于页增加 AGPL 源码链接
- [ ] CI 构建 host 矩阵

---

## 11. 测试

### Go host

- Bearer 401/200
- `ADDR=127.0.0.1:0` 返回可用端口
- data dir 生成 `cookies.json`
- 被屏蔽路由返回 404/403
- 健康检查

### Rust

- `https_only` 拒绝 http 远程地址
- redirect `https → http` 被拒绝
- loopback client 只允许 127.0.0.1
- DTO 映射、ID 兼容
- 错误分类

### Flutter

- 设置页 URL/token 校验
- host 未启动/失败错误态
- 搜索来源过滤
- LX fallback 触发
- 发现页平台切换与空态

### 真机

- Android 内置 host 冷启动、后台、杀进程重启
- Linux bundle 启动
- 远程 HTTPS + token
- 网易云/QQ 搜索、播放、登录

---

## 12. 风险

| 风险 | 影响 | 缓解 |
|---|---|---|
| 网易云搜索 bug | 搜索不可用 | music-lib weapi PR/fork |
| 网易云/QQ 风控 | 播放/搜索失败 | 10 条默认、缓存、退避、LX fallback |
| QQ 部分歌曲需登录 | 播放失败 | 登录提示 + LX fallback |
| QQ LX fallback 字段不足 | fallback 失败 | 先按 songmid 尝试，失败明确报错 |
| Android DNS | 内置 host 无法联网 | NDK + CGO 构建 |
| Android 不抽取 .so | exec 失败 | useLegacyPackaging + extractNativeLibs |
| 体积 +34MB/ABI | 安装包变大 | 只发 arm64/armv7；x86_64 可选 |
| iOS | 无法内置 | 远程模式 |
| 远程单账号 | 多用户串号 | 文档明确单用户 |

---

## 13. 已验证事实

```text
# 零 fork host
go build → 33MB
LAETIBEAT_MUSICAPI_ADDR=127.0.0.1:0 → 127.0.0.1:40319
无 token /system/cookies → 401

# Android cgo
CGO_ENABLED=1 GOOS=android GOARCH=arm64 CC=NDK/.../aarch64-linux-android24-clang
→ PIE, interpreter /system/bin/linker64, LOAD Align 0x4000, 34MB

# 纯 go-music-api 网易云能力
/playlist/recommend?sources=netease   200
/playlist/categories?sources=netease  200
/ranking/toplists?sources=netease     200
/ranking/hot?source=netease           200
/playlist/detail?source=netease       200
/album/detail?source=netease          200
/music/lyric?source=netease           200
/playlist/user?source=netease         401（需要 Cookie）
/music/search?sources=netease         空（需要修 music-lib）

# QQ
/playlist/recommend?sources=qq        200（匿名）
/ranking/toplists?sources=qq          200（匿名）
/ranking/hot?source=qq                200（匿名）
/playlist/user?source=qq              401（需要 Cookie）
/music/url?source=qq&quality=standard 部分歌曲 200；VIP 失败

# weapi 搜索修复验证
/weapi/cloudsearch/pc                 200，返回 result.songs
```

---

## 14. 待确认

1. 发现页默认平台：记住上次选择；首次默认网易云。
2. 两个平台都未登录时，发现页显示匿名 section（推荐/榜单/热门）还是登录提示？
3. QQ 登录方式是否同时提供 QQ 扫码和微信扫码？
4. 远程模式是否继续保留？如果保留，是否接受“必须 HTTPS + token”的硬性要求？
5. 是否接受搜索每平台固定 10 条、不做假分页？
