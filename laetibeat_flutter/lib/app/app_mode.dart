import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/settings/persistence.dart';

const String kAppModeKey = 'app.mode';

/// 应用级在线音源模式。
///
/// local / subsonic 不使用在线 sidecar；qq / netease 各自启动独立 host。
enum AppMode {
  local(id: 'local', label: '本地音乐'),
  subsonic(id: 'subsonic', label: 'Subsonic'),
  qq(id: 'qq', label: 'QQ 音乐'),
  netease(id: 'netease', label: '网易云音乐');

  const AppMode({required this.id, required this.label});

  final String id;
  final String label;

  bool get usesOnlineHost => this == AppMode.qq || this == AppMode.netease;

  /// sidecar 可执行文件/数据目录标识。
  String? get hostId => switch (this) {
    AppMode.qq => 'qq',
    AppMode.netease => 'netease',
    _ => null,
  };

  static AppMode fromId(String? id) {
    for (final mode in values) {
      if (mode.id == id) return mode;
    }
    return AppMode.local;
  }

  static AppMode fromName(String? name) {
    for (final mode in values) {
      if (mode.name == name) return mode;
    }
    return AppMode.local;
  }
}

class AppModeNotifier extends Notifier<AppMode> {
  @override
  AppMode build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return AppMode.fromName(prefs.getString(kAppModeKey));
  }

  Future<void> setMode(AppMode mode) async {
    if (state == mode) return;
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(kAppModeKey, mode.name);
  }
}

final appModeProvider = NotifierProvider<AppModeNotifier, AppMode>(
  AppModeNotifier.new,
);
