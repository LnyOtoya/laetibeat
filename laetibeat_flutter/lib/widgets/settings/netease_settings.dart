import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persistence.dart';

const String kNetEaseApiBaseUrlKey = 'netease.api_base_url';
const String kNetEaseAllowLxFallbackKey = 'netease.allow_lx_fallback';

/// 网易云在线音源的本地配置。
///
/// 当前尚未接入真实 API，只保存用户准备使用的服务地址和后备开关。
class NeteaseSettings {
  const NeteaseSettings({this.apiBaseUrl = '', this.allowLxFallback = false});

  final String apiBaseUrl;
  final bool allowLxFallback;

  bool get isConfigured => apiBaseUrl.isNotEmpty;

  NeteaseSettings copyWith({String? apiBaseUrl, bool? allowLxFallback}) {
    return NeteaseSettings(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      allowLxFallback: allowLxFallback ?? this.allowLxFallback,
    );
  }
}

class NeteaseSettingsNotifier extends Notifier<NeteaseSettings> {
  @override
  NeteaseSettings build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return NeteaseSettings(
      apiBaseUrl: prefs.getString(kNetEaseApiBaseUrlKey) ?? '',
      allowLxFallback: prefs.getBool(kNetEaseAllowLxFallbackKey) ?? false,
    );
  }

  Future<void> save({
    required String apiBaseUrl,
    required bool allowLxFallback,
  }) async {
    final normalized = normalizeNeteaseBaseUrl(apiBaseUrl);
    state = NeteaseSettings(
      apiBaseUrl: normalized,
      allowLxFallback: allowLxFallback,
    );

    final prefs = ref.read(sharedPreferencesProvider);
    if (normalized.isEmpty) {
      await prefs.remove(kNetEaseApiBaseUrlKey);
    } else {
      await prefs.setString(kNetEaseApiBaseUrlKey, normalized);
    }
    await prefs.setBool(kNetEaseAllowLxFallbackKey, allowLxFallback);
  }

  Future<void> clear() async {
    state = const NeteaseSettings();
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(kNetEaseApiBaseUrlKey);
    await prefs.remove(kNetEaseAllowLxFallbackKey);
  }
}

final neteaseSettingsProvider =
    NotifierProvider<NeteaseSettingsNotifier, NeteaseSettings>(
      NeteaseSettingsNotifier.new,
    );

String normalizeNeteaseBaseUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}
