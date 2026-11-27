# Laetibeat 多音源计划

> 状态：网易云 Node API Provider、在线媒体库核心、LX `wy` 后备及网易云音源 HTTPS-only 播放已实施；本计划记录现状与剩余验证。
> 最后更新：2026-11-27
> 关联文档：`TODO.md`（工程债与修复排期）、`reference/MeloX-Android/`（多音源架构参考）

## 目标

1. 将洛雪从“顶层音源提供者”降级为“网易云曲目的后备播放解析器”。
2. 新增网易云音乐作为正式在线 Provider，首版通过用户可配置的 Node API 后端接入。
3. 用户可关闭洛雪后备，只走网易云直连（需要用户自己的网易云会员）。
4. fallback 不改变曲目身份；统计、歌单、队列仍属于网易云曲目。
5. 保持本地音乐、OpenSubsonic、LX 旧曲目兼容。
6. 首版不移植 Rust 内置网易云客户端；保留 `NetEaseBackend` 抽象，后续可替换为 Rust 直连。

---

## 一、Laetibeat 当前结论

> 当前已实现用户配置 Node API 的网易云 Provider、在线媒体库核心及可选 LX `wy` 后备；Rust 内置直连仍暂缓。网易云音频流使用独立 HTTPS-only 本机转发器，和全局网络策略分开，不影响其他来源。

### 已具备

- [x] `laetibeat_lx::LxSourceManager::resolve_music_url(source, info, quality)` 已是独立 URL 解析器，不要求曲目来源为 LX。
- [x] 已有 LX 候选源、优先级、启停、质量阶梯、URL 缓存和 `ensurePlayable("wy")` 能力。
- [x] 已有网易云 `wy` 的搜索、歌单、歌词实现：`search.rs` / `songlist.rs` / `lyric.rs`。
- [x] `UiTrack` 的 `source/sourceId/id/coverId/sourceExtraJson` 足以承载网易云曲目。
- [x] 播放后端只消费 URL，解析层改造不需要改音频引擎。
- [x] `laetibeat_netease` 提供用户配置 Node API 的连接、二维码登录态、搜索、歌单、歌词、详情和播放 URL。
- [x] 网易云搜索、在线歌单、每日推荐、收藏艺人/专辑及详情已接入 Flutter；网易云曲目保留自身身份。
- [x] 网易云曲目可选 LX `wy` 后备，后备不改变队列和统计中的曲目身份。
- [x] Android `just_audio` 与桌面 `media_kit` 的网易云播放源均可经 HTTPS-only 转发器播放；HTTP 音源升级到 HTTPS，HTTP 降级重定向会被拒绝。

### 当前缺口

- [ ] 播放解析仍以内联来源分支实现，尚未提取统一的 `ResolveRequest` / `ResolveResult` 类型。
- [ ] Node API 可选 Token、自助配置安全校验等能力仍需单独核对；Rust 内置网易云直连继续暂缓。
- [ ] Android 实测已验证一条试听流 HTTPS 返回 200；完整非试听音源、不同 CDN 和桌面 `media_kit` 仍待验证。
- [ ] 网易云音频 HTTPS-only 不代表 App 全部网络都强制 HTTPS；API、图片及其他音源继续遵循各自现有配置。

### 建议目标模型

- 曲目身份：`provider = local | opensubsonic | netease`，`providerId` 为目录/服务器/账号 id，`trackId` 为本地相对路径/Subsonic id/网易云 songId。
- 播放解析：独立的 `ResolveRequest` / `ResolveResult`；结果包含 `url`、`resolvedBy`、`quality`、`expiresAt`、`headers`。
- fallback 不改变曲目身份；通过 LX 播放时统计仍记在网易云曲目上。
- 网易云曲目转为 `lxMusicInfo` 时显式传平台 `wy`；不要继续复用 `track.sourceId` 当平台。

### 播放决策

1. `NetEaseDirectResolver`：使用用户 Cookie/API/SDK 获取直链。
2. 失败且 `allowLxFallback = true`：调用 `LxFallbackResolver(platform = "wy")`。
3. 再失败：提示登录网易云 / 开启洛雪后备 / 重试。
4. 用户关闭洛雪后备时只走直连。

### 待决策

- [x] 网易云首版采用用户可配置的第三方 Node API（Vercel / VPS / NAS）；官方 SDK/OpenAPI 暂缓。
- [x] 首版不移植 Rust 内置网易云客户端；保留 `NetEaseBackend` 抽象。
- [x] 已从搜索 + 播放扩展到在线媒体库核心；更广泛的云端能力仍分阶段添加。
- [ ] LX 完全移出音源列表，还是保留独立 LX 搜索入口？
- [x] LX 后备通过用户设置 `allowLxFallback` 控制。
- [x] 试听或无播放 URL 时按设置尝试 LX `wy` 后备；未启用/后备失败时保留网易云试听或显示错误。

