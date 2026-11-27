# Laetibeat 项目蓝图

> 最后更新：2026-11-27
> 当前阶段：native 分支启动。`gomusic` 分支保留 go-music-api 实现；`native` 分支改用 QQMusicApi-rs + ncm-api-rs 的 Rust 原生 sidecar，并做本地 / Subsonic / QQ / 网易云独立模式。
>
> **重要**：本文件下方涉及「网易云 Node API」「`laetibeat_netease`」「网易云 Provider」的条目是历史记录；`main` / `gomusic` 已移除旧 Node 实现。native 分支设计见 `docs/native-modes-migration.md`。

## 2026-11-27 native 分支启动

- [x] 确认 `QQMusicApi-rs` 可作为 Rust sidecar
- [x] 确认 `ncm-api-rs` 可作为 Rust sidecar；Android arm64 编译验证通过
- [x] 新增 `docs/native-modes-migration.md`
- [x] 创建并推送 `gomusic` 分支
- [x] 创建并推送 `native` 分支
- [x] `laetibeat_qq_host` spike（搜索/URL/歌词/QR；真实扫码待验证）
- [x] `laetibeat_netease_host` spike（搜索/URL/歌词/QR；真实扫码待验证）
- [x] `AppMode` 模式控制器
- [x] 模式切换停止服务 / 保留 Cookie
- [x] 搜索 / 发现 / 播放 / 登录按模式切换
- [ ] 首页 / 本地 / Subsonic 页面按模式区分
- [x] Android / Linux 打包两个 Rust host
- [x] CI 增加 Rust host 矩阵
- [x] 删除 go-music-api 与 Go 打包链
- [x] 保留 `laetibeat_online` 作为 native host 统一客户端
- [ ] native 通过 PR 合并回 main
- [ ] 在 main 上发布 v2.0.0（或确认后的版本）

## 2026-11-27 在线音源迁移（gomusic 分支，已完成）

- 架构：Flutter → Rust `laetibeat_online` → 内置/远程 `laetibeat_musicapi_host` → go-music-api + music-lib
- 支持平台：网易云、QQ（搜索、歌单、专辑、榜单、热门、播放、LRC、扫码登录、我的歌单）
- 内置模式：Android / Linux 自动启动 Go host，随机 loopback 端口 + Token；异常重启；父进程退出清理
- 远程模式：HTTPS + Bearer token；loopback 例外
- 网易云搜索：music-lib 本地单函数 fork（linux/forward 已 502，改 weapi）
- 播放：在线直链经 HTTPS-only 本机转发器；支持 LX fallback
- 文档：`docs/musicapi-migration.md`（gomusic 设计/验收）、`docs/native-modes-migration.md`（native 目标）、`PLAN.md`、`THIRD_PARTY_NOTICES.md`（AGPL）
- 旧网易云 Node API 实现保留在 `api` 分支，不再维护
- 发版流程：`docs/release-checklist.md`；本地预检：`scripts/release_preflight.sh v1.0.2 --build`

## 当前状态速览

- 本地音乐：扫描、增量复用、专辑/艺术家聚合、播放、封面、歌词、统计、推荐
- Navidrome：单服务端配置、手动同步、SQLite 快照、浏览/搜索/播放、封面/歌词、scrobble
- 缓存：本地封面按需读取；远端封面内存 + 磁盘 LRU；在线音源封面当前直连 HTTPS；歌词 SQLite 正负缓存；LX 歌词 SQLite 正缓存 + 封面磁盘 LRU；移动端缓存管理支持总上限滑块、分源明细与一键释放空间；「为你发现」按天写入 SQLite 缓存（`discovery_cache`），打开优先读缓存
- 移动端：音乐库/搜索/设置/播放页/迷你播放器已完成；首页现为「最新发行」轮播、「为你发现」、「最近加入」、「重拾旧爱」；`mobile_welcome_section` / `mobile_daily_section` 仍未接入，属于待清理旧组件
- 移动端导航：底部 tab 为 首页 / 发现 / 媒体库 / 统计；设置入口移至首页 AppBar 折叠态；发现页已接入网易云/QQ 平台切换、推荐歌单、排行榜、热门歌曲、我的歌单
- 移动端设置：入口页已迁移到 `m3e_core.M3ESegmentedColumn`；具体设置子页尚未统一迁移
- 移动端 OpenSubsonic：连接、测试、扫描、歌单、艺术家简介、专辑/曲目浏览已接入真实数据；「为你发现」使用最近聆听艺术家的 `getSimilarSongs2`
- 音效：移动端已接入系统 5 段均衡器、淡入淡出；配置音源后自动切换默认歌曲来源
- 歌词：已接入 LRCLIB、LiriQo 搜索，支持逐字/逐行/静态标记、翻译与临时应用
- 跨平台：Linux 桌面可用；Android UI 已解耦，audio_service 后台/锁屏/通知已验证；Windows/macOS 打包未开始
- LX 音源：QuickJS、inited、HTTP、AES/RSA、setTimeout、SourceStore、SourceManager、FRB facade、移动端管理 UI、五平台独立搜索、`musicUrl` / `lyric` / `pic` 播放链路已打通
- LX 剩余重点：脚本执行安全与中断、源生命周期与懒加载、异步 request broker、真实源联调
- 主要功能缺口：收藏/歌单编辑/队列编辑/下载、移动端 SAF、MPRIS 迁移、高级 DSP/响度归一、真实电台内容
- 音频后端：桌面 media_kit；Android 使用 just_audio + audio_service；音频效果第一版已接入
- 设计系统：新增 `lib/design/`（颜色/字体/间距/圆角/尺寸/动效/断点 token、Material You 官方取色、`AppArtwork` / `AppText` / `AppMediaRow` 等基础组件）；页面级左右 gutter 统一为 `AppLayout.pageGutter` + `AppPageBody`；具体页面尚未全部迁移
- 新 UI 方向：继续 Flutter；`m3e_core` / `material_3_expressive` 只作组件库；Shell、路由、主题与取色自管；MiniPlayer + NavBar 为悬浮 BottomOverlay；Full Player 为 Root Navigator Route（2026-11-23 定稿；2026-11-24 导航内容有调整，见下方校正）
- 发布工程：正式签名、CI/Release workflow 已配置；首个 tag/Release 与 App 内更新检查仍待完成，见下方「2026-11-26 发布基础与更新链路」。
- 在线音源：内置 go-music-api host（网易云/QQ）+ 洛雪后备；旧 Node API Provider 已移除，见 `docs/musicapi-migration.md`

## 2026-11-26 发布基础与更新链路（新优先级）

> 结论：先完成正式签名 + GitHub Actions + 首个 Release，再做更新检查 MVP；应用内下载安装后置。不要等所有 TODO 完成。
> 更新范围先限定 Android；若后续上架 Google Play，则改用 Play In-App Updates，不自行下载 APK。
> 执行方式：按 P0-REL → P1-UPD → P2-UPD 顺序，一次只做一项，完成并验证后再勾选。

### 当前发布现状

- [x] 已有 GitHub remote：`git@github.com:LnyOtoya/laetibeat.git`
- [x] 首个版本基线确定：`1.0.0`；pubspec 当前 `1.0.0+1`，CI 发布时按 tag 覆盖 versionName / versionCode
- [x] Android `release` 构建已改为读取 `key.properties`，不再使用 debug keystore
- [x] 缺少签名配置时 release 构建会直接失败；debug 构建不受影响
- [x] 已生成正式 PKCS12 keystore 和本地 `android/key.properties`（均不提交）
- [x] `flutter build apk --release` 成功；`apksigner` 验证证书为 `CN=Lny Otoya`，非 debug 证书
- [x] 已添加 CI / Release workflow，待首次 GitHub Actions 运行验证
- [x] split-per-abi 本地构建成功：arm64-v8a 74 MB / armeabi-v7a 68 MB / x86_64 78 MB
- [ ] 无 tag / GitHub Release
- [ ] `applicationId` 仍为 `com.otimeum.laetibeat`，需确认最终包名；debug 后缀 `.debug` 保留
- [x] 版本策略确定：tag `vMAJOR.MINOR.PATCH`；versionName 取 tag；versionCode 由 semver 计算
- [x] 设置页版本号改为 `PackageInfo` 读取真实 versionName，不再写死 `0.1.0`
- [x] 根目录新增 MIT `LICENSE`（Copyright 2026 Otoya）；所有 Rust crate 标记 `license = "MIT"`
- [x] 新增 `THIRD_PARTY_NOTICES.md`，覆盖 Flutter/Rust 直接依赖、字体和原生组件
- [x] 设置页「开源许可」接入 Flutter `LicensePage`；移动端新增「关于」页入口

### Phase 0：正式签名与发布流水线（先做）

- [x] P0-REL-1 生成 release keystore
  - [x] 生成 PKCS12 keystore，存放在仓库外
  - [x] 备份到密码管理器/离线介质
  - [x] alias = `laetibeat`，有效期 10000 天
- [x] P0-REL-2 配置 Android release signing
  - [x] `build.gradle.kts` 读取 `android/key.properties` 并创建 `signingConfigs.release`
  - [x] 删除 `signingConfig = signingConfigs.getByName("debug")`
  - [x] 新增 `android/key.properties.example`
  - [x] 缺少签名配置时 release 构建直接报错；`assembleDebug` 正常
  - [x] `key.properties`、`*.jks`、`*.p12` 已被 `android/.gitignore` 忽略
  - [x] 用户创建真实 `android/key.properties`，正式签名 release 构建成功
- [x] P0-REL-3 固定版本策略
  - [x] tag：`vMAJOR.MINOR.PATCH`
  - [x] `versionName` 取 tag 去掉 `v`
  - [x] `versionCode = MAJOR * 1000000 + MINOR * 1000 + PATCH`（如 v1.0.0 → 1000000）
  - [x] CI 使用 `--build-name` / `--build-number` 覆盖 pubspec
  - [x] 首次切换正式签名后，已安装 debug 签名 release 包需卸载一次
- [x] P0-REL-4 新增 CI workflow（`.github/workflows/ci.yml`）
  - [x] push / PR：`flutter analyze`、`flutter test`、`cargo test --workspace`
  - [x] 固定 Flutter 3.50.1 / Rust 1.99.0 / JDK 17
  - [x] 缓存 Flutter pub、Gradle、Cargo
  - [ ] 首次 GitHub Actions 运行通过
- [x] P0-REL-5 新增 Release workflow（`.github/workflows/release.yml`）
  - [x] 触发：推送 `v*` tag 或 `workflow_dispatch`
  - [x] 注入 `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD`
  - [x] `flutter build apk --release --split-per-abi --build-name --build-number`
  - [x] 只发布架构包，不发布 universal APK
  - [x] 上传 arm64-v8a / armeabi-v7a / x86_64 APK 与 SHA256SUMS.txt
  - [x] 创建 GitHub Release，上传 APK 与 release notes
  - [x] 权限 `contents: write`
  - [x] 在 GitHub 仓库配置 4 个签名 Secrets
  - [x] 新增 `CHANGELOG.md`；workflow 按 tag 提取对应版本段落并追加安装说明
  - [ ] 首次 tag 发布验证
- [ ] P0-REL-6 首个正式 Release 验证
  - 从旧版正式签名包覆盖安装成功
  - 从 GitHub Release 下载安装成功
  - versionName / versionCode 与 tag 一致
- [ ] P0-REL-7 文档化发布流程
  - 打 tag、CI、keystore 备份、回滚/撤包步骤
  - [x] CHANGELOG 维护规则：平时写 `[Unreleased]`；发版时改成版本号+日期，并在顶部新增空 `[Unreleased]`

### Phase 1：更新检查 MVP（随后做）

- [ ] P1-UPD-1 增加依赖：`package_info_plus`、`http`（或 `dio`）、`url_launcher`
  - [x] `package_info_plus` 已加入，并用于设置页版本号
  - [ ] `http` / `dio`
  - [ ] `url_launcher`
- [ ] P1-UPD-2 更新服务
  - `GET https://api.github.com/repos/LnyOtoya/laetibeat/releases/latest`
  - `Accept: application/vnd.github+json` + `User-Agent`
  - 解析 `tag_name`、`body`、`published_at`、assets
  - 语义化版本比较；忽略 draft / prerelease
  - split APK 的 versionCode 会叠加 ABI offset；按 versionName/tag 比较，不跨 ABI 比较 versionCode
  - 不把 GitHub PAT 放进 App
- [ ] P1-UPD-3 检查策略
  - 首帧后静默检查一次；结果缓存 6～24 小时
  - 点击按钮强制检查
  - 网络失败静默，不阻塞首页
  - 记录 `lastCheckAt` / `skippedVersion`（`shared_preferences`）
- [ ] P1-UPD-4 AppBar 按钮
  - 在 `mobile_home_page.dart` 的 `actionsBuilder` 中放在设置左侧
  - 顺序：`[检查更新][设置]`
  - `M3EIconButton` + `M3EIcons.system_update_alt` + tooltip
  - 有新版本时用 `M3EBadge(showDot: true)` 提示
- [ ] P1-UPD-5 M3E 更新弹窗
  - 短提示：`M3EDialog.show` + `M3EDialog`
  - 标题：发现新版本 vX.Y.Z；内容：当前版本、发布日期、更新内容
  - 操作：`稍后`（text）/ `下载更新`（filled）
  - 长更新日志：`M3EDialog.showAdaptive`，内容可滚动
  - 无更新：SnackBar「已是最新版本」
- [ ] P1-UPD-6 下载动作
  - MVP 用 `url_launcher` 打开 GitHub Release 页面/资产地址
  - 记录点击/下载来源，便于后续排查

### Phase 2：应用内下载与安装（后置）

- [ ] P2-UPD-1 APK 下载：缓存目录、进度、取消、失败重试
- [ ] P2-UPD-2 校验：SHA-256（Release notes 或 `latest.json` 提供）
- [ ] P2-UPD-3 Android 安装
  - `REQUEST_INSTALL_PACKAGES`
  - FileProvider + `content://` URI
  - `open_filex` 或原生 Intent
  - 未知来源安装引导
- [ ] P2-UPD-4 下载 UI
  - `M3EDialog.showFullScreen` 或 `M3EDialog.showAdaptive`
  - 下载中禁用关闭/提供取消
  - 进度、错误、重试、完成后安装
- [ ] P2-UPD-5 分发策略
  - 已确定只发布 `--split-per-abi` 架构包，不发布 universal APK
  - 资产命名稳定：`laetibeat-<version>-<abi>.apk`；客户端按 ABI 选择
  - 可选 `latest.json`（版本、notes、assets、sha256）

### 推荐执行顺序

1. P0-REL-1 ～ P0-REL-3（签名与版本）
2. P0-REL-4 ～ P0-REL-6（CI、首个 Release）
3. P1-UPD-1 ～ P1-UPD-6（检查更新 MVP）
4. P2-UPD-1 ～ P2-UPD-5（应用内下载安装）
5. 回到既有 P0/P1/P2 TODO

### 验收口径

- [ ] AppBar 中更新按钮位于设置左侧，折叠态与设置一致显示
- [ ] 点击后 3 秒内给出结果：有新版本弹 M3E 弹窗，无新版本 SnackBar，网络错误不崩溃
- [ ] 弹窗能滚动查看完整更新内容，操作不超过两个
- [ ] Release 页面能打开正确版本；Android 安装包签名一致
- [ ] CI 在 PR 上跑通；tag 能自动发布 APK

## 2026-11-26 导航调整：电台 → 发现

- [x] 底部 tab 改为「首页 / 发现 / 媒体库 / 统计」。
- [x] 新增 `AppDestination.discover`、`MobileRoutes.discover`、`MobileDiscoverPage`。
- [x] 发现页位于首页之后，改为横向推荐卡片：媒体推荐、心动模式、歌单推荐、漫游、雷达歌单、相似歌曲。
- [x] 移除底部导航的电台入口与 `MobileRadioPage`；媒体库在线音乐中的「电台」占位仍保留。
- [x] l10n 增加 `navDiscover` / `discoverSubtitle` / `discoverEmptyTitle` / `discoverEmptyMessage`。
- [x] Rust 新增发现接口：`/personalized`、`/personal_fm`、`/simi/song`、`/homepage/block/page` 雷达 block、`/likelist`、`/playmode/intelligence/list`。
- [x] 数量控制：每日推荐 30、推荐歌单 6、私人 FM 1、相似歌曲 5、雷达歌单 6。
- [x] 不做假数据：六张卡片都依赖登录后的个性化数据，未登录时发现页整体显示登录提示，不再请求或展示匿名/游客推荐。
- [x] 登录后 `/recommend/songs`、`/personalized`、`/personal_fm`、`/homepage/block/page`、`/playmode/intelligence/list`、`/simi/song` 均携带 Cookie，避免继续拿到游客推荐。
- [x] 媒体库「每日推荐」页同步改为登录后显示；相关 provider 未登录直接拒绝请求。
- [x] 发现页第一张卡片标题由「媒体推荐」改为「今日推荐」。
- [x] 发现页六卡下方新增「根据你喜爱的歌曲推荐」：从 `/homepage/block/page` 中按标题匹配对应 block，解析 `resourceExtInfo.songData` / `song`。
- [x] 该区域标题左侧使用 `M3EShapeContainer.cookie9Sided`，右侧播放全部按钮；列表使用 `M3ESegmentedList`，每列 4 首、横向滚动、下一列露出一部分。
- [x] 首页动态区块通用解析：按 blockCode 取区块、标题用接口返回文案，内容区分 cards / songs / mixed。
- [x] 卡片区使用圆角正方形封面 + 歌单名最多两行，横向滚动约显示 2 个、第三个露出一部分；歌曲区复用每列 4 首布局。
- [x] 排除广播、Banner、功能入口球等非内容区块。
- [x] 发现页接入 `M3EPullToRefreshIndicator`；首次加载 `refresh=false`，下拉刷新后递增 token 并以 `refresh=true` 请求。
- [ ] 实测：登录后该 block 是否出现、返回曲目数量与真机横向分列布局；block 缺失时显示空状态。
- [ ] 实测：下拉刷新后不同 homepageMode 的区块集合变化（RCMD_MODE / PLAYLIST_MODE）与卡片点击跳转。
- [ ] 实测：登录后心动模式与相似歌曲队列、漫游队列续拉、雷达接口缓存与真机横向卡片布局。

## 2026-11-25 最终结构定稿（Rust / Dart 边界）

> 方案：首版网易云通过用户可配置的 Node API（Vercel / VPS / NAS）接入；Rust 负责领域、网络、解析、缓存和数据库，Dart 负责 UI、设置、安全存储和播放引擎。Rust 内置网易云直连暂缓。

### 分层

- Rust：
  - `laetibeat_core`：本地扫描 / 统计 / 歌单 / 远端库 SQLite
  - `laetibeat_remote`：OpenSubsonic / LRCLIB / LiriQo
  - `laetibeat_netease`（新增）：Node API 客户端、登录、搜索、歌单、日推、歌词、封面、播放 URL
  - `laetibeat_lx`：QuickJS / LX 脚本运行时
  - `laetibeat_resolver`（新增）：local / Subsonic / NetEase / LX fallback 解析链、缓存、错误分类
  - `rust_lib_laetibeat`：FRB DTO 与 API 门面
- Dart：
  - 页面 / 导航 / 主题 / Riverpod state
  - 设置页：API Base URL、Token、测试连接、登录 QR、洛雪后备开关
  - `flutter_secure_storage`：Cookie / Token
  - `PlayerNotifier` / `PlaybackBackend` / audio_service / 通知
  - `PlaybackTrack` 扩展 headers / expiresAt
  - 封面/歌词渲染、错误文案本地化

### 边界原则

