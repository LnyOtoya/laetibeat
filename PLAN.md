# Laetibeat 多音源计划

> 状态：规划中，尚未实施
> 最后更新：2026-11-25
> 关联文档：`TODO.md`（工程债与修复排期）、`reference/MeloX-Android/`（多音源架构参考）

## 目标

1. 将洛雪从“顶层音源提供者”降级为“网易云曲目的后备播放解析器”。
2. 新增网易云音乐作为正式在线 Provider。
3. 用户可关闭洛雪后备，只走网易云直连（需要用户自己的网易云会员）。
4. fallback 不改变曲目身份；统计、歌单、队列仍属于网易云曲目。
5. 保持本地音乐、OpenSubsonic、LX 旧曲目兼容。

---

## 一、Laetibeat 当前结论

> 路线技术可行，但要拆成“音源提供者”和“播放解析器”两层。LX 后端已具备作为后备解析器的基础；网易云直连 Provider 尚未实现；当前 UI/模型仍把 LX 当顶层音源，需要中等规模重构。

### 已具备

- [x] `laetibeat_lx::LxSourceManager::resolve_music_url(source, info, quality)` 已是独立 URL 解析器，不要求曲目来源为 LX。
- [x] 已有 LX 候选源、优先级、启停、质量阶梯、URL 缓存和 `ensurePlayable("wy")` 能力。
- [x] 已有网易云 `wy` 的搜索、歌单、歌词实现：`search.rs` / `songlist.rs` / `lyric.rs`。
- [x] `UiTrack` 的 `source/sourceId/id/coverId/sourceExtraJson` 足以承载网易云曲目。
- [x] 播放后端只消费 URL，解析层改造不需要改音频引擎。

### 当前缺口

- [ ] 没有网易云 API/SDK、登录态、直链解析和音源配置。
- [ ] 没有 Resolver 抽象、fallback 链、开关、总超时和错误分类。
- [ ] `source='lx'` 仍同时表示“曲目来源”和“播放解析器”，需要拆开。
- [ ] 封面/歌词/统计只识别 local / opensubsonic / lx，新增 netease 会错走本地。
- [ ] `PlaybackTrack` 没有 headers；网易云直链若需要 Referer/UA/Cookie，需要扩展播放后端。

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

- [ ] 网易云接官方 SDK/OpenAPI，还是第三方 API？
- [ ] 先做搜索 + 播放，还是直接做完整媒体库？
- [ ] LX 完全移出音源列表，还是保留独立 LX 搜索入口？
- [ ] 后备解析是全局开关，还是播放失败时询问？
- [ ] 直连返回低音质/试听 URL 时，直接播放还是继续尝试 LX？

### 风险

- [ ] 洛雪后备不保证 VIP/版权歌曲或高音质可用。
- [ ] 第三方网易云 API/SDK 的稳定性、合规性和会员能力需单独验证。
- [ ] 直链可能需要 headers；iOS ATS 可能拦截 http 直链。
- [ ] 统计/scrobble 若按解析器而非曲目身份记录，会污染数据。
- [ ] LX 现有 P0-3 候选源退化、P0-4 Context 串扰会直接影响 fallback 可靠性。

---

## 二、MeloX-Android 调研结论

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

## 三、推荐实施阶段

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

### Phase 2：网易云直连 Provider

- [ ] Cookie/登录态安全存储。
- [ ] 搜索、歌词、封面、音质。
- [ ] 直连 URL 解析。
- [ ] 错误分类：登录 / 会员 / 版权 / 地区 / 无音源 / 网络。
- [ ] 串联 `NetEaseDirectResolver` + `LxFallbackResolver`。
- [ ] 保留 headers 和 URL 过期时间。

### Phase 3：网易云完整在线库

- [ ] 专辑 / 艺人 / 歌单 / 用户收藏。
- [ ] 搜索过滤、每日推荐、统计、scrobble。
- [ ] 再决定是否把 LX 从 `SongSources` 移出，或保留独立 LX 搜索入口。

---

## 四、参考文件

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

## 五、一句话结论

**MeloX-Android 已证明“网易云作为主音源、LX 作为最后一级后备解析器”可行；但它靠的是大量自研逆向协议客户端，而不是一个万能 SDK。Laetibeat 应借鉴其 Provider/Capability、PlaybackResolution 和 fallback 顺序，先做“网易云直连 + LX `wy` 后备”这个最小闭环。**
