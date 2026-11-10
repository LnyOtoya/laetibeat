# Laetibeat 项目蓝图

> 最后更新：2026-11-10
> 当前阶段：本地 / OpenSubsonic / LX 三源搜索与播放链路已打通，进入正确性、稳定性与工程债收尾

## 当前状态速览

- 本地音乐：扫描、增量复用、专辑/艺术家聚合、播放、封面、歌词、统计、推荐
- Navidrome：单服务端配置、手动同步、SQLite 快照、浏览/搜索/播放、封面/歌词、scrobble
- 缓存：本地封面按需读取；远端封面内存 + 磁盘 LRU；歌词 SQLite 正负缓存；LX 歌词 SQLite 正缓存 + 封面磁盘 LRU；移动端缓存管理支持总上限滑块、三源明细与一键释放空间
- 移动端：音乐库/搜索/设置/播放页/迷你播放器已完成；首页目前只保留播放器主视图，`mobile_welcome_section` / `mobile_daily_section` 组件尚未接入
- 移动端 OpenSubsonic：连接、测试、扫描、歌单、艺术家简介、专辑/曲目浏览已接入真实数据
- 音效：移动端已接入系统 5 段均衡器、淡入淡出；配置音源后自动切换默认歌曲来源
- 歌词：已接入 LRCLIB、LiriQo 搜索，支持逐字/逐行/静态标记、翻译与临时应用
- 跨平台：Linux 桌面可用；Android UI 已解耦，audio_service 后台/锁屏/通知已验证；Windows/macOS 打包未开始
- LX 音源：QuickJS、inited、HTTP、AES/RSA、setTimeout、SourceStore、SourceManager、FRB facade、移动端管理 UI、五平台独立搜索、`musicUrl` / `lyric` / `pic` 播放链路已打通
- LX 剩余重点：脚本执行安全与中断、源生命周期与懒加载、稳定 source id、歌词/封面持久缓存、真实源联调
- 主要功能缺口：收藏/歌单编辑/队列编辑/下载、移动端 SAF、MPRIS 迁移、高级 DSP/响度归一
- 音频后端：桌面 media_kit；Android 使用 just_audio + audio_service；音频效果第一版已接入

## 当前优先事项（2026-11-10）

> 排序原则：用户可见错误 > 稳定性/安全 > 功能补齐 > 工程债。
> 详细背景见各阶段条目与“已知问题 / 技术债”。

### P0 正确性与用户可见问题

- [ ] 修复 LX 播放统计来源：`PlaybackSessionTracker` 当前把 `source=lx` 记成 `local`，污染本地统计与推荐
- [ ] 搜索建议增加 300ms 防抖：`LibrarySearchSuggestions` 当前每次按键都会触发 LX 网络搜索
- [ ] LX 源导入/启用/禁用/删除/改优先级后刷新 `lxEnabledPlatformsProvider` 与 `lxSearchProvider`
- [ ] LX 冷启动改为懒加载：`init_lx_source_store` 不再同步 `load_enabled_sources()`，避免 bootstrap 被脚本初始化/网络阻塞
- [x] 缓存管理重做：总缓存上限滑块、启动时套用、UI 默认值与实际分配对齐、清理缓存时同步清理内存缓存；页面进入自动重扫、可见期间 3 秒刷新、支持下拉刷新（`flutter analyze` / `flutter test` 通过）
- [ ] 为 QuickJS 增加执行超时、内存上限、中断与死循环保护
- [ ] Android 接入 SAF / file_picker 目录选择，修复 `MobileDirectoryPicker` 返回 null
- [ ] `PlaybackBackend` 增加 buffering / error / processing phase，`LaetibeatAudioHandler` 不再固定 `processingState=ready`

### P1 稳定性与架构债

- [ ] LX 源 id 改为基于 manifest 身份的稳定 id，脚本 hash 仅作版本字段
- [ ] `lx.request` 从同步 `reqwest::blocking` 改为异步 request broker，支持取消
- [x] LX 歌词/封面持久化缓存，并与缓存分组统计对齐
- [ ] 远端同步支持增量、取消与进度节流；推荐避免全量加载远端曲目
- [ ] 统一 `source` 类型（local / opensubsonic / lx）为常量或枚举，清理字符串字面量
- [ ] 清理死代码：`AudioSource`、`PlayState`、`SourceType::Opensubsonic`、`linux_mpris.dart`、`tmp.dart.bak`、未引用的移动首页组件
- [ ] 更新 `ARCHITECTURE.md`：当前移动端播放后端、单 Navigator、audio_service 状态
- [x] 在可用 Flutter 环境复验 `flutter analyze` / `flutter test`（2026-11-10；analyze 仍有 4 个既有 warning/info）
- [ ] 补充播放队列、搜索、缓存管理的回归测试
- [ ] 补齐仓库 LICENSE / 第三方 NOTICE，确认 QuickJS / FFmpeg 分发合规
- [ ] Android cleartext 改为按域名白名单的 network security config

