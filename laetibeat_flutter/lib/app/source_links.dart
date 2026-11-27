/// 项目与内置在线音源 sidecar 的源码入口，供合规与关于页使用。
const String laetibeatSourceUrl = 'https://github.com/LnyOtoya/laetibeat';
const String qqMusicApiSourceUrl =
    'https://github.com/jinzhongjia/QQMusicApi-rs';
const String ncmApiSourceUrl = 'https://github.com/SPlayer-Dev/ncm-api-rs';

const String embeddedOnlineHostsLicenseNotice = '''
laetibeat_qq_host is licensed under GPL-3.0-only and depends on
QQMusicApi-rs (GPL-3.0-only).

laetibeat_netease_host is MIT-licensed and depends on ncm-api-rs (WTFPL).

Both hosts run as separate executables inside the Android APK / Linux bundle
and communicate with the Flutter app over a loopback HTTP API. They are not
linked into the Flutter/Dart process.

Source code:
- Laetibeat: https://github.com/LnyOtoya/laetibeat
- QQMusicApi-rs: https://github.com/jinzhongjia/QQMusicApi-rs
- ncm-api-rs: https://github.com/SPlayer-Dev/ncm-api-rs

Full license texts are included in the source tree and release assets
(laetibeat_qq_host/LICENSE, laetibeat_netease_host/LICENSE and
laetibeat_netease_host/LICENSE-WTFPL).
''';
