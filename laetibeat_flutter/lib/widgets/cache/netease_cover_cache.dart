import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/netease.dart' as rust_netease;

import 'cover_cache.dart';

class NeteaseCoverProvider {
  static const String _sourceId = 'netease';
  static const int _defaultMemoryLimit = 32 * 1024 * 1024;

  int _maxCacheBytes = _defaultMemoryLimit;
  int _cachedBytes = 0;
  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  final Map<String, Future<Uint8List?>> _inFlight =
      <String, Future<Uint8List?>>{};

  void setMaxBytes(int bytes) {
    _maxCacheBytes = bytes;
    _trim();
  }

  void clearMemory() {
    _cache.clear();
    _cachedBytes = 0;
  }

  Future<Uint8List?> coverUrl(String? value) async {
    final url = value?.trim();
    if (url == null || url.isEmpty) return null;

    final cached = _cache.remove(url);
    if (cached != null) {
      _cache[url] = cached;
      return cached;
    }

    final pending = _inFlight[url];
    if (pending != null) return pending;

    final future = _load(url);
    _inFlight[url] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[url], future)) {
        _inFlight.remove(url);
      }
    }
  }

  Future<Uint8List?> _load(String url) async {
    final disk = await neteaseCoverDiskCache.read(_sourceId, url);
    if (disk != null && disk.isNotEmpty) {
      _putMemory(url, disk);
      return disk;
    }

    final bytes = await rust_netease.neteaseGetCover(url: url);
    if (bytes.isEmpty) return null;
    await neteaseCoverDiskCache.write(_sourceId, url, bytes);
    _putMemory(url, bytes);
    return bytes;
  }

  void _putMemory(String key, Uint8List bytes) {
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
}

final neteaseCoverSourceProvider = Provider<NeteaseCoverProvider>((ref) {
  final provider = NeteaseCoverProvider();
  ref.onDispose(provider.clearMemory);
  return provider;
});
