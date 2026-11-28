# Changelog

## [Unreleased]

### Added

- UI Skin 骨架：`ui.skin` 持久化、`AppSkin` 契约与注册表；默认皮肤仍为 Material 3 Expressive。
- 移动端一级导航按音源模式动态变化：本地 2 个、Subsonic 3 个、QQ / 网易云 4 个，并自动落到模式默认页。
- 网易云首页接入 `/homepage/block/page` 动态 feed：支持 `refresh`、`cursor`，渲染推荐歌单、猜你喜欢、雷达歌单、新歌新碟等 block。
- 网易云首页顶部新增可横向滑动的六卡快捷入口：今日推荐、心动模式、歌单推荐、漫游、雷达歌单、相似歌曲；今日推荐进入每日推荐页，歌单/雷达进入列表页，其余直接播放。
- 网易云首页按 1.0.1 发现页重构：顶部横向大卡、私人 FM、block 卡片轮播/歌曲分栏、下拉刷新。
- 网易云首页新增「私人 FM」区块：采用 Subsonic「为你发现」布局，展示 3 首私人 FM 歌曲，支持换一批、播放全部与下拉刷新。
- 移除「根据你喜爱的歌曲推荐」区域。
- 首页雷达歌单固定展示私人 / 时光 / 宝藏 / 新歌四个（ID 固定），标题与封面来自账号当日数据，每日刷新；不再使用用户歌单名称白名单。
- 在线页面使用 host 磁盘响应缓存：切换页面与重启程序展示上次内容，只有下拉刷新会清空缓存并重新请求。
- 新增 `docs/mode-pages.md` 记录导航与页面内容矩阵。

### Fixed

- 修复 QQ / 网易云模式下搜索被误判为“当前模式不提供在线搜索”。
- 网易云首页与雷达接口要求真实登录，未登录直接提示登录；移除游客 token 与匿名首页 feed。
- 私人 FM 大卡与小卡不再重复：host 连续拉取多批去重补足数量，小卡从第 2 首开始展示。
- 网易云封面经本机 host 图片代理加载，修复部分封面因 CDN 403 显示占位的问题。

## [1.1.0] - 2026-11-27

### Upgrade Notice

- 在线音源后端从 go-music-api 切换为 QQ / 网易云独立 Rust sidecar。
- 旧「内置服务 / 远程服务」配置不再使用；首次升级后请在「设置 → 音源模式」选择 QQ 或网易云。
- 在线账号 Cookie / Credential 目录变更，需要重新扫码登录。
- 本地 / Subsonic 模式不启动在线 sidecar。

### Added

- 音源模式：本地 / Subsonic / QQ / 网易云，持久化 `app.mode`。
- QQ / 网易云独立 Rust sidecar 的启动、停止、重启与切换；切换前暂停播放。
- 按模式隔离数据目录 `modes/{qq,netease}`，切回时恢复 Cookie / Credential。
- 设置页「音源模式」入口、sidecar 状态与开发期 host 路径覆盖。
- 搜索、播放、歌词、歌单、专辑、榜单、热门、二维码登录按模式切换。
- 发现页与账号列表跟随当前模式。
- Android jniLibs / Linux bundle 打包 QQ 与网易云 Rust host。
- Gradle / CMake / CI / release 许可证接入双 host。

### Removed

- 删除 `laetibeat_musicapi_host`、`third_party/music-lib` 与 Go 打包 / CI 链路。
- 删除旧 `onlineHostProvider` 与 builtin / remote 服务地址配置。

### Changed

- `laetibeat_online` 保留为两个 Rust host 的统一客户端。
- 在线设置只保留音质、LX 后备与账号；服务地址由模式 sidecar 提供。

## [1.0.2] - 2026-11-27

### Added

- 内置 go-music-api host：Android arm64/armv7/x86_64 与 Linux x64 随 App 分发，无需额外部署。
- 网易云 / QQ 统一在线音源：搜索、歌单、专辑、榜单、热门、播放、LRC。
- 网易云 / QQ / 微信扫码登录、账号状态、退出登录与「我的歌单」。
- 发现页平台切换、推荐歌单、排行榜、热门歌曲。
- 在线音频 HTTPS-only 本机转发器与 LX fallback。

### Changed

- 移除旧网易云 Node API 客户端、页面、Cookie 存储与兼容层。
- 在线音源设置支持「内置服务 / 远程服务」两种模式。
- 网易云搜索改用 go-music-api 的 weapi 实现（music-lib 本地补丁）。

### Security

- 远程 host 强制 HTTPS + Bearer token；本机 host 仅绑定 loopback。
- 屏蔽封面代理、Cookie 明文接口、Swagger 与旧 `/music/*` 路由。
- 内置 host 使用随机端口 / 随机 token，并在 App 退出后自动清理。

## [1.0.1] - 2026-11-27

### Security

- 网易云音源强制通过 HTTPS 请求，阻止 HTTPS 音源重定向降级到 HTTP；其他音源行为不变。

### Changed

- 网易云音频播放通过本机 loopback 转发器处理，并保留 Range 请求支持 seek。
- Debug 网络日志不输出带签名参数的完整音源 URL。

## [1.0.0] - 2026-11-26

### Added

- 首个正式版本。
- 本地音乐扫描、播放、封面、歌词与统计。
- OpenSubsonic / Navidrome 在线媒体库。
- 洛雪 LX 音源宿主与多平台搜索播放。
- 网易云在线音乐：搜索、登录、歌单、专辑、艺人、每日推荐。
- 发现页：登录后推荐卡片、动态区块、下拉刷新与封面缓存。
- 移动端首页、发现、媒体库、统计四个底部入口。
- 设置页显示安装包真实版本号。

### Fixed

- 修复网易云封面缓存并发写入/淘汰失败。
- 详情页封面与取色改为预取、渐进渲染和平滑主题过渡。
