import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/library.dart' as rust_library;
import 'package:path_provider/path_provider.dart';

import '../cache/cover_cache.dart';
import '../player/cover_provider.dart';
import 'persistence.dart';

enum CacheGroup { local, subsonic, lx }

/// Default total quota kept in sync with the historical per-group defaults
/// (local 1GB + Subsonic 2GB + LX 512MB).
const int kDefaultCacheTotalMb = 3584;

/// Slider stops shown under the global cache-size setting.
const List<int> kCacheLimitMbLevels = <int>[512, 1024, 2048, 3584, 4096, 0];

/// One global cache quota, split across the three caches using the historical
/// default ratio. The UI only edits the total; each provider still receives
/// its own byte limit so existing LRU implementations keep working.
class CacheLimits {
  const CacheLimits({this.totalMb = kDefaultCacheTotalMb});

  final int totalMb;

  static const int _localWeight = 1024;
  static const int _subsonicWeight = 2048;
  static const int _lxWeight = 512;
  static const int _weightSum = _localWeight + _subsonicWeight + _lxWeight;

  bool get isUnlimited => totalMb == 0;

  int get totalBytes => totalMb * 1024 * 1024;

  int get localMb => isUnlimited ? 0 : totalMb * _localWeight ~/ _weightSum;

  int get subsonicMb =>
      isUnlimited ? 0 : totalMb * _subsonicWeight ~/ _weightSum;

  /// Take the remainder so the three per-group limits always add up to the
  /// total shown in the UI.
  int get lxMb => isUnlimited ? 0 : totalMb - localMb - subsonicMb;

  int forGroup(CacheGroup group) => switch (group) {
    CacheGroup.local => localMb,
    CacheGroup.subsonic => subsonicMb,
    CacheGroup.lx => lxMb,
  };

  /// Byte cap passed to the actual cache implementations. `0` means unlimited
  /// at the UI level; providers use a very large cap instead of special-casing.
  int bytesFor(CacheGroup group) {
    final mb = forGroup(group);
    return mb == 0 ? (1 << 60) : mb * 1024 * 1024;
  }
}

class CacheLimitsNotifier extends Notifier<CacheLimits> {
  static const String _totalKey = 'cache.limit.total_mb';
  static const String _legacyLocalKey = 'cache.limit.local_mb';
  static const String _legacySubsonicKey = 'cache.limit.subsonic_mb';
  static const String _legacyLxKey = 'cache.limit.lx_mb';

  @override
  CacheLimits build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getInt(_totalKey);
    if (saved != null) return CacheLimits(totalMb: saved);

    // Migrate the old per-group settings once, so existing users keep their
    // effective total instead of suddenly falling back to the default.
    final legacyTotal =
        (prefs.getInt(_legacyLocalKey) ?? 1024) +
        (prefs.getInt(_legacySubsonicKey) ?? 2048) +
        (prefs.getInt(_legacyLxKey) ?? 512);
    return CacheLimits(totalMb: legacyTotal);
  }

  Future<void> setTotalMb(int mb) async {
    if (state.totalMb == mb) return;
    state = CacheLimits(totalMb: mb);
    await ref
        .read(sharedPreferencesProvider)
        .setInt(_totalKey, mb);
  }
}

final cacheLimitsProvider = NotifierProvider<CacheLimitsNotifier, CacheLimits>(
  CacheLimitsNotifier.new,
);

/// Push the global quota down to the three memory/disk cache implementations.
Future<void> applyCacheLimitsToCovers({
  required CacheLimits limits,
  required FileCoverProvider localCovers,
  required RemoteCoverProvider remoteCovers,
  required LxCoverProvider lxCovers,
}) async {
  localCovers.setMaxBytes(limits.bytesFor(CacheGroup.local));
  remoteCovers.setMaxBytes(limits.bytesFor(CacheGroup.subsonic));
  await remoteCoverDiskCache.setMaxBytes(
    limits.bytesFor(CacheGroup.subsonic),
  );
  lxCovers.setMaxBytes(limits.bytesFor(CacheGroup.lx));
  await lxCoverDiskCache.setMaxBytes(limits.bytesFor(CacheGroup.lx));
}

class CacheGroupUsage {
  const CacheGroupUsage({
    required this.lyricsBytes,
    required this.coversBytes,
    required this.otherBytes,
  });

