import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_mode.dart';
import 'mode_runtime.dart';
import 'persistence.dart';

const String kOnlineAllowLxFallbackKey = 'online.allow_lx_fallback';
const String kOnlineDefaultQualityKey = 'online.default_quality';

const String kOnlineDefaultQuality = 'high';

/// 在线音源质量与 LX 后备设置。
///
/// 服务地址 / Token 由 `AppMode` 对应的本地 sidecar 运行时提供，不再单独配置。
class OnlineSettings {
  const OnlineSettings({
    this.allowLxFallback = false,
    this.defaultQuality = kOnlineDefaultQuality,
  });

  final bool allowLxFallback;
  final String defaultQuality;

  OnlineSettings copyWith({bool? allowLxFallback, String? defaultQuality}) {
    return OnlineSettings(
      allowLxFallback: allowLxFallback ?? this.allowLxFallback,
      defaultQuality: defaultQuality ?? this.defaultQuality,
    );
  }
}

class OnlineSettingsNotifier extends Notifier<OnlineSettings> {
  @override
  OnlineSettings build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return OnlineSettings(
      allowLxFallback: prefs.getBool(kOnlineAllowLxFallbackKey) ?? false,
      defaultQuality:
          prefs.getString(kOnlineDefaultQualityKey) ?? kOnlineDefaultQuality,
    );
  }

  Future<void> setAllowLxFallback(bool value) async {
    if (state.allowLxFallback == value) return;
    state = state.copyWith(allowLxFallback: value);
    await ref
        .read(sharedPreferencesProvider)
        .setBool(kOnlineAllowLxFallbackKey, value);
  }

  Future<void> setDefaultQuality(String value) async {
    if (state.defaultQuality == value) return;
    state = state.copyWith(defaultQuality: value);
    await ref
        .read(sharedPreferencesProvider)
        .setString(kOnlineDefaultQualityKey, value);
  }

  Future<void> clear() async {
    state = const OnlineSettings();
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(kOnlineAllowLxFallbackKey);
    await prefs.remove(kOnlineDefaultQualityKey);
  }
}

final onlineSettingsProvider =
    NotifierProvider<OnlineSettingsNotifier, OnlineSettings>(
      OnlineSettingsNotifier.new,
    );

/// 当前模式 sidecar 的 loopback 地址；local / subsonic 为空。
final onlineBaseUrlProvider = Provider<String>((ref) {
  final mode = ref.watch(appModeProvider);
  if (!mode.usesOnlineHost) return '';
  final runtime = ref.watch(modeRuntimeProvider);
  return runtime.hasBaseUrl ? runtime.baseUrl! : '';
});

final onlineAllowLxFallbackProvider = Provider<bool>((ref) {
  return ref.watch(
    onlineSettingsProvider.select((settings) => settings.allowLxFallback),
  );
});

final onlineDefaultQualityProvider = Provider<String>((ref) {
  return ref.watch(
    onlineSettingsProvider.select((settings) => settings.defaultQuality),
  );
});

/// 当前模式 sidecar 的 Bearer token；local / subsonic 为空。
final onlineTokenProvider = AsyncNotifierProvider<OnlineTokenNotifier, String?>(
  OnlineTokenNotifier.new,
);

class OnlineTokenNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final mode = ref.watch(appModeProvider);
    if (!mode.usesOnlineHost) return null;
    return ref.watch(modeRuntimeProvider).token;
  }
}