- Dart 不直接调用网易云 Node API；统一走 Rust。
- Rust 不持久化用户 Cookie；Dart 通过安全存储持有，调用时传入。
- Rust 返回类型化错误，Dart 负责本地化提示。
- fallback 不改变曲目身份；统计/歌单/队列仍按网易云曲目记录。

### 本轮已完成

- [x] 媒体库移除右上角 SplitButton。
- [x] 本地音乐新增「私服歌曲」，放在「歌曲」上方。
- [x] 进入「私服歌曲」默认 Navidrome；进入「歌曲」默认本地歌曲。
- [x] 设置中增加「在线音乐 / 网易云音乐」配置入口；当前仅保存 API 地址与后备开关，未接 API 时不显示内容。
- [x] 设置新增「在线音乐」单选页；媒体库「在线音乐」分组跟随所选来源，当前仅网易云，未接 API 时显示空占位。

## 2026-11-25 Phase A：网易云无登录链路（已完成）

> 本地 NAS API：`http://192.168.31.51:3000/`
> 已验证：`/login/status`、`/search`、`/song/detail`、`/lyric/new`、`/check/music`、`/recommend/songs` 均可访问；免费歌曲 `fee=0` 未登录返回完整 320k URL，`fee=1` 未登录返回 45 秒试听（`freeTrialInfo`）。局域网内不需要 `realIP` / `randomCNIP`。

### 本轮已完成

- [x] Rust 新增 `laetibeat_netease`：连接测试、搜索、歌曲详情、歌词、播放 URL、每日推荐。
- [x] FRB 暴露网易云 API，Dart 不直接请求 Node API。
- [x] 设置页增加“测试连接”，区分服务可达 / 未登录 / 已登录。
- [x] 媒体库“每日推荐”接入 `/recommend/songs` 真实数据。
- [x] 免费歌曲可播放；`freeTrialInfo` 或缺失 URL 标记为试听。
- [x] 曲目身份：`source=netease`、`id=netease:<songId>`，`sourceExtraJson` 保留 songId/albumId/duration/fee。
- [x] 封面：Rust 下载 + Dart `NeteaseCoverProvider` 内存缓存。
- [x] 歌词：`NeteaseLyricProvider` 接入，支持 LRC、翻译和逐字 `yrc`。
- [x] 本地联调：`LAETIBEAT_NETEASE_API=http://192.168.31.51:3000 cargo test -p laetibeat_netease live_probe -- --ignored` 通过。

### 后续状态

- [x] 搜索页接入 `neteaseSearchProvider`（Rust API 已就绪）。
- [x] 二维码登录、Cookie 安全存储、用户歌单与 LX `wy` fallback 已实现，分别见 Phase B1、B2、B4。
- [ ] 实测登录后会员歌曲是否返回完整 URL；非会员仍显示试听。
- [x] 艺人/专辑在线入口已接入收藏列表与详情；电台仍为占位，后续单独接入。

## 2026-11-25 Phase B1：网易云登录与 Cookie（已实现，待登录实测）

> 同时支持二维码登录和手机验证码登录；Cookie 由 Dart 安全存储，Rust 无状态接收。

- [x] Rust：`/login/qr/key`、`/login/qr/create`、`/login/qr/check`，所有请求带时间戳。
- [x] Rust：`/captcha/sent`、`/login/cellphone`，手机号/验证码用 POST body。
- [x] Rust：`/login/status`、`/recommend/songs`、`/song/url/v1` 支持可选 Cookie。
- [x] FRB：二维码创建/轮询、验证码发送、手机登录、带 Cookie 状态。
- [x] Dart：Cookie 存 `flutter_secure_storage`，不落 Rust DB、不打印。
- [x] Dart：网易云设置页显示登录入口、账号昵称、退出登录。
- [x] Dart：二维码登录页，轮询 800/801/802/803，803 保存 Cookie。
- [x] Dart：手机验证码登录页，发送验证码、倒计时、登录、保存 Cookie。
- [x] 登录后每日推荐、播放 URL 自动带 Cookie。
- [x] 实测：二维码扫码登录成功，可获取账号信息，每日推荐正常。
- [ ] 实测：手机验证码登录返回 400，暂缓；二维码登录优先。
- [ ] 实测：登录后 `fee=1` 歌曲是否返回完整 URL；非会员仍显示试听。
- [x] 二维码接口联调：`live_qr_probe` 已通过（key/create/check 形状）。

## 2026-11-25 Phase B2：我的在线歌单（已实现，待实测）

- [x] Rust：`/user/playlist` 用户歌单列表，带 Cookie。
- [x] Rust：`/playlist/track/all` 歌单全部歌曲，带 Cookie。
- [x] FRB：歌单 DTO、用户歌单列表、歌单歌曲。
- [x] Dart：登录用户 uid + Cookie 获取歌单。
- [x] 媒体库「我的在线歌单」接入真实数据。
- [x] 歌单详情页：封面、歌曲列表、点击播放。
- [x] 歌单/歌曲加载失败、未登录状态提示。
- [ ] 实测：真实账号歌单列表与歌单歌曲加载。
- [x] 用户歌单遵循 API 默认 30 条；歌单歌曲按 25 首首屏请求，滚动接近列表末尾时按 `offset` 分页补充，详情列表使用 sliver builder 按需构建。
- [ ] 后续：歌单收藏/编辑。

## 2026-11-25 Phase B3：网易云搜索 UI（已实现，待实测）

- [x] 搜索来源增加「网易云」筛选。
- [x] 搜索结果页支持网易云歌曲搜索。
- [x] 搜索结果走 `neteaseSearchProvider`，Dart 不直接请求 Node API。
- [x] 支持加载、空结果、错误提示。
- [x] 点击结果直接播放，封面复用网易云封面缓存。
- [x] 默认搜索来源设置增加「网易云」。
- [ ] 实测：搜索、切源、播放。
- [ ] 后续：网易云歌单/专辑/艺人搜索分类。

## 2026-11-25 Phase B4：网易云 → LX `wy` 后备（已实现，待实测）

- [x] 网易云直连返回试听或无 URL 时读取 `allowLxFallback`。
- [x] 网易云曲目转换为 LX `wy` 的 `musicInfo`（`songmid` = NetEase songId）。
- [x] 后备前等待 LX `wy` 可播，最长 12 秒。
- [x] 音质阶梯：默认音质 → 320k → 128k。
- [x] 后备成功时返回完整 URL；失败时回退到网易云试听。
- [x] 后备不改变曲目身份，队列/统计仍是网易云曲目。
- [x] 后备开关改为即时保存，不再要求点“保存”。
- [x] 试听片段播完停止，不再自动切下一首。
- [x] 直连/后备增加 debugPrint 诊断日志。
- [ ] 实测：启用洛雪 wy 源 + 网易云设置开启后备，播放 VIP 歌曲。
- [ ] 后续：后备结果 UI 标记、失败提示优化。

## 2026-11-25 Phase C1：网易云歌单搜索（已实现，待实测）

- [x] Rust：`/cloudsearch?type=1000` 歌单搜索。
- [x] FRB：歌单搜索 DTO 与函数。
- [x] Dart：歌单搜索 provider。
- [x] 搜索页「歌单」分类接入网易云结果。
- [x] 点击歌单进入现有网易云歌单详情。
- [x] 本地联调：`live_probe` 已包含歌单搜索。
- [ ] 实测：App 内搜索歌单、打开、播放。

## 2026-11-25 Phase C2：网易云专辑/艺人搜索（已实现，待实测）

- [x] Rust：`/cloudsearch?type=10` 专辑搜索、`/album` 专辑详情。
- [x] Rust：`/cloudsearch?type=100` 艺人搜索、`/artists` 艺人详情。
- [x] FRB：专辑/艺人 DTO、搜索、详情函数。
- [x] Dart：专辑/艺人搜索 provider、详情 provider。
- [x] 搜索页「专辑」「艺人」分类接入网易云结果。
- [x] 专辑详情页：封面、歌曲、播放。
- [x] 艺人详情页：头像、热门歌曲、播放。
- [x] 艺人详情仅向界面返回 5 首热门歌曲。
- [x] 艺人详情热门歌曲区有标题和更多入口；更多页最多显示 50 首。
- [x] 本地联调：`live_probe` 已包含专辑/艺人搜索与详情。
- [ ] 实测：App 内搜索专辑/艺人、打开、播放。
- [ ] 后续：搜索结果收藏/喜欢。

## 2026-11-25 Phase C3：在线音乐艺人/专辑入口（已实现，待实测）

- [x] Rust：`/artist/sublist` 收藏艺人，带 Cookie。
- [x] Rust：`/album/sublist` 收藏专辑，带 Cookie。
- [x] FRB：收藏艺人/收藏专辑列表函数。
- [x] Dart：收藏艺人/收藏专辑 provider。
- [x] 媒体库在线音乐「艺人」接入收藏艺人列表。
- [x] 媒体库在线音乐「专辑」接入收藏专辑列表。
- [x] 收藏艺人/专辑按 25 条首屏请求，滚动接近列表末尾时使用 `offset` 分页加载。
- [x] 点击艺人/专辑进入现有详情页。
- [x] 未登录、空列表、加载失败状态。
- [ ] 实测：登录后查看收藏艺人/专辑、打开、播放。

## 2026-11-25 Phase D1：艺人专辑列表（已实现，待实测）

- [x] Rust：`/artist/album` 艺人专辑列表。
- [x] FRB：暴露艺人专辑列表。
- [x] Dart：艺人专辑 provider。
- [x] 艺人详情页增加专辑列表。
- [x] 点击专辑进入现有专辑详情。
- [x] 艺人专辑以横向卡片展示，只显示封面、专辑名和发行年份。
- [x] 艺人专辑请求遵循 API 默认 30 条，不覆盖 `limit/offset`。
- [x] 本地联调：`live_probe` 已包含艺人专辑列表。
- [ ] 实测：艺人页专辑列表、打开、播放。

## 2026-11-26 Phase D2：在线页面布局与底栏避让（实现完成，待真机验证）

- [x] 艺人详情热门歌曲保留 5 首；“更多”页最多显示 50 首。
- [x] 艺人专辑区改为横向卡片，专辑名与发行年份各占一行。
- [x] 网易云歌单、每日推荐、收藏列表及专辑/艺人详情的可滚动内容，末尾增加 Shell 提供的动态底栏 inset。
- [x] OpenSubsonic 远端专辑/艺人详情与洛雪歌单预览接入同一底栏 inset；本地音乐页面保持原行为。
- [ ] 手动真机验证横向专辑卡片、各在线页面滚动末尾无遮挡。

## 2026-11-27 Phase E1：网易云播放音源 HTTPS-only（已实现）

- [x] 仅网易云直连及网易云曲目的 LX `wy` 后备音源设置 HTTPS-only 策略；其他来源保持原播放路径。
- [x] 音源经仅绑定 `127.0.0.1` 的本机转发器；HTTP 音源 URL 升级为 HTTPS，TLS 证书照常校验。
- [x] 转发器逐跳检查重定向，最多跟随 5 次 HTTPS 重定向，拒绝任何降级到 HTTP 的跳转。
- [x] 转发 Range / If-Range 请求和必要响应头，支持音频缓冲与 seek。
- [x] Debug 日志只记录上游 scheme、host 和状态码，不记录带签名参数的完整音源 URL。
- [x] 单元测试覆盖 HTTP→HTTPS、HTTPS 原样保留、非 HTTP(S) 拒绝及 HTTPS 重定向降级拦截；`flutter test`、`flutter analyze` 通过。
- [x] Pixel 7 Debug 实测：网易云试听音源 `songId=35847388` 请求 `https://m702.music.126.net`，返回 HTTP 200；Flutter 运行时无异常。
- [ ] 真机验证完整非试听音源；本次实测样本为试听流，未覆盖全部 CDN / 重定向组合。
- [ ] 桌面 `media_kit` 播放链路实机验证。

## 2026-11-24 代码审查发现（只记录，不改实现）

> 来源：全仓库静态阅读 + `cargo test` / `cargo clippy` + `flutter analyze` / `flutter test`。
> 本轮只更新 TODO，不修改代码。部分问题与下方历史待办重复（material_ui 迁移、MPRIS、死代码、下载等），这里保留 2026-11-24 的审查证据与验收标准，修复时以对应条目为准，不重复安排多轮修复。
> 注意：行号以审查时快照为准；2026-11-24 晚间的首页、设置、导航改造已使部分 UI 行号失效，修复时请以文件路径 + 条目描述重新定位。

### 验证基线

- [x] `cargo test --workspace --offline`：53 passed（core 10 / lx 39 / remote 3 / rust_lib 1；含 P0-5 迁移、discovery cache 测试）
- [x] `cargo clippy --workspace --offline --all-targets`：仅风格 warning，无 error
- [x] `flutter analyze --no-pub`：27 issues，0 error；2 warning + 25 info
- [x] `flutter test --no-pub`：14 tests all passed
- [ ] 上述通过不代表 P0 不存在：现有测试未覆盖播放暂停竞态、嵌套 Navigator 返回、OpenSubsonic 配置解析、LX 候选源选择、SAF 部分失败等路径

### P0：正确性与用户可见问题

- [ ] P0-1 移动端 OpenSubsonic 配置会覆盖协议/端口，且缺少 API Key 模式
  - 位置：`laetibeat_flutter/lib/pages/mobile/settings/sources/opensubsonic/mobile_opensubsonic_config_page.dart:141-171`（`_buildConfig`）
  - 现状：端口为空强制 `4533`；`baseUrl` 使用下拉框 `_scheme.name`；忽略用户在 URL 中输入的 `https://` 和 `:port`；`_buildConfig()` 固定 `authMode: SubsonicAuthMode.token`
  - 影响：`https://music.example.com` 会变成 `https://music.example.com:4533`；`http://host:8080` 会变成 `http://host:4533`；API Key 用户无法在移动端配置
  - 修复/验收：完整解析 URL，尊重 scheme/port/path；仅 http 且未指定端口时补默认 4533；暴露 API Key/Token 选择；补 URL 解析单元测试
  - 对照：桌面 `laetibeat_flutter/lib/widgets/settings/subsonic_connection_sheet.dart` 已支持两种认证与完整 URL，可复用其逻辑

- [ ] P0-2 Root Navigator + 嵌套 Navigator 的系统返回行为不一致
  - 位置：`laetibeat_flutter/lib/pages/mobile/mobile_app.dart:230-236`（嵌套 Navigator）、`:85-97`（chrome 显隐）；`laetibeat_flutter/lib/pages/mobile/mobile_navigation.dart`
  - 现状：业务页面全在 Shell 内部的嵌套 Navigator；代码中没有 `PopScope` / `NavigatorPopHandler` / `WillPopScope`；Flutter 的 `WidgetsApp.didPopRoute()` 只会对 root navigator 调 `maybePop()`
  - 影响：三键返回可能直接从嵌套页面退出 App；预测性返回可能命中嵌套路由，出现 TODO 已记录的 FullPlayer/底层路由交错
  - 修复/验收：在扁平化 Navigator 或 Shell 层 `PopScope` 代理两种方案中定稿；补“Library 详情/搜索/设置子页按系统返回回到上一层”的回归测试
  - 关联：下方「已知问题：Predictive Back + 多 Navigator 交错」

- [ ] P0-3 LX 源候选选择在进程重启后退化
  - 位置：`laetibeat_lx/src/manager.rs:382-407`，关键 `.unwrap_or(true)` 在 `:396`
  - 现状：`candidates_for()` 只看内存 `self.declarations`；持久化的 `record.declaration` 只在 `resolved_declaration()` 中用于 UI；重启后内存声明为空，所有已启用源都被视为候选
  - 影响：首次播放任意平台时依次加载/执行不匹配平台的脚本；每源可能数秒甚至 30s 超时；与“持久化声明用于懒加载”目标矛盾
  - 修复/验收：提供统一 `effective_declaration(record)`（内存优先，其次 hash 一致的持久化声明）；未知能力默认 `false`；补“重启后只尝试声明支持该平台的源”测试

- [ ] P0-4 LX 共享 QuickJS Context 存在跨请求结果串扰风险
  - 位置：`laetibeat_lx/src/runtime.rs:132-211`（`dispatch`）
  - 现状：一个 `Context` 长期复用；`dispatch` 开始把 `__lx_result` 置为 undefined，但旧 `setTimeout` 与旧 Promise `.then` 仍可能保留并在下一次 `pump_timers()` 时写入旧结果
  - 影响：偶发返回错误播放 URL/歌词，或“source did not produce a result”，难以复现
  - 修复/验收：每次 dispatch 分配 id 并在 JS/Rust 两侧校验；或每次操作新建 Context；至少在该次 dispatch 结束时清理遗留 timer；补“旧定时器不得影响下一次结果”测试

- [x] P0-5 远端专辑/曲目 `created` 字段没有落库（2026-11-24 已修复）
  - 修复：`SCHEMA_VERSION = 3` 为 `remote_albums` / `remote_tracks` 增加 `created TEXT`；同步写入专辑与曲目加入时间；`UiRemoteAlbum` / `UiRemoteTrack` 透传；补迁移与持久化测试
  - 验收：`cargo test --workspace` 通过；移动首页“最近加入”优先使用曲目 `created`，缺失时回退专辑 `created`

- [ ] P0-6 远端 URL 解析期间点暂停，音频仍会起播
  - 位置：`laetibeat_flutter/lib/widgets/player/player_provider.dart:465-500`（`load` 乐观 `isPlaying: true`）与 `:553-609`（`_openResolved` 解析后 `open(play: true)`）
  - 影响：LX/Subsonic URL 解析期间用户点暂停，`toggle()` 暂停旧音频后，解析完成仍会起播；UI 与音频状态不一致
  - 修复/验收：记录用户期望播放状态/generation；`open` 前再次校验；或先 `open(play: false)` 再按期望决定 `play()`；补快速“播放→暂停”竞态测试

### P1：性能、内存与稳定性

- [ ] P1-1 缓存预算同时作用于内存和磁盘，且默认值过大
  - 位置：`laetibeat_flutter/lib/widgets/settings/cache_usage_service.dart:15`（默认 3584MB）、`:28-44`（权重拆分）、`:95-108`（同一预算套内存与磁盘）
  - 影响：最坏情况下仅内存缓存就可能接近 3.5GB（本地 1024MB + Subsonic 2048MB + LX 512MB），Android 容易 OOM
  - 修复/验收：拆分“磁盘缓存上限”（用户可见）与“内存缓存上限”（独立、较小）；内存上限建议几十到一百多 MB；缓存页文案与实际语义一致

- [ ] P1-2 非 autoDispose 的 family Provider 让 LRU 失效
  - 位置：`laetibeat_flutter/lib/widgets/player/cover_provider.dart:361,378`；`laetibeat_flutter/lib/widgets/player/lyric_provider.dart:324`；`laetibeat_flutter/lib/widgets/player/lx_search_provider.dart:287`
  - 现状：`trackCoverProvider` / `remoteCoverProvider` / `trackLyricsProvider` / `lxSearchProvider` 默认 keepAlive 到容器销毁，每个访问过的 key 永久保留结果；底层 `FileCoverProvider._trim` 无法释放 Provider state 持有的字节
  - 修复/验收：列表/搜索类 family 改 `.autoDispose`；仅当前播放曲目保留；或改为统一可淘汰缓存；补滚动大库/连续搜索后的内存回归检查

- [ ] P1-3 播放面板每次进度更新都重建整棵树
  - 位置：`laetibeat_flutter/lib/widgets/player/playback_panel.dart:51` 直接 `ref.watch(playerProvider)`；`laetibeat_flutter/lib/pages/desktop/player/device_panel.dart:17` 同样监听整个 `PlayerState`
  - 影响：位置流每秒多次更新，`M3ETheme`、`LayoutBuilder`、封面、歌词、控制区全部重建；移动端尤其明显
  - 修复/验收：进度条/时间单独 `select(position)`；按钮 `select(isPlaying)`；曲目信息 `select(current)`；设备/音频参数单独 Consumer；补 rebuild 次数或性能基准

