# laetibeat_qq_host

Laetibeat 的 QQ 音乐本地 host。基于
[`QQMusicApi-rs`](https://github.com/jinzhongjia/QQMusicApi-rs) 的纯 Rust 客户端，
作为独立 sidecar 运行，不依赖 Node / Python / Docker / NAS。

> 当前为 N1 spike：已接搜索、播放 URL、歌词、QQ/微信二维码登录与 Credential 持久化；
> Flutter 尚未接入。

## 构建

```bash
# Linux
cargo build --release -p laetibeat_qq_host

# Android arm64（NDK 28）
NDK=$ANDROID_SDK/ndk/28.2.13676358
BIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin
CC_aarch64_linux_android=$BIN/aarch64-linux-android24-clang \
AR_aarch64_linux_android=$BIN/llvm-ar \
RANLIB_aarch64_linux_android=$BIN/llvm-ranlib \
CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER=$BIN/aarch64-linux-android24-clang \
cargo build --release -p laetibeat_qq_host --target aarch64-linux-android
```

Android 产物是 PIE 可执行文件，可按后续 N5 方案放入 `jniLibs` 并从
`nativeLibraryDir` 启动。

## 运行

```bash
LAETIBEAT_MUSICAPI_ADDR=127.0.0.1:0 \
LAETIBEAT_MUSICAPI_TOKEN=secret \
LAETIBEAT_MUSICAPI_DATA_DIR="$HOME/.local/share/laetibeat/qq" \
./laetibeat_qq_host
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
| `LAETIBEAT_QQ_ADDR` / `LAETIBEAT_MUSICAPI_ADDR` | `127.0.0.1:0` | 监听地址 |
| `LAETIBEAT_QQ_TOKEN` / `LAETIBEAT_MUSICAPI_TOKEN` | 空 | Bearer token；非 loopback 时必须 |
| `LAETIBEAT_QQ_DATA_DIR` / `LAETIBEAT_MUSICAPI_DATA_DIR` | `.laetibeat-qq` | 数据目录 |
| `LAETIBEAT_MUSICAPI_PARENT_PID` | 空 | 父进程退出后自动退出 |

数据目录：

```text
device.json        QQMusicApi-rs 设备身份
credential.json    登录凭证（0600）
```

## 当前 HTTP API

### 健康检查

```http
GET /laetibeat/health
```

### 搜索

```http
GET /api/v1/music/search?q=稻香&type=song|playlist|album&limit=10&page=1
```

返回 `{code:0,msg:"ok",data:{songs|playlists|albums:[...]}}`。

### 播放 URL

```http
GET /api/v1/music/url?mid=002PZvTU4YHsBI&quality=high|standard|lossless
```

### 歌词

```http
GET /api/v1/music/lyric?mid=002PZvTU4YHsBI
```

### 二维码登录

```http
GET /api/v1/login/qr?type=qq|wx|mobile
GET /api/v1/login/qr/status?identifier=...
```

`type=mobile` 的轮询尚未接入；当前支持 QQ / 微信。登录成功后凭证写入
`credential.json`，后续启动自动加载。

## 安全

- 默认只绑定 loopback
- 非 loopback + 空 token 拒绝启动
- Bearer token 常量时间比较
- 请求体上限 4 MiB
- 不添加 CORS
- 访问日志只记录 method/path/status/duration，不记录 query

## 许可证

本 host 及其依赖 `qqmusic-api` 使用 **GPL-3.0-only**。详见 `LICENSE`。
