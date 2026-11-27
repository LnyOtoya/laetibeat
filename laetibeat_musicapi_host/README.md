# laetibeat_musicapi_host

Laetibeat 的内置音乐服务 host。它把
[`go-music-api`](https://github.com/guohuiyuan/go-music-api) 的 `router` / `service`
作为库导入，并在外层提供：

- `127.0.0.1` 随机端口（内置模式）或指定地址（远程模式）
- 可选 Bearer token
- App 私有数据目录（`cookies.json`）
- 路由屏蔽：封面代理、Cookie 明文接口、Swagger、旧 `/music/*` 兼容路由
- CORS 移除、请求体上限、访问日志脱敏

上游源码不做任何修改。升级只需修改 `go.mod` 的版本号。

Flutter 构建会自动调用本目录：

- Android：`android/app/build.gradle.kts` 用 NDK clang + CGO 构建 arm64 host，输出到 `jniLibs/arm64-v8a/`
- Linux：`linux/CMakeLists.txt` 用 `CGO_ENABLED=0` 构建并安装到 `bundle/lib/`

前提：构建机需要安装 Go 1.25+；Android 还需要与 Flutter 对齐的 NDK。

## 构建

```bash
go mod tidy
go test ./...
CGO_ENABLED=0 go build -trimpath -ldflags '-s -w' -o build/laetibeat_musicapi_host .
```

Android 必须使用 NDK + CGO（Android 上纯 Go DNS 不可用）：

```bash
NDK=$ANDROID_SDK/ndk/28.2.13676358
CC=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang
CGO_ENABLED=1 GOOS=android GOARCH=arm64 CC=$CC \
  go build -buildmode=pie -trimpath -ldflags '-s -w' \
  -o build/arm64-v8a/liblaetibeat_musicapi_host.so .
```

## 运行

```bash
LAETIBEAT_MUSICAPI_ADDR=127.0.0.1:0 \
LAETIBEAT_MUSICAPI_TOKEN=secret \
LAETIBEAT_MUSICAPI_DATA_DIR="$HOME/.local/share/laetibeat/musicapi" \
./build/laetibeat_musicapi_host
```

启动后 stdout 第一行：

```text
LAETIBEAT_MUSICAPI_LISTEN=127.0.0.1:40319
```

后续所有请求带：

```text
Authorization: Bearer secret
```

健康检查：

```bash
curl -H 'Authorization: Bearer secret' \
  http://127.0.0.1:40319/laetibeat/health
```

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `LAETIBEAT_MUSICAPI_ADDR` | `127.0.0.1:0` | 监听地址 |
| `LAETIBEAT_MUSICAPI_TOKEN` | 空 | 为空时不鉴权；内置模式必须设置 |
| `LAETIBEAT_MUSICAPI_DATA_DIR` | 当前目录 | Cookie 等写入目录 |
| `LAETIBEAT_MUSICAPI_PARENT_PID` | 空 | 内置模式父进程 PID；父进程退出后自动退出 |

## 安全说明

默认屏蔽：

- `/api/v1/music/cover`、`/music/download_cover`（任意 URL 抓取，SSRF）
- `/api/v1/system/cookies`、`/music/cookies`（明文 Cookie）
- `/swagger/*`
- `/music/*` 兼容路由

远程模式必须置于 HTTPS 反向代理之后，并设置 token；不要把 `0.0.0.0` 明文端口直接暴露到公网。

## 许可证

AGPL-3.0。详见 `LICENSE`。上游 `go-music-api` 与 `music-lib` 同样为 AGPL-3.0。