- [ ] P1-4 首页推荐与媒体库首页全量加载远端数据
  - 位置：`laetibeat_flutter/lib/widgets/recommendation_provider.dart:125-129`（全部远端专辑 + 全部曲目）；`laetibeat_flutter/lib/pages/mobile/library/mobile_library_page.dart:87-98`（计数/预览加载全部曲目/专辑/艺术家/歌单）
  - 影响：上万首 Subsonic 库时构造大量 FRB DTO、扫描整表，首页卡顿/内存上涨
  - 修复/验收：SQL `COUNT(*)`、分页查询、首页专用聚合；推荐使用 SQL 侧专辑聚合，不把全部曲目拉到 Dart
  - 2026-11-24 现状：新增「为你发现」已改为按天读取/写入 `discovery_cache`，不再每次开屏请求 `getSimilarSongs2`；本条仍针对专辑级推荐和媒体库首页的全量加载
  - 关联：下方既有“远端同步支持增量、取消与进度节流；推荐避免全量加载远端曲目”

- [ ] P1-5 LX 搜索在输入过程中反复请求且结果常驻
  - 位置：`laetibeat_flutter/lib/pages/mobile/search/library_search_suggestions.dart:117-139`；`laetibeat_flutter/lib/widgets/player/lx_search_provider.dart:287`
  - 现状：300ms 防抖后每个新查询都会请求非官方平台接口；`lxSearchProvider` 非 autoDispose
  - 影响：输入 10 个字符可能产生 10 次请求并常驻 10 份结果；有被平台限流风险
  - 修复/验收：提高防抖/最小查询长度；`autoDispose`；同平台请求取消/合并；建议只在提交或明确点击时触发网络建议

- [ ] P1-6 缓存管理页每 3 秒递归扫描缓存目录
  - 位置：`laetibeat_flutter/lib/pages/mobile/settings/storage/mobile_storage_settings_page.dart:72-135`；`laetibeat_flutter/lib/widgets/settings/cache_usage_service.dart:150-230`
  - 影响：`remote_covers` / `lx_covers` 递归遍历 + SQLite 统计，GB 级缓存时 I/O 和耗电明显
  - 修复/验收：改为变更后刷新/手动下拉刷新，或维护目录大小索引；移除无条件 3 秒全量扫描

- [ ] P1-7 Subsonic 旧配置可能“复活”
  - 位置：`laetibeat_flutter/lib/widgets/settings/subsonic_provider.dart:124-134,333`
  - 现状：`saveConfigs([])` 只删除 `_serverKey`，未删除旧 `_serversKey`；`migrateLegacyIfNeeded()` 只判断 `_serverKey` 是否存在
  - 影响：删除服务器后，下次启动可能再次迁移旧多服务器配置的第一项
  - 修复/验收：迁移完成或删除配置时清除 `_serversKey` 与旧密钥，或写入“已迁移”标记；补删除后重启不复活测试

- [ ] P1-8 快照/索引写入不是真正原子替换
  - 位置：`laetibeat_flutter/lib/widgets/settings/persistence.dart:53-60`；`laetibeat_lx/src/store.rs:397-412`
  - 现状：先删除目标文件再 `rename`，崩溃窗口会丢文件，与“原子写”注释不符
  - 修复/验收：改为覆盖式原子替换（同目录临时文件 + 平台支持时直接 rename 覆盖）；补写入中断/损坏恢复测试

- [ ] P1-9 `lx.request` 仍是同步阻塞实现，且每次新建 Client、先读完整响应再限大小
  - 位置：`laetibeat_lx/src/http.rs:33-148`
  - 现状：`reqwest::blocking`；每次请求新建 `Client`；`response.bytes()` 完整读取后才检查 `MAX_BODY_BYTES`；`formData` 未实现
  - 影响：无法取消；连接复用差；大响应有内存风险；部分源脚本兼容性不足
  - 修复/验收：迁移异步 request broker 并支持取消；复用 Client；流式读取边读边限制；实现 `formData` 或明确不支持
  - 关联：下方既有 LX 剩余重点

- [ ] P1-10 LX 脚本网络能力的安全边界需要明确
  - 位置：`laetibeat_lx/src/preload.js`（`lx.request`）、`laetibeat_lx/src/http.rs:60`（仅限制 http/https，不限 host）
  - 现状：用户导入的任意 JS 可请求 `localhost`/内网任意 http(s) 地址；Android 当前全局允许明文流量
  - 影响：恶意/失控源可做内网探测（SSRF）；无源签名或导入权限提示
  - 修复/验收：导入不可信源时明确警告；评估域名白名单/请求确认；Android 明文流量改按域名白名单（关联既有待办）

- [ ] P1-11 `normalize_seconds` 两套阈值不一致，长音频时长会被误判
  - 位置：`laetibeat_lx/src/search.rs:927-933`（阈值 10_000）、`laetibeat_lx/src/songlist.rs:1308-1314`（阈值 86_400）
  - 影响：同一首 3 小时音频，搜索接口可能把 10800 秒当毫秒除以 1000 变成 10 秒；歌单接口却保留 10800 秒
  - 修复/验收：统一时长归一化规则；优先按接口字段语义判断，不用单一阈值；补长音频/毫秒值测试

### P2：UX、功能与工程债

- [ ] P2-1 大量“能点但没功能”的控件
  - 位置示例：`laetibeat_flutter/lib/pages/mobile/home/mobile_home_content.dart`（最近加入“查看更多”、歌曲收藏）；`laetibeat_flutter/lib/pages/mobile/library/albums/album_detail_page.dart`（收藏）；`laetibeat_flutter/lib/pages/mobile/library/artists/artist_detail_page.dart`（收藏/热门歌曲/随机播放）；`laetibeat_flutter/lib/pages/mobile/library/views/songs_library_view.dart`（批量收藏）；`laetibeat_flutter/lib/pages/mobile/library/widgets/library_layout_control_bar.dart`（排序）；`laetibeat_flutter/lib/pages/mobile/settings/mobile_settings_page.dart`（备份/关于）；`laetibeat_flutter/lib/pages/mobile/settings/content/mobile_content_settings_page.dart`（歌词恢复默认第三项 `onTap` 未处理）；`laetibeat_flutter/lib/pages/mobile/radio/mobile_radio_page.dart`（电台占位空状态）
  - 修复/验收：实现、隐藏或明确禁用并标注“即将支持”，避免用户误以为功能存在
  - 2026-11-24 校正：首页旧“查看更多/收藏”行号已失效；设置页入口已改 segmented list；电台 tab 已接入但页面仍为占位

- [ ] P2-2 桌面端与移动端功能分叉
  - 现状：桌面设置 `playerAudio` / `storage` / `backup` / `changelog` 仍是 `SettingsPlaceholder`（`laetibeat_flutter/lib/pages/desktop/settings/settings_content.dart:21-31`）；桌面搜索无 LX；`ChartPage` / `PlaylistPage` 仍为 `Placeholder`；`linux_mpris.dart` 未接入，`mediaSessionServiceProvider` 始终 Noop；设置有下载目录但无下载写入
  - 修复/验收：明确桌面端维护策略；要么补齐，要么在 UI 中移除/标注未支持功能，避免半成品入口

- [ ] P2-3 i18n 覆盖不完整
  - 现状：`lib/l10n` 约 346 个 key，但 `lib` 中约 398 处含中文字符串字面量、分布在 60 个文件（部分为日志/错误文案）
  - 典型：`mobile_home_page.dart`、`mobile_home_content.dart`、`mobile_library_page.dart`、`desktop_title_bar.dart`、各类 Snackbar 与 Rust 返回的中文错误
  - 修复/验收：先清理移动端主路径硬编码 UI 文案；Rust 改为错误码/错误枚举 + Dart 侧翻译

- [ ] P2-4 `material_ui` 与 `flutter/material` 混用（已有条目，需继续推进）
  - 现状：`flutter analyze` 仍报 15 个源文件 import 已弃用的 `package:flutter/material.dart`；`MaterialYouThemeHost` 注入的是 `material_ui` 的 `Theme`，旧 Flutter Material 组件读 fallback `ThemeData`
  - 影响：默认颜色/字体/密度与设计系统不一致，动态取色覆盖不到旧组件
  - 修复/验收：统一迁移到 `material_ui`；清理 `app.dart` 中为兼容旧组件加的 `flutter_localizations` 委托

- [ ] P2-5 死代码、死测试与文档漂移
  - 现状（已确认无业务引用）：`AppMorphingTabBar` + 6 个 morphing 测试、`MobileSearchInlineView` / `MobileSearchBrowseView`、`MobileWelcomeSection` / `MobileDailySection` / `mobile_home_constants.dart`、`AppThemeFactory`、`linux_mpris.dart`、`playback_settings.dart` / `library_settings.dart` / `notifications_settings.dart` / `audio_output_settings.dart`、`selectable_card_list.dart` / `squish_button_pair.dart`、`lib/pages/tmp.dart.bak`
  - 文档：`ARCHITECTURE.md` 仍描述旧的嵌套 Navigator + `NavigatorPopHandler`、移动端目录选择返回 null、移动端 MediaKit 等，与当前代码不符
  - 修复/验收：删除已确认不再使用的组件/测试；同步更新 `ARCHITECTURE.md` 与 TODO 历史勾选项；补一条“无引用文件”检查

- [ ] P2-6 本地歌单快照丢失远端曲目元数据
  - 位置：`laetibeat_flutter/lib/widgets/playlist_provider.dart:93-121`（`_trackFromPlaylistItem` 将 albumId/artistId/bitrate 置空）
  - 影响：从歌单播放远端曲目时，统计聚合、推荐、音质推断退化
  - 修复/验收：歌单条目 schema 增加 `album_id` / `artist_id` / `bitrate`，或播放时按 `source/sourceId/trackId` 回查远端库

- [ ] P2-7 媒体库/搜索的“全部”语义与 LX 过滤不一致
  - 位置：`laetibeat_flutter/lib/pages/mobile/library/views/songs_library_view.dart:54-85`（`lx` 分支不加入任何曲目）；`laetibeat_flutter/lib/pages/mobile/library/mobile_library_page.dart:53-72`（计数不随来源过滤）；`laetibeat_flutter/lib/pages/mobile/search/mobile_search_page.dart` 中 `all` 只含本地 + Subsonic
  - 影响：选择“全部/洛雪”时计数与列表不一致；LX 歌曲/专辑/艺术家视图为空但歌单视图有 LX 订阅；用户容易误判
  - 修复/验收：明确“全部”是否包含 LX；计数按当前过滤计算；LX 分类给出空态说明或隐藏不支持的子页

- [ ] P2-8 播放进度未持久化；播完后的重播不进入统计
  - 位置：`laetibeat_flutter/lib/widgets/player/player_provider.dart:251-271` 注释称恢复“进度”，但 `PlaybackStateSnapshot` 没有 position 字段；`toggle()` 播完后 seek(0) 直接播放，未重新开启 session
  - 影响：重启后从曲首开始；顺序播放结束后点播放不计入新的播放统计
  - 修复/验收：快照持久化 position；重播时调用 `_sessionTracker.onTrackChanged`；补恢复/重播测试

- [ ] P2-9 SAF 扫描部分失败会永久缺失曲目
  - 位置：`laetibeat_flutter/lib/widgets/settings/music_library_provider.dart:326-398`
  - 现状：部分文件解析失败只计入 `failedFiles`，仍写快照并记录 scan version；失败文件不会自动重试
  - 修复/验收：失败项保留待重试状态，或下次扫描强制重试；UI 可查看失败文件

- [ ] P2-10 LX 其他待核实项
  - `laetibeat_lx/src/search.rs:485` 把 Kugou 的 `Suffix` 追加到歌名；需确认该字段是版本信息还是文件格式，避免出现“Song mp3”
  - `laetibeat_lx/src/songlist.rs:284-310`（`get_playlist_all`）最多 20 页，Migu 50/页，超大歌单会静默截断到约 1000 首
  - `lx.request` 的 `formData` 仍未实现；需要盘点真实源兼容性
  - `LxSourceStatus::Initializing` 在同步 `load_source` 下 UI 不可观测；`allow_update_alert` 无 UI 使用且 `__lx_on_update_alert` 为空实现

## 2026-11-24 首页 / 导航 / 设置校正

> 本节用于覆盖上方「Home 页重写」「导航栏重设计」中已经过期的描述；那些历史记录保留作为演进记录，不再作为当前实现依据。

### 已完成

- [x] 首页 AppBar 展开标题改为「最新发行」；轮播改为按发行年份排序的最新发行专辑封面
- [x] 首页新增「为你发现」：
  - 最近聆听的 Subsonic 艺术家，每天轮换一个；
  - 调用 `getSimilarSongs2`；
  - 结果按天写入远端库 SQLite `discovery_cache`，打开程序优先读当天缓存；
  - 播放事件后异步预取；只有点击「换一个」才强制重新请求并覆盖当天缓存；
  - 大艺术家卡片 + 三个横向预览封面；完整列表进入 `DiscoveryPage`
- [x] 「最新添加」改为「最近加入」，使用 `m3e_core.M3ESegmentedList` 展示 4 首歌曲，左侧封面改用 48dp `cookie9Sided`
- [x] 移除首页最下方旧的「为你推荐」区域及相关 `_recommendedTracks` / `_RecommendedSong` / `_TrackCover`
- [x] 设置入口页重写为 `m3e_core.M3ESegmentedColumn`，参数为 outer 24 / inner 4 / gap 2 / padding 12 / margin 12×4；条目改用 `m3e_core.M3EListItem`
- [x] 底部导航由「首页 / 媒体库 / 统计 / 设置」改为「首页 / 媒体库 / 统计 / 电台」
- [x] 设置入口移至首页 AppBar，仅在折叠态显示；展开态隐藏
- [x] 新增 `MobileRoutes.radio`、`AppDestination.radio`、`MobileRadioPage`（2026-11-26 已由 discover 取代）
- [x] 新增 l10n `navRadio`（中/英）（2026-11-26 已由 `navDiscover` 取代）

### 仍待处理

- [ ] 媒体库在线音乐中的「电台」入口目前只有空状态占位，尚未接入 Subsonic `getInternetRadioStations` / 电台播放链路；底部导航的电台 tab 已于 2026-11-26 替换为「发现」
- [ ] 「为你发现」完整页的歌曲收藏按钮仍为占位，归入 P2-1
- [ ] 设置入口页的备份/关于仍无实际页面或功能，归入 P2-1
- [ ] Home 历史记录中的「继续听」「最新添加」「为你推荐」描述已过期，后续以本节为准

### 修复排期（2026-11-24 讨论结论）

- **第一批（低风险正确性）**：P0-3、P0-1、P0-6、P1-7、P1-11
- **第二批（需先定方案）**：P0-2 导航返回、P0-4 QuickJS 结果隔离
- **第三批（性能/内存）**：P1-1、P1-2、P1-3、P1-4
- **第四批（工程债/安全）**：P1-5、P1-6、P1-8、P1-9、P1-10
- **P2**：按 UX/功能价值另行排期，优先处理 P2-1 死入口与电台占位

## 新 UI 架构决策（2026-11-23 定稿）

> 本轮先定架构，不写代码。目标是把「Shell / BottomOverlay / MiniPlayer / FullPlayer」职责拆清，并为后续 AOSP 取色与实现留出稳定边界。

### 技术路线

- [x] 继续 Flutter，不转 Kotlin Compose
- [x] `m3e_core` 只作组件库：其组件读 `material_ui` 的 `Theme.of(context)`，不需要 `M3ETheme` / `M3EMaterialApp`
- [x] `material_3_expressive` 只作组件库：组件需要 `M3ETheme` 祖先，但仅使用静态 `M3ETheme(data: ...)` 注入
- [x] 不使用 `M3EMaterialApp`、`M3EThemeScope`、`M3EDynamicColorHost`、`M3ETheme(dynamicColoring: true)` 作为应用外壳
- [x] Shell、Root Navigator、页面路由、主题生命周期、动态色、亮度全部自管
- [x] 两套组件共享同一份 `ColorScheme`：`ThemeData(colorScheme:)` 给 `material_ui` / `m3e_core`，`M3EColorScheme.fromColorScheme(...)` 给 `material_3_expressive`
- [ ] 新增 `AppThemeHost`：`Theme` + 静态 `M3ETheme` 放在 `MaterialApp.builder` 中、Root Navigator 之上，保证 dialog / sheet / menu overlay 也能拿到两套主题
- [ ] 处理包内同名 `M3EColorScheme`：`m3e_core` 与 `material_3_expressive` 使用 import prefix 或 `show` / `hide`

### 导航栏重设计

> 2026-11-24 现状校正：底部 tab 已是「首页 / 媒体库 / 统计 / 电台」4 tabs；Settings 已从底部移除、改由首页 AppBar 折叠态进入。以下 2026-11-23 记录保留为架构演进历史。

- [x] 备份旧导航栏与测试到 `backup/navigation/2026-11-23/`
- [x] 新增独立 `AppFloatingNavBar`：`M3EFabHorizontalFloatingToolbar` + 3 个可展开 tab + 独立 Search FAB
- [x] Search 不参与 tab 选中；FAB 使用 `M3EFabSize.medium` + `M3EFabColor.primary`
- [x] tab 宽度 token：`floatingNavTabCollapsed = 46` / `floatingNavTabExpanded = 100` / `floatingNavTabHeight = 48`；FAB = 56
- [x] 组件使用 `motor` 的 `SingleMotionController` + `M3E.expressiveSpatialFast` 做 tab 展开/收起
- [x] 新增直接依赖 `motor: ^1.1.0`（原先为 transitive）
- [x] 组件文件 `lib/design/components/navigation/app_floating_nav_bar.dart` 已导出
- [x] `MobileShell` 已迁移到 `AppFloatingNavBar`：3 tabs + Search FAB；移除旧 morphing tab bar 引用
- [x] Search FAB 改为 push `MobileRoutes.search`（`MobileSearchPage`），移除 shell inline search 状态
- [x] MiniPlayer 暂从 `bottomAccessory` 拆出，作为 nav 上方 Column 的临时迁移形态（下一步改 BottomOverlay）
- [x] 更新 `mobile_shell_navigation_test` / 新增 `mobile_shell_search_fab_test`（未运行测试）
- [x] 迁移后仅运行 `flutter analyze`：改动文件无问题；全项目剩余 29 条既有 info/warning，无新增 error
- [x] 移除 Search FAB 的 `tooltip`：当前 Shell 在 Navigator/Overlay 外，`RawTooltip` 会报 `No Overlay widget found`；无障碍 label 保留在 Semantics
- [x] MiniPlayer 的 `M3EIconButton.tooltip` 改为 `semanticLabel`，避免播放歌曲后同样触发 Overlay 缺失
- [ ] 完成 BottomOverlay 架构：MiniPlayer 独立悬浮、NavBar 在上、slide/clip/hit-testing
- [ ] 完成 FullPlayerRoute / 临时导航 / Shell 状态保活
- [ ] 不自动进行 adb 截图/真机运行；需要真机时先询问

### 颜色与 AOSP 对齐

