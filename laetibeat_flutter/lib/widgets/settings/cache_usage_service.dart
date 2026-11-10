import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/library.dart' as rust_library;
import 'package:path_provider/path_provider.dart';

import 'persistence.dart';

enum CacheGroup { local, subsonic, lx }

const List<int> kCacheLimitMbLevels = <int>[256, 512, 1024, 2048, 4096, 0];

class CacheLimits {
  const CacheLimits({
    this.localMb = 1024,
    this.subsonicMb = 2048,
    this.lxMb = 512,
  });

  final int localMb;
  final int subsonicMb;
  final int lxMb;

  int forGroup(CacheGroup group) => switch (group) {
    CacheGroup.local => localMb,
    CacheGroup.subsonic => subsonicMb,
    CacheGroup.lx => lxMb,
  };

  CacheLimits withGroup(CacheGroup group, int mb) => CacheLimits(
    localMb: group == CacheGroup.local ? mb : localMb,
    subsonicMb: group == CacheGroup.subsonic ? mb : subsonicMb,
    lxMb: group == CacheGroup.lx ? mb : lxMb,
  );
}

class CacheLimitsNotifier extends Notifier<CacheLimits> {
  static const String _localKey = 'cache.limit.local_mb';
  static const String _subsonicKey = 'cache.limit.subsonic_mb';
  static const String _lxKey = 'cache.limit.lx_mb';

  @override
  CacheLimits build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return CacheLimits(
      localMb: prefs.getInt(_localKey) ?? 1024,
      subsonicMb: prefs.getInt(_subsonicKey) ?? 2048,
      lxMb: prefs.getInt(_lxKey) ?? 512,
    );
  }

  Future<void> setLimit(CacheGroup group, int mb) async {
    if (state.forGroup(group) == mb) return;
    state = state.withGroup(group, mb);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(switch (group) {
      CacheGroup.local => _localKey,
      CacheGroup.subsonic => _subsonicKey,
      CacheGroup.lx => _lxKey,
    }, mb);
  }
}

final cacheLimitsProvider = NotifierProvider<CacheLimitsNotifier, CacheLimits>(
  CacheLimitsNotifier.new,
);

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
    final libraryDb = await _fileSize(File('${support.path}/laetibeat_library.db'));
    final covers = await _dirSize(Directory('${support.path}/remote_covers'));
    final lxStore = await _dirSize(Directory('${support.path}/laetibeat_lx'));
    final statsDb = await _fileSize(File('${support.path}/laetibeat_stats.db'));
    final queue = await _fileSize(
      File('${support.path}/playback_queue.json'),
    ) + await _fileSize(File('${support.path}/playback_state.json'));

    // The library DB also contains lyric rows, so subtract the lyric text
    // bytes to avoid counting them twice in the breakdown.
    final subsonicOther = (libraryDb - totalLyrics).clamp(0, libraryDb);
    return CacheUsageSnapshot(
      local: CacheGroupUsage(
        lyricsBytes: localLyrics,
        coversBytes: 0,
        otherBytes: localSnapshot + queue,
      ),
      subsonic: CacheGroupUsage(
        lyricsBytes: subsonicLyrics,
        coversBytes: covers,
        otherBytes: subsonicOther,
      ),
      lx: CacheGroupUsage(
        lyricsBytes: lxLyrics,
        coversBytes: 0,
        otherBytes: lxStore + statsDb,
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

final cacheUsageProvider = FutureProvider<CacheUsageSnapshot>((ref) {
  return ref.watch(cacheUsageServiceProvider).scan();
});

String formatCacheBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
