import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saf/saf.dart';

import 'persistence.dart';

/// 下载目录配置。Android 使用 SAF tree URI，桌面暂用真实路径。
class DownloadLocation {
  const DownloadLocation({
    this.locator,
    this.displayName,
  });

  final String? locator;
  final String? displayName;

  bool get isSet => locator != null && locator!.isNotEmpty;
  bool get isSaf => locator?.startsWith('content://') ?? false;
}

class DownloadLocationNotifier extends Notifier<DownloadLocation> {
  @override
  DownloadLocation build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return DownloadLocation(
      locator: prefs.getString(kDownloadDirectoryKey),
      displayName: prefs.getString(kDownloadDirectoryNameKey),
    );
  }

  Future<void> pickDirectory() async {
    String? locator;
    String? displayName;

    if (Platform.isAndroid) {
      final picked = await Saf().pickDirectory(
        writePermission: true,
        persistablePermission: true,
      );
      if (picked == null) return;
      locator = picked.uri;
      displayName = picked.name;
    } else {
      final path = await FilePicker.getDirectoryPath();
      if (path == null || path.trim().isEmpty) return;
      locator = path;
      displayName = path;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(kDownloadDirectoryKey, locator);
    await prefs.setString(kDownloadDirectoryNameKey, displayName);
    state = DownloadLocation(locator: locator, displayName: displayName);
  }
}

final downloadLocationProvider =
    NotifierProvider<DownloadLocationNotifier, DownloadLocation>(
  DownloadLocationNotifier.new,
);