- [x] 现状确认：`MaterialYouThemeHost` 使用 `DynamicColorPlugin.getCorePalette()` 读取 AOSP 系统 tonal palettes，再经 MCU `DynamicScheme` 重建全部角色
- [x] 现状确认：`material_3_expressive` 内置 `M3EDynamicColorHost` 只取 CorePalette 的 primary 当 seed，再 `ColorScheme.fromSeed`；会丢失 secondary / tertiary / neutral palettes
- [x] 现状确认：`M3EThemeScope` 内置动态色还会对 error / success / warning 做 harmonize，不适合作为 AOSP 对齐路径
- [x] 现状确认：`m3e_core` 的 `M3EColorScheme` 是从 seed 生成 / 混合 `systemColorScheme` 的工具，不是 AOSP 最终角色直通
- [x] 决策：标准 Material 3 角色优先直接使用 AOSP 最终角色，或复刻 Compose 的固定 light/dark tone 映射；不再对标准角色使用 `fromSeed`
- [x] 决策：`M3EColorScheme.fromColorScheme` 只负责接收标准角色并派生 M3E 扩展角色；扩展角色不声称与 AOSP 完全一致
- [x] `MaterialYouThemeHost` 同时注入动态 `Theme` 和 `M3ETheme`，让 `m3e_core` 与 `material_3_expressive` 使用同一套 ColorScheme
- [x] 移除 `M3EMaterialApp`：它在 `appBuilder` 的 child 内部又包了一层静态 `M3ETheme`，会 shadow 外层动态 host；改用 `MaterialApp` + `MaterialYouThemeHost`
- [x] 标准 `MaterialApp` 使用 `theme` / `darkTheme` / `themeMode`，动态 host 根据当前 brightness 生成对应壁纸色
- [ ] 实现颜色来源方案：优先新增平台通道返回 AOSP 最终角色；若复杂度高，则实现 Compose 风格 `CorePalette -> 固定 tone -> ColorScheme`
- [ ] 保留 `MaterialYouThemeHost` 作为回退（桌面 / 无动态色 / 旧 Android），但标准角色路径切换为直通映射
- [ ] 建立 color debug 对比：AOSP 角色值 vs Flutter `ColorScheme` vs M3E 扩展角色
- [ ] 明确 `harmonized()` 只影响 error / success / warning，不修改标准角色

### Shell 与 BottomOverlay

- [x] Root Navigator 结构：`AppShellRoute` 与 `FullPlayerRoute` 同级；Shell 必须作为持久 Route 留在栈中
- [x] `AppShellRoute` 内部：页面层 full-bleed；MiniPlayer / NavBar 是悬浮覆盖层，不参与页面布局、不改变页面约束
- [x] Shell 使用 `Stack(fit: expand)`：`Positioned.fill(NavigationHost)` + `Positioned(bottom: 0, left/right: 0, child: BottomOverlay)`
- [x] `BottomOverlay` 内部再使用 `Stack`：MiniPlayer 在下、BottomNavBar 在上；Navigation Bar 最后绘制
- [x] BottomOverlay 使用固定高度 `navBarHeight + miniPlayerHeight`；不再用 Column / 高度增长挤压页面
- [x] MiniPlayer 隐藏方式：向下平移自身高度到 NavBar 后面 + `Clip.hardEdge` + `IgnorePointer` + `ExcludeSemantics`
- [x] MiniPlayer 可见时页面不重排；页面内容可以滚动到悬浮层下面
- [x] 页面级底部留白改为页面自己的 scroll padding / content padding，不由 Shell 强制改 layout
- [x] 移除 `AppMorphingTabBar` 的 `bottomAccessory` 职责；MiniPlayer 改由 `AppBottomOverlay` 管理
- [x] 将 `MobileShell` 从 `MaterialApp.appBuilder` 包裹 Root Navigator 的结构，迁移为 Root Navigator 中的 `MobileShellPage`
- [x] 新增 `mobileRootNavigatorKey` + `mobileNavigatorKey`：Root Navigator / Tab Navigator 分离
- [x] Full Player 改由 `pushMobileRootRoute` 推到 Root Navigator，可覆盖 Shell
- [x] 新增 `AppBottomOverlay`：固定高度、页面 full-bleed、NavBar 在 MiniPlayer 上层
- [x] 使用 `AppBottomInsetScope` 提供悬浮 chrome 高度；页面自行用于 scroll/content padding，Shell 不包裹页面
- [x] 拆分 `MiniPlayer` 与 `AppMorphingTabBar`：Shell 使用 `AppBottomOverlay` + `AppFloatingNavBar`
- [x] `AppBottomOverlay` 内用 `AnimationController` 驱动 MiniPlayer slide / fade / clip / hit-testing
- [x] MiniPlayer overlay 高度使用 `miniPlayerAccessory = 96`：`M3EToolbar.floating` 的 64 高 pill + 上下各 16 外部 padding
- [x] 当前歌曲出现时 MiniPlayer 从 NavBar 后滑出；无当前歌曲时滑回并清空 hit test
- [x] BottomOverlay 在 MiniPlayer 隐藏时，上方透明区域不拦截页面点击（IgnorePointer + Stack 无空白子节点）
- [x] Shell 不再包裹/压缩页面；`AppBottomInsetScope` 仅提供悬浮 chrome 高度，供页面自己的 scroll/content padding 使用
- [ ] 更新 `mobile_shell_navigation_test` / `app_morphing_tab_bar_accessory_test` 以匹配新分层
- [x] 页面级底部 scroll padding：Shell 传 `floatingChromeInset`，Home/Library/Stats 等已有 padding 重新生效
- [ ] 新增 Shell overlay / MiniPlayer slide / FullPlayer Route 回归测试

### Full Player

- [x] Full Player 是 Root Navigator 上的真实 Route，覆盖整个 Shell（含 BottomOverlay）
- [x] Full Player 关闭通过 Route Pop；普通返回路径正确
- [ ] Predictive Back 下 Full Player 返回层级错误（Flutter 已知问题，见下）
- [x] Shell 在 Full Player 打开期间保持存活；滚动位置、Tab、搜索、列表状态不得重建
- [x] 第一版不做 Full Player 内部 Nested Navigator
- [x] Queue 采用 Modal / Sheet；Lyrics 采用播放器内展示模式或按交互决定独立 Route；Artist / Album / Settings 走正常业务 Route
- [x] 只有 Full Player 内部出现独立页面历史且需要恢复时，才引入 Nested Navigator
- [x] 新增 `mobileFullPlayerRoute`：PageRouteBuilder fade/slide 转场；封面使用 Hero 共享元素
- [x] MiniPlayer 点击 / 上拖阈值触发 `pushMobileFullPlayer`；pop 后回到 MiniPlayer 且 Shell 状态保持
- [ ] 处理 Full Player 内子页面返回顺序：子页面 → Full Player → Shell
- [ ] 不在 Full Player 打开时重新创建 Shell 或重新初始化播放器

### Home 页重写

> 以下为 2026-11-23 首轮重写记录；其中「继续听 / 最新添加 / 为你推荐」等内容已在 2026-11-24 被「最新发行 / 为你发现 / 最近加入」取代，当前状态以「2026-11-24 首页 / 导航 / 设置校正」为准。

- [x] 备份旧 `MobileHomeContent` 到 `backup/home/2026-11-23/`
- [x] 首页 gutter token 化：普通 section 使用 `AppLayout.gutterFor(width)`（手机 16）；继续听 carousel 使用 `AppLayout.carouselGutter = 8`；Home 页禁用 `AppPageBody` 全局 gutter，各 section 自行应用
- [x] 最新添加 / 重拾旧爱 / 为你推荐 header 使用 `AppInsets.sectionHeader`：上 8、下 16
- [x] 所有移动端页面背景映射为 `surface`（`AppSurfaceLevel.base` / `colorScheme.surface`）；所有页面 AppBar 背景统一为 `surface`（Home 展开/折叠、Library、Search、Stats、设置/详情共用 helper；取色映射页按需求保持纯白）
- [x] Home 文本颜色全部走主题 role：主文本 `onSurface`，副标题/来源/时间 `onSurfaceVariant`；封面标题和 carousel 歌名不再硬编码白色；专辑封面底部 scrim 改用 `surface` 动态色
- [x] 顶部改为 `M3ECarousel`（hero-left、横向）：首张更宽，item gap 不变
- [x] Home 顶部改用 `M3EAppBar.top`：largeFlexible、regular、square、safeArea、默认展开、滚动不隐藏；展开标题“继续听”，折叠标题“首页”并在下方显示 subtitle“浏览音乐库近况”，使用 260ms fade + slide 过渡；折叠标题显式使用 `titleLarge`，避免过渡瞬间仍继承 `displaySmall` 导致标题块溢出
- [x] 轮播图卡片内不再显示 `继续听`，只保留歌曲名
- [x] 轮播图卡片歌名改为无 icon 的 `m3e_core.M3EButton`（filled/sm/round），按钮承担动态配色与可读性；carousel scrim 设为 none
- [x] 设置 `applyDynamicTextContentTransform: false`，避免 M3E 按 slot 大小隐藏 title
- [x] 数据暂用当前播放队列；点击卡片播放对应曲目
- [x] 轮播图右下角增加“查看更多”占位按钮（`m3e_core.M3EButton.icon`，tonal/sm/round，眼睛图标，按 `carouselGutter` 对齐）
- [x] 最新添加：最多 3 张垂直卡片（非轮播），卡片之间加 `M3EDivider`，最后一首后不加；末尾右下角“查看更多”占位；本地 + Subsonic、M3ECard、艺术家头像/来源/发行年份、添加相对时间、收藏占位按钮
- [ ] 最新添加：真实收藏逻辑与专辑详情跳转
- [x] 很久没听：`重拾旧爱` 横向 `cookie9Sided` shapes，艺术家名在下方；数据暂从 longTimeNoSee 推荐专辑按艺术家去重，头像暂用专辑封面
- [ ] 很久没听：接入真正的艺术家级最近播放/长期未听统计与艺术家详情跳转
- [x] 为你推荐：横向 square shapes 歌曲列表，使用推荐专辑曲目去重，点击播放；封面暂用曲目封面
- [ ] 为你推荐：接入歌曲级推荐与真实歌单封面来源
- [ ] 将“继续听”数据源替换为真实播放历史

### 已知问题：Predictive Back + 多 Navigator 交错

- 现象：Home → Library → MiniPlayer → FullPlayer 后，第一次侧滑返回仍停留在 FullPlayer，但底层已从 Library 变为 Home；第二次侧滑才退出 FullPlayer。
- 当前路由栈：
  - Root Navigator: `[MobileShellPage, FullPlayerRoute]`
  - Shell 内 Tab Navigator: `[Home, Library]`
- 根因：Flutter Predictive Back 在多个 Navigator 交错（interleaved routes）时会错误 pop 底层 nested Navigator 的路由，而不是最上层 Root Route。
- 相关 issue：
  - flutter/flutter#152578
  - flutter/flutter#152323
- `NavigatorPopHandler` 不能解决这个交错路由问题；它只处理 Shell 在最上层时的 nested 返回。
- `AndroidManifest.xml` 当前为 `android:enableOnBackInvokedCallback="true"`。
- 待选方案：
  - A. 临时关闭 `enableOnBackInvokedCallback`，验证是否恢复正常（会失去 Predictive Back 预览）
  - B. 扁平化 Navigator：单一 Root Navigator + Tab 状态容器
  - C. Full Player 改到 Tab Navigator，Shell 隐藏 chrome（Hero 可能需重做）
  - D. 自定义 Route 覆盖 `isCurrent`，处理祖先 Route current 状态
- 当前状态：问题已记录，尚未修改代码；方案待定。

### 状态模型

- [x] `PlaybackState`: `Idle` / `Playing` / `Paused`，只负责音乐播放
- [x] `PlayerPresentationState`: `Hidden` / `Mini` / `Full`，只负责播放器界面展示
- [x] 有当前歌曲时至少 `Mini`；暂停不改变 Presentation，MiniPlayer 不消失
- [x] 关闭 Full Player 后回到 `Mini`，播放继续
- [x] 动画进度不是状态：Hidden ↔ Mini 的 slide progress、Mini ↔ Full 的 route progress 单独管理
- [x] 第一版 `Hidden` 表示无当前歌曲；若未来允许用户手动隐藏 Mini，必须单独建模，不能复用 `Hidden`
- [ ] 新增全局 `PlayerController`（歌曲 / 播放状态 / 进度 / 队列 / 模式）
- [ ] 新增 `PlayerPresentationController`（Hidden / Mini / Full 目标状态 + 各动画进度）
- [ ] 播放器状态与页面生命周期解耦；页面 pop 不影响播放

### 动画策略

- [x] 第一版分离：MiniPlayer 使用独立 `AnimationController`；Full Player 使用 Route Transition
- [x] 点击 Mini → push `FullPlayerRoute`；Mini 保持 Mini 状态，由 Route 覆盖，不需要先自己消失
- [x] Hero 只负责封面 / 共享元素；整页展开仍由 Route Transition 负责
- [x] 上拖 Mini 第一版采用阈值触发 push；不做手指连续跟手 morph
- [ ] 只有当「拖动 Mini 连续展开 / 下拉 Full 连续收回 / 中断反向吸附」成为核心体验时，再引入共享 `PlayerExpansionController`
- [ ] 共享 controller 必须同时解决：手势中断、Route 动画、系统返回、预测性返回、Mini hit testing

### 本轮明确不做

- [x] 不把 Compose / Kotlin 重写作为当前路线
- [x] 不做 Full Player 内部 Nested Navigator
- [x] 不做 Mini ↔ Full 单一连续 AnimationController
- [x] 不让 BottomOverlay 高度变化挤压页面布局
- [x] 不在 Shell 层强制页面 bottom padding


## 当前优先事项（2026-11-10）

> 排序原则：用户可见错误 > 稳定性/安全 > 功能补齐 > 工程债。
> 详细背景见各阶段条目与“已知问题 / 技术债”。

### P0 正确性与用户可见问题

- [x] 修复 LX 播放统计来源：`PlaybackSessionTracker` 使用 `source=lx` + 平台 `sourceId`
- [x] 搜索建议增加 300ms 防抖：`LibrarySearchSuggestions` 改为 debounce 后再触发网络搜索
- [x] LX 源导入/启用/禁用/删除/改优先级后刷新播放能力（现为 `lxPlayablePlatformsProvider`）与 `lxSearchProvider`
- [x] LX 冷启动改为懒加载：`init_lx_source_store` 只打开 store，list/search 首次需要能力时再加载启用源
- [x] 缓存管理重做：总缓存上限滑块、启动时套用、UI 默认值与实际分配对齐、清理缓存时同步清理内存缓存；页面进入自动重扫、可见期间 3 秒刷新、支持下拉刷新（`flutter analyze` / `flutter test` 通过）
- [x] 为 QuickJS 增加执行超时、内存上限、中断与死循环保护（新增死循环中断测试）
- [x] 本地音乐库改为单 SAF tree 目录：`saf.walk` 发现文件，原始 fd 经 `dup` 交给 Rust；标签/内嵌封面/内嵌歌词真机验证通过
- [x] 设置页增加“下载目录”（独立 SAF tree + 持久授权）与“是否在音乐库内”判断
- [ ] 下载写入 SAF、目录结构模板、下载后增量扫描
- [x] `PlaybackBackend` 增加 buffering / error / processing phase，`LaetibeatAudioHandler` 映射真实 `processingState` 与 `bufferedPosition`

> Android 本地音乐定稿（2026-11-10）：只允许一个音乐库目录；用户选择哪个 SAF 目录就扫描哪个，不做多根合并。下载目录单独在设置中选择，可等于音乐库目录、音乐库子目录或独立目录；独立目录不自动进入音乐库。首次启动引导页后续复用同一套设置。

### P1 稳定性与架构债

- [x] LX 源 id 改为基于 manifest 身份的稳定 id，脚本 hash 仅作版本字段（含旧记录迁移与重复合并）
- [ ] `lx.request` 从同步 `reqwest::blocking` 改为异步 request broker，支持取消
- [x] LX 歌词/封面持久化缓存，并与缓存分组统计对齐
- [ ] 远端同步支持增量、取消与进度节流；推荐避免全量加载远端曲目
- [ ] 统一 `source` 类型（local / opensubsonic / lx）为常量或枚举，清理字符串字面量
- [x] 媒体库首页入口化：现有歌曲/专辑/艺术家/歌单内容保留为子页面，首页只做入口导航
- [x] 媒体库详情页来源筛选：歌曲/专辑/艺术家/歌单页已完成“全部/本地/Navidrome”chips 与来源 badge
- [ ] 清理死代码：`AudioSource`、`PlayState`、`SourceType::Opensubsonic`、`linux_mpris.dart`、`tmp.dart.bak`、未引用的移动首页组件
- [ ] 更新 `ARCHITECTURE.md`：当前移动端播放后端、单 Navigator、audio_service 状态
- [x] 在可用 Flutter 环境复验 `flutter analyze` / `flutter test`（2026-11-22；analyze 剩余 6 条均为既有 warning/info，`lib/design/` 无新增问题；test 14 个通过）
- [x] 设计系统 token 化：`lib/design/` 新增颜色/字体/间距/圆角/尺寸/动效/断点 token；`AppTheme` 成为 `M3EThemeData` 唯一入口
- [x] Material You 官方取色：接入 `material_color_utilities` + `dynamic_color`，`MaterialYouColorScheme` 从官方 `DynamicScheme` 解析全部角色，`MaterialYouThemeHost` 使用系统 CorePalette；关闭 M3E 自带 `dynamicColoring`
- [x] 优先读取 Android 最终 system color resources（`system_primary_light` 等）：Kotlin MethodChannel `com.otimeum.laetibeat/system_colors` + `SystemColorSource`；`MaterialYouColorScheme.fromSystemRoles` 直接映射标准角色；失败回退 CorePalette / accent seed
- [x] 页面 gutter 契约：`AppLayout.pageGutter` + `AppPageBody` 作为唯一水平 inset；`AppScaffold` 默认套用；`AppSectionHeader` / `AppMediaRow` / `AppEmptyState` 默认水平 padding 归零
- [x] 基础组件拆分：`AppArtwork`（尺寸/形状/占位）、`AppText`、`AppSurface`、`AppMediaRow`、`AppMediaTile`、`AppEmptyState`
- [x] 新增 `test/design_system_smoke_test.dart`：Material You light/dark 角色、主题宿主渲染、Section 与 MediaRow 左边缘对齐
- [x] 新增 `AppMorphingTabBar`：默认 tab pill + 搜索 pill + extra action；搜索态为 leading pill + 搜索框；M3E 颜色/圆角/字体/tab 语义
- [x] 新增 `test/app_morphing_tab_bar_test.dart`：默认态渲染、点击搜索进入搜索态、搜索框与 collapsed leading 出现
- [x] `AppMorphingTabBar` 第二阶段：tab pill ↔ search pill 的 spring morph、宽度/位置动画、键盘上浮、反向 retarget
- [x] 新增 `test/app_morphing_tab_bar_animation_test.dart`：搜索展开/关闭时左右 pill 宽度变化与反向 retarget
- [x] 新增 `test/app_morphing_tab_bar_compact_test.dart`：320dp 宽度下默认态与搜索态无溢出
- [x] 新增 `test/app_morphing_tab_bar_search_action_test.dart`：`onSearchPressed` 外部搜索动作不触发 inline morph
- [x] 新增 `test/mobile_shell_navigation_test.dart`：MobileShell 使用 morphing bar，Home → Stats 顶层切换
- [x] 新增 `test/app_morphing_tab_bar_accessory_test.dart`：bottom accessory 渲染，搜索态收起并缩短整体高度（旧架构测试，待迁移到 BottomOverlay）
- [x] `AppMorphingTabBar` 接入 shell：Home / Library / Stats 三个顶层 tab；MiniPlayer 作为 bottom accessory（已被 2026-11-23 独立 BottomOverlay 架构取代，待拆分）
- [x] 浮动导航改为 `Stack` overlay，移除 `Scaffold.bottomNavigationBar` 的全宽背景板；`AppBottomInsetScope` 为页面提供底部留白（新架构改为页面 full-bleed，`AppBottomInsetScope` 仅保留为可选 floating chrome metrics）
- [x] ~~底部导航加入 Settings 顶层 tab~~（2026-11-24 已移除；改为 Radio，设置入口移至首页 AppBar 折叠态）
- [x] 媒体库 AppBar 右侧增加 `m3e_core.M3ESplitButton` 来源选择：本地 / Navidrome / 洛雪，默认本地；滚动时 AppBar 不隐藏；SplitButton 直接使用 intrinsic 宽度，end-aligned 向左扩展
- [x] `librarySourceFilterProvider` 改为派生自外观设置 `defaultSongSourceProvider`：右上角 SplitButton 与设置页歌曲来源双向同步；支持全部 / 本地 / Navidrome / 洛雪
- [x] `SongSources.all` 增加洛雪；曲库 / 专辑 / 艺术家 / 歌单子页统一读取来源过滤，不显示各自 chips
- [x] 设置 > 外观新增“当前取色映射”：白底页面列出 M3EColorScheme 全部角色、名称与 ARGB 值，路由 `/settings/appearance/color-mapping`
- [x] 媒体库去掉搜索框与旧入口，改为 `M3EExpandableSegmentedItem` 五项：曲库 / 专辑 / 艺术家 / 歌单 / 电台；默认折叠，可展开进入子项；颜色恢复为组件默认映射
- [x] 曲库列表改用 `m3e_core.M3ESegmentedList.builder`：multiple + 首次 longPress 进入选择，选中后 tap 连续多选；使用给定 decoration 参数
- [x] m3e_core 没有 FastScroller/Scrollbar；曲库移除滚动条，`M3ESegmentedListDecoration` 对齐官方参考：outer 24 / inner 16、gap 6、padding 4、margin 12×5
- [x] Segment 展开内容改为自适应横向封面行：`M3EShapeContainer.square` 64dp，根据可用宽度计算显示个数，不横向滚动；点击 header / 内容区均展开折叠，最右侧 icon-only 圆形按钮进入详情页
- [x] 设置 > 内容设置新增“音源配置”入口，跳转 `MobileMusicSourcesPage`
- [x] `AppMorphingTabBar` bottom accessory：搜索态自动收起；extra action 的搜索态收起由 `hideExtraActionWhenSearching` 控制
- [x] 新增 `MobileSearchInlineView`：复用搜索历史与 `LibrarySearchSuggestions`，搜索框由 shell 的 controller/focusNode 驱动
- [x] `MobileShell` inline search：搜索态替换 body、`PopScope` 返回关闭、提交后推入现有结果页
- [x] 新增 `MobileSearchBrowseView`：Apple Music 式两阶段搜索，未聚焦显示 2×2 流派卡片（假数据）
- [x] 搜索框聚焦后进入输入态：home pill 隐藏，搜索字段占左侧，右侧出现独立 clear pill
- [x] `AppMorphingTabBar` 新增 `searchEditing` / `onSearchClear`，保持搜索字段 element 稳定，避免聚焦后键盘被重布局收起
- [x] 新增 `test/mobile_shell_inline_search_test.dart`：browse → 聚焦输入 → clear 关闭搜索
- [ ] 把底部搜索框移入 Navigator Overlay，恢复文本选择/复制菜单（当前禁用 selection overlay 规避 Overlay 缺失）
- [x] 页面迁移试点：Home / Library 已改用 `AppScaffold` / `AppPageBody` / `AppText` / `AppSpacing` / `AppRadii` / `AppSurfaceLevel`；Library 搜索栏 `margin: 0` 与卡片对齐
- [ ] 页面迁移剩余：Search / Settings / Playback / Library 子页统一到 design token
- [ ] 统一 UI 代码 import 到 `material_ui`，清理 `package:flutter/material.dart`（当前仍有 18 个文件）
- [ ] 补充 `AppTopBar`（AppBar 标题/leading 与页面 gutter 对齐）、按钮、输入框、卡片等交互组件封装
- [ ] 页面内硬编码颜色/字号/间距清零，全部改用 design token
- [ ] 补充播放队列、搜索、缓存管理的回归测试
- [ ] 补齐仓库 LICENSE / 第三方 NOTICE，确认 QuickJS / FFmpeg 分发合规
- [ ] Android cleartext 改为按域名白名单的 network security config

