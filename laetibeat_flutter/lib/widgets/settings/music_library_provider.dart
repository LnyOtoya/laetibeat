import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:saf/saf.dart';

import '../../core/services/directory_picker.dart';
import 'persistence.dart';

//本地音乐库状态:记录选中的目录与扫描出的单曲/专辑/艺术家
class MusicLibraryState {
  /// 桌面为真实路径；Android SAF 为 content:// tree URI。
  final String? directory;

  /// 目录显示名（SAF 用 document name，桌面用路径）。
  final String? directoryName;

  final List<rust.UiTrack> tracks;

  /// 专辑聚合(由 Rust 侧生成,曲目已按碟号/音轨号排序)
  final List<rust.UiAlbum> albums;

  /// 艺术家聚合(由 Rust 侧生成)
  final List<rust.UiArtist> artists;
  final bool isLoading;
  final String? error;
  final bool hasScanned; //标记是否执行过扫描,用于控制状态项显隐

  /// 最近一次扫描的统计(复用/解析/移除/耗时)
  final LibraryScanStats? scanStats;

  const MusicLibraryState({
    this.directory,
    this.directoryName,
    this.tracks = const <rust.UiTrack>[],
    this.albums = const <rust.UiAlbum>[],
    this.artists = const <rust.UiArtist>[],
    this.isLoading = false,
    this.error,
    this.hasScanned = false,
    this.scanStats,
  });

  bool get isSaf => directory?.startsWith('content://') ?? false;

  /// copyWith 哨兵:区分"未传参"与"显式传入 null"
  static const Object _unset = Object();

  MusicLibraryState copyWith({
    Object? directory = _unset,
    Object? directoryName = _unset,
    List<rust.UiTrack>? tracks,
    List<rust.UiAlbum>? albums,
    List<rust.UiArtist>? artists,
    bool? isLoading,
    Object? error = _unset,
    bool? hasScanned,
    Object? scanStats = _unset,
  }) {
    return MusicLibraryState(
      directory: identical(directory, _unset)
          ? this.directory
          : directory as String?,
      directoryName: identical(directoryName, _unset)
          ? this.directoryName
          : directoryName as String?,
      tracks: tracks ?? this.tracks,
      albums: albums ?? this.albums,
      artists: artists ?? this.artists,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _unset) ? this.error : error as String?,
      hasScanned: hasScanned ?? this.hasScanned,
      scanStats: identical(scanStats, _unset)
          ? this.scanStats
          : scanStats as LibraryScanStats?,
    );
  }
}

class MusicLibraryNotifier extends AsyncNotifier<MusicLibraryState> {
  @override
  Future<MusicLibraryState> build() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedDirectory = prefs.getString(kMusicDirectoryKey);
    final savedName = prefs.getString(kMusicDirectoryNameKey);

    // 启动时优先恢复上次扫描的快照,避免每次都重新扫描
    final snapshot = await ref.read(librarySnapshotStoreProvider).load();

    // 快照加载期间用户可能已切换目录:以最新目录为准,丢弃旧快照
    final latestDirectory = prefs.getString(kMusicDirectoryKey);
    final latestName = prefs.getString(kMusicDirectoryNameKey);
    if (latestDirectory != savedDirectory) {
      return MusicLibraryState(
        directory: latestDirectory,
        directoryName: latestName ?? _fallbackDirectoryName(latestDirectory),
      );
    }

    final directory = snapshot?.directory ?? savedDirectory;
    if (directory != null && directory != savedDirectory) {
      await prefs.setString(kMusicDirectoryKey, directory);
    }

