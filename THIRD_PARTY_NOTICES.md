# Third-Party Notices

Laetibeat itself is licensed under the MIT License. See [LICENSE](LICENSE).

This project depends on third-party software. The list below covers the main
direct dependencies and platform components. Full dependency versions are
locked in `laetibeat_flutter/pubspec.lock` and `Cargo.lock`; upstream license
texts should be retained when distributing binaries.

## Flutter / Dart dependencies

| Package | License | Upstream |
| --- | --- | --- |
| cupertino_icons | MIT | https://pub.dev/packages/cupertino_icons |
| flutter_rust_bridge | MIT | https://pub.dev/packages/flutter_rust_bridge |
| flutter_riverpod | MIT | https://pub.dev/packages/flutter_riverpod |
| material_3_expressive | MIT | https://pub.dev/packages/material_3_expressive |
| material_ui | BSD-3-Clause | https://pub.dev/packages/material_ui |
| m3e_core | MIT | https://pub.dev/packages/m3e_core |
| dynamic_color | Apache-2.0 | https://pub.dev/packages/dynamic_color |
| material_color_utilities | Apache-2.0 | https://pub.dev/packages/material_color_utilities |
| motor | MIT | https://pub.dev/packages/motor |
| window_manager | MIT | https://pub.dev/packages/window_manager |
| media_kit | MIT | https://pub.dev/packages/media_kit |
| media_kit_libs_linux | MIT | https://pub.dev/packages/media_kit_libs_linux |
| media_kit_libs_android_audio | MIT | https://pub.dev/packages/media_kit_libs_android_audio |
| dbus | MPL-2.0 | https://pub.dev/packages/dbus |
| flutter_lyric | MIT | https://pub.dev/packages/flutter_lyric |
| shared_preferences | BSD-3-Clause | https://pub.dev/packages/shared_preferences |
| path_provider | BSD-3-Clause | https://pub.dev/packages/path_provider |
| flutter_secure_storage | BSD-3-Clause | https://pub.dev/packages/flutter_secure_storage |
| uuid | MIT | https://pub.dev/packages/uuid |
| just_audio | MIT | https://pub.dev/packages/just_audio |
| audio_service | MIT | https://pub.dev/packages/audio_service |
| audio_session | MIT | https://pub.dev/packages/audio_session |
| refresh_rate | BSD-3-Clause | https://pub.dev/packages/refresh_rate |
| intl | BSD-3-Clause | https://pub.dev/packages/intl |
| file_picker | MIT | https://pub.dev/packages/file_picker |
| saf | MIT | https://pub.dev/packages/saf |
| package_info_plus | BSD-3-Clause | https://pub.dev/packages/package_info_plus |

## Rust dependencies

| Crate | License | Upstream |
| --- | --- | --- |
| serde / serde_json | MIT OR Apache-2.0 | https://crates.io/crates/serde |
| walkdir | MIT OR Unlicense | https://crates.io/crates/walkdir |
| lofty | MIT | https://crates.io/crates/lofty |
| rusqlite | MIT | https://crates.io/crates/rusqlite |
| libc | MIT OR Apache-2.0 | https://crates.io/crates/libc |
| opensubsonic | MIT | https://crates.io/crates/opensubsonic |
| tokio | MIT | https://crates.io/crates/tokio |
| reqwest | MIT OR Apache-2.0 | https://crates.io/crates/reqwest |
| thiserror | MIT OR Apache-2.0 | https://crates.io/crates/thiserror |
| rquickjs | MIT | https://crates.io/crates/rquickjs |
| base64 | MIT OR Apache-2.0 | https://crates.io/crates/base64 |
| flutter_rust_bridge | MIT | https://crates.io/crates/flutter_rust_bridge |
| allo-isolate | Apache-2.0 | https://crates.io/crates/allo-isolate |

## Native and platform components

- **AndroidX / Kotlin runtime**: Apache-2.0.
- **media_kit Android native libraries**: the Dart/Kotlin package is MIT, but it
  bundles or links FFmpeg/libmpv. FFmpeg and libmpv have their own LGPL/GPL
  terms depending on the build configuration. Their notices and source/relink
  obligations must be reviewed before distributing a release APK.
- **OpenSubsonic / Navidrome**: the app talks to a user-provided server; server
  software is not bundled with the app.
- **LX Music custom sources**: scripts are supplied by their authors and are
  not relicensed by this project. Each source's own license applies.

## Fonts

- **Google Sans Flex**
- **Noto Sans SC / TC / JP / KR**

These font families are distributed under the SIL Open Font License 1.1 unless
the upstream font package states otherwise. Retain the OFL notice when
redistributing the fonts.

## In-app notices

The app's **设置 → 关于 → 开源许可** entry shows license texts registered by
Flutter and its Dart packages. Rust crates and native components are listed in
this file; a future in-app third-party notices page will include their full
texts.