### 风险

- [ ] 洛雪后备不保证 VIP/版权歌曲或高音质可用。
- [ ] 第三方网易云 API/SDK 的稳定性、合规性和会员能力需单独验证。
- [ ] 直链可能需要 headers；iOS ATS 可能拦截 http 直链。
- [ ] 统计/scrobble 若按解析器而非曲目身份记录，会污染数据。
- [ ] LX 现有 P0-3 候选源退化、P0-4 Context 串扰会直接影响 fallback 可靠性。

---

## 二、网易云 API 部署形态决策（2026-11-25）

> 已确定：首版不移植 Rust 内置网易云客户端；先使用用户可配置的 Node API 后端。Vercel / VPS / NAS 都只是部署位置，App 只认一个 HTTPS Base URL。

### 2.1 决定的架构

```text
Laetibeat
  └─ 网易云 API Base URL（用户配置）
        ├─ Vercel
        ├─ 自己的 VPS
        └─ 自己的 NAS + 域名 / Cloudflare Tunnel
```

请求链路：

- 登录、搜索、歌单、歌词、播放 URL：手机 → 用户配置的 Node API → 网易云。
- 网易云音频流：播放器 → `127.0.0.1` 本机 HTTPS-only 转发器 → 网易云 CDN；源 URL 会升级为 HTTPS，任何 HTTPS→HTTP 重定向都会被拒绝。音频仍不经过 Node API。
- 本机播放器到 loopback 转发器使用 HTTP；loopback 只绑定 `127.0.0.1`，音源到公网 CDN 的请求严格使用 HTTPS。
- 其他 Provider 的音源不经过该转发器，行为保持不变。
- 网易云看到的出口 IP 是 Node API 所在主机的 IP，不是手机 IP，也不是域名本身。
- 自定义域名只是入口；Vercel 的自定义域名不会改变 Vercel 出口 IP，NAS 的域名不会改变家庭宽带出口 IP。

### 2.2 支持的部署形态

| 部署 | 入口 | 网易云出口 IP | 说明 |
|---|---|---|---|
| Vercel | `*.vercel.app` / 自定义域名 | Vercel 出口 IP | 最省事；可能需要 `realIP` / `randomCNIP`，存在共享 IP/频率问题 |
| VPS | 自定义域名 | VPS 固定 IP | 稳定、可控；需要维护和 HTTPS |
| NAS + 公网 IPv4 | 域名 + 端口转发 | 家庭公网 IP | 隐私好；需要 DDNS、HTTPS、端口转发 |
| NAS + IPv6 | AAAA 域名 | 家庭 IPv6 | 部分手机网络没有 IPv6 |
| NAS + Cloudflare Tunnel | 自定义域名 | 家庭公网 IP | 无需公网 IP；入站走 Cloudflare，出站仍从 NAS 发出 |
| 本地 Docker | 局域网地址 | 局域网出口 | 仅同网使用；移动端建议 HTTPS |

补充：

- Vercel 默认不保证独立静态出口 IP；不同项目也可能共享出口 IP 池。
- NAS 家庭宽带可能是动态 IP、CGNAT 或没有公网 IPv4，需要 DDNS 或 Tunnel。
- VPS 固定 IP 通常比 Vercel/NAS 更可控，但仍有成本。
- 音频不经过 Node API，所以 NAS 上行带宽不是主要瓶颈。

### 2.3 App 侧配置

- [ ] `baseUrl`：用户填写，必须 HTTPS。
- [ ] `apiToken`：可选，自定义 Header。
- [ ] 测试连接。
- [ ] 二维码 / 短信登录。
- [ ] Cookie 存 `flutter_secure_storage`，不要上传到第三方。
- [ ] Cookie 优先放 POST body，不要放 URL query。
- [ ] 禁止跟随到非配置域名的重定向。
- [ ] `allowLxFallback` 开关。
- [ ] 失败提示：检查 API 地址 / 登录状态 / 洛雪后备。

Node API 参考文档：`reference/neteaseapi.md`。

### 2.4 安全与运维

