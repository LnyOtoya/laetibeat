import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _neteaseCookieKey = 'netease.cookie';

class NeteaseCookieStore {
  NeteaseCookieStore([this._secure = const FlutterSecureStorage()]);

  final FlutterSecureStorage _secure;

  Future<String?> read() async {
    final value = await _secure.read(key: _neteaseCookieKey);
    return value == null || value.trim().isEmpty ? null : value;
  }

  Future<void> write(String cookie) async {
    final value = cookie.trim();
    if (value.isEmpty) return;
    await _secure.write(key: _neteaseCookieKey, value: value);
  }

  Future<void> clear() => _secure.delete(key: _neteaseCookieKey);
}

final neteaseCookieStoreProvider = Provider<NeteaseCookieStore>((ref) {
  return NeteaseCookieStore();
});

/// 网易云登录 Cookie。Dart 侧安全存储，Rust 只按请求接收。
final neteaseCookieProvider =
    AsyncNotifierProvider<NeteaseCookieNotifier, String?>(
      NeteaseCookieNotifier.new,
    );

class NeteaseCookieNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() {
    return ref.read(neteaseCookieStoreProvider).read();
  }

  Future<void> save(String cookie) async {
    await ref.read(neteaseCookieStoreProvider).write(cookie);
    state = AsyncData(cookie.trim());
  }

  Future<void> clear() async {
    await ref.read(neteaseCookieStoreProvider).clear();
    state = const AsyncData(null);
  }
}
