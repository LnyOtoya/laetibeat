/// 项目与内置在线音源的源码入口，供 AGPL 合规与关于页使用。
const String laetibeatSourceUrl = 'https://github.com/LnyOtoya/laetibeat';
const String goMusicApiSourceUrl = 'https://github.com/guohuiyuan/go-music-api';
const String musicLibSourceUrl = 'https://github.com/guohuiyuan/music-lib';

const String embeddedMusicApiLicenseNotice = '''
go-music-api and music-lib are licensed under the GNU Affero General Public
License, version 3 (AGPL-3.0).

Laetibeat bundles a separately running Go host built from go-music-api and a
locally patched music-lib. The host communicates with the Flutter app over a
loopback HTTP API and is distributed as a separate executable.

Source code:
- Laetibeat (including the host wrapper and local music-lib patch):
  https://github.com/LnyOtoya/laetibeat
- go-music-api: https://github.com/guohuiyuan/go-music-api
- music-lib: https://github.com/guohuiyuan/music-lib

The full AGPL-3.0 text is included in the source tree and in release assets
(laetibeat_musicapi_host/LICENSE and the music-lib LICENSE).
''';