- [ ] 公网暴露必须有访问令牌 / 反向代理鉴权 / 限流。
- [ ] 全 App 所有外部网络请求强制 HTTPS（本轮只为网易云音频流实施 HTTPS-only）。
- [ ] 不暴露 NAS 管理后台。
- [ ] Node API 容器隔离、非 root 运行。
- [ ] Node API 镜像版本与 App 兼容检查。
- [ ] 不记录 Cookie、完整请求 URL 或账号敏感信息。
- [ ] 配置 API 地址时提示：只填写自己信任的服务。

### 2.5 频率与风控

- 每用户独立实例可以避免“多人共用一个 Vercel”的共享压力。
- 但网易云仍按账号、Cookie、出口 IP、地区、登录频率做风控。
- Vercel 出口 IP 可能共享；NAS 家庭 IP 可能动态或 CGNAT；VPS 固定 IP 更可控。
- 仍需客户端缓存、请求退避、避免重复登录、播放 URL 过期后重新解析。
- Vercel 可能需要 `realIP` / `randomCNIP`；NAS/VPS 在国内通常不需要，但要实测。

### 2.6 暂不做

- [ ] Rust 内置网易云直连（暂缓）。
- [ ] 官方 SDK/OpenAPI 接入（暂缓）。
- [ ] `unblock` / `song/url/match` 灰色歌曲解锁（默认不做）。
- [ ] 云盘、评论、动态、播客、MV、电台等非核心接口。

---

## 三、MeloX-Android 调研结论

### 项目定位

`reference/MeloX-Android` 是 iOS 第三方播放器 MeloX 的 Android 迁移版，使用 Kotlin + Jetpack Compose + Media3。它不是“接入某个万能音乐 SDK”，而是：

> 自建统一的 Provider / Capability 抽象层，然后为每个平台分别实现逆向协议客户端；少数平台接入官方或第三方库。

它已经把“网易云作为主音源、LX 脚本作为最后一级 fallback”做成了实际架构。

### 各平台实现方式

| 平台 | 搜索 / 目录 | 登录 | 播放解析 | 实现性质 |
|---|---|---|---|---|
| 网易云音乐 | 自研 `NeteaseSearchClient` / `NeteaseLibraryClient` | WebView Cookie、手机、二维码 | 自研 EAPI `/api/song/enhance/player/url/v1` | 逆向 HTTP API |
| QQ 音乐 | 自研 `QQMusicCatalogClient` / `musicu.fcg` | 扫码 / 手机 | 自研 `music.vkey.GetVkey / UrlGetVkey` | 逆向 HTTP API |
| 酷狗 / 酷狗概念版 | 自研 `KugouRequestClient` / `KugouCatalogClient` | 自研登录客户端 | 签名请求 + 匿名播放 + 公共 tracker | 逆向 HTTP API |
| 酷我音乐 | 自研 `KuwoApiClient` | 手机登录 | 自研 HTTP 播放接口 | 逆向 HTTP API |
| 汽水音乐 | 自研 `QishuiApiClient`，直连 `api.qishui.com` / `luna` | 二维码 | `media-player` / H5 试听 | 逆向 HTTP API |
| Bilibili | 自研 Web API + WBI 签名 | WebView Cookie | `playurl` | 逆向 HTTP API |
| YouTube Music | vendored InnerTube（来自 Metrolist） | WebView Cookie / InnerTube 账号 | NewPipeExtractor | 第三方开源库 + 逆向协议 |
| Spotify | 官方 Spotify Web API | OAuth 2.0 PKCE | `librespot-java` | 官方 API + 第三方播放库 |
| Apple Music | 官方 Apple Music REST API | 官方 MusicKit Authentication AAR | 官方 MusicKit Playback AAR | 官方 SDK / API |
| Jellyfin | 官方 Jellyfin REST API | 服务器账号 | Jellyfin API | 服务器 API |
| 本地音乐 | MediaStore / 文件系统 | 无 | 本地文件 | 系统 API |

### 关键判断

- 网易云、QQ、酷狗、酷我、汽水、Bilibili 都不是官方 SDK，而是自行实现的逆向 HTTP 客户端。
- 不是传统 HTML 爬虫，主要是直接调用平台 JSON API，并自行处理登录 Cookie、签名、加密和请求头。
- Spotify Web API 只有目录/歌单/收藏，不能直接播放；播放依赖 `librespot-java`。
- Apple Music 是真正的官方 MusicKit SDK 路径，播放由官方 DRM 播放器完成，不能导出普通音频 URL。
- YouTube Music 依赖 Third-party 的 InnerTube 与 NewPipeExtractor，不是官方 SDK。
- MeloX 自己的 `plugin-sdk` 是应用级插件系统，不是平台 SDK。
- 登录态只保存在本机，不经过中转服务器。

