# Changelog

## [Unreleased]

### Added

- native 分支：`AppMode`（本地 / Subsonic / QQ / 网易云）与 `app.mode` 持久化。
- native 分支：`ModeHostController` 管理 QQ / 网易云 Rust sidecar 的启动、停止、重启与切换。
- native 分支：按模式隔离数据目录 `modes/{qq,netease}`，切换时暂停播放并自动恢复 Cookie / Credential。
- native 分支：设置页「音源模式」入口、sidecar 状态与开发期 host 路径覆盖。
- native 分支：现有在线客户端可直接使用 QQ / 网易云 host。
- native 分支：搜索、播放、歌词、歌单、专辑、榜单、热门、二维码登录按模式切换。
- native 分支：发现页与账号列表跟随当前模式。
- native 分支：Android jniLibs / Linux bundle 打包 QQ 与网易云 Rust host。
- native 分支：Gradle / CMake / CI / release 许可证接入双 host。

### Removed

- native 分支：删除 `laetibeat_musicapi_host`、`third_party/music-lib` 与 Go 打包/CI 链路。
- native 分支：删除旧 `onlineHostProvider` 与 builtin/remote 服务地址配置。

### Changed

- native 分支：`laetibeat_online` 保留为两个 Rust host 的统一客户端。
- native 分支：在线设置只保留音质、LX 后备与账号；服务地址由模式 sidecar 提供。

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
