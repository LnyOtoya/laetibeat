import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'persistence.dart';

const String kOnlineBaseUrlKey = 'online.base_url';
const String kOnlineAllowLxFallbackKey = 'online.allow_lx_fallback';
const String kOnlineDefaultQualityKey = 'online.default_quality';
const String kOnlineTokenKey = 'online.token';

const String kOnlineDefaultQuality = 'high';

/// go-music-api 在线音源配置。
class OnlineSettings {
  const OnlineSettings({
    this.baseUrl = '',
    this.allowLxFallback = false,
    this.defaultQuality = kOnlineDefaultQuality,
  });

  final String baseUrl;
  final bool allowLxFallback;
  final String defaultQuality;

  bool get isConfigured => baseUrl.isNotEmpty;

  OnlineSettings copyWith({
    String? baseUrl,
    bool? allowLxFallback,
    String? defaultQuality,
  }) {
    return OnlineSettings(
      baseUrl: baseUrl ?? this.baseUrl,
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
      baseUrl: prefs.getString(kOnlineBaseUrlKey) ?? '',
      allowLxFallback: prefs.getBool(kOnlineAllowLxFallbackKey) ?? false,
      defaultQuality:
          prefs.getString(kOnlineDefaultQualityKey) ?? kOnlineDefaultQuality,
    );
  }

  Future<void> save({
    required String baseUrl,
    required bool allowLxFallback,
    required String defaultQuality,
  }) async {
    final normalized = normalizeOnlineBaseUrl(baseUrl);
    state = OnlineSettings(
      baseUrl: normalized,
      allowLxFallback: allowLxFallback,
      defaultQuality: defaultQuality,
    );

    final prefs = ref.read(sharedPreferencesProvider);
    if (normalized.isEmpty) {
      await prefs.remove(kOnlineBaseUrlKey);
    } else {
      await prefs.setString(kOnlineBaseUrlKey, normalized);
    }
    await prefs.setBool(kOnlineAllowLxFallbackKey, allowLxFallback);
    await prefs.setString(kOnlineDefaultQualityKey, defaultQuality);
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
    await prefs.remove(kOnlineBaseUrlKey);
    await prefs.remove(kOnlineAllowLxFallbackKey);
    await prefs.remove(kOnlineDefaultQualityKey);
  }
}

final onlineSettingsProvider =
    NotifierProvider<OnlineSettingsNotifier, OnlineSettings>(
      OnlineSettingsNotifier.new,
    );

final onlineBaseUrlProvider = Provider<String>((ref) {
  return ref.watch(
    onlineSettingsProvider.select((settings) => settings.baseUrl),
  );
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

class OnlineTokenStore {
  OnlineTokenStore([this._secure = const FlutterSecureStorage()]);

  final FlutterSecureStorage _secure;

  Future<String?> read() async {
    final value = await _secure.read(key: kOnlineTokenKey);
    return value == null || value.trim().isEmpty ? null : value;
  }

  Future<void> write(String token) async {
    final value = token.trim();
    if (value.isEmpty) {
      await clear();
      return;
    }
    await _secure.write(key: kOnlineTokenKey, value: value);
  }

  Future<void> clear() => _secure.delete(key: kOnlineTokenKey);
}

final onlineTokenStoreProvider = Provider<OnlineTokenStore>((ref) {
  return OnlineTokenStore();
});

final onlineTokenProvider = AsyncNotifierProvider<OnlineTokenNotifier, String?>(
  OnlineTokenNotifier.new,
);

class OnlineTokenNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() {
    return ref.read(onlineTokenStoreProvider).read();
  }

  Future<void> save(String token) async {
    await ref.read(onlineTokenStoreProvider).write(token);
    final value = token.trim();
    state = AsyncData(value.isEmpty ? null : value);
  }

  Future<void> clear() async {
    await ref.read(onlineTokenStoreProvider).clear();
    state = const AsyncData(null);
  }
}

String normalizeOnlineBaseUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

/// 与 Rust `HttpClient` 一致的地址校验：远程必须 HTTPS，loopback 允许 HTTP。
bool isValidOnlineBaseUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) return false;
  if (uri.scheme == 'https') return true;
  if (uri.scheme != 'http') return false;
  final host = uri.host.toLowerCase();
  if (host == 'localhost') return true;
  final address = InternetAddress.tryParse(host);
  return address != null && address.isLoopback;
}