### P2 功能补齐

- [ ] 收藏/喜欢（本地 + OpenSubsonic star/unstar）
- [ ] 本地歌单 CRUD 与加入歌单
- [ ] 队列编辑（加入队列、下一首播放、删除、拖动排序、清空）
- [ ] 下载
- [ ] 移动端首页推荐/历史接入，或删除孤立组件
- [ ] MPRIS 迁移到 audio_service，或彻底移除旧实现
- [ ] 高级 DSP / ReplayGain / 响度归一

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
- [x] 6.2 远端封面：内存 LRU + 磁盘 LRU（受总缓存上限的 Subsonic 份额控制），服务器变更时清理
- [x] 6.3 本地歌词：内嵌 → sidecar，按音频/sidecar 指纹缓存
- [x] 6.4 远端歌词：OpenSubsonic 返回，正缓存长期、负缓存 1 天
- [x] 6.5 歌词缓存 20MB 上限与过期负缓存清理
- [x] 6.6 搜索歌词：LRCLIB + LiriQo、逐字/逐行/静态、翻译、应用覆盖
- [ ] 6.7 搜索歌词持久化：写入本地 .lrc / 标签，或保存覆盖记录
- [x] 6.8 移动端缓存管理：总用量/上限、粗细进度条、释放空间、三源歌词/封面/其他明细、总缓存上限滑块、自动与下拉刷新

## 阶段7：跨平台与系统集成

- [x] 7.1 Linux 桌面音频输出与调试构建
- [x] 7.2 导航壳解耦：DesktopApp / MobileApp 分离，页面按形态独立组合
- [x] 7.3 页面响应式：桌面 TwoPaneLayout 窄屏折叠，移动端使用独立单栏页面
- [x] 7.4 移动端播放页：迷你播放器 + 全屏播放页，隐藏 DevicePanel
- [ ] 7.5 MPRIS 迁移到 audio_service + audio_service_mpris（当前自研 MPRIS 已停用）
- [x] 7.6 Android 后台播放、媒体会话、常驻通知（真机验证通过）
- [ ] 7.7 Windows / macOS / Android 打包与适配测试
- [x] 7.8 window_manager 平台门控与移动端启动配置
- [x] 7.9 移动端页面体系：首页/音乐库/搜索/设置/外观/内容/音源配置
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
- [x] 将 `reference/` 加入 `.gitignore`，发布前确认不进入源码包/APK
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
- [ ] 初始化超时、请求超时、脚本执行超时
- [ ] 为 QuickJS 设置内存上限与 interrupt handler，死循环可被中断
- [ ] 请求取消与 Context 销毁
- [x] 基础 JS 异常/结果回传
- [x] 禁止 `eval`
- [x] 脚本大小、inited 载荷、结果大小基础限制
- [ ] 禁止动态 `Function`、文件系统和宿主内部对象（当前只禁用了 `eval`）
- [ ] 完整输入/输出长度限制与 JSON 序列化校验
- [ ] 脚本内存/CPU 占用限制和崩溃隔离
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
- [ ] 生成稳定 source id：当前基于脚本全文 MD5，脚本一更新就会变成新源；应改为基于 manifest 身份，脚本 hash 仅作版本字段
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
- [ ] 导入/启用/禁用/删除/优先级变更后 invalidate `lxEnabledPlatformsProvider` / `lxSearchProvider`
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
- [ ] 修复 LX 播放统计来源：统计键使用 `source=lx` + 平台 `sourceId`
- [ ] 搜索建议 300ms 防抖，避免每次按键触发 LX 网络搜索

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
- [x] `cargo test --workspace` 通过（30 tests：core 5 / lx 22 / remote 3）
- [x] Android armv7/aarch64/x86_64 release Rust 编译通过（含 LX/QuickJS/FRB）
- [x] `flutter build apk --release` 通过（150.3MB；不要用 `--no-pub` 跳过插件注册表重生成）
- [x] 验证 `setTimeout` 延迟后解析 musicUrl
- [ ] 为 LX 统计来源、搜索防抖、Provider invalidation、缓存上限补充回归测试
- [ ] 验证 `musicUrl` 失败/超时/取消
- [ ] 验证歌词/封面返回格式与长度限制
- [ ] 验证恶意脚本无法访问文件/网络/宿主对象
- [ ] 验证 `eval` / 动态 Function 被阻止
- [ ] 验证脚本死循环能被中断
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
- [ ] 搜索输入防抖（300ms）：当前 `LibrarySearchSuggestions` 每次按键都会触发搜索
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

