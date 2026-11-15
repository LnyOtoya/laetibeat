import 'dart:io';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:permission_handler/permission_handler.dart';

/// 音乐目录选择能力。业务层只依赖该接口。
abstract interface class DirectoryPicker {
  Future<String?> pickMusicDirectory();
}

/// 桌面端：走 Rust 侧 rfd 原生目录选择框。
class DesktopDirectoryPicker implements DirectoryPicker {
  const DesktopDirectoryPicker();

  @override
  Future<String?> pickMusicDirectory() => rust.pickDirectory();
}

/// 移动端：Android 走 SAF 目录选择，iOS 走 file_picker。
///
/// Android 侧使用 lifetime SAF grant 并请求音频读取权限，这样 Rust 扫描器
/// 至少能在当前授权目录内读取音频文件；取消/拒绝权限时返回 null。
class MobileDirectoryPicker implements DirectoryPicker {
  const MobileDirectoryPicker();

  @override
  Future<String?> pickMusicDirectory() async {
    if (Platform.isAndroid) {
      final hasPermission = await _ensureAudioPermission();
      if (!hasPermission) {
        debugPrint('未获得音频读取权限，无法选择本地音乐目录');
        return null;
      }
    }

    final path = await FilePicker.getDirectoryPath(
      androidOptions: Platform.isAndroid
          ? const FilePickerAndroidOptions(
              safOptions: AndroidSAFOptions(
                grant: AndroidSAFGrant.lifetime,
                accessMode: AndroidSAFAccessMode.readOnly,
                persistGrant: true,
              ),
            )
          : const AndroidOptions(),
    );
    if (path == null || path.trim().isEmpty) return null;
    return path;
  }

  Future<bool> _ensureAudioPermission() async {
    final audio = await Permission.audio.request();
    if (audio.isGranted) return true;
    // Android 12 及以下没有 READ_MEDIA_AUDIO，回退到存储权限。
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }
}

final directoryPickerProvider = Provider<DirectoryPicker>((ref) {
  throw UnimplementedError(
    'directoryPickerProvider 必须在 bootstrap 中注入',
  );
});
