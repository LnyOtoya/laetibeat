import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/netease.dart' as rust_netease;

import '../player/cover_color.dart';
import 'cover_cache.dart';

/// 网易云详情页首屏所需的封面资源：字节 + 主色。
class NeteaseCoverAsset {
  const NeteaseCoverAsset({required this.bytes, required this.color});

  final Uint8List bytes;
  final ui.Color color;
}

class NeteaseCoverProvider {
  static const String _sourceId = 'netease';
  static const int _defaultMemoryLimit = 32 * 1024 * 1024;

  int _maxCacheBytes = _defaultMemoryLimit;
  int _cachedBytes = 0;
  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  final Map<String, ui.Color> _colorCache = <String, ui.Color>{};
  final Map<String, Future<Uint8List?>> _inFlight =
      <String, Future<Uint8List?>>{};
  final Map<String, Future<ui.Color>> _colorInFlight =
      <String, Future<ui.Color>>{};

  void setMaxBytes(int bytes) {
    _maxCacheBytes = bytes;
    _trim();
  }

  void clearMemory() {
    _cache.clear();
    _colorCache.clear();
    _cachedBytes = 0;
  }

  Future<Uint8List?> coverUrl(String? value) async {
    final url = value?.trim();
    if (url == null || url.isEmpty) return null;

    final key = _cacheKey(url);
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }

    final pending = _inFlight[key];
    if (pending != null) return pending;

    final future = _load(url, key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    }
  }

  /// 详情页首屏资源：封面字节 + 主色一起返回，避免先出封面再突然变色。
  Future<NeteaseCoverAsset?> assetForUrl(String? value) async {
    final url = value?.trim();
    if (url == null || url.isEmpty) return null;

    final bytes = await coverUrl(url);
    if (bytes == null) return null;

    final key = _cacheKey(url);
    final cachedColor = _colorCache[key];
    if (cachedColor != null) {
      return NeteaseCoverAsset(bytes: bytes, color: cachedColor);
    }

    final pending = _colorInFlight[key];
    if (pending != null) {
      return NeteaseCoverAsset(bytes: bytes, color: await pending);
    }

    final future = _extractColor(bytes);
    _colorInFlight[key] = future;
    try {
      final color = await future;
      _colorCache[key] = color;
      return NeteaseCoverAsset(bytes: bytes, color: color);
    } finally {
      if (identical(_colorInFlight[key], future)) {
        _colorInFlight.remove(key);
      }
    }
  }

  Future<ui.Color> _extractColor(Uint8List bytes) async {
    try {
      return await dominantCoverColor(bytes);
    } catch (_) {
      return const ui.Color(0xFF6750A4);
    }
  }

  Future<Uint8List?> _load(String url, String key) async {
    final disk = await neteaseCoverDiskCache.read(_sourceId, key);
    if (disk != null && disk.isNotEmpty) {
      _putMemory(key, disk);
      return disk;
    }

    final bytes = await rust_netease.neteaseGetCover(url: url);
    if (bytes.isEmpty) return null;
    await neteaseCoverDiskCache.write(_sourceId, key, bytes);
    _putMemory(key, bytes);
    return bytes;
  }

  void _putMemory(String key, Uint8List bytes) {
    final previous = _cache.remove(key);
    if (previous != null) _cachedBytes -= previous.length;
    _cache[key] = bytes;
    _cachedBytes += bytes.length;
    _trim();
  }

  void _trim() {
    while (_cachedBytes > _maxCacheBytes && _cache.isNotEmpty) {
      final oldestKey = _cache.keys.first;
      final removed = _cache.remove(oldestKey);
      _cachedBytes -= removed?.length ?? 0;
    }
  }

  /// 同一张封面可能带不同的缩放/水印 query，缓存 key 只保留路径部分。
  String _cacheKey(String url) {
    final hash = url.indexOf('#');
    final withoutFragment = hash >= 0 ? url.substring(0, hash) : url;
    final query = withoutFragment.indexOf('?');
    return query >= 0 ? withoutFragment.substring(0, query) : withoutFragment;
  }
}

final neteaseCoverSourceProvider = Provider<NeteaseCoverProvider>((ref) {
  final provider = NeteaseCoverProvider();
  ref.onDispose(provider.clearMemory);
  return provider;
});

/// 详情页首屏使用：等封面字节和主色都准备好。
final neteaseCoverAssetProvider = FutureProvider.autoDispose
    .family<NeteaseCoverAsset?, String>((ref, url) {
      return ref.watch(neteaseCoverSourceProvider).assetForUrl(url);
    });

/// 点击列表项时可提前预热封面和主色。
void prefetchNeteaseCover(WidgetRef ref, String? url) {
  if (url == null || url.isEmpty) return;
  unawaited(ref.read(neteaseCoverSourceProvider).assetForUrl(url));
}