### P2 功能补齐

- [ ] 收藏/喜欢（本地 + OpenSubsonic star/unstar）
- [x] 本地歌单 CRUD 与加入歌单（新建/重命名/删除/加歌/移歌/排序/详情播放）
- [ ] 队列编辑（加入队列、下一首播放、删除、拖动排序、清空）
- [ ] 下载
- [ ] 移动端首页推荐/历史接入，或删除孤立组件
- [ ] MPRIS 迁移到 audio_service，或彻底移除旧实现
- [ ] 高级 DSP / ReplayGain / 响度归一

## 设计系统与 Token 化（2026-11-22）

### 目标

- 单一主题入口：`lib/design/theme/app_theme.dart` 构建 `M3EThemeData`
- Material You 取色对齐 Google 官方：使用 `material_color_utilities` 的 `DynamicScheme` 解析全部角色，而不是只取 CorePalette.primary 再重新 seed
- 全部 token 化：颜色、字体、间距、圆角、尺寸、动效、断点
- 组件按用途拆文件：封面 `AppArtwork` 单独文件，尺寸/形状/占位也分别拆文件
- 所有页面内容左右 gutter 一致：`AppLayout.pageGutter` + `AppPageBody`
- 本轮只建设计系统，不修改具体页面

### 已完成

- [x] 目录：`lib/design/{tokens,theme,components}` + `design.dart` 出口
- [x] 颜色 token：`AppColorTokens`、`AppColorRole`、`AppSurfaceLevel`
- [x] 字体 token：`AppTypography`（Google Sans Flex + CJK fallback）；`AppTextRole` 映射 M3 15 个 type role
- [x] 间距/圆角/尺寸/动效/断点 token：`AppSpacing`、`AppRadii`、`AppIconSize`、`AppComponentSize`、`AppMotion`、`AppBreakpoints`
- [x] 布局 token：`AppLayout.pageGutter`、`AppLayout.gutterFor(width)`、`AppLayout.maxContentWidth`
- [x] Material You：`MaterialYouColorScheme.fromSeed()` / `fromCorePalette()`；支持 tonalSpot / fidelity / content / vibrant / expressive / neutral / monochrome / rainbow / fruitSalad
- [x] `MaterialYouThemeHost`：Android 使用系统 CorePalette 全部 palettes；桌面回退 accent color / 品牌 seed；resume 时刷新
- [x] `AppTheme.light/dark/build` 统一 typography / spacing / iconTheme / visualDensity
- [x] 封面组件：`AppArtwork`、`AppArtworkSize`、`AppArtworkShape`、`AppArtworkPlaceholder`
- [x] 文本组件：`AppText`、`AppTextRole`
- [x] 容器与布局：`AppSurface`、`AppScaffold`、`AppPageBody`、`AppSectionHeader`
- [x] 媒体内容：`AppMediaRow`、`AppMediaTile`
- [x] 反馈：`AppEmptyState`
- [x] 导航：`AppMorphingTabBar` spring morph（tab pill ↔ search pill、键盘上浮、反向 retarget；M3E 颜色/tab 语义）；已接入 `MobileShell` 的 Home / Library / Stats 与 inline search
- [x] 导航选中态：整格 pill 同时包住 icon + label，移除 icon-only 小胶囊；InkWell 关闭 splash/highlight，避免点击时大阴影叠加
- [x] 导航 tab 支持左右拖动切换；选中 pill 使用 `AnimatedPositioned` 动画，点击切换同样滑动
- [x] 新增 `test/app_morphing_tab_bar_tab_drag_test.dart`：点击动画中间位置 + 横向拖动切换
- [x] App 根节点接入：`app.dart` 使用 `MaterialYouThemeHost`，关闭 M3E 自带 `dynamicColoring`
- [x] `AppThemeFactory` 委托到 `lib/design`，不再自写 seed / 字体
- [x] 验证：`flutter analyze` 无新增问题；`flutter test` 14 个通过（含 gutter 对齐、morphing tab bar 状态/宽度动画/点击与拖动切换/320dp、shell 导航、bottom accessory 与 inline search 回归测试）

### 页面 gutter 契约

| 层 | 水平 padding | 说明 |
|---|---|---|
| `AppScaffold` / `AppPageBody` | `AppLayout.pageGutter` | 唯一页面 gutter |
| `AppSectionHeader` | 0 | 继承页面 gutter |
| `AppMediaRow` | 0 | 垂直 8；继承页面 gutter |
| `AppSurface` | 0（外部） | 只设内部 padding |
| `AppMediaTile` | 0（外部） | 由 carousel 持有 gutter |
| `AppArtwork` | 0 | 只决定尺寸/形状 |
| `AppEmptyState` | 0 | 垂直 24；继承页面 gutter |
| 横向 carousel | `AppLayout.pageGutter` | 自己持有，保证可滚到边缘 |
| Bottom Sheet / Dialog | `AppLayout.pageGutter` | 与页面一致 |
| AppBar | 同一 gutter token | 通过 `contentPadding` / 后续 `AppTopBar` 统一 |

### 待办

- [x] 页面迁移试点：Home / Library 已改用 `AppScaffold` / `AppPageBody` / `AppText` / `AppSpacing` / `AppRadii` / `AppSurfaceLevel`
- [ ] 页面迁移剩余：Search / Settings / Playback / Library 子页
- [x] `AppMorphingTabBar` inline search 与路由联动：已用 `MobileSearchInlineView` 接入 shell，提交后进入现有结果页
- [ ] 抽取搜索历史 store，消除 `MobileSearchPage` 与 `MobileSearchInlineView` 的重复逻辑
- [x] ~~Mini Player bottom accessory：已从 overlay 迁入 morphing bar 上方，搜索态自动收起~~ 已被 2026-11-23 独立悬浮 BottomOverlay 架构取代，待拆分
- [ ] 新增 `AppTopBar`，统一 AppBar leading/title/actions 与页面 gutter 对齐
- [ ] 补齐交互组件：按钮、图标按钮、输入框、卡片、Chip、Bottom Sheet 的 token 封装
- [ ] 统一 UI import 到 `material_ui`，清理 18 个 `package:flutter/material.dart` 文件
- [ ] 页面内硬编码颜色/字号/间距清零
- [ ] 桌面端响应式：`AppPageBody.maxContentWidth` + NavigationRail + 右侧播放面板
- [ ] 视觉回归：360 / 412 / 768 / 1280 宽度，light/dark，动态色开/关，文本缩放 1.3 / 2.0

## 搜索页 LX 单平台分类路由重构（2026-11-17）

### 目标

- 搜索结果页默认来源仍为本地；只有用户选择“洛雪”后才走 LX。
- 选择洛雪后，默认平台必须是**第一个已启用的洛雪源**（当前为 QQ 音乐），不是写死酷我。
- LX 一次只查询一个平台，绝不聚合所有洛雪源。
- 分类决定只搜索对应内容：
  - 歌曲 → 当前平台歌曲
  - 歌单 → 当前平台歌单
  - 专辑 → 当前平台专辑
  - 艺术家 → 当前平台艺术家
- 切换平台（QQ/酷我/网易等）后，当前分类结果只来自该平台。
- “全部”来源不包含 LX；LX 仅在明确选择洛雪来源时启用。

### 实施

- [x] TODO 记录
- [x] `_lxPlatform` 改为可空，并从已启用源顺序取第一个作为默认
- [x] 平台选择器只展示已启用平台，顺序与源列表一致
- [x] 移除歌曲“全部”分类中的全 LX 平台聚合
- [x] 移除 `_SearchResults` 中无条件监听所有 LX 平台的逻辑
- [x] 歌单分类只使用当前 LX 平台
- [x] 专辑分类接入当前 LX 平台结果
- [x] 艺术家分类接入当前 LX 平台结果
- [x] 验证切换平台后不会触发其他平台请求
- [ ] 专辑/艺术家目前由当前平台歌曲结果聚合，后续补平台原生专辑/艺术家搜索接口

## 搜索与 LX 音源解耦（2026-11-18 已实施，待真机复验）

> 结论：**搜索能力是内置的，和用户导入的音源脚本无关**。只有"解析播放地址"才需要已启用源。
> 参考项目的对应实现：`src/core/search/music.ts` 直接调用内置 `musicSdk[source].musicSearch`，
> 与 `inited` 声明的自定义源完全无关；自定义源只在 `musicUrl` 阶段介入。

### 问题（已修复）

- 搜索页把"平台列表"从已启用源的 `capabilities` 推导，未启用源时整页被 `lxSearchEnableHint` 挡住，无法搜索/浏览/订阅。
- `LxSourceDeclaration.sources` 使用 `BTreeMap`，字典序（kg < kw < mg < tx < wy）导致默认平台恒为 `kg`（酷狗）；官方默认是 `kw`（酷我）。
- 默认平台 `kg` 的歌单搜索未实现，歌单分类只把原始英文错误当一行文字显示，看起来像"歌单无结果"。
- 本地歌单从未接入搜索页歌单分类；`filter=local` 与 `filter=all` 的歌单 tab 永不含本地歌单。
- `_LxPlatformResults` 硬编码 3 秒翻页延迟 + 每页 10 条，用户实际只能看到第一页。
- 搜索建议硬编码 `tx`（QQ），与当前选中平台无关。

### 决策

- **平台顺序跟随官方**：`kw → kg → tx → wy → mg`。该顺序即 `laetibeat_lx::search::SUPPORTED_PLATFORMS`，UI 直接消费 `supported_lx_search_platforms()`，不再依赖容器迭代顺序。
- **搜索 / 浏览 / 订阅与源解耦**：内置平台搜索无条件可用；只有播放需要已启用源。缺源时只提示，不封锁页面。
- **默认平台** = 内置顺序中第一个"有启用源声明 `musicUrl`"的平台；完全没有源时回退到内置第一个平台（`kw`）。
- **专辑 / 艺术家**保持"当前平台歌曲结果聚合"，不补全平台原生专辑/艺术家接口（后期有强需求再做）。
- **请求节流**：同一平台串行 + 最小间隔 300ms；取消 3 秒翻页延迟；每页 20 条；翻页由 `has_more` 与 `_loadingMore` 去重，避免滚动事件放大请求量。既能正常浏览，也不至于高频打接口。
- **不做跨平台聚合**：一次只查当前平台（维持 2026-11-17 的结论）。

### 实施

- [x] 拆分 provider：`lxPlatformsProvider`（内置、有序、恒可用）/ `lxPlayablePlatformsProvider`（源声明、仅播放门控）
- [x] 搜索页平台 bar 恒显示内置平台；无播放源的平台显示"未启用音源"标记
- [x] 移除"未启用源则整页提示"分支；无播放源时点击播放/播放全部改为提示导入或启用源
- [x] 默认平台改为"第一个可播放平台，否则内置第一个"
- [x] `_LxPlatformResults`：去掉 3 秒延迟、页大小 20、改走统一 gated 搜索入口
- [x] 歌单分类补本地歌单（`localPlaylistsProvider` → `LocalPlaylistDetailPage`）
- [x] 歌单分类对不支持的平台（当前 kg / wy / mg）显示明确文案，而不是原始错误
- [x] 搜索建议不再硬编码 `tx`，跟随当前默认平台
- [x] 清理死代码：`_buildSongs`、`_SongEntry`、`search_source.dart`、`_LxPlatformStatusBar`
- [x] l10n 新增 `lxSearchSourceRequired` / `lxPlaylistSearchUnsupported` / `lxPlatformNoSource`
- [x] `mobile_lx_sources_page` 改为 invalidate `lxPlayablePlatformsProvider`
- [x] `_playLxResults` 改为直接走 gated 搜索（原先读 `lxSearchProvider` 的缓存值，歌曲 tab 下可能为空导致按钮无效）
- [x] `cargo check --workspace` / `cargo test --workspace`（37 tests）通过
- [ ] 有 Flutter 环境时复验 `flutter analyze` / `flutter test`（本机无 Flutter SDK，Dart 改动未做编译验证）
- [ ] Android 真机验证：无音源时搜索/订阅可用、播放提示正确、切平台只发一次请求

### 第二轮：异常修复与歌单诊断（2026-11-18）

- [x] 修复进入搜索结果页必现的 `setState() called during build`：`initState` 里的 `ref.invalidate(lxPlayablePlatformsProvider)` 改为 `addPostFrameCallback` 后再执行（上一页 suggestions 仍 watch 该 provider，element 存活导致 invalidate 触发 scope 的 setState）
- [x] `songlist.rs` 补日志：`lx.playlist.search` / `lx.playlist.detail` / `lx.playlist.all` 记录 platform、page、limit、keyword 长度、返回条数、耗时与错误
- [x] QQ 歌单搜索失败重试：`code != 0` 时最多 3 次（官方为 5 次），200/400ms 退避
- [x] 搜索空态按分类区分：`searchNoPlaylistResults` / `searchNoAlbumResults` / `searchNoArtistResults`（原先歌单空态显示"没有找到歌曲"，容易被误判为"没反应"）
- [x] `cargo check --workspace` / `cargo test --workspace`（38 tests）通过
- [ ] 真机复验：进搜索页不再报错；`adb logcat -s LaetibeatLx` 能看到各平台歌单请求的条数与耗时
- [x] 定位 QQ 歌单"无返回"：真机日志为 `playlist response is not UTF-8: invalid utf-8 sequence of 2 bytes from index 667`
- [x] 修复：QQ `client_music_search_songlist` 返回的是**UTF-8 主体 + 被按字节截断的中文**（服务端会先截断再 HTML 转义，如 `&#46;`），严格 UTF-8 解码必然失败；改为宽松解码（`utils::decode_text`：严格 UTF-8 → 非法字节占比 <10% 用 lossy → 否则按 GB18030），并应用到 `songlist` / `search` / `http` 三条取文本路径
- [x] `clean()` 统一用 `html_escape::decode_html_entities`，QQ 描述里的 `&#10;` / `&#46;` 不再原样显示
- [x] 新增依赖 `encoding_rs`（GB18030 兜底），并加 `decodes_utf8_and_gbk_bodies` 测试
- [ ] 真机复验 tx 歌单：期望日志 `lx.playlist.search platform=tx ... items=N`
- [ ] 已知无法消除：QQ 超长描述会被服务端截断，末尾可能出现少量 � 替换符

### 第三轮：补齐 kg / wy / mg 歌单（2026-11-18）