  final int lyricsBytes;
  final int coversBytes;
  final int otherBytes;

  int get totalBytes => lyricsBytes + coversBytes + otherBytes;
}

class CacheUsageSnapshot {
  const CacheUsageSnapshot({
    required this.local,
    required this.subsonic,
    required this.lx,
  });

  final CacheGroupUsage local;
  final CacheGroupUsage subsonic;
  final CacheGroupUsage lx;

  int get lyricsBytes =>
      local.lyricsBytes + subsonic.lyricsBytes + lx.lyricsBytes;
  int get coversBytes =>
      local.coversBytes + subsonic.coversBytes + lx.coversBytes;
  int get otherBytes =>
      local.otherBytes + subsonic.otherBytes + lx.otherBytes;
  int get totalBytes => lyricsBytes + coversBytes + otherBytes;

  CacheGroupUsage forGroup(CacheGroup group) => switch (group) {
    CacheGroup.local => local,
    CacheGroup.subsonic => subsonic,
    CacheGroup.lx => lx,
  };
}

class CacheUsageService {
  Future<CacheUsageSnapshot> scan() async {
    final support = await getApplicationSupportDirectory();
    final localLyrics = await _lyricsStats('local:');
    final subsonicLyrics = await _lyricsStats('opensubsonic:');
    final lxLyrics = await _lyricsStats('lx:');
    final totalLyrics = await _lyricsStats(null);

    final localSnapshot = await _fileSize(
      File('${support.path}/library_snapshot.json'),
    );
    final libraryDb = await _fileSize(
      File('${support.path}/laetibeat_library.db'),
    );
    final covers = await _dirSize(Directory('${support.path}/remote_covers'));
    final lxCovers = await _dirSize(Directory('${support.path}/lx_covers'));

    // 只统计“清除所有缓存”会真正释放的内容。LX 源脚本、播放统计库和
    // 播放队列属于用户数据，不应被算进缓存占用。
    final subsonicOther = (libraryDb - totalLyrics).clamp(0, libraryDb);
    return CacheUsageSnapshot(
      local: CacheGroupUsage(
        lyricsBytes: localLyrics,
        coversBytes: 0,
        otherBytes: localSnapshot,
      ),
      subsonic: CacheGroupUsage(
        lyricsBytes: subsonicLyrics,
        coversBytes: covers,
        otherBytes: subsonicOther,
      ),
      lx: CacheGroupUsage(
        lyricsBytes: lxLyrics,
        coversBytes: lxCovers,
        otherBytes: 0,
      ),
    );
  }

  Future<int> _lyricsStats(String? prefix) async {
    try {
      final stats = await rust_library.lyricsCacheStats(prefix: prefix);
      return stats.bytes;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _fileSize(File file) async {
    try {
      return await file.exists() ? await file.length() : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _dirSize(Directory dir) async {
    var total = 0;
    try {
      if (!await dir.exists()) return 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }
}

final cacheUsageServiceProvider = Provider<CacheUsageService>((ref) {
  return CacheUsageService();
});

final cacheUsageProvider = FutureProvider.autoDispose<CacheUsageSnapshot>((
  ref,
) {
  return ref.watch(cacheUsageServiceProvider).scan();
});

String formatCacheBytes(int bytes) {
  final parts = formatCacheSizeParts(bytes);
  return '${parts.value} ${parts.unit}';
}

/// Split value and unit so the storage header can enlarge only the number.
({String value, String unit}) formatCacheSizeParts(int bytes) {
  if (bytes < 1024) return (value: '$bytes', unit: 'B');
  if (bytes < 1024 * 1024) {
    return (value: (bytes / 1024).toStringAsFixed(1), unit: 'KB');
  }
  if (bytes < 1024 * 1024 * 1024) {
    return (value: (bytes / (1024 * 1024)).toStringAsFixed(1), unit: 'MB');
  }
  return (value: (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2), unit: 'GB');
}

/// Compact label used by the total-cache-size slider stops.
String formatCacheLimitLabel(int mb) {
  if (mb == 0) return '∞';
  if (mb < 1024) return '${mb}MB';
  final gb = mb / 1024;
  return gb == gb.roundToDouble()
      ? '${gb.toInt()}GB'
      : '${gb.toStringAsFixed(1)}GB';
}