### 核心架构

- `MusicProvider` 只声明身份与能力。
- 搜索、播放、歌词、歌单、专辑、艺人、收藏等拆成可选 Capability。
- 曲目身份使用 `MusicResourceId(source, value)`，平台特有字段放在 `ProviderTrackMetadata`。
- 播放结果使用 `PlaybackResolution`，区分：
  - `Playable(url, headers, quality, bitrate, format, expiresAt)`
  - `Preview`
  - `LoginRequired`
  - `SubscriptionRequired`
  - `RegionRestricted`
  - `CopyrightRestricted`
  - `Unavailable(reason)`

### 播放 fallback 顺序

```text
1. 当前音源自己的 Provider
2. 内置跨平台严格匹配（可选，默认关闭）
3. 第三方解析器（可选，需协议确认）
```

第三阶段顺序：

```text
Meting → CHKSZ → UNM → resolver 插件 → LX 脚本
```

规则：

- 默认一次只使用用户选择的一个音源。
- 跨平台 fallback 默认关闭，必须用户显式开启。
- 只有会员/版权/地区/无音源才进入对应 fallback。
- `LoginRequired` 不会进入 fallback，因为这是账号级问题。
- 只接受完整音频，预览/试听不算。
- 跨平台匹配必须通过标题、歌手、时长校验。
- 当前音源失败后会跳过同一平台，避免重复请求。
- 顺序按配置逐个尝试，不做并行竞速。
- 返回结果保留 headers 和 URL 过期时间。

### LX 如何作为后备

`LxUserPlaybackResolver` 接收来自其他 Provider 的 `MusicTrack`，并映射平台：

```text
Netease   -> wy
QQMusic   -> tx
Kugou     -> kg
KugouLite -> kg
Kuwo      -> kw
```

`buildLxMusicInfo()` 会构造 LX 脚本需要的扁平 `musicInfo`，包括：

- 通用字段：`name`、`singer`、`source`、`songmid`、`interval`、`albumName`、`img`、`types`、`_types`
- QQ：`songId`、`strMediaMid`、`albumMid`
- 酷狗：`hash`、`albumId`
- 酷我：`songId`

这说明：

- LX 是最后一级 resolver，不是主 Provider。
- LX 解析不会改变原曲目来源。
- 跨平台匹配需要目标平台自己的 ID，不能把网易云 ID 直接当 QQ `songmid`。
- 对“网易云曲目 → LX `wy`”这个目标，因为两边都是网易云 songId，可以跳过跨平台搜索匹配，直接走 `wy`。

### 对 Laetibeat 的启示

#### 应借鉴

1. Provider 与 Resolver 分离。
2. `source + id` 命名空间，不再让 `sourceId` 承担过多语义。
3. 播放结果携带 headers、expiry、quality 和错误类型。
4. 默认关闭 fallback；用户显式开启。
5. LX 放在 fallback 最后一级，不作为主音源。
6. fallback 不改变曲目身份，统计/歌单/队列仍按原 Provider 记录。
7. 登录态只保存本机，不引入中转服务器。
8. 用 Capability 隐藏平台不支持的功能，不伪造数据。

#### 不直接照搬

- MeloX-Android 是 GPLv3；直接复制代码会影响 Laetibeat 的许可证选择。
- 网易云/QQ/酷狗等逆向协议客户端维护成本很高，接口和签名会变化。
- Apple Music 依赖官方 MusicKit 原生 SDK 和 DRM，不适合 URL-only 播放架构。
- MeloX 的完整插件系统、跨平台严格匹配和远程配置体系，超出当前 MVP 范围。

---

## 四、推荐实施阶段

### Phase 0：验证网易云 → LX `wy` 可行性

- [ ] 用现有 `search_wy` 结果构造 `LxMusicInfo`。
- [ ] 直接调用 `resolve_lx_music_url(source: "wy")`。
- [ ] 验证 songId、extra、headers、免费歌曲与 VIP 歌曲行为。
- [ ] 验证返回 URL 是否需要 Referer/User-Agent/Cookie。

### Phase 1：抽 Resolver 链，LX 降级为后备

- [ ] 新增 `ResolveRequest` / `ResolveResult`。
- [ ] 把 local / opensubsonic / lx 分支迁入 Resolver。
- [ ] 增加 `allowLxFallback` 设置。
- [ ] 增加 `lxPlatformForTrack()` 适配。
- [ ] 修 P0-3（候选源退化）和 P0-4（Context 串扰）。
- [ ] 先不接网易云直连，用测试曲目验证 fallback。