- [x] 平台能力表（Rust 单一口径）：`songlist::PLAYLIST_SEARCH_PLATFORMS` + `supports_playlist_search()`，附测试；Dart 侧仍以错误信息降级（当前 5/5 支持，不会触发）
- [x] kg 搜索：`msearchretry.kugou.com/api/v3/search/special`（`page` 从 1 开始）
- [x] kg 详情：`mobilecdn.kugou.com/api/v5/special/info`（名称/作者/封面/播放量/简介）+ `v3/special/song`（歌曲），**两个都免签名**；歌曲 id 用 `album_audio_id`（与歌曲搜索的 `Audioid` 一致），`hash` 写入 `extra` 供 `musicUrl` 使用
- [x] wy 搜索：`eapi /api/cloudsearch/pc`（`type:1000`），复用抽出的 `search::eapi_json`
- [x] wy 详情：`eapi /api/v6/playlist/detail` 拿 `trackIds`（`tracks` 只返回 10 首）→ `eapi /api/v3/song/detail` 每批 200 个 id 批量取详情
- [x] mg 搜索：复用现有签名 + `searchSwitch.songlist=1`
- [x] mg 详情：`c.musicapp.migu.cn/MIGUM3.0/resource/playlist/v2.0`（信息）+ `app.c.nf.migu.cn/MIGUM3.0/resource/playlist/song/v2.0`（歌曲），免签名；字段与 `parse_mg` 一致（列表接口用 `songName`）
- [x] 分页修正：**mg 会把 `pageSize` 静默截到 50**，因此整单拉取按平台取页大小（mg 50 / 其余 1000），`has_more` 改为按实际返回条数计算；否则 100 首的歌单只能拿到 50 首
- [x] 抽出 `search::eapi_json`（wy 全平台复用）与 `search::mg_sign`（mg 搜索/歌单共用签名）
- [x] 单测：`supports_all_five_playlist_platforms`、`parses_kg_playlist_search_and_tracks`、`parses_wy_playlist_search_and_songs`、`parses_mg_playlist_search_and_tracks`、`parses_tx_playlist_summaries`（fixture 取自真实响应）
- [x] 真实网络冒烟（临时测试，跑完已删除）：5 平台歌单搜索 + 详情 + 整单拉取全部通过，条数与 `total` 一致（kg 194 / tx 223 / wy 145 / mg 100）
- [x] `cargo check --workspace --all-targets` 无 warning；`cargo test --workspace` 43 tests 通过
- [ ] 真机验证：切到 kg / wy / mg 的歌单分类能出结果、能进预览页、能订阅
- [ ] 已知限制：kg / mg 的整单拉取需要多页时请求数 = ceil(总数 / 平台页大小)；wy 每 200 首一次批量请求

### 第八轮：读路径与加载解耦（快照锁，2026-11-22）

问题：所有 LX 调用共用一把 `Mutex<Option<LxSourceManager>>`，后台预热（数秒）
会把 UI 的能力查询 `list_lx_sources` 一起堵住——预热等于白做。

- [x] 新增 `SNAPSHOT: OnceLock<RwLock<Vec<LxSourceEntry>>>`：`list_lx_sources` 只读它，
      **完全不碰 manager 锁**
- [x] 快照在 `with_manager` 结束时刷新（成功/失败都刷新，因为失败会改状态、清声明缓存）；
      `init_lx_source_store` 也发布一次初始快照
- [x] 锁顺序单一（先 manager 再 snapshot），不存在反向持锁，因此无死锁风险
- [x] 回归测试 `list_lx_sources_does_not_wait_for_manager_lock`：主线程持 manager 锁 2s，
      子线程调用 list 必须立刻返回（超时即失败，不会挂死）
- [x] `cargo check --workspace --all-targets` 无 warning；`cargo test --workspace` 51 tests 通过
- [ ] 仍串行（可接受，后续再解）：
      - `resolve_lx_music_url` / `resolve_lx_lyric` / `resolve_lx_pic` 在 JS 执行期间持有 manager 锁，
        两个并发的解析会排队
      - 预热期间点播放，解析会等预热做完（语义上可接受，源本来就在加载）
- [ ] 下一步（若要彻底并发）：每源一个 Actor（专用线程 + 消息队列），manager 只保存句柄；
      届时 `LxRuntime` 不再需要放在全局 Mutex 里

### 第七轮：LX 声明持久化 + 加载提速（第 2、3 步，2026-11-22）

目标：把"每次启动都要重新初始化"变成"装好一次，之后毫秒级"。

- [x] **持久化 `inited` 声明**：`LxSourceRecord` 新增 `declaration` / `declaration_hash` / `declaration_at`
      （`#[serde(default)]`，兼容旧 `index.json`）；`load_source` 成功后写回，失败时清除
- [x] **缓存失效**：`resolved_declaration()` 只在 `declaration_hash == script_hash` 时使用缓存，
      脚本更新/重新导入后自动失效
- [x] **`list_lx_sources` 不再加载脚本**：只读内存/缓存声明，"哪些平台能播"从秒级变毫秒级
- [x] **按需 `pump_timers`**：只有脚本没有同步 `send(inited)` 时才等定时器；
      初始化阶段预算降到 5s（`INIT_TIMER_BUDGET`）
- [x] **可中断等待**：`pump_timers` 里的 `thread::sleep` 改成 50ms 分片 + 检查墙上时钟 deadline
      （`set_interrupt_handler` 只能打断 JS 执行，打断不了 sleep，这是 20s deadline 跑出 25s 的原因）
- [x] Dart：`lxRuntimeProvider` 改为快照 `LxRuntimeSnapshot { playablePlatforms, warming }`；
      新增 `warmUp()`（后台逐个加载启用源，单飞去重）；`ensurePlayable` 复用它
- [x] Dart：启动预热即使已有缓存也照样加载，保证"进 App 后首次播放"也不用等
- [x] 删除派生的 `lxPlayablePlatformsProvider`，搜索页/建议页直接读运行时快照
- [x] 回归测试：
      - `synchronous_inited_does_not_wait_for_timers`：同步 `inited` + 60s 定时器，加载必须 < 2s（实测 0.00s）
      - `caches_declaration_across_reopen`：声明跨进程存活、可清除
      - `reopens_with_cached_declaration`：重启后不跑 JS 就有能力，真正用时才加载
      - `script_change_invalidates_cached_declaration`：脚本变更后旧声明不再暴露
- [x] `cargo check --workspace --all-targets` 无 warning；`cargo test --workspace` 50 tests 通过
- [ ] 真机验证：
      - 首次启动：日志 `lx.runtime init source=fish_music elapsed=...` 应从 ~25s 降到几秒
      - 第二次启动：`elapsed` 日志仍会出现（后台预热），但**界面立刻**显示可播放状态
      - 关闭网络后启动：应仍显示可播放（读缓存），点播放时才报解析失败
- [ ] 后续：拆锁（store 一把 / runtime 一把），让预热彻底不阻塞 UI 查询；
      失败状态加 TTL 与手动重试入口

### 第六轮：LX 运行时异步化（第 1 步，2026-11-22）

问题现象：每次启动 App 都要手动进入「洛雪音源配置页」等它加载完，LX 才能播放。

根因不是"没做异步"，而是**语义错误**：`lxPlatformCanPlay` 用 `ref.read(...).value == null` 判断，
把"还在初始化"当成了"没有源"，于是首次点播放直接弹"请先导入音源"；而配置页是唯一会 `await`
并显示 loading 的地方，所以用户只能靠它"手动等待"。另外启动时完全没有预热。

- [x] 新增 `lxRuntimeProvider`（`AsyncNotifier`，非 autoDispose）：所有入口（搜索页、建议、播放、
      设置页）共享同一个初始化 Future，结果常驻进程；离开页面不再丢状态
- [x] 启动预热：`bootstrap` 在 `runApp` 之后 `unawaited(_prewarmLxRuntime(container))`，
      把源脚本初始化（实测 25s）挪到后台，不阻塞首帧
- [x] 播放门控改为三态 `LxPlaybackStatus { ready, preparing, unavailable }`：
      - ready → 直接起播
      - preparing → 提示「正在准备洛雪音源…」并 `await`（最长 60s），就绪后继续起播
      - unavailable → 提示需要导入/启用源；若上一次初始化失败，先 `invalidate` 重试一次
- [x] 搜索页：歌曲/专辑/歌手/「播放全部」四个入口统一走 `ensureLxPlayable`，不再同步判死
- [x] 平台栏：初始化期间显示中性提示「正在准备洛雪音源…」而不是红色「暂无可播放音源」
- [x] 平台默认值：运行时就绪前不因"可播列表为空"把默认平台从 kw 切走，避免初始化完成后跳变
- [x] `lxPlayablePlatformsProvider` 保留为派生 provider（`ref.watch(lxRuntimeProvider.future)`），
      现有建议页/平台栏调用点无需改动
- [x] 设置页增删/启用源后 `invalidate(lxRuntimeProvider)`
- [x] 新增 l10n：`lxSourcePreparing`（中/英）
- [x] `cargo test --workspace` 46 tests 仍通过（本轮只改 Dart）
- [ ] 真机验证：
      - 冷启动后直接进搜索 → 平台栏显示「正在准备洛雪音源…」，随后变为可播，不用再进配置页
      - 初始化期间点歌 → 弹「正在准备洛雪音源…」并等待，就绪后自动起播
      - 离开搜索页再回来 → 不再重新初始化
      - 设置页启用/禁用源后返回搜索 → 可播状态立即更新
- [ ] 后续（第 2、3 步）：持久化 `inited` 声明使"能否播放"毫秒级可得；
      按需 `pump_timers` + 可中断 sleep + 拆锁，把 25s 降到几秒

### 第五轮：音质 types（2026-11-18）

目标：让「默认音质 = 无损/320k」真正生效，而不是每次都掉到 128k。

- 设计：不新增 FFI 字段。把可用音质写进 `LxSearchTrack.extra["types"]`（降序，如 `["flac","320k","128k"]`），它本来就会随 `sourceExtraJson` 持久化并作为 `musicInfo.types` 传给音源脚本，播放端直接读。
- [x] Rust 公共件：`search::ordered_quality_types`、`insert_quality_types` + 5 个平台的质量映射
  - kw：`N_MINFO` 的 `bitrate` 档位 4000/2000/320/128
  - kg（搜索）：`FileSize` / `HQFileSize` / `SQFileSize` / `ResFileSize`
  - tx：`file.size_128mp3` / `size_320mp3` / `size_flac` / `size_hires`
  - wy：`l` / `h` / `sq` / `hr` 对象是否存在
  - mg：`audioFormats[].formatType` = PQ / HQ / SQ / ZQ24
- [x] 搜索解析接入（5 平台）：`parse_kw` / `push_kg_track` / `parse_tx` / `parse_wy` / `parse_mg`
- [x] 歌单详情解析接入（5 平台）：`parse_kw_track` / `parse_kg_playlist_track`（小写 `filesize` / `320filesize` / `sqfilesize`，无 24bit）/ `parse_tx_track` / `parse_wy_song_list` / `parse_mg_playlist_track`
- [x] 播放音质阶梯：`player_provider._resolveTrack` 有清单时只尝试真实存在的档位（优先用户默认音质，然后高→低），没有清单时回退旧逻辑（默认音质 → 元数据推断 → 128k）
- [x] UI：LX 搜索结果的副标题显示最高音质（复用 `lxQualityFlac` / `lxQuality320` / `lxQuality128`）
- [x] 测试：`derives_quality_types_per_platform`（5 平台 + 空数据）、`parses_kw_playlist_track_quality`，并给 kg/wy/mg 详情 fixture 补了 types 断言
- [x] 真实网络核对（临时测试，跑完已删除）：
  - 搜索：kw `[flac,320k,128k]`；kg `[flac24bit,flac,320k,128k]`；tx `[flac,320k,128k]`；wy `[flac,320k,128k]`；mg `[flac24bit,flac,320k,128k]` / `[flac,320k,128k]`
  - 详情：5 平台均返回 `[flac,320k,128k]`（kg 旧接口无 24bit，符合预期）
- [x] `cargo check --workspace --all-targets` 无 warning；`cargo test --workspace` 46 tests 通过
- [ ] 真机验证：设置里选「无损 FLAC」后，日志 `LX play resolve start ... qualities=[flac, 320k, 128k]`；无无损时直接跳过 flac，不再先失败一次
- [ ] 后续：每档体积（size）未保留，UI 无法显示「无损 · 32MB」；播放页/歌单预览页也还没显示音质标签（目前只有 LX 搜索结果行）

### 第四轮：P0 工程债（2026-11-18）

- [x] **媒体通知桥接的 O(n) 队列签名**：`LaetibeatAudioHandler._sync` 每次 position tick 都把整个队列 `map(id).join('\u0000')` 拼成字符串（整库 1 万首时每秒数次分配几百 KB）。改为 `identical(state.queue, _lastQueue)` 引用比较——`PlayerState.copyWith` 复用同一个 List，只有 `load` / `insertNext` 才换引用，所以 O(1) 且语义等价
- [x] **订阅歌单同步的原子性**：`local_playlists::replace_tracks` 原先是 `DELETE`（自动提交）后再走 `add_tracks` 的独立事务，中途失败会把订阅歌单**清空**。改为单个事务内 `DELETE → insert → 更新时间戳`，`add_tracks` 抽出 `add_tracks_in(&Connection, ..)` 供两条路径复用；补测试 `replace_tracks_overwrites_atomically`
- [x] **`reference/` gitlink 清理**：`git rm --cached reference/lx-music-mobile`，本地参考目录保留
- [x] **桌面端日志**：新增 `rust_lib_laetibeat::init_logging()`（Android → logcat tag `LaetibeatLx`；桌面 → `env_logger`，默认 info、`RUST_LOG` 可覆盖），在 `init_app` 里统一初始化；此前桌面端 `laetibeat_lx` 的 `log::info!` 全部被丢弃。新增依赖 `env_logger`（仅非 Android 目标）
- [x] `cargo check --workspace --all-targets` 无 warning；`cargo test --workspace` 44 tests 通过
- [ ] 真机验证：长队列（整库）播放时滑动音乐库不再掉帧 / 无 GC 抖动
- [ ] 桌面验证：启动后 stderr 能看到 `lx.playlist.*` 等日志
- [ ] 订阅歌单：异常中断（如断网）后歌单条目保持原样而非被清空

### 歌单订阅的已订阅状态（2026-11-18）

- 说明：订阅信息存在本地歌单的 `source` + `source_list_id` 上，重新搜索同一平台歌单时会据此判断。
- [x] 修复重复订阅：`_subscribe` 原先把 `localPlaylistsProvider.value` 当同步值读，列表尚未加载完时会拿到 `null`，把已订阅误判成未订阅并创建重复歌单；改为 `await ref.read(localPlaylistsProvider.future)`
- [x] 预览页按钮显示订阅状态：已订阅时显示「已订阅」+ 同步图标，点击进入"覆盖同步"确认（此前按钮永远是「订阅」）
- [ ] 搜索结果列表行内未标记"已订阅"（仅在预览页体现）

### 歌单接口实测结论（2026-11-18）

| 平台 | 歌单搜索 | 歌单详情 | 结论 |
|---|---|---|---|
| kw | `search.kuwo.cn/r.s?...ft=playlist` ✅ 已实现 | `nplserver.kuwo.cn/pl.svc` ✅ 已实现 | 完成 |
| tx | `c.y.qq.com/soso/fcgi-bin/client_music_search_songlist` ✅ | `fcg_ucc_getcdinfo_byids_cp.fcg` ✅ | 完成（编码问题已修） |
| kg | `msearchretry.kugou.com/api/v3/search/special` ✅ | `mobilecdn.kugou.com/api/v5/special/info` + `v3/special/song` ✅ **免签名** | **已实现**（2026-11-18） |
| wy | `eapi /api/cloudsearch/pc`（`type:1000`）✅ | `eapi /api/v6/playlist/detail`（info + `trackIds`）→ `eapi /api/v3/song/detail` 批量 | **已实现**（2026-11-18） |
| mg | `jadeite.migu.cn/.../searchAll` + `searchSwitch.songlist=1` ✅ | `c.musicapp.migu.cn/MIGUM3.0/resource/playlist/v2.0` + `app.c.nf.migu.cn/MIGUM3.0/resource/playlist/song/v2.0` ✅ **免签名** | **已实现**（2026-11-18） |

分页语义差异：kw `pn` 从 0 / tx `page_no` 从 0 / kg `page` 从 1 / wy `offset` / mg `pageNo` 从 1。

### 待决策：平台范围

- 结论：**不建议裁剪到 QQ + 网易云**。理由：
  1. 酷我 / 酷狗 / QQ 同属 TME，曲库高度重叠，但同一首歌在不同平台的可播放状态、音质、可用版本（Live / DJ / 现场）不同，多平台是"换源"兜底；咪咕则覆盖运营商系长尾。
  2. 删除成本 ≥ 补齐成本：kw 的歌单/歌词/封面、kg 的 KRC 歌词与封面、mg 的 MRC 解密都已跑通，删掉等于丢弃已验证资产。
  3. 用户导入的自定义源可能只声明 kw/kg，平台被删会让这些脚本失去可搜索入口；且 LX 官方为 5 平台，用户有预期。
  4. 单平台失效时（接口风控很常见），多平台是唯一降级手段。
- 建议方案：保留 5 个平台，引入"平台能力表"（搜索 / 歌单 / 歌词 / 封面 / 播放），UI 只展示实际支持的能力；某平台接口失效时只关掉能力位，不删代码。
- [x] 平台范围：保留全部 5 个平台（2026-11-18 决定），歌单能力已 5/5 打通

### 后续（本次未做）

- [x] `kg` / `wy` / `mg` 歌单搜索与详情（2026-11-18 完成，见第三轮）
- [x] 搜索结果保留可用音质（`extra.types`）并驱动播放选质（2026-11-18，见第五轮）；仍未保留每档体积
- [ ] 封面 `pic` fallback 只有 `kg`；官方 `kw` / `mg` 也有 `pic` 实现
- [ ] 专辑 / 艺术家分类只聚合歌曲第 1 页（当前 50 条），应改为与歌曲分页共用同一数据源
- [ ] `lxSearchProvider` 非 autoDispose，逐词常驻内存；建议 autoDispose + 少量 keepAlive
- [ ] 搜索建议（tipSearch）与热词/排行榜仍未接入

## LX 在线歌单与订阅（2026-11-15 定稿方向）

> 参考项目只作为逻辑参考，不复制其代码、素材或第三方音源脚本。

### 目标流程

```text
搜索页
├─ 歌曲
├─ 歌单
├─ 专辑
└─ 艺术家
```

歌单分类支持：

```text
[全部] [本地] [Subsonic] [LX]
LX 平台：酷我 / QQ / 网易 / 咪咕 / 酷狗
```

点击 LX 歌单进入预览页：

```text
封面 / 名称 / 作者 / 播放量 / 描述
[播放全部] [订阅]
歌曲列表
```

订阅后出现在媒体库歌单页，带 `[LX · 平台]` badge，可像本地歌单一样增删改查；下拉刷新重新拉取平台歌单并覆盖本地快照。

### 数据原则

- 歌单与音源解耦：歌单只保存歌曲身份与元数据，播放时再由 LX 源解析 URL/歌词/封面
- 本地歌单增加订阅元数据：`source`、`source_list_id`、`last_synced_at`
- 歌单条目增加 `source_extra_json`，保留 TX/KG 等平台播放所需字段
- LX 曲目统一映射：`source=lx`、`source_id=平台`、`track_id=平台歌曲 ID`
- 订阅歌单是本地快照；同步会覆盖本地修改，需要提示用户

### 实施顺序

- [x] 1. 本地歌单 schema v3：订阅字段 + `source_extra_json`
- [x] 2. Rust LX 歌单底座：平台参数、搜索/详情/全量接口
- [x] 3. 先接酷我 KW 歌单搜索与详情
- [x] 4. FRB facade 与代码生成
- [x] 5. 搜索页歌单分类接入 LX，复用现有平台切换
- [x] 6. 在线歌单预览页：播放全部、订阅
- [x] 7. 媒体库歌单页显示订阅来源 badge
- [x] 8. 订阅歌单下拉同步，同步前确认覆盖
- [x] 9. 自己创建 LX 歌单并从 LX 搜索结果添加歌曲
- [x] 10. 已补 KW / TX 歌单搜索与详情；WY / MG / KG 待补

### 待确认

- [x] 订阅歌单同步采用“全量覆盖”，同步前确认
- [x] 订阅歌单允许与本地/Subsonic 歌曲混合（条目均带 source 身份）
- [x] 平台歌单搜索默认当前平台；后续可增加“全部平台”聚合

## 媒体库信息架构重构（2026-11-10 定稿方向）

### 目标

媒体库首页只做入口导航，具体内容放到子页面：

```text
媒体库首页
├─ 全部歌曲
├─ 专辑
├─ 艺术家
├─ 歌单
├─ 收藏（后续）
├─ 最近播放（后续）
└─ 下载（后续）
```

