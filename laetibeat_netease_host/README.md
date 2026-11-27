# laetibeat_netease_host

Laetibeat 的网易云音乐本地 host。基于
[`ncm-api-rs`](https://github.com/SPlayer-Dev/ncm-api-rs) 的纯 Rust SDK，
作为独立 sidecar 运行，不依赖 Node / Python / Docker / NAS。

> 当前为 N2 spike：已接搜索、播放 URL、歌词、二维码登录与 Cookie 持久化；
> Flutter 尚未接入。

## 构建

```bash
# Linux
cargo build --release -p laetibeat_netease_host

# Android arm64（NDK 28）
NDK=$ANDROID_SDK/ndk/28.2.13676358
BIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin
CC_aarch64_linux_android=$BIN/aarch64-linux-android24-clang \
AR_aarch64_linux_android=$BIN/llvm-ar \
RANLIB_aarch64_linux_android=$BIN/llvm-ranlib \
CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER=$BIN/aarch64-linux-android24-clang \
cargo build --release -p laetibeat_netease_host --target aarch64-linux-android
```

## 运行

```bash
LAETIBEAT_MUSICAPI_ADDR=127.0.0.1:0 \
LAETIBEAT_MUSICAPI_TOKEN=secret \
LAETIBEAT_MUSICAPI_DATA_DIR="$HOME/.local/share/laetibeat/netease" \
./laetibeat_netease_host
```

启动后 stdout 输出：

```text
LAETIBEAT_MUSICAPI_LISTEN=127.0.0.1:PORT
```

所有请求需要：

```text
Authorization: Bearer secret
```

环境变量：

| 变量 | 默认 | 说明 |
|---|---|---|
| `LAETIBEAT_NETEASE_ADDR` / `LAETIBEAT_MUSICAPI_ADDR` | `127.0.0.1:0` | 监听地址 |
| `LAETIBEAT_NETEASE_TOKEN` / `LAETIBEAT_MUSICAPI_TOKEN` | 空 | Bearer token；非 loopback 时必须 |
| `LAETIBEAT_NETEASE_DATA_DIR` / `LAETIBEAT_MUSICAPI_DATA_DIR` | `.laetibeat-netease` | 数据目录 |
| `LAETIBEAT_MUSICAPI_PARENT_PID` | 空 | 父进程退出后自动退出 |

数据目录：

```text
cookies.json    登录 Cookie（0600）
```

未登录时 host 会自动注册游客 token；游客 token 不写入 `cookies.json`。

## 当前 HTTP API

### 健康检查

```http
GET /laetibeat/health
```

### 搜索

```http
GET /api/v1/music/search?q=稻香&type=song|playlist|album|artist&limit=10&offset=0
```

返回 ncm-api-rs 的原始 `body`，放在 `data` 下。

### 播放 URL

```http
GET /api/v1/music/url?id=3404293607&quality=high|standard|lossless|hires
```

先尝试 `song_url_v1`；失败时回退到旧的 `br=999000` 接口。返回值中包含实际
`quality` 和 `url`；网易云返回的 URL 通常为 HTTP，由 App 的 HTTPS-only 转发器处理。

### 歌词

```http
GET /api/v1/music/lyric?id=3404293607
```

返回 `lyric` 与 `trans`。

### 二维码登录

```http
GET /api/v1/login/qr
GET /api/v1/login/qr/status?key=...
```

二维码只返回 `qrurl`（网易云登录链接），由 App 使用 `qr_flutter` 渲染。

状态：`waiting` / `scanned` / `success` / `expired` / `failed`。


## laetibeat_online 兼容层

N4 起，现有 `laetibeat_online` 客户端可直接指向本 host。兼容端点：

```text
GET    /api/v1/music/search?q=&type=song|playlist|album&sources=netease&limit=&offset=
GET    /api/v1/music/url?source=netease&id=&quality=
GET    /api/v1/music/lyric?source=netease&id=
GET    /api/v1/music/qualities
GET    /api/v1/playlist/detail?source=netease&id=
GET    /api/v1/album/detail?source=netease&id=
GET    /api/v1/playlist/user?source=netease&page=&limit=
GET    /api/v1/playlist/recommend?sources=netease
GET    /api/v1/ranking/toplists?sources=netease
GET    /api/v1/ranking/toplist?source=netease&toplist_id=
GET    /api/v1/ranking/hot?source=netease&limit=
GET    /laetibeat/system/platforms
DELETE /laetibeat/system/platforms/netease
POST   /api/v1/system/qr_login/netease
GET    /api/v1/system/qr_login/netease?key=
```

所有 envelope 使用 `code=200`；`data` 结构与 go-music-api 客户端 DTO 对齐。

## 安全

- 默认只绑定 loopback
- 非 loopback + 空 token 拒绝启动
- Bearer token 常量时间比较
- 请求体上限 4 MiB
- 不添加 CORS
- 访问日志只记录 method/path/status/duration，不记录 query

## 许可证

Host 代码 MIT；依赖 `ncm-api-rs` 为 WTFPL。详见 `LICENSE` 与
`THIRD_PARTY_NOTICES.md`。
