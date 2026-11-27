import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 远端封面磁盘缓存:按 sourceId 分目录,总容量 LRU 淘汰。
/// 文件名使用 base64Url,避免 coverId 里的特殊字符影响路径。
class RemoteCoverDiskCache {
  RemoteCoverDiskCache({
    this.maxBytes = 256 * 1024 * 1024,
    this.rootName = 'remote_covers',
  });

  final String rootName;

  /// 磁盘缓存总上限,默认 256MB
  int maxBytes;

  Directory? _root;
  final Map<String, _CacheEntry> _index = {};
  Future<void>? _initializing;
  bool _loaded = false;
  Future<void> _serial = Future<void>.value();

  Future<T> _locked<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _serial = _serial.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Uint8List?> read(String sourceId, String coverId) {
    return _locked(() async {
      try {
        await _ensureIndex();
        final file = await _file(sourceId, coverId);
        if (!await file.exists()) {
          _index.remove(file.path);
          return null;
        }

        late final Uint8List bytes;
        try {
          bytes = await file.readAsBytes();
        } on PathNotFoundException {
          _index.remove(file.path);
          return null;
        }
        final now = DateTime.now();
        try {
          await file.setLastModified(now);
        } catch (_) {}
        final entry = _index[file.path];
        if (entry != null) {
          entry.lastAccess = now.millisecondsSinceEpoch;
        }
        return bytes;
      } catch (e) {
        debugPrint('读取封面缓存失败: $e');
        return null;
      }
    });
  }

  Future<void> write(String sourceId, String coverId, Uint8List bytes) {
    if (bytes.isEmpty) return Future<void>.value();
    return _locked(() async {
      File? tmp;
      try {
        await _ensureIndex();
        final file = await _file(sourceId, coverId);
        tmp = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
        await tmp.writeAsBytes(bytes, flush: true);
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } on PathNotFoundException {
          // Another cleanup removed it; the rename below can proceed.
        }
        await tmp.rename(file.path);
        _index[file.path] = _CacheEntry(
          size: bytes.length,
          lastAccess: DateTime.now().millisecondsSinceEpoch,
        );
        await _evictIfNeeded();
      } catch (e) {
        debugPrint('写入封面缓存失败: $e');
        if (tmp != null) {
          try {
            if (await tmp.exists()) await tmp.delete();
          } catch (_) {}
        }
      }
    });
  }

  /// 服务器地址变更或删除时清空该音源的封面
  Future<void> clearSource(String sourceId) {
    return _locked(() async {
      try {
        final root = await _rootDir();
        final dir = Directory('${root.path}/${_sourceDirName(sourceId)}');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        final prefix = '${dir.path}${Platform.pathSeparator}';
        _index.removeWhere((path, _) => path.startsWith(prefix));
      } catch (e) {
        debugPrint('清理封面缓存失败: $e');
      }
    });
  }

  /// Apply a new cache limit immediately and evict the least recently used
  /// files if necessary.
  Future<void> setMaxBytes(int bytes) {
    return _locked(() async {
      maxBytes = bytes;
      await _ensureIndex();
      await _evictIfNeeded();
    });
  }

  /// Clear every cached cover while leaving source configuration intact.
  Future<void> clearAll() {
    return _locked(() async {
      try {
        final root = await _rootDir();
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
        _root = null;
        _index.clear();
        _initializing = null;
        _loaded = false;
      } catch (e) {
        debugPrint('清理全部封面缓存失败: $e');
        rethrow;
      }
    });
  }

  Future<Directory> _rootDir() async {
    final existing = _root;
    if (existing != null) return existing;

    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/$rootName');
    await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  Future<Directory> _sourceDir(String sourceId) async {
    final root = await _rootDir();
    final dir = Directory('${root.path}/${_sourceDirName(sourceId)}');
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String sourceId, String coverId) async {
    final dir = await _sourceDir(sourceId);
    return File('${dir.path}/${_fileName(coverId)}.img');
  }

  String _sourceDirName(String sourceId) => _encodeKey(sourceId);
  String _fileName(String coverId) => _encodeKey(coverId);

  String _encodeKey(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  Future<void> _ensureIndex() {
    if (_loaded) return Future<void>.value();
    return _initializing ??= _scan();
  }

  Future<void> _scan() async {
    final root = await _rootDir();
    final entries = <String, _CacheEntry>{};
    try {
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        // 清理上次写入中断留下的临时文件
        if (entity.path.endsWith('.tmp')) {
          try {
            await entity.delete();
          } catch (_) {}
          continue;
        }
        if (!entity.path.endsWith('.img')) continue;
        try {
          final stat = await entity.stat();
          entries[entity.path] = _CacheEntry(
            size: stat.size,
            lastAccess: stat.modified.millisecondsSinceEpoch,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('扫描封面缓存失败: $e');
    }
    _index
      ..clear()
      ..addAll(entries);
    _loaded = true;
  }

  Future<void> _evictIfNeeded() async {
    var total = _index.values.fold<int>(0, (sum, entry) => sum + entry.size);
    if (total <= maxBytes) return;

    final sorted = _index.entries.toList()
      ..sort((a, b) => a.value.lastAccess.compareTo(b.value.lastAccess));

    for (final entry in sorted) {
      if (total <= maxBytes) break;
      var removed = false;
      try {
        final file = File(entry.key);
        if (await file.exists()) {
          await file.delete();
        }
        removed = true;
      } on PathNotFoundException {
        // Another operation already removed the file; the index should follow.
        removed = true;
      } catch (e) {
        debugPrint('淘汰封面缓存失败: $e');
      }
      if (removed) {
        _index.remove(entry.key);
        total -= entry.value.size;
      }
    }
  }
}

class _CacheEntry {
  _CacheEntry({required this.size, required this.lastAccess});

  final int size;
  int lastAccess;
}

/// 全局封面磁盘缓存
final RemoteCoverDiskCache remoteCoverDiskCache = RemoteCoverDiskCache();

/// LX 音源封面磁盘缓存，和 Subsonic 封面分目录统计与清理。
final RemoteCoverDiskCache lxCoverDiskCache = RemoteCoverDiskCache(
  rootName: 'lx_covers',
);

/// 清理某个音源的封面缓存
Future<void> clearRemoteCoverCache(String sourceId) =>
    remoteCoverDiskCache.clearSource(sourceId);