现有歌曲/专辑/艺术家/歌单页面布局保留，作为未来入口的子页面，不做大幅重写。

### 详情页

- 使用 `mobileLargeSubpageAppBar` 返回媒体库首页
- 顶部来源筛选 chips：全部 / 本地 / Navidrome / 后续 Jellyfin、Emby
- 默认筛选“全部”
- 每行显示来源 badge
- 每个分类拥有独立筛选状态，不使用全局 `activeSource`
- LX 不进入媒体库；继续只作为搜索来源，用 chip 标记

### 数据原则

- 媒体库主要统一本地 + OpenSubsonic，后续远端源按同一模型接入
- 初期不做自动跨源去重
- 收藏/歌单/队列使用 source-aware 身份：`source + sourceId + trackId`
- 首页数量只读缓存，加载中显示 `—`，不为了数量阻塞或主动全量同步

### 导航原则

- 媒体库根路由 = 入口首页
- 点击入口 push 对应子页面
- 专辑详情/艺术家详情继续从内容页 push
- 不再用顶部按钮组在同一层互相 `pushNamed` 切分类
- 保持单根 Navigator 与预测性返回路径清晰

### 实施阶段

- [x] 1. 新增媒体库入口首页，移除当前顶部歌曲/专辑/艺术家按钮组
- [x] 2. 将现有四个内容视图包装为独立子页面，保留现有布局与操作
- [x] 3. 歌曲页接入来源 chips + 来源 badge + 本地/OpenSubsonic 统一来源筛选
- [x] 4. 专辑/艺术家页接入来源筛选；新增本地专辑详情页与本地艺术家详情页
- [x] 5. 歌单页统一本地/OpenSubsonic 歌单；本地 CRUD、Subsonic 歌单详情/新建/更新/删除/加歌/移歌已接入
- [ ] 6. 预留收藏/最近播放/下载入口，未实现前不显示死入口
- [x] 7. 清理旧分类路由切换逻辑；`defaultSongSourceProvider` 改为“默认来源筛选”，默认全部

### 待讨论

- [x] 首页入口采用列表卡片：全部歌曲 Hero Card + 专辑/艺术家/歌单分组列表
- [x] 首页显示数量：本地直接统计，OpenSubsonic 只读已缓存 Provider，未知显示 `—`
- [ ] 来源筛选是否跨进入/退出页面记忆
- [ ] 同一专辑/歌曲同时存在于本地与远端时的展示与去重策略
- [ ] 收藏/歌单的跨源统一入口是否在首页提前暴露

## 阶段1：数据模型与基础扫描

- [x] 1.1 初始化 Rust workspace
- [x] 1.2 定义 Track/Album/Artist 与音源抽象（`PlayState` / `AudioSource` 当前未使用，列入死代码清理；远端由 laetibeat_remote 独立实现）
- [x] 1.3 本地文件夹扫描与元数据解析（walkdir + lofty，支持 mp3/flac/m4a/wav）
- [x] 1.4 解码方案定板：桌面使用 media_kit（libmpv + FFmpeg），不自研 PCM 解码
- [x] 1.5 增量扫描：path + modified_ms + file_size 指纹复用
- [x] 1.6 Rust 侧专辑/艺术家聚合与碟号/音轨号排序

## 阶段2：前端与 FFI

- [x] 2.1 初始化 Flutter 前端（laetibeat_flutter）
- [x] 2.2 配置 flutter_rust_bridge
- [x] 2.3 打通 Dart ↔ Rust 数据传输
- [x] 2.4 UI 骨架：选择目录 → Rust 扫描 → 列表展示
- [x] 2.5 音乐库 JSON 快照持久化（临时文件 + rename、schemaVersion、Isolate 编解码）
- [x] 2.6 移动端运行时生成接口：歌单、艺术家简介等 FFI 已接入

## 阶段3：桌面播放与播放器 UI

- [x] 3.1 PlaybackBackend 抽象 + MediaKitBackend（Linux）
- [x] 3.2 播放状态由引擎流驱动：position/duration/playing/completed
- [x] 3.3 播放队列、随机播放、重复模式（顺序/单曲/列表）
- [x] 3.4 队列与播放状态持久化（不恢复播放进度）
- [x] 3.5 共享播放面板：封面取色、歌词、全屏、队列浮层
- [x] 3.6 设备/输出面板：设备切换、采样率/声道/码率
- [x] 3.7 本地/远端音源切换（简化到单 Navidrome）
- [x] 3.8 拖动进度条松手 seek；超长曲目 h:mm:ss 显示
- [x] 3.9 移动端复用的迷你播放器、全屏播放页、播放队列浮层
- [x] 3.10 移动端歌曲列表接入真实本地/远端数据
- [ ] 3.11 收藏/喜欢（Favorite 导航、曲目/专辑喜欢、本地 + OpenSubsonic star/unstar）
- [ ] 3.12 歌单（本地 CRUD、加入歌单、远端 playlist 详情）
- [ ] 3.13 队列编辑（加入队列、下一首播放、删除、拖动排序、清空）
- [ ] 3.14 下载（当前按钮为占位）
- [x] 3.15 播放设置第一版：Android 系统均衡器、淡入淡出
- [ ] 3.15.1 倍速、跳过静音、ReplayGain / 响度归一
- [ ] 3.15.2 压缩器/限幅器、Bass Boost、Virtualizer、Stereo Width、Crossfeed
- [ ] 3.16 底部三点菜单/列表行的“加入播放队列”“查看详情”等占位动作

## 阶段4：OpenSubsonic / Navidrome

- [x] 4.1 认证：API Key + 用户名密码 token（由 opensubsonic crate 处理 MD5/salt）
- [x] 4.2 统一客户端封装与 sourceId 注册表（laetibeat_remote）
- [x] 4.3 浏览/搜索/播放/封面/歌词接口
- [x] 4.4 单服务端连接配置：内容页弹层、测试成功才可保存
- [x] 4.5 手动同步音乐：getAlbumList2 分页 + 每专辑 getAlbum 并发，进度流
- [x] 4.6 SQLite 远端库：generation 代际切换，失败回滚保留旧数据
- [x] 4.7 远端浏览/搜索改为读本地 SQLite 快照
- [x] 4.8 scrobble 上报（now playing + 达到阈值后的正式记录）
- [x] 4.9 远端歌单：OpenSubsonic getPlaylists FFI + 移动端歌单列表
- [x] 4.10 艺术家详情：getArtistInfo2 FFI + biography
- [ ] 4.11 远端 playlist 详情、添加/删除曲目
- [ ] 4.12 远端 starred / 收藏列表
- [ ] 4.13 增量同步、取消同步、进度事件节流
- [ ] 4.14 离线 scrobble 队列与失败重试
- [ ] 4.15 大曲库分页/按需加载（当前推荐会缓存全部远端曲目）
- [ ] 4.16 last.fm 等外部统计平台上报

## 阶段5：播放统计与首页

- [x] 5.1 SQLite 播放事件与曲目聚合统计
- [x] 5.2 首页播放记录：今天/本周/本月、累计播放、收听时长、Top 歌手/专辑
- [x] 5.3 跨音源统计（本地 + 远端合并；LX 来源分类待修复）
- [x] 5.4 专辑级推荐三模式，合并本地与远端播放记录
- [ ] 5.5 播放热力图
- [ ] 5.6 Home「See all」等入口落地

## 阶段6：封面 / 歌词 / 缓存

- [x] 6.1 本地封面：Rust lofty 读取内嵌图
- [x] 6.2 远端封面：内存 LRU + 磁盘 LRU（受总缓存上限的 Subsonic 份额控制），服务器变更时清理。
- [x] 网易云封面：独立 32MB 内存 LRU + `netease_covers` 磁盘 LRU，按网易云封面 URL 复用；与洛雪缓存隔离。
- [x] 6.3 本地歌词：内嵌 → sidecar，按音频/sidecar 指纹缓存
- [x] 6.4 远端歌词：OpenSubsonic 返回，正缓存长期、负缓存 1 天
- [x] 6.5 歌词缓存 20MB 上限与过期负缓存清理
- [x] 6.6 搜索歌词：LRCLIB + LiriQo、逐字/逐行/静态、翻译、应用覆盖
- [ ] 6.7 搜索歌词持久化：写入本地 .lrc / 标签，或保存覆盖记录
- [x] 6.8 移动端缓存管理：总用量/上限、粗细进度条、释放空间、分源歌词/封面/其他明细、总缓存上限滑块、自动与下拉刷新

## 阶段7：跨平台与系统集成

- [x] 7.1 Linux 桌面音频输出与调试构建
- [x] 7.2 导航壳解耦：DesktopApp / MobileApp 分离，页面按形态独立组合
- [x] 7.3 页面响应式：桌面 TwoPaneLayout 窄屏折叠，移动端使用独立单栏页面
- [x] 7.4 移动端播放页：迷你播放器 + 全屏播放页，隐藏 DevicePanel
- [ ] 7.5 MPRIS 迁移到 audio_service + audio_service_mpris（当前自研 MPRIS 已停用）
- [x] 7.6 Android 后台播放、媒体会话、常驻通知（真机验证通过）
- [ ] 7.7 Windows / macOS / Android 打包与适配测试
- [x] 7.8 window_manager 平台门控与移动端启动配置
- [x] 7.9 移动端页面体系：首页/音乐库/搜索/设置/外观/内容/音源配置/电台占位
- [ ] 7.9.1 电台内容：接入 Subsonic `getInternetRadioStations` 与电台播放链路
- [x] 7.10 移动端库分类：歌曲、歌单、艺术家、专辑；支持排序、宫格/列表切换
- [x] 7.11 移动端详情页：专辑详情、艺术家详情、多碟分组、曲目列表
- [x] 7.12 移动端搜索栏、AppBar、底部导航、预测性返回
- [x] 7.13 歌曲排序：默认/标题/艺术家/专辑/添加时间，设置页同步
- [x] 7.14 移动端 OpenSubsonic 配置页真实连接、测试、扫描

## 阶段8：Android 音频服务迁移（已完成主体，待状态抽象收尾）

目标：Android 从 media_kit 迁移到 `audio_service` + `just_audio`，桌面继续 media_kit。

### 8.1 播放后端拆分

- [x] 新增 `JustAudioBackend`（Android/iOS）
- [x] bootstrap 按平台注入：Android/iOS → JustAudio，桌面 → MediaKit
- [x] 保持 `PlaybackBackend` 接口不向 UI 泄漏具体引擎
- [ ] 补齐 buffering / error / processing state 抽象；当前 `LaetibeatAudioHandler` 固定 `processingState=ready`，`bufferedPosition` 直接等于 `position`
- [ ] PlaybackBackend 暴露 buffering / error / phase 流；JustAudio 映射 `processingStateStream`，MediaKit 映射对应状态
- [ ] 验证 OpenSubsonic stream URL、本地 file URI、恢复播放

### 8.2 audio_service 与状态归属

- [x] 初始化 `audio_service`，配置通知渠道与 ongoing 行为
- [x] 新增 `LaetibeatAudioHandler`，映射 play/pause/stop/seek/next/previous
- [x] 明确播放状态源：现有 PlayerNotifier 继续持有播放器与队列
- [x] AudioHandler 与 UI 同 isolate，统计/scrobble/队列持久化保持原路径
- [x] 用 `MediaItem` 同步标题、艺术家、专辑、时长、封面 `artUri`
- [x] 同步队列、随机模式、重复模式
- [x] 通知栏、锁屏、媒体按钮真机验证
- [ ] 蓝牙耳机按键真机验证
- [ ] 通知点击回到播放页/当前页面验证
- [ ] 替换/收缩 `MediaSessionService.sync()` 拉取式桥接
- [x] 播放完成/队列结束时按钮状态与媒体通知同步

### 8.3 Android 配置

- [x] Manifest 增加 `WAKE_LOCK`
- [x] Manifest 增加 `FOREGROUND_SERVICE`
- [x] Manifest 增加 `FOREGROUND_SERVICE_MEDIA_PLAYBACK`
- [x] 声明 `AudioService`，`foregroundServiceType="mediaPlayback"`
- [x] 声明 `MediaButtonReceiver`
- [x] MainActivity 切换到 `AudioServiceActivity`
- [x] Android 13+ 请求 `POST_NOTIFICATIONS`（MainActivity 原生请求）
- [x] 通知频道、单色小图标、专辑封面大图标
- [x] 处理 Android 14+ 前台服务类型声明

### 8.4 音频焦点与生命周期

- [x] 配置 `audio_session` 为音乐用途
- [x] 来电/其他应用播放时暂停或 duck
- [x] 耳机拔出 becoming noisy 处理
- [ ] 蓝牙/有线/扬声器切换真机验证
- [x] 暂停后通知保留策略（暂停时停止前台服务）
- [x] App 退到后台、锁屏、划掉后的行为验证
- [x] 后台播放时统计和 scrobble 继续工作验证

### 8.5 验证

- [x] 本地文件后台播放
- [ ] OpenSubsonic 流媒体后台播放
- [x] 锁屏控制
- [x] 通知栏播放/暂停/上一首/下一首
- [x] 划掉 App 后继续播放
- [ ] 蓝牙耳机播放/暂停/上一首/下一首
- [ ] 暂停、继续、seek、播放完成
- [ ] 通知权限拒绝时的降级行为
- [ ] Android 13/14/15 和不同厂商 ROM

### 8.6 播放音效第一版

- [x] JustAudioBackend 接入 `AudioPipeline + AndroidEqualizer`
- [x] 移动端“播放器与音频”设置页：5 段竖向均衡器
- [x] EQ 开关、频段增益持久化
- [x] 淡入淡出开关、淡入/淡出 0–10 秒设置
- [x] `PlaybackBackend.setVolume` + `PlayerNotifier` 音量渐变
- [x] 淡入淡出兼容 Android 音频焦点 duck
- [ ] ReplayGain / LUFS 响度归一
- [ ] Compressor / Limiter
- [ ] Bass Boost / Virtualizer
- [ ] Stereo Width / Crossfeed
- [ ] Crossfade / Gapless
- [ ] 按输出设备保存不同音效 profile（外放/蓝牙/有线/USB DAC）
- [ ] 音效与 USB DAC bit-perfect 互斥/旁路策略

## 阶段9：Rust 音频引擎 / 发烧音频（未来）

目标：参考 Flick 等项目的 Rust UAC 实现，逐步建立独立的高解析音频后端；不阻塞阶段 8 的普通移动端播放。

### 9.1 架构原则

- [ ] FRB 只做控制面和状态事件，不通过 FRB 传输 PCM
- [ ] Rust 音频线程独立于 Flutter UI isolate
- [ ] 普通 Android 输出、Oboe/AAudio 独占、USB UAC 作为不同输出 backend
- [ ] 独占失败/未接 DAC 时自动回退 Android 标准管线
- [ ] 音频统计、队列、媒体库继续与普通播放共用

### 9.2 Rust 音频引擎

- [ ] 新增 Rust audio crate：解码、DSP、输出、队列时钟
- [ ] 解码：Symphonia / FFmpeg，覆盖 FLAC/WAV/MP3/M4A/OGG
- [ ] 重采样、dither、预放大、限幅
- [ ] 10 段/31 段参量均衡器
- [ ] ReplayGain / LUFS 响度归一、动态压缩
- [ ] 淡入淡出、crossfade、gapless
- [ ] Bass Boost、Virtualizer、Stereo Width、Crossfeed
- [ ] 按输出设备切换 DSP profile
- [ ] 播放位置、缓冲、完成、错误事件
- [ ] 与 Flutter 的播放队列/统计状态同步

### 9.3 Android 输出

- [ ] Oboe/AAudio 标准输出
- [ ] 支持设备的 Oboe/AAudio exclusive mode
- [ ] DAP/内置 DAC 设备适配与白名单
- [ ] 输出采样率/位深跟随源文件
- [ ] 设备切换、耳机拔出、路由变化处理

### 9.4 USB DAC 独占

- [ ] Android UsbManager 授权与设备枚举
- [ ] USB fd 转交 Rust/libusb
- [ ] UAC1/UAC2 描述符解析
- [ ] claim interface、alt setting、采样率控制
- [ ] isochronous OUT 传输与环形缓冲
- [ ] 异步 DAC feedback 端点
- [ ] DAC quirk 兼容表
- [ ] 独占音量控制与系统音量键
- [ ] 拔出/重连恢复

### 9.5 DSD / 高解析

- [ ] DSF/DFF 解析
- [ ] WavPack DSD
- [ ] Native DSD
- [ ] DoP over PCM
- [ ] DSD → PCM 降级
- [ ] DAC 能力探测与输出策略

### 9.6 参考项目与许可证

- [ ] 研究 Flick 的 Rust UAC2 / Oboe / DSP 架构（MIT；仅作本地参考，不整包复制）
- [ ] 研究 TrueSample Player 的 `usbaudio` UAC1/UAC2 库
- [ ] 研究 sylvakru 的 USB 独占实现
- [ ] 确认代码许可证、libusb/FFmpeg 等依赖分发方式
- [ ] 只移植必要模块，避免直接复制完整应用层

### 9.7 验收

- [ ] 本地 FLAC 原采样率直出 USB DAC
- [ ] 44.1/48/96/192kHz 切换正确
- [ ] 24bit 输出正确
- [ ] 无系统通知音混入（独占模式）
- [ ] DAC 拔出/重连不崩溃
- [ ] 普通模式与独占模式可切换
- [ ] 输出路径诊断 UI：采样率/位深/是否 bit-perfect

## 阶段10：洛雪 / LX 音源宿主（已接入，收尾中）

目标：支持用户导入 LX 自定义 `.js` 音源，在 Rust 侧运行脚本并解析 `musicUrl` / `lyric` / `pic`；不把第三方音源打包进应用。

### 10.1 边界与目录原则

- [x] `reference/lx-music-mobile` 仅作为协议和行为参考，不参与构建、运行、发布
- [x] 将 `reference/` 加入 `.gitignore`
- [x] `git rm --cached reference/lx-music-mobile`（2026-11-18）：此前它以 gitlink 形式留在索引里，`.gitignore` 对已跟踪条目无效，别人 clone 会得到空的 submodule；现已移出索引，本地文件保留
- [x] 不直接复制官方 JS/Kotlin/React Native/Redux 代码；按行为重写
- [x] 新建独立 crate：`laetibeat_lx/`，与 `laetibeat_flutter/`、`laetibeat_core/` 同级
- [x] `laetibeat_lx` 只依赖自身需要的 Rust crates，不反向依赖 Flutter/FRB
- [x] `laetibeat_flutter/rust` 只增加极薄的 FRB facade，不把宿主逻辑写进现有业务文件
- [x] 用户自行导入音源脚本；不内置、不预置、不自动抓取第三方源
- [x] 明确非官方接口、版权和服务条款风险，UI 中保留说明

### 10.2 JS 引擎选型

候选：

- [ ] `rquickjs` + QuickJS：优先评估，体积小、适合 Android、Rust 绑定成熟
- [ ] QuickJS-ng：作为 QuickJS 维护性替代评估
- [ ] `boa_engine`：纯 Rust、移植简单，但 ES 覆盖/性能/Promise 事件循环需验证
- [ ] `deno_core` / V8：能力完整但体积和构建成本过高，暂不作为移动端首选
- [ ] Hermes：RN 生态引擎，嵌入 Rust 成本高，暂不考虑
- [ ] Duktape / MuJS / JerryScript：ES5/旧规范风险，暂不考虑
- [ ] WebView：后台执行和沙箱控制差，暂不考虑
- [x] 初步决策：优先 `rquickjs`，先做 Android 真机 PoC；不满足再评估 QuickJS-ng/Boa
- [x] `rquickjs 0.14` 在 Linux host 编译与单元测试通过
- [x] Android `aarch64-linux-android` `cargo check` 通过
- [x] 记录并通过 cargokit 自动向 rquickjs bindgen 传递 NDK sysroot（armv7/aarch64/x86_64）
- [x] 验证 armv7/aarch64/x86_64 Android release 构建（flutter build apk）