    final directoryName =
        savedName ?? _fallbackDirectoryName(directory);
    // SAF 解析逻辑升级后，旧快照里的标签可能是错的；先丢弃并等待重新扫描。
    if (directory?.startsWith('content://') == true &&
        prefs.getInt(kLocalScanVersionKey) != kLocalScanVersion) {
      return MusicLibraryState(
        directory: directory,
        directoryName: directoryName,
      );
    }
    if (snapshot == null) {
      return MusicLibraryState(
        directory: directory,
        directoryName: directoryName,
      );
    }
    return MusicLibraryState(
      directory: directory,
      directoryName: directoryName,
      tracks: snapshot.tracks,
      albums: snapshot.albums,
      artists: snapshot.artists,
      hasScanned: snapshot.hasScanned,
      scanStats: snapshot.scanStats,
    );
  }

  //选择本地音乐目录
  Future<void> pickDirectory() async {
    final picked = await ref.read(directoryPickerProvider).pickMusicDirectory();
    if (picked == null) return;

    final current = state.value ?? const MusicLibraryState();
    // 目录未变则保持现有库;换目录时旧库数据/快照不再有效
    if (picked.locator == current.directory) return;

    //仅记录目录,不自动扫描
    state = AsyncValue.data(
      current.copyWith(
        directory: picked.locator,
        directoryName: picked.displayName,
        tracks: const <rust.UiTrack>[],
        albums: const <rust.UiAlbum>[],
        artists: const <rust.UiArtist>[],
        hasScanned: false,
        error: null,
        scanStats: null,
      ),
    );
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(kMusicDirectoryKey, picked.locator);
    await prefs.setString(kMusicDirectoryNameKey, picked.displayName);
    await ref.read(librarySnapshotStoreProvider).clear();
  }

  //重新扫描当前目录
  Future<void> rescan() async {
    final current = state.value;
    final dir = current?.directory;
    if (dir == null) {
      debugPrint('未选择本地音乐目录，跳过扫描');
      return;
    }

    state = AsyncValue.data(
      current!.copyWith(isLoading: true, error: null, hasScanned: true),
    );

    if (current.isSaf) {
      await _rescanSaf(current, dir);
    } else {
      await _rescanDesktop(current, dir);
    }
  }

  Future<void> _rescanDesktop(
    MusicLibraryState current,
    String dir,
  ) async {
    debugPrint('开始扫描本地音乐目录: $dir');
    try {
      // 把上次扫描结果作为增量缓存:未变化的文件由 Rust 直接复用
      final result = await rust.scanLocalMusicFolder(
        dirPath: dir,
        knownTracks: current.tracks,
      );
      final library = result.library_;
      debugPrint(
        '本地音乐扫描完成: tracks=${library.tracks.length} '
        'albums=${library.albums.length} '
        'parsed=${result.stats.parsedFiles} reused=${result.stats.reusedFiles}',
      );
      final stats = LibraryScanStats(
        totalFiles: result.stats.totalFiles,
        parsedFiles: result.stats.parsedFiles,
        reusedFiles: result.stats.reusedFiles,
        removedFiles: result.stats.removedFiles,
        elapsed: Duration(milliseconds: result.stats.elapsedMs.toInt()),
        scannedAt: DateTime.now(),
      );
      final next = state.value!.copyWith(
        tracks: library.tracks,
        albums: library.albums,
        artists: library.artists,
        isLoading: false,
        error: null,
        scanStats: stats,
      );
      state = AsyncValue.data(next);
      await _saveSnapshot(dir, next, stats);
    } catch (e, stack) {
      debugPrint('本地音乐扫描失败: $e\n$stack');
      state = AsyncValue.data(
        state.value!.copyWith(
          isLoading: false,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _rescanSaf(MusicLibraryState current, String treeUri) async {
    debugPrint('开始扫描 SAF 音乐库: $treeUri');
    final prefs = ref.read(sharedPreferencesProvider);
    final allowReuse =
        prefs.getInt(kLocalScanVersionKey) == kLocalScanVersion;
    final saf = Saf();
    final started = DateTime.now();
    final knownById = <String, rust.UiTrack>{
      for (final track in current.tracks) track.id: track,
    };
    final seen = <String>{};
    final tracks = <rust.UiTrack>[];
    var totalFiles = 0;
    var parsedFiles = 0;
    var reusedFiles = 0;
    var failedFiles = 0;

    try {
      await for (final entry in saf.walk(treeUri)) {
        final file = entry.file;
        if (file.isDir) continue;
        if (!_isAudioFile(file)) continue;

        totalFiles += 1;
        seen.add(file.uri);

        final cached = knownById[file.uri];
        final unchanged =
            allowReuse &&
            cached?.modifiedMs?.toInt() == file.lastModified &&
            cached?.fileSize?.toInt() == file.length;
        if (unchanged) {
          tracks.add(cached!);
          reusedFiles += 1;
          continue;
        }

        try {
          final track = await saf.withFileDescriptor(
            file.uri,
            'r',
            (descriptor) => rust.parseSafTrack(
              fd: descriptor.fd,
              documentUri: file.uri,
              relativePath: entry.relativePath,
              displayName: file.name,
              modifiedMs: BigInt.from(file.lastModified),
              fileSize: BigInt.from(file.length),
            ),
          );
          tracks.add(track);
          parsedFiles += 1;
        } catch (e) {
          failedFiles += 1;
          debugPrint('解析 SAF 音频失败: ${file.name} $e');
        }
      }

      final library = await rust.aggregateLocalTracks(tracks: tracks);
      if (library.tracks.isNotEmpty) {
        final sample = library.tracks.first;
        debugPrint(
          'SAF 样例: title=${sample.title} artist=${sample.artist} '
          'album=${sample.album} duration=${sample.duration}',
        );
      }
      final removedFiles = knownById.keys.where((id) => !seen.contains(id)).length;
      final stats = LibraryScanStats(
        totalFiles: totalFiles,
        parsedFiles: parsedFiles,
        reusedFiles: reusedFiles,
        removedFiles: removedFiles,
        elapsed: DateTime.now().difference(started),
        scannedAt: DateTime.now(),
      );
      final error = failedFiles > 0
          ? '部分文件解析失败: $failedFiles'
          : null;
      final next = state.value!.copyWith(
        tracks: library.tracks,
        albums: library.albums,
        artists: library.artists,
        isLoading: false,
        error: error,
        scanStats: stats,
      );
      state = AsyncValue.data(next);
      debugPrint(
        'SAF 音乐库扫描完成: tracks=${library.tracks.length} '
        'parsed=$parsedFiles reused=$reusedFiles failed=$failedFiles',
      );
      await prefs.setInt(kLocalScanVersionKey, kLocalScanVersion);
      await _saveSnapshot(treeUri, next, stats);
    } catch (e, stack) {
      debugPrint('SAF 音乐库扫描失败: $e\n$stack');
      state = AsyncValue.data(
        state.value!.copyWith(
          isLoading: false,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _saveSnapshot(
    String directory,
    MusicLibraryState next,
    LibraryScanStats stats,
  ) async {
    // 扫描成功后写快照;写盘失败不影响本次扫描结果
    try {
      await ref.read(librarySnapshotStoreProvider).save(
            LibrarySnapshot(
              directory: directory,
              hasScanned: true,
              scannedAt: stats.scannedAt,
              scanStats: stats,
              tracks: next.tracks,
              albums: next.albums,
              artists: next.artists,
            ),
          );
    } catch (e) {
      debugPrint('保存音乐库快照失败: $e');
    }
  }
}

bool _isAudioFile(SafDocumentFile file) {
  final mime = file.mimeType;
  if (mime != null && mime.startsWith('audio/')) return true;
  final name = file.name.toLowerCase();
  return name.endsWith('.mp3') ||
      name.endsWith('.flac') ||
      name.endsWith('.m4a') ||
      name.endsWith('.wav');
}

String? _fallbackDirectoryName(String? directory) {
  if (directory == null || directory.isEmpty) return null;
  if (directory.startsWith('content://')) {
    final uri = Uri.tryParse(directory);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return Uri.decodeComponent(uri.pathSegments.last);
    }
  }
  // 桌面端保留完整路径展示，和改造前一致。
  return directory;
}

//当前本地音乐库
final musicLibraryProvider =
    AsyncNotifierProvider<MusicLibraryNotifier, MusicLibraryState>(
  MusicLibraryNotifier.new,
);
