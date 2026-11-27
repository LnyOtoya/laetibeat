# Native Modes Migration

> 状态：已决策，尚未实现。目标分支 `native`；当前 go-music-api 实现保留在 `gomusic`。
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
ncm-api-rs = { path = "../reference/ncm-api-rs", features = ["server"] }
```

但不直接使用 `ncm-server` 默认配置：

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

### N1：QQ host spike

- [ ] `laetibeat_qq_host` crate
- [ ] 搜索 / 播放 URL / 歌词
- [ ] 二维码登录
- [ ] Credential 持久化
- [ ] Linux + Android arm64 构建

### N2：NetEase host spike

- [ ] `laetibeat_netease_host` crate
- [ ] 搜索 / 播放 URL / 歌词
- [ ] 二维码登录
- [ ] Cookie 持久化
- [ ] Linux + Android arm64 构建（已验证库可编译）

### N3：模式控制器

- [ ] `AppMode` provider
- [ ] sidecar start/stop
- [ ] 数据目录按模式隔离
- [ ] 切换时暂停播放
- [ ] 切换回来恢复 Cookie

### N4：UI 分模式

- [ ] 首页 / 发现 / 搜索按模式显示
- [ ] QQ 与网易云各自的个性化 section
- [ ] 设置页模式选择
- [ ] 登录/退出按模式隔离

### N5：打包

- [ ] Android 双 host jniLibs
- [ ] Linux 双 host bundle
- [ ] CI host matrix
- [ ] release assets / licenses

### N6：删除 go-music-api

- [ ] 删除 `laetibeat_musicapi_host`
- [ ] 删除 `third_party/music-lib`
- [ ] 删除 Go 相关 Gradle/CMake/CI
- [ ] 删除 go-music-api Rust 客户端代码
- [ ] 更新文档与许可证

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

- `QQMusicApi-rs` 默认纯 Rust（`tls-graviola`），aarch64 / x86_64 不需要 C 工具链；尚未做 Android spike。

## 13. 相关文档

- `reference/QQMusicApi-rs/README.md`
- `reference/ncm-api-rs/README.md`
- `reference/ncm-api-rs/docs/API.md`
- `docs/musicapi-migration.md`（仅适用于 gomusic 分支）
- `ARCHITECTURE.md`