### 10.3 JS 运行时与宿主

- [x] 每个音源独立 QuickJS Context，禁止共享全局状态
- [ ] 专用 JS 线程/Actor；JS Context 只在单线程访问
- [x] 独立 `laetibeat_lx/src/preload.js` 兼容层初版
- [x] 实现 `globalThis.lx.EVENT_NAMES`
- [x] 实现 `lx.on('request')`
- [x] 实现 `lx.send('inited')`
- [x] 实现 `lx.send('updateAlert')` 基础事件
- [x] 实现 `lx.request` 的 Rust `reqwest` HTTP 代理初版
- [x] 实现 `lx.utils.buffer` 的基础 base64/hex/UTF-8 转换
- [x] 实现 `lx.utils.crypto.md5` 与 `randomBytes`
- [x] 实现 `lx.utils.crypto.aesEncrypt`（AES-128-CBC / AES-128-ECB）
- [x] 实现 `lx.utils.buffer`（from / bufToString，含 base64/hex/UTF-8）
- [x] 实现 `lx.utils.crypto.rsaEncrypt`（NoPadding，PEM / 裸 base64 公钥）
- [x] 实现基础 `setTimeout` / `clearTimeout`（Rust 有界 timer pump）
- [ ] 替换为长期异步 JS 事件循环，支持超过 5 秒的定时任务
- [x] 基础 Promise / microtask 调度（`execute_pending_job`）
- [x] 初始化超时、请求超时、脚本执行超时
- [x] 为 QuickJS 设置内存上限与 interrupt handler，死循环可被中断
- [ ] 请求取消与 Context 销毁
- [x] 基础 JS 异常/结果回传
- [x] 禁止 `eval`
- [x] 脚本大小、inited 载荷、结果大小基础限制
- [ ] 禁止动态 `Function`、文件系统和宿主内部对象（当前只禁用了 `eval`）
- [ ] 完整输入/输出长度限制与 JSON 序列化校验
- [ ] 脚本崩溃隔离（内存上限与 CPU 中断已完成，尚未做独立进程/线程崩溃隔离）
- [ ] 避免启动时同步加载全部启用源：拆分 store 初始化与 runtime 懒加载

### 10.4 HTTP 请求代理

- [x] `lx.request` → Rust `reqwest` 请求代理
- [x] 支持 GET/POST、headers、body、form
- [x] 支持文本/JSON/二进制响应
- [x] 单请求超时与重定向
- [ ] 支持 formData/multipart
- [ ] 支持请求取消与异步 requestKey
- [ ] 为每个请求建立 requestKey，完成/失败/取消回写 JS
- [x] 脚本只能通过宿主代理发请求，不直接接触 Rust 内部
- [x] Android TLS 初始化：`LaetibeatApplication` 在进程启动时调用 rustls-platform-verifier
- [ ] 将同步 `reqwest::blocking` 改为异步 request broker，避免阻塞 JS 线程

### 10.5 音源导入与存储

- [x] 解析脚本头部 `/* @name @description @author @homepage @version */`
- [x] 生成稳定 source id：基于 manifest 身份生成，脚本 hash 仅作版本字段；旧 content-hash id 在 store 打开时自动迁移并合并重复源
- [x] 保存脚本正文和元数据
- [x] 支持删除、启用、禁用、优先级排序
- [x] 保存 `allowShowUpdateAlert`
- [x] 脚本文件放应用私有目录，元数据放 JSON 索引初版
- [x] 支持本地 `.js` 文件选择 UI
- [x] 支持在线 URL 导入（当前由 Flutter 下载后交给 Rust）
- [ ] 持久化源运行状态：未初始化/初始化中/可用/失败
- [ ] 保存 `inited` 声明的 sources、actions、qualitys（当前仅保存在内存）
- [x] 不将脚本内容写入日志或普通配置快照

### 10.6 源管理器

- [x] `LxSourceManager` 生命周期与单实例
- [x] 加载/切换当前音源
- [x] 多源启用与优先级/回退基础逻辑
- [ ] 跨源匹配基础结构（SourceManager 不负责搜索层）
- [x] `resolveMusicUrl(source, musicInfo, quality)`
- [x] `resolveLyric(source, musicInfo)` 基础分发
- [x] `resolvePic(source, musicInfo)` 基础分发
- [x] 初始化失败与请求失败状态回传（内存状态）
- [ ] `updateAlert` 事件与更新 URL 展示
- [ ] 源脚本过期/失效诊断信息
- [ ] 启用/禁用/删除/优先级/active 变更后通知 Flutter 刷新能力 Provider
- [ ] 启动时只加载 store，源 runtime 按首次搜索/播放懒加载，并隔离单源初始化失败

### 10.7 FRB 与 Flutter UI

- [x] `laetibeat_flutter/rust` 增加 `api/lx.rs` 薄 facade
- [x] 暴露 `import_lx_source`
- [x] 暴露 `list_lx_sources`
- [x] 暴露 `set_lx_source_enabled`
- [x] 暴露 `set_lx_source_priority`
- [x] 暴露 `load_lx_source`
- [x] 暴露 `resolve_lx_music_url`
- [x] 暴露 `resolve_lx_lyric`
- [x] 暴露 `resolve_lx_pic`
- [x] 通过 `list_lx_sources` 查询内存状态（事件流/更新提示仍待做）
- [x] 移动端设置页增加“洛雪音源”入口
- [x] 启动时初始化 `<application support>/laetibeat_lx` 存储
- [ ] 启动时仅打开 store；已启用源按需懒加载，避免 bootstrap 同步加载
- [x] 导入弹窗：本地文件/在线 URL
- [x] 源列表：名称、版本、作者、状态、启用开关、优先级
- [x] 删除确认、错误提示
- [ ] `updateAlert` 更新提示 UI
- [x] 导入/启用/禁用/删除/优先级变更后 invalidate `lxPlayablePlatformsProvider` / `lxSearchProvider`（2026-11-18）
- [x] 移动端与桌面端 UI 隔离，不共享桌面布局

### 10.8 搜索与播放接入

- [x] 明确 LX 自定义源通常只提供 `musicUrl` / `lyric` / `pic`，不提供搜索
- [x] 决定搜索层来源：独立 LX 平台搜索（不依赖本地/Subsonic）
- [x] `tx` 请求签名搜索
- [x] `wy` eapi 加密搜索
- [x] 将 LX 源作为已知歌曲的播放地址解析器，而不是默认搜索源
- [x] 扩展播放解析接口，加入 `lx`
- [x] 保存 `source/songmid/musicInfo`：`UiTrack.sourceId` / `id` / `sourceExtraJson` 与队列快照已持久化
- [ ] 持久化 quality 偏好或解析时的 quality，保证切歌后可稳定复现
- [x] URL 内存缓存（5 分钟）与失效重试
- [ ] 播放失败时自动换源/手动换源 UI（当前只有当前曲目重试）
- [x] 歌词/封面来源与现有缓存策略衔接（基础实现）
- [x] LX 歌词/封面持久化缓存，避免每次重新解析/下载
- [x] 修复 LX 播放统计来源：统计键使用 `source=lx` + 平台 `sourceId`
- [x] 搜索建议 300ms 防抖，避免每次按键触发 LX 网络搜索

### 10.9 测试与安全

- [x] 用自己编写的 fixture 测试源导入元数据解析
- [x] 用简单测试音源验证 `inited` 握手
- [x] 验证静态 `musicUrl` 成功路径
- [x] 用本地 HTTP 测试服务器验证 `lx.request` → JSON → `musicUrl`
- [x] 验证 AES-128-ECB 已知向量
- [x] 验证 SourceStore 导入/列表/读取/删除/启用/优先级
- [x] 验证 RSA 无效公钥错误路径
- [x] 验证 SourceManager 启用、加载、优先级、解析、移除
- [x] `flutter analyze` / `flutter test` 通过（2026-11-10；analyze 仍有 4 个既有 warning/info，本次无新增问题）
- [x] `cargo test --workspace` 通过（37 tests：core 7 / lx 27 / remote 3）
- [x] Android armv7/aarch64/x86_64 release Rust 编译通过（含 LX/QuickJS/FRB）
- [x] `flutter build apk --release` 通过（150.3MB；不要用 `--no-pub` 跳过插件注册表重生成）
- [x] 验证 `setTimeout` 延迟后解析 musicUrl
- [ ] 为 LX 统计来源、搜索防抖、Provider invalidation、缓存上限补充回归测试
- [ ] 验证 `musicUrl` 失败/超时/取消
- [ ] 验证歌词/封面返回格式与长度限制
- [ ] 验证恶意脚本无法访问文件/网络/宿主对象
- [ ] 验证 `eval` / 动态 Function 被阻止
- [x] 验证脚本死循环能被中断
- [ ] 验证多个源之间上下文隔离
- [ ] 验证独立平台搜索的分页、空结果、网络失败
- [ ] Android 真机验证 QuickJS `.so` 打包、加载与启动
- [ ] 验证应用后台/锁屏时源请求不会阻塞 UI
- [ ] 检查 QuickJS/rquickjs/AES/RSA 等依赖许可证
- [ ] 不提交官方项目代码、素材和第三方音源脚本

### 10.10 验收标准

- [x] 用户能导入一个本地 `.js` 源
- [x] 源初始化成功并显示状态；能力详情尚未展开
- [x] 播放器对 `source=lx` 的已知歌曲调用 `resolveLxMusicUrl`
- [x] 播放器对 `source=lx` 接入歌词和封面解析（基础实现）
- [x] 无本地/Subsonic 时，启用 LX 源后可在搜索页搜索 kw/kg/tx/wy/mg 并播放
- [x] 搜索分页 / 加载更多
- [x] 搜索失败重试
- [x] 搜索输入防抖（300ms）：`LibrarySearchSuggestions` 已在 `didUpdateWidget` 里 300ms 防抖
- [ ] 搜索请求真正取消（当前通过请求代次丢弃旧结果）
- [ ] LX 源启用/删除后搜索页能力列表立即刷新
- [ ] 真实 LX 源 + 真实平台搜索结果联调
- [x] 平台特定字段透传（kg hash、mg copyrightId、tx strMediaMid/songId）
- [x] `UiTrack.sourceExtraJson` 与队列快照持久化
- [x] LX URL 内存缓存（5 分钟）与失败重试
- [x] 带平台字段/URL 缓存的 release APK 构建通过（151.2MB）
- [x] 修复 KG 搜索：Audioid 为数字类型时被跳过
- [x] 带 KG/MG 歌词、KW/KG 封面、MG mrc 解密的 release APK 构建通过（151.4MB）
- [x] kg 内置歌词接口（KRC 解码）
- [x] mg 内置歌词接口：lrcUrl + mrcUrl TEA 解密 + trcUrl 翻译（待真实 mrc 样本验证）
- [x] kw 搜索封面（web_albumpic_short -> 500px）
- [x] kg 搜索封面（Image 模板）与播放封面回退（media.store.kugou.com）
- [x] 用真实 MG mrc 样本验证 TEA 解密与 MRC 解析
- [x] 将 `lxlyric` 以 QRC 格式传给 flutter_lyric，逐字歌词优先于逐行 LRC
- [x] 带逐字歌词链路的 release APK 构建通过（151.4MB）
- [x] 带多源管理/错误提示的 release APK 构建通过（151.5MB）
- [ ] 播放 URL 失效后的媒体层自动重试
- [ ] `tx` / `wy` 接口失效时的错误提示与降级
- [ ] 用真实 `source=lx` 曲目测试播放/歌词/封面
- [ ] 请求失败/超时/取消不会崩溃
- [ ] 禁用/删除源后 Context 正确释放
- [ ] LX 播放统计按 `source=lx` + 平台 `sourceId` 记录，不污染本地统计
- [ ] 源脚本失效时错误可定位且不影响本地/OpenSubsonic
- [x] `reference/` 不被提交，应用不内置任何洛雪音源

## 已知问题 / 技术债

### 正确性与状态一致性

- LX source id 已改为 manifest 身份稳定 id，脚本更新复用同一记录；旧 content-hash 记录会在 store 打开时迁移并清理重复脚本
- 平台列表已拆成 `lxPlatformsProvider`（内置、恒可用）与 `lxPlayablePlatformsProvider`（autoDispose、仅播放门控）；源管理操作后只需 invalidate 后者
- `load_enabled_sources` 会在首次 list/search 时同步初始化所有启用源；已避免阻塞 bootstrap，但首次搜索仍可能等待脚本初始化
- LX 歌词正缓存长期保留、未命中负缓存 1 天；封面磁盘缓存按平台 + 歌曲 id，URL 变化时需等待缓存清理
- 全局缓存上限按默认比例（本地 1GB : Subsonic 2GB : 洛雪 512MB : 网易云 128MB）分配到四组；网易云封面有独立目录、限额与清理入口
- 缓存占用只统计“清除所有缓存”会释放的内容；LX 源脚本、播放统计库和播放队列不计入缓存大小
- `SourceType` 只有 `LocalFile` 和 `Opensubsonic`，LX 不在数据模型中；`source` 字段仍是字符串字面量，容易拼错
- 移动端首页只挂载播放器主视图，`mobile_welcome_section.dart` / `mobile_daily_section.dart` / `mobile_home_constants.dart` 当前无引用
- 本地歌单已实现：SQLite 持久化、CRUD、跨源条目快照、详情播放、移除与排序；封面复用首曲封面（本地 `trackCoverProvider` / 远端 `remoteCoverProvider`），schema v3 为条目新增 `cover_id` / `source_extra_json`，为歌单新增订阅元数据
- 媒体库首页已入口化；歌曲/专辑/艺术家/歌单页已统一本地/OpenSubsonic 并接入来源 chips 与 badge
- OpenSubsonic 歌单已接入 get/create/update/delete：详情、改名、删除、按索引移歌、加歌；暂未做 comment/public 编辑 UI
- 本地专辑/艺术家详情页已接入：专辑曲目按 `track_ids`、艺术家专辑按专辑艺术家/曲目关联聚合；跨源同名专辑/艺术家暂不自动合并
- LX 在线歌单当前已接入酷我 KW 与 QQ TX；WY / MG / KG 尚未实现，切过去会显示"该平台暂不支持歌单搜索"（官方 5/5 均有实现，待补）
- 媒体库首页的远端数量只读已缓存 Provider；首次进入且未打开过对应详情页时显示 `—`，不主动触发全量远端加载
- 移动端内容设置已接通“选择本地媒体库”与“扫描”；真机上 SAF 目录持久授权与 Rust 扫描结果仍需验证

### 播放、音频服务与平台

- 自研 MPRIS 会卡死 waybar，已停用；`linux_mpris.dart` 仍留在仓库但没有引用，后续应迁移 audio_service 或删除
- Android 已接入 just_audio + audio_service；后台、锁屏、通知、划掉 App、scrobble 已完成真机验证
- `MediaSessionService` 仍是 Noop，`MediaIntegrationHost` 仅做简单状态同步；当前真正生效的是 `LaetibeatAudioHandler` 直连 PlayerNotifier
- `PlaybackBackend` 已接入 buffering / error / processing phase；媒体通知的加载/缓冲/错误状态仍需在 Android 真机上验证
- audio_service 只在 Android 初始化；iOS 目前没有后台媒体会话接入
- media_kit 在 Android 上出现过原生 SIGSEGV；Android 已改用 just_audio，桌面风险另论
- Android 本地音乐库已改为单 SAF tree：`saf.walk` 发现文件、`withFileDescriptor` 把原始 fd 交给 Rust；Rust 用 `dup(fd)` 构造 File 后交给 `lofty::read_from`，避免经 `/proc/self/fd` 重新打开时被 scoped storage 拒绝
- SAF 同目录 `.lrc`/`.txt` 外挂歌词与 `cover.jpg`/`folder.jpg` 等文件夹封面已接入；扫描已加入目录/解析进度、取消和批量并发，封面读取限制 3 路并发，仍需大曲库真机压力验证
- Android `usesCleartextTraffic="true"` 全局放开；LX 的 kw/wy 等接口需要 HTTP，但建议改为按域名白名单的 network security config
- 通知点击回到播放页/当前页面尚未验证
- 导航 Favorite/History/Daily Recommend 目前只改变选中态，不切换页面
- 桌面 `chart_page.dart` / `playlist_page.dart` 仍是 `Placeholder`
- AndroidEqualizer 的频段数量/频率由设备决定，当前 UI 固定展示 5 个典型频段
- 淡入淡出通过音量渐变实现，不是双 deck 的 crossfade；切歌仍有短暂换曲间隔
- 当前只接入 AndroidEqualizer 和 LoudnessEnhancer 能力；压缩/限幅/Bass Boost/Virtualizer/Crossfeed 尚无实现
- 高级 DSP、USB 独占、DSD 尚未实现；当前没有现成 Flutter 包可直接满足
- 蓝牙/外放仍经过 Android 混音与蓝牙编码，DSP 可改善听感但无法 bit-perfect
- Flick 试听与 just_audio 差异不明显，音质问题更可能来自解码/系统音效/耳机调音；后续以 ReplayGain、EQ、DSP 为主线

### 远端与缓存

- 远端同步仅支持全量，暂无取消与增量；大库同步时间较长
- Scrobble 为 best-effort，服务器离线时不会补报
- 推荐聚合会把全部远端曲目缓存到内存，超大曲库需要改为聚合查询
- 远端推荐依赖先执行一次「同步音乐」
- 远端歌词正缓存没有 TTL，服务器更新歌词后需要手动清理
- 本地音乐库仍使用 JSON 快照；播放统计与远端库使用两个独立 SQLite
- 歌词搜索结果的应用是当前会话内存覆盖，尚未持久化到本地 .lrc 或数据库
- 多个设置分类仍是占位：备份与还原、更新日志；桌面“储存”“播放器与音频”仍为占位
- 大量 UI 文案仍是硬编码中文，未全部接入 l10n

### LX 运行时与安全

- QuickJS 已设置 64MB 内存上限、512KB 栈限制和 init/action 执行超时/中断；独立进程级崩溃隔离仍未实现
- `eval` 已禁用，但动态 `Function` 仍可用；文件系统/宿主内部对象隔离仍需验证
- LX HTTP 当前使用同步 `reqwest::blocking`，请求会阻塞对应 JS 执行线程；后续改为异步 request broker
- 每个请求没有 requestKey，无法完成/失败/取消回写 JS
- `setTimeout` 目前是有界 timer pump，不是长期异步事件循环；超过 5 秒的定时任务会失败
- `updateAlert` host 回调为空实现，移动端更新提示 UI 未接入
- SourceManager 的 status/declarations 仅存在内存，没有持久化；冷启动失败不可见
- LX 自定义源主要提供 `musicUrl` / `lyric` / `pic`，通常不提供搜索；搜索层需要单独维护
- 洛雪音源脚本属于第三方内容，不随应用分发；不同脚本的兼容性、可用性和版权风险需由用户自行承担
- `reference/lx-music-mobile` 已从 git 索引移除（保留本地目录），不会再进仓库/发布包
- 仓库根目录暂无 `LICENSE` / 第三方 `NOTICE`；发布前需确认 QuickJS/rquickjs、FFmpeg、opensubsonic 等依赖的分发合规
- Flutter release 构建可能复用包含 `integration_test` 的旧 `GeneratedPluginRegistrant.java`；失败时删除该生成文件或 `flutter clean` 后重试
- Dart 侧测试仅覆盖 form factor 等少量逻辑；播放队列、搜索聚合、缓存设置、LX UI 缺少回归测试
