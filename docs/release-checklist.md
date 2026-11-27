# Release Checklist

> 当前目标版本：`1.0.2`（2026-11-27）
> 版本策略：tag `vMAJOR.MINOR.PATCH`；`pubspec` 使用 `X.Y.Z+VERSION_CODE`。
> `versionCode = MAJOR * 1000000 + MINOR * 1000 + PATCH`。
> split APK 会在 base versionCode 上叠加 ABI offset：armv7 `+1000`、arm64 `+2000`、x86_64 `+4000`。

## 1. 发版前

- [ ] 分支为 `main`，本地与 `origin/main` 一致
- [ ] CI 的 `test` / `host` job 均通过
- [ ] 工作区干净
- [ ] `laetibeat_flutter/pubspec.yaml` 版本与目标 tag 一致
- [ ] `CHANGELOG.md` 有非空 `## [版本] - YYYY-MM-DD` 段落
- [ ] `THIRD_PARTY_NOTICES.md`、`laetibeat_musicapi_host/LICENSE`、`third_party/music-lib/LICENSE` 存在
- [ ] 本地 `android/key.properties` 指向正确 keystore
- [ ] GitHub Secrets 已配置：
  - `ANDROID_KEYSTORE_BASE64`
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_ALIAS`
  - `ANDROID_KEY_PASSWORD`

版本号修改示例（`1.0.2`）：

```yaml
# laetibeat_flutter/pubspec.yaml
version: 1.0.2+1000002
```

```markdown
## [1.0.2] - 2026-11-27
```

## 2. 本地预检

```bash
export PATH="$HOME/Development/flutter/bin:$PATH"
scripts/release_preflight.sh v1.0.2 --build
```

脚本会检查：

- pubspec 版本 / versionCode 与 tag 一致
- CHANGELOG 段落存在且非空
- AGPL / 通知文件存在
- 工作区干净（可用 `--allow-dirty` 临时跳过）
- `flutter analyze` / `flutter test`
- `cargo test --workspace`
- `go test ./...`
- release split APK：
  - 三个 ABI 均包含 `liblaetibeat_musicapi_host.so`
  - `extractNativeLibs=true`
  - `versionName` / `versionCode` 正确
  - `apksigner verify` 通过

> 注意：`--allow-dirty` 仅用于本地调试；正式发版必须从干净的 commit 运行。

## 3. 真机冒烟

- [ ] 安装 `app-arm64-v8a-release.apk`
- [ ] 首次启动后「发现」能自动加载内置 host 内容
- [ ] 网易云 / QQ 搜索
- [ ] 播放一首歌；按 Home 后继续播放
- [ ] 设置 → 在线音乐：内置服务运行中；可切换远程模式
- [ ] 设置 → 关于 → 在线音源源码可打开
- [ ] 从上一版本覆盖安装，数据与 Cookie 保留
- [ ] `adb shell am force-stop <包名>` 后无残留 host 进程

## 4. 打 Tag 并发布

```bash
git tag -a v1.0.2 -m "Laetibeat 1.0.2"
git push origin v1.0.2
```

Release workflow 会：

- 校验 tag 与 CHANGELOG
- 运行 Flutter / Rust / Go 测试
- 构建 split APK（arm64-v8a / armeabi-v7a / x86_64）
- 上传 APK、SHA256SUMS、MIT/AGPL 许可证、`THIRD_PARTY_NOTICES.md`
- 创建 GitHub Release

也可以用 `workflow_dispatch` 指定已存在的 tag。

## 5. 发布后

- [ ] Release 页面 assets 完整
- [ ] 三个 APK 都能从 GitHub Release 下载安装
- [ ] `SHA256SUMS.txt` 与文件一致
- [ ] Release notes 与 CHANGELOG 一致
- [ ] 覆盖安装 / 更新检查路径正常
- [ ] 记录发布链接与已知问题

## 6. 回滚

```bash
# 删除远端 tag（仅在发布内容有严重问题时）
git push origin :refs/tags/v1.0.2
git tag -d v1.0.2
```

然后：

- 重新打一个修复版本 tag；不要复用已发布的版本号
- 在 Release 页面标记旧版本为 pre-release 或删除
- 记录 Android versionCode 不能回退的兼容性影响

## 7. 当前 1.0.2 已知事项

- 内置 host 以 AGPL-3.0 分发；源码入口见关于页与 `THIRD_PARTY_NOTICES.md`
- 网易云搜索依赖 `third_party/music-lib` 的 weapi 本地补丁
- QQ 部分 VIP / 版权歌曲直链可能失败；可开启洛雪后备或登录 QQ
- 远程 host 为单用户假设
- iOS 仅支持远程模式
