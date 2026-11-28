import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/online.dart' as rust_online;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

import 'online_settings.dart';

const int onlineSearchPageSize = 10;

/// Manual refresh only: clear the host's persisted response cache so the
/// following provider invalidations hit upstream instead of returning cache.
Future<void> onlineClearCache(WidgetRef ref) async {
  final baseUrl = ref.read(onlineBaseUrlProvider);
  if (baseUrl.isEmpty) return;
  final token = await ref.read(onlineTokenProvider.future);
  if (token == null || token.isEmpty) return;
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('$baseUrl/laetibeat/cache/clear'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    await request.close();
  } catch (_) {
    // 清理失败不阻塞手动刷新流程；最坏情况是继续展示旧快照。
  } finally {
    client.close(force: true);
  }
}

typedef OnlineSearchKey = ({
  String source,
  String query,
  int limit,
  int offset,
});

typedef OnlineListKey = ({String source, String id});

typedef OnlineUserPlaylistKey = ({String source, int page, int limit});

typedef OnlineHotSongsKey = ({String source, int limit});

typedef OnlineHomeFeedKey = ({String source});

final onlineHomeFeedProvider =
    FutureProvider.family<rust_online.UiOnlineHomeFeed, OnlineHomeFeedKey>((
      ref,
      key,
    ) async {
      final baseUrl = ref.watch(onlineBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('当前模式 sidecar 未启动');
      }
      final token = await ref.watch(onlineTokenProvider.future);
      return rust_online.onlineHomeFeed(
        baseUrl: baseUrl,
        token: token,
        source: key.source,
        refresh: false,
      );
    });

final onlinePlatformStatusesProvider =
    FutureProvider<List<rust_online.UiOnlinePlatformStatus>>((ref) async {
      final baseUrl = ref.watch(onlineBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先在设置中配置在线音源服务');
      }
      final token = await ref.watch(onlineTokenProvider.future);
      return rust_online.onlinePlatformStatuses(baseUrl: baseUrl, token: token);
    });

bool onlineHasCookie(
  List<rust_online.UiOnlinePlatformStatus> statuses,
  String source,
) {
  return statuses.any((status) => status.source == source && status.hasCookie);
}

final onlineStatusProvider = FutureProvider<rust_online.UiOnlineStatus>((
  ref,
) async {
  final baseUrl = ref.watch(onlineBaseUrlProvider);
  if (baseUrl.isEmpty) {
    throw StateError('请先在设置中配置在线音源服务');
  }
  final token = await ref.watch(onlineTokenProvider.future);
  return rust_online.onlineHealth(baseUrl: baseUrl, token: token);
});

final onlineSongSearchProvider = FutureProvider.autoDispose
    .family<List<rust.UiTrack>, OnlineSearchKey>((ref, key) async {
      final baseUrl = ref.watch(onlineBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先在设置中配置在线音源服务');
      }
      final token = await ref.watch(onlineTokenProvider.future);
      return rust_online.onlineSearchSongs(
        baseUrl: baseUrl,
        token: token,
        source: key.source,
        query: key.query,
        limit: key.limit,
        offset: key.offset,
      );
    });

final onlinePlaylistSearchProvider = FutureProvider.autoDispose
    .family<List<rust_online.UiOnlinePlaylist>, OnlineSearchKey>((
      ref,
      key,
    ) async {
      final baseUrl = ref.watch(onlineBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先在设置中配置在线音源服务');
      }
      final token = await ref.watch(onlineTokenProvider.future);
      return rust_online.onlineSearchPlaylists(
        baseUrl: baseUrl,
        token: token,
        source: key.source,
        query: key.query,
        limit: key.limit,
        offset: key.offset,
      );
    });

final onlineAlbumSearchProvider = FutureProvider.autoDispose
    .family<List<rust_online.UiOnlineAlbum>, OnlineSearchKey>((ref, key) async {
      final baseUrl = ref.watch(onlineBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先在设置中配置在线音源服务');
      }
      final token = await ref.watch(onlineTokenProvider.future);
      return rust_online.onlineSearchAlbums(
        baseUrl: baseUrl,
        token: token,
        source: key.source,
        query: key.query,
        limit: key.limit,
        offset: key.offset,
      );
    });

final onlinePlaylistTracksProvider =
    FutureProvider.family<List<rust.UiTrack>, OnlineListKey>((ref, key) async {
      final baseUrl = ref.watch(onlineBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先在设置中配置在线音源服务');
      }
      final token = await ref.watch(onlineTokenProvider.future);
      return rust_online.onlinePlaylistTracks(
        baseUrl: baseUrl,
        token: token,
        source: key.source,
        playlistId: key.id,
      );
    });

final onlineAlbumTracksProvider =
    FutureProvider.family<List<rust.UiTrack>, OnlineListKey>((ref, key) async {
      final baseUrl = ref.watch(onlineBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先在设置中配置在线音源服务');
      }
      final token = await ref.watch(onlineTokenProvider.future);
      return rust_online.onlineAlbumTracks(
        baseUrl: baseUrl,
        token: token,
        source: key.source,
        albumId: key.id,
      );
    });

