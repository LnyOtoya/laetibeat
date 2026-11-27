# Laetibeat 多音源计划

> 状态：网易云 / QQ 在线音源已通过内置 `go-music-api` host 接入；M0–M4 完成，M5 进行中。
> 最后更新：2026-11-27
> 关联文档：`docs/musicapi-migration.md`（迁移设计与验收）、`TODO.md`（工程债）、`THIRD_PARTY_NOTICES.md`（AGPL/第三方许可）

## 目标

1. 用 **go-music-api + music-lib** 替代旧网易云 Node API，作为网易云 / QQ 的统一在线音源后端。
2. host 内置在 App 中（Android / Linux），不要求 NAS、Docker 或额外服务。
3. 远程 host 作为可选模式；远程必须 HTTPS + Bearer token。
4. 在线音源统一抽象：搜索、歌单、专辑、榜单、热门、直链、歌词、音质、扫码登录。
5. 洛雪只作为无版权/试听失败时的后备解析，不改变曲目身份。
6. 本地音乐、OpenSubsonic、LX 音源保持独立，不受在线音源影响。

## 当前架构

```text
Flutter (mobile/desktop)
  └─ Riverpod providers
      └─ Rust `laetibeat_online`
          └─ loopback HTTP + Bearer token
              └─ 内置 / 远程 `laetibeat_musicapi_host`
                  ├─ go-music-api router/service
                  └─ music-lib providers (netease / qq)
```

- 内置模式：App 启动后拉起 Go host，随机 loopback 端口 + 随机 Token；host 生命周期由 App 管理。
- 远程模式：用户填写 HTTPS Base URL + Token；Rust 客户端执行 HTTPS-only/重定向策略。
- 音频：播放器只消费 URL；在线 URL 经本机 HTTPS-only 转发器，HTTP 源升级 HTTPS，拒绝 HTTPS→HTTP 降级。
- 登录：网易云 / QQ / 微信扫码，Cookie 由 host 写入数据目录 `cookies.json`；App 只读取“是否登录”，不接触 Cookie 明文。
- 曲目身份：`source` = `netease` / `qq`；`ui_id` = `source:platformId`；LX fallback 不改变身份。

## 已完成里程碑

### M0：Go host 骨架

- [x] `laetibeat_musicapi_host/` Go module
- [x] loopback 随机端口、Bearer token、数据目录
- [x] 路由屏蔽：封面代理、Cookie 明文接口、Swagger、旧 `/music/*`
- [x] 请求体上限、CORS 移除、脱敏访问日志
- [x] Linux 构建、健康检查、单元测试

### M1：Rust 客户端 + 核心在线

- [x] `laetibeat_online`：HTTPS 策略、搜索/歌单/专辑/榜单/热门/直链/歌词/音质
- [x] FRB API 与 Dart providers
- [x] 设置页：服务地址、Token、测试连接、默认音质、LX 后备
- [x] 搜索页：网易云 / QQ 歌曲、歌单、专辑
- [x] 播放：在线直链、headers、HTTPS-only 转发器、LX fallback
- [x] 网易云搜索修复：music-lib 本地单函数 fork（weapi）

### M2：发现页平台选择

- [x] AppBar 平台切换（网易云 / QQ），选择持久化
- [x] 推荐歌单、排行榜、热门歌曲
- [x] 榜单详情页、分 section 加载/错误/空态、下拉刷新

### M3：登录与我的歌单

- [x] 网易云 QR、QQ QR、微信 QR
- [x] host `cookies.json` 持久化
- [x] `GET /laetibeat/system/platforms` 只返回 `has_cookie`
- [x] `DELETE /laetibeat/system/platforms/{source}` 退出登录
- [x] 设置页账号区、发现页「我的歌单」

### M4：内置打包与进程管理

- [x] Android：Gradle + NDK clang/CGO，arm64 / armv7 / x86_64 host 到 `jniLibs`
- [x] `extractNativeLibs=true` + `useLegacyPackaging=true`
- [x] Linux：CMake 构建并安装 host 到 `bundle/lib`
- [x] Dart `OnlineHostController`：随机端口/token、健康检查、异常重启、父进程退出清理
- [x] 内置 / 远程模式切换与运行时地址覆盖
- [x] Android 真机：DNS、搜索、发现页、播放、后台、kill 重启、force-stop 清理
- [x] Linux bundle host 启动与健康检查

## 目录

```text
laetibeat_online/              Rust 在线音源客户端（MIT）
laetibeat_musicapi_host/       Go host（AGPL-3.0）
  third_party/music-lib/       本地 pinned 副本 + 网易云搜索补丁
laetibeat_flutter/
  lib/widgets/settings/online_*.dart
  lib/pages/mobile/discover/
  lib/pages/mobile/library/online/
  lib/pages/mobile/settings/online/
  lib/core/playback/online_audio_https_proxy.dart
docs/musicapi-migration.md     迁移设计、阶段验收、风险
```

## 安全模型

- 远程地址强制 HTTPS；仅 loopback 允许 HTTP。
- 重定向最多 5 跳；远程不跨 host、不允许 HTTPS→HTTP。
- host 默认只绑定 `127.0.0.1`；非 loopback 无 token 拒绝启动。
- 屏蔽 `/api/v1/music/cover`、`/api/v1/system/cookies`、`/music/*`、Swagger。
- 访问日志只记录 method/path/status/duration，不记录 query。
- 内置 Token 每次启动随机生成，不持久化；远程 Token 存 `flutter_secure_storage`。
- Cookie 只存在 host 数据目录；App 侧不返回 Cookie 明文。

## 当前限制

- 扫码登录需要用户在设备上人工确认；自动化只覆盖二维码会话创建/轮询。
- QQ 部分 VIP/版权歌曲直链返回 500；可开启洛雪后备或登录 QQ。
- 远程 host 是单用户假设；多用户共享会串 Cookie。
- 桌面端在线音乐入口尚未补齐（Linux host 打包已就绪）。
- iOS 只能使用远程模式。
- `third_party/music-lib` 是本地补丁；上游修复网易云搜索后应删除并 bump 版本。

## M5：清理与合规

- [x] Gradle 支持 arm64 / armv7 / x86_64 host
- [x] CI host 矩阵：Linux amd64/arm64 + Android arm64/armv7/x86_64
- [x] `THIRD_PARTY_NOTICES.md` 增加 go-music-api / music-lib / qr_flutter
- [x] 关于页增加 AGPL 源码入口与 LicenseRegistry 条目
- [x] `TODO.md` 顶部更新当前状态并标注历史条目
- [x] `ARCHITECTURE.md` 与实现同步
- [ ] 首次 CI / Release 验证

## 历史

旧网易云 Node API 实现保留在 `api` 分支，不再维护。`main` 已移除
`laetibeat_netease`、旧网易云 UI/缓存/HTTPS 代理与 Node API 后端。

## 验收

- `flutter analyze`：0 error
- `flutter test`：通过
- `cargo test --workspace`：通过
- `go test ./...`：通过
- Android 真机 + Linux bundle：内置 host 可用
