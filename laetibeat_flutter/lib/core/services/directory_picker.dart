import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:saf/saf.dart';

/// 用户选择的音乐目录。
///
/// [locator] 在桌面是真实路径，在 Android 是 SAF tree URI。
/// [displayName] 只用于 UI 展示。
class PickedMusicDirectory {
  const PickedMusicDirectory({
    required this.locator,
    required this.displayName,
    required this.isSaf,
  });

  final String locator;
  final String displayName;
  final bool isSaf;
}

/// 音乐目录选择能力。业务层只依赖该接口。
abstract interface class DirectoryPicker {
  Future<PickedMusicDirectory?> pickMusicDirectory();
}

/// 桌面端：走 Rust 侧 rfd 原生目录选择框。
class DesktopDirectoryPicker implements DirectoryPicker {
  const DesktopDirectoryPicker();

  @override
  Future<PickedMusicDirectory?> pickMusicDirectory() async {
    final path = await rust.pickDirectory();
    if (path == null || path.isEmpty) return null;
    return PickedMusicDirectory(
      locator: path,
      displayName: path,
      isSaf: false,
    );
  }
}

/// 移动端：Android 使用 SAF tree，其他平台回退 file_picker 路径。
class MobileDirectoryPicker implements DirectoryPicker {
  const MobileDirectoryPicker();

  @override
  Future<PickedMusicDirectory?> pickMusicDirectory() async {
    if (Platform.isAndroid) {
      final picked = await Saf().pickDirectory(
        writePermission: false,
        persistablePermission: true,
      );
      if (picked == null) return null;
      return PickedMusicDirectory(
        locator: picked.uri,
        displayName: picked.name,
        isSaf: true,
      );
    }

    final path = await FilePicker.getDirectoryPath();
    if (path == null || path.trim().isEmpty) return null;
    return PickedMusicDirectory(
      locator: path,
      displayName: path,
      isSaf: false,
    );
  }
}

final directoryPickerProvider = Provider<DirectoryPicker>((ref) {
  throw UnimplementedError(
    'directoryPickerProvider 必须在 bootstrap 中注入',
  );
});