### Phase 2A：网易云 Node API Provider（首版，主体已实施）

- [x] 增加网易云 API 服务配置：Base URL、测试连接；可选 Token 仍待实现。
- [x] 支持用户配置的 Vercel / VPS / NAS 地址；App 通过 Base URL 连接。
- [x] 二维码登录与 `flutter_secure_storage` Cookie 存储；短信登录仍待验证修复。
- [x] 接入搜索、歌曲详情、歌单、每日推荐、歌词、`/song/url/v1`。
- [x] 解析音质、试听与 URL 有效期；按需携带的额外媒体 headers 仍待核实。
- [ ] 错误分类：登录 / 会员 / 版权 / 地区 / 无音源 / 网络。
- [x] 串联网易云播放解析与可选 LX `wy` fallback；当前逻辑位于 `PlayerNotifier`，尚未抽成独立 Resolver 类型。
- [ ] 客户端缓存、请求退避、避免重复登录；不在 URL 中携带 Cookie。

### Phase 2A.1：网易云音源 HTTPS-only（已实施）

- [x] 仅网易云直连和网易云曲目的 LX `wy` 后备音源经过 loopback HTTPS-only 转发器。
- [x] `http://` 音源升级到 HTTPS；只跟随 HTTPS 重定向，拒绝 HTTPS 降级到 HTTP。
- [x] Android / 桌面播放后端接入；其他音源不经过代理。
- [x] Pixel 7 Debug 样例：音频 CDN HTTPS 请求返回 200；单元测试和静态分析通过。
- [ ] 完整非试听歌曲与桌面 `media_kit` 真机验证。
- [ ] 全 App 外部请求统一 HTTPS 不属于本阶段；API、图片和其他 Provider 需分别评估。

### Phase 2B：Rust 内置直连（暂缓）

- [ ] 定义 `NetEaseBackend` 接口，支持 `RemoteNodeBackend` / `NativeRustBackend` 切换。
- [ ] Node API 稳定后，再评估把核心接口移植进 Rust。
- [ ] 不移植 200+ 接口，只移植核心 8～12 个。

### Phase 3：网易云完整在线库

- [x] 搜索、在线歌单、每日推荐、收藏艺人/专辑及专辑/艺人详情核心流程。
- [ ] 排行榜、听歌报告、网易云统计/scrobble 等扩展能力。
- [ ] 再决定是否把 LX 从 `SongSources` 移出，或保留独立 LX 搜索入口。

---

## 五、参考文件

- `reference/neteaseapi.md`（网易云 Node API Enhanced 文档；部署在 Vercel/VPS/NAS 的后端）
- `reference/MeloX-Android/docs/multi-provider-architecture.md`
- `reference/MeloX-Android/docs/PLAYBACK-FALLBACK.md`
- `reference/MeloX-Android/docs/THIRD-PARTY-RESOLVERS.md`
- `reference/MeloX-Android/android/app/src/main/kotlin/com/lladlam/melox/core/music/provider/MusicProvider.kt`
- `reference/MeloX-Android/android/app/src/main/kotlin/com/lladlam/melox/playback/PlaybackFallbackChain.kt`
- `reference/MeloX-Android/android/app/src/main/kotlin/com/lladlam/melox/playback/LxUserPlaybackResolver.kt`
- `reference/MeloX-Android/android/app/src/main/kotlin/com/lladlam/melox/core/provider/lxuser/LxUserScriptContract.kt`
- `reference/MeloX-Android/android/app/src/main/kotlin/com/lladlam/melox/core/audio/NeteaseQualityClient.kt`
- `reference/MeloX-Android/android/app/src/main/kotlin/com/lladlam/melox/core/provider/qqmusic/QQMusicPlaybackVkeyClient.kt`
- `reference/MeloX-Android/android/app/src/main/kotlin/com/lladlam/melox/core/provider/kugou/KugouRequestClient.kt`
- `reference/MeloX-Android/android/app/src/main/kotlin/com/lladlam/melox/core/provider/spotify/SpotifyLibrespotPlayback.kt`
- `reference/MeloX-Android/android/app/src/main/kotlin/com/lladlam/melox/core/provider/youtubemusic/YouTubeMusicProvider.kt`

---

## 六、一句话结论

**Laetibeat 已通过用户可配置的 Node API 接入网易云，并实现在线媒体库核心及可选 LX `wy` 后备；网易云音源播放额外使用 HTTPS-only 转发，阻止音源 URL 或重定向降级为 HTTP。下一步优先验证完整音源与桌面播放，再按需扩展云端能力；Rust 内置直连仍暂缓。**