final onlineUserPlaylistsProvider =
    FutureProvider.family<
      List<rust_online.UiOnlinePlaylist>,
      OnlineUserPlaylistKey
    >((ref, key) async {
      final baseUrl = ref.watch(onlineBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先在设置中配置在线音源服务');
      }
      final token = await ref.watch(onlineTokenProvider.future);
      return rust_online.onlineUserPlaylists(
        baseUrl: baseUrl,
        token: token,
        source: key.source,
        page: key.page,
        limit: key.limit,
      );
    });

final onlineDailySongsProvider = FutureProvider<List<rust.UiTrack>>((
  ref,
) async {
  final baseUrl = ref.watch(onlineBaseUrlProvider);
  if (baseUrl.isEmpty) {
    throw StateError('当前模式 sidecar 未启动');
  }
  final token = await ref.watch(onlineTokenProvider.future);
  return rust_online.onlineDailySongs(
    baseUrl: baseUrl,
    token: token,
    source: 'netease',
    refresh: false,
  );
});

final onlineRadarPlaylistsProvider =
    FutureProvider<List<rust_online.UiOnlinePlaylist>>((ref) async {
      final baseUrl = ref.watch(onlineBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('当前模式 sidecar 未启动');
      }
      final token = await ref.watch(onlineTokenProvider.future);
      return rust_online.onlineRadarPlaylists(
        baseUrl: baseUrl,
        token: token,
        source: 'netease',
        limit: 50,
      );
    });

final onlinePersonalFmPreviewProvider = FutureProvider<List<rust.UiTrack>>((
  ref,
) async {
  final baseUrl = ref.watch(onlineBaseUrlProvider);
  if (baseUrl.isEmpty) {
    throw StateError('当前模式 sidecar 未启动');
  }
  final token = await ref.watch(onlineTokenProvider.future);
  return rust_online.onlinePersonalFm(
    baseUrl: baseUrl,
    token: token,
    source: 'netease',
    mode: null,
    submode: null,
    limit: 4,
  );
});

final onlineRecommendPlaylistsProvider =
    FutureProvider.family<List<rust_online.UiOnlinePlaylist>, String>((
      ref,
      source,
    ) async {
      final baseUrl = ref.watch(onlineBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先在设置中配置在线音源服务');
      }
      final token = await ref.watch(onlineTokenProvider.future);
      return rust_online.onlineRecommendPlaylists(
        baseUrl: baseUrl,
        token: token,
        source: source,
      );
    });

final onlineTopListsProvider =
    FutureProvider.family<List<rust_online.UiOnlineTopList>, String>((
      ref,
      source,
    ) async {
      final baseUrl = ref.watch(onlineBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先在设置中配置在线音源服务');
      }
      final token = await ref.watch(onlineTokenProvider.future);
      return rust_online.onlineTopLists(
        baseUrl: baseUrl,
        token: token,
        source: source,
      );
    });

final onlineTopListSongsProvider =
    FutureProvider.family<List<rust.UiTrack>, OnlineListKey>((ref, key) async {
      final baseUrl = ref.watch(onlineBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先在设置中配置在线音源服务');
      }
      final token = await ref.watch(onlineTokenProvider.future);
      return rust_online.onlineTopListSongs(
        baseUrl: baseUrl,
        token: token,
        source: key.source,
        topListId: key.id,
      );
    });

final onlineHotSongsProvider =
    FutureProvider.family<List<rust.UiTrack>, OnlineHotSongsKey>((
      ref,
      key,
    ) async {
      final baseUrl = ref.watch(onlineBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先在设置中配置在线音源服务');
      }
      final token = await ref.watch(onlineTokenProvider.future);
      return rust_online.onlineHotSongs(
        baseUrl: baseUrl,
        token: token,
        source: key.source,
        limit: key.limit,
      );
    });

final onlineLyricProvider =
    FutureProvider.family<rust_online.UiOnlineLyric, OnlineListKey>((
      ref,
      key,
    ) async {
      final baseUrl = ref.watch(onlineBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先在设置中配置在线音源服务');
      }
      final token = await ref.watch(onlineTokenProvider.future);
      return rust_online.onlineLyric(
        baseUrl: baseUrl,
        token: token,
        source: key.source,
        trackId: key.id,
      );
    });

/// 从 `UiTrack` 中取出平台内 id；兼容旧快照与 `sourceExtraJson`。
String onlinePlatformId(rust.UiTrack track) {
  final extra = track.sourceExtraJson;
  if (extra != null && extra.isNotEmpty) {
    try {
      final decoded = jsonDecode(extra);
      if (decoded is Map) {
        for (final key in <String>['platformId', 'songId', 'songmid']) {
          final value = decoded[key];
          if (value is String && value.isNotEmpty) return value;
          if (value is num) return value.toInt().toString();
        }
      }
    } catch (_) {
      // 快照损坏，回退到 id。
    }
  }
  final prefix = '${track.source}:';
  if (track.id.startsWith(prefix)) {
    return track.id.substring(prefix.length);
  }
  return track.id;
}

String onlineSourceLabel(String source) {
  return switch (source) {
    'netease' => '网易云',
    'qq' => 'QQ 音乐',
    _ => source,
  };
}

/// 在线 source 到 LX 平台 key 的映射。
String? onlineLxPlatform(String source) {
  return switch (source) {
    'netease' => 'wy',
    'qq' => 'tx',
    _ => null,
  };
}