- `PlaybackSessionTracker` 只区分 `opensubsonic` 和 `local`，LX 播放会被记成 `local`，污染本地统计、Top 歌手/专辑与推荐；应使用 `source=lx` + 平台 `sourceId`
- 搜索建议未做 300ms 防抖，`LibrarySearchSuggestions` 每次按键都会触发 LX 网络搜索
- `lxEnabledPlatformsProvider` 没有 autoDispose 且从未 invalidate；启用/删除/禁用 LX 源后，搜索页能力列表可能一直保持旧值直到重启
- `init_lx_source_store` 在 bootstrap 中同步执行 `load_enabled_sources()`，每个源都会 eval 脚本、执行 inited、pump timer（最长 5 秒），并可能同步发 HTTP 请求；源多时冷启动会被阻塞
- LX source id 基于脚本全文 MD5，脚本一更新就变成新 source，旧记录残留并产生重复条目
- LX 歌词正缓存长期保留、未命中负缓存 1 天；封面磁盘缓存按平台 + 歌曲 id，URL 变化时需等待缓存清理
- 全局缓存上限目前按历史默认比例（本地 1GB : Subsonic 2GB : 洛雪 512MB）分配到三组，暂不支持独立分组配额
- 缓存占用只统计“清除所有缓存”会释放的内容；LX 源脚本、播放统计库和播放队列不计入缓存大小
- `SourceType` 只有 `LocalFile` 和 `Opensubsonic`，LX 不在数据模型中；`source` 字段仍是字符串字面量，容易拼错
- 移动端首页只挂载播放器主视图，`mobile_welcome_section.dart` / `mobile_daily_section.dart` / `mobile_home_constants.dart` 当前无引用
- 本地歌单尚未实现；移动端歌单页只显示 OpenSubsonic 歌单
- 移动端内容设置中的“选择本地音乐库”“同步数据库”按钮仍是空实现

### 播放、音频服务与平台

- 自研 MPRIS 会卡死 waybar，已停用；`linux_mpris.dart` 仍留在仓库但没有引用，后续应迁移 audio_service 或删除
- Android 已接入 just_audio + audio_service；后台、锁屏、通知、划掉 App、scrobble 已完成真机验证
- `MediaSessionService` 仍是 Noop，`MediaIntegrationHost` 仅做简单状态同步；当前真正生效的是 `LaetibeatAudioHandler` 直连 PlayerNotifier
- `PlaybackBackend` 没有 buffering / error / processing phase；`LaetibeatAudioHandler` 固定 `processingState=ready`，`bufferedPosition` 直接等于 `position`
- audio_service 只在 Android 初始化；iOS 目前没有后台媒体会话接入
- media_kit 在 Android 上出现过原生 SIGSEGV；Android 已改用 just_audio，桌面风险另论
- `MobileDirectoryPicker` 仍返回 null，Android 无法配置本地音乐目录，需接 SAF / `file_picker.getDirectoryPath` / `READ_MEDIA_AUDIO`
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

- QuickJS 没有内存上限、执行超时和 interrupt handler；恶意/错误脚本的 `while(true)` 会长期占用 manager mutex
- `eval` 已禁用，但动态 `Function` 仍可用；文件系统/宿主内部对象隔离仍需验证
- LX HTTP 当前使用同步 `reqwest::blocking`，请求会阻塞对应 JS 执行线程；后续改为异步 request broker
- 每个请求没有 requestKey，无法完成/失败/取消回写 JS
- `setTimeout` 目前是有界 timer pump，不是长期异步事件循环；超过 5 秒的定时任务会失败
- `updateAlert` host 回调为空实现，移动端更新提示 UI 未接入
- SourceManager 的 status/declarations 仅存在内存，没有持久化；冷启动失败不可见
- LX 自定义源主要提供 `musicUrl` / `lyric` / `pic`，通常不提供搜索；搜索层需要单独维护
- 洛雪音源脚本属于第三方内容，不随应用分发；不同脚本的兼容性、可用性和版权风险需由用户自行承担
- `reference/lx-music-mobile` 仅本地参考，不参与构建/发布；正式提交前必须确认其不进入仓库或发布包
- 仓库根目录暂无 `LICENSE` / 第三方 `NOTICE`；发布前需确认 QuickJS/rquickjs、FFmpeg、opensubsonic 等依赖的分发合规
- Flutter release 构建可能复用包含 `integration_test` 的旧 `GeneratedPluginRegistrant.java`；失败时删除该生成文件或 `flutter clean` 后重试
- Dart 侧测试仅覆盖 form factor 等少量逻辑；播放队列、搜索聚合、缓存设置、LX UI 缺少回归测试
