import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/lx.dart' as rust_lx;
import 'package:laetibeat/src/rust/api/playlists.dart' as rust_playlists;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:laetibeat/widgets/player/lx_search_provider.dart';
import 'package:laetibeat/widgets/player/lx_track.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';

/// 本地歌单列表。
final localPlaylistsProvider =
    FutureProvider<List<rust_playlists.UiLocalPlaylistSummary>>((ref) {
      return rust_playlists.listLocalPlaylists();
    });

/// 本地歌单详情。
final localPlaylistDetailProvider = FutureProvider.autoDispose
    .family<rust_playlists.UiLocalPlaylistDetail?, int>((ref, id) {
      return rust_playlists.getLocalPlaylist(id: id);
    });

/// OpenSubsonic 歌单详情。
typedef RemotePlaylistKey = ({String sourceId, String playlistId});

final remotePlaylistDetailProvider = FutureProvider.autoDispose
    .family<rust_subsonic.UiRemotePlaylistDetail, RemotePlaylistKey>((
      ref,
      key,
    ) {
      return rust_subsonic.subsonicGetPlaylist(
        sourceId: key.sourceId,
        playlistId: key.playlistId,
      );
    });

/// 把当前曲目转成歌单条目快照。
rust_playlists.UiPlaylistTrackInput playlistTrackInputFromTrack(
  rust.UiTrack track, {
  String? fallbackCoverId,
}) {
  return rust_playlists.UiPlaylistTrackInput(
    source: track.source,
    sourceId: track.sourceId,
    trackId: track.id,
    relativePath: track.relativePath,
    coverId: track.coverId ?? fallbackCoverId,
    sourceExtraJson: track.sourceExtraJson,
    title: track.title,
    artist: track.artist,
    album: track.album,
    durationSeconds: track.durationSeconds.toInt(),
  );
}

/// 把 LX 在线歌单转换成订阅条目；首曲缺少封面时使用歌单封面兜底。
List<rust_playlists.UiPlaylistTrackInput> playlistInputsFromLxDetail(
  rust_lx.UiLxPlaylistDetail detail,
) {
  final fallback = detail.info.coverUrl;
  return <rust_playlists.UiPlaylistTrackInput>[
    for (var index = 0; index < detail.tracks.length; index += 1)
      playlistTrackInputFromTrack(
        lxSearchTrackToUiTrack(detail.tracks[index]),
        fallbackCoverId: index == 0 ? fallback : null,
      ),
  ];
}

/// 解析本地歌单条目为可播放曲目。
///
/// 本地条目优先使用当前扫描结果，文件不存在时返回 null；远端条目使用
/// 歌单里保存的快照构造 UiTrack，播放解析仍由 source/sourceId/trackId 完成。
List<rust.UiTrack?> resolveLocalPlaylistTracks(
  WidgetRef ref,
  rust_playlists.UiLocalPlaylistDetail detail,
) {
  final localTracks = <String, rust.UiTrack>{
    for (final track
        in ref.watch(musicLibraryProvider).value?.tracks ??
            const <rust.UiTrack>[])
      track.id: track,
  };
  return [
    for (final item in detail.items)
      switch (item.source) {
        'local' => localTracks[item.trackId],
        _ => _trackFromPlaylistItem(item),
      },
  ];
}

rust.UiTrack? _trackFromPlaylistItem(rust_playlists.UiLocalPlaylistItem item) {
  final seconds = item.durationSeconds.toInt();
  return rust.UiTrack(
    id: item.trackId,
    relativePath: item.relativePath,
    title: item.title,
    artist: item.artist,
    album: item.album,
    albumArtist: item.artist,
    albumId: '',
    artistId: '',
    trackNumber: null,
    discNumber: null,
    year: null,
    genre: null,
    duration: formatTrackDuration(seconds),
    durationSeconds: BigInt.from(seconds),
    path: '',
    source: item.source,
    sourceId: item.sourceId,
    coverId: item.coverId,
    sourceExtraJson: item.sourceExtraJson,
    bitrate: null,
    sampleRate: null,
    channels: null,
    modifiedMs: null,
    fileSize: null,
  );
}

/// LX 在线歌单搜索。
typedef LxPlaylistSearchKey = ({String platform, String query});

final Map<String, Future<List<rust_lx.UiLxPlaylistSummary>>>
_lxPlaylistSearchCache = <String, Future<List<rust_lx.UiLxPlaylistSummary>>>{};

Future<List<rust_lx.UiLxPlaylistSummary>> _searchLxPlaylistsOnce({
  required String platform,
  required String query,
}) {
  final cacheKey = '$platform\u0000$query';
  final cached = _lxPlaylistSearchCache[cacheKey];
  if (cached != null) return cached;
  // Bound the cache: one entry per (platform, query) adds up over a session.
  if (_lxPlaylistSearchCache.length >= 32) {
    _lxPlaylistSearchCache.clear();
  }
  final future = lxSearchGate.run(
    platform,
    () => rust_lx.searchLxPlaylists(
      platform: platform,
      keyword: query,
      page: 1,
      limit: 30,
    ),
  );
  _lxPlaylistSearchCache[cacheKey] = future;
  future.then<void>(
    (_) {},
    onError: (Object error, StackTrace stackTrace) {
      _lxPlaylistSearchCache.remove(cacheKey);
    },
  );
  return future;
}

final lxPlaylistSearchProvider = FutureProvider.autoDispose
    .family<List<rust_lx.UiLxPlaylistSummary>, LxPlaylistSearchKey>((
      ref,
      key,
    ) async {
      var cancelled = false;
      ref.onDispose(() => cancelled = true);
      // 平台切换很快时只保留最后一次请求，避免旧的同步 HTTP 请求堆积。
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (cancelled) return const <rust_lx.UiLxPlaylistSummary>[];
      return _searchLxPlaylistsOnce(platform: key.platform, query: key.query);
    });

/// LX 在线歌单全量详情（预览与订阅使用）。
typedef LxPlaylistKey = ({String platform, String playlistId});

final lxPlaylistAllProvider = FutureProvider.autoDispose
    .family<rust_lx.UiLxPlaylistDetail, LxPlaylistKey>((ref, key) {
      return rust_lx.getLxPlaylistAll(
        platform: key.platform,
        playlistId: key.playlistId,
      );
    });
