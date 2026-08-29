# Laetibeat项目蓝图

## 阶段1: 数据模型与基础文件扫描与标签读取

- [x] 1.1 初始化rust workspace
- [x] 1.2 定义核心数据结构(歌曲track，专辑album，艺术家artist，播放状态playstate)以及统一音源抽象接口(AudioSource)
- [x] 1.3 实现本地文件夹扫描与元数据解析(引入walkdir遍历，lofty读取歌曲标签。对wav标签进行特殊处理)
- [ ] 1.4 搭建解码模块(使用symphonia将音频文件解包为标准PCM数据流，与音频输出解耦)

## 阶段2: 前端搭建与FFI桥接

- [x] 2.1 初始化flutter前端项目(laetibeat_flutter)
- [x] 2.2 配置flutter_rust_bridge,建立rust与dart代码绑定
- [ ] 2.3 实现flutter调用rust基础数据传输与测试
- [ ] 2.4 搭建UI基础骨架，一个选择本地文件夹的按钮，点击后触发rust扫描，并在屏幕上打印出歌曲名字

## 阶段3: 高级UI交互与媒体会话初步完善

- [ ] 3.1 完善播放器各个页面，包括播放列表和音源切换等
- [ ] 3.2 接入just_audio与audio_service，打通Android媒体会话与常驻保活。

## 阶段4: 接入opensubsonic api

- [ ] 4.1 封装opensubsonic 专有的token鉴权生成算法md5,(pwd + salt)
- [ ] 4.2 统一封装reqwest客户端，处理公共参数(u,v,c,f=josn等)的拼接
- [ ] 4.3 实现基础接口调用方法(如ping，getMusicFolders，getIndexes)，并将其接入抽象音源AudioSource中

## 阶段5: 统计播放实现

- [ ] 5.1 实现播放统计统一化(rust统一手机各音源播放事件，向lastfm等平台统一上报，以及纯本地记录策略，利用轻量数据库如SQLite)
- [ ] 5.2 flutter完成播放热力图等组件，通过rust统一解耦拉取数据并渲染

## 阶段6: 跨平台输出适配

- [ ] 6.1 桌面端集成基础音频输出(cpal或rodio)，移动端对接系统媒体会话
- [ ] 6.2 多端打包与适配测试(android、Windows、Linux、)
