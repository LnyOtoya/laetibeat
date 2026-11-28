import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/settings/persistence.dart';
import 'app_destination.dart';

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

  /// 当前模式在移动端显示的一级导航目的地。
  List<AppDestination> get mobileDestinations => switch (this) {
    AppMode.local => const <AppDestination>[AppDestination.library],
    AppMode.subsonic => const <AppDestination>[
      AppDestination.home,
      AppDestination.library,
    ],
    AppMode.qq || AppMode.netease => const <AppDestination>[
      AppDestination.home,
      AppDestination.discover,
      AppDestination.library,
    ],
  };

  /// 进入该模式时默认落地的一级目的地。
  AppDestination get mobileInitialDestination =>
      this == AppMode.local ? AppDestination.library : AppDestination.home;

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
