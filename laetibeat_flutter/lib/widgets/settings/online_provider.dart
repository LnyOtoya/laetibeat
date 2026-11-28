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

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class OnlineMembership {
  const OnlineMembership({
    required this.key,
    required this.label,
    required this.level,
    required this.active,
    required this.expiresAt,
  });

  final String key;
  final String label;
  final int level;
  final bool active;
  final int expiresAt;

  factory OnlineMembership.fromJson(Map<String, dynamic> json) {
    return OnlineMembership(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      level: _asInt(json['level']),
      active: json['active'] as bool? ?? false,
      expiresAt: _asInt(json['expires_at']),
    );
  }
}

class OnlineUserProfile {
  const OnlineUserProfile({
    required this.uid,
    required this.nickname,
    required this.avatarUrl,
    required this.signature,
    required this.level,
    required this.follows,
    required this.followeds,
    required this.listenSeconds,
    required this.listenSongs,
    required this.createDays,
    required this.vipType,
    required this.memberships,
  });

  final int uid;
  final String nickname;
  final String avatarUrl;
  final String signature;
  final int level;
  final int follows;
  final int followeds;
  final int listenSeconds;
  final int listenSongs;
  final int createDays;
  final int vipType;
  final List<OnlineMembership> memberships;

  int get listenHours => listenSeconds ~/ 3600;
  List<OnlineMembership> get activeMemberships =>
      memberships.where((value) => value.active).toList(growable: false);

  factory OnlineUserProfile.fromJson(Map<String, dynamic> json) {
    final memberships = json['memberships'];
    return OnlineUserProfile(
      uid: _asInt(json['uid']),
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      signature: json['signature'] as String? ?? '',
      level: _asInt(json['level']),
      follows: _asInt(json['follows']),
      followeds: _asInt(json['followeds']),
      listenSeconds: _asInt(json['listen_seconds']),
      listenSongs: _asInt(json['listen_songs']),
      createDays: _asInt(json['create_days']),
      vipType: _asInt(json['vip_type']),
      memberships: memberships is List
          ? memberships
                .whereType<Map>()
                .map(
                  (value) => OnlineMembership.fromJson(
                    Map<String, dynamic>.from(value),
                  ),
                )
                .toList(growable: false)
          : const <OnlineMembership>[],
    );
  }
}

class OnlineAlbumMeta {
  const OnlineAlbumMeta({
    required this.id,
    required this.name,
    required this.coverUrl,
    required this.artist,
    required this.publishTime,
    required this.description,
    required this.company,
  });

  final String id;
  final String name;
  final String? coverUrl;
  final String artist;
  final int publishTime;
  final String description;
  final String company;

  factory OnlineAlbumMeta.fromJson(Map<String, dynamic> json) {
    return OnlineAlbumMeta(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      coverUrl: json['cover'] as String?,
      artist: json['artist'] as String? ?? '',
      publishTime: _asInt(json['publish_time']),
      description: json['description'] as String? ?? '',
      company: json['company'] as String? ?? '',
    );
  }
}

final onlineUserProfileProvider = FutureProvider<OnlineUserProfile>((
  ref,
) async {
  final baseUrl = ref.watch(onlineBaseUrlProvider);
  if (baseUrl.isEmpty) {
    throw StateError('当前模式 sidecar 未启动');
  }
  final token = await ref.watch(onlineTokenProvider.future);
  if (token == null || token.isEmpty) {
    throw StateError('请先登录网易云账号');
  }
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('$baseUrl/api/v1/user/profile'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['data'] is! Map) {
      throw StateError('用户信息返回格式异常');
    }
    return OnlineUserProfile.fromJson(
      Map<String, dynamic>.from(decoded['data'] as Map),
    );
  } finally {
    client.close(force: true);
  }
});

Future<Map<String, dynamic>> _onlineGetData(
  Ref ref,
  String path, [
  Map<String, String> query = const <String, String>{},
]) async {
  final baseUrl = ref.watch(onlineBaseUrlProvider);
  if (baseUrl.isEmpty) {
    throw StateError('当前模式 sidecar 未启动');
  }
  final token = await ref.watch(onlineTokenProvider.future);
  if (token == null || token.isEmpty) {
    throw StateError('请先登录网易云账号');
  }
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse(
        '$baseUrl$path',
      ).replace(queryParameters: query.isEmpty ? null : query),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['data'] is! Map) {
      throw StateError('接口返回格式异常');
    }
    return Map<String, dynamic>.from(decoded['data'] as Map);
  } finally {
    client.close(force: true);
  }
}

rust_online.UiOnlinePlaylist _playlistFromJson(Map<String, dynamic> json) {
  return rust_online.UiOnlinePlaylist(
    source: json['source'] as String? ?? 'netease',
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    coverUrl: json['cover'] as String?,
    trackCount: _asInt(json['track_count']),
    playCount: BigInt.from(_asInt(json['play_count'])),
    creator: json['creator'] as String?,
    description: json['description'] as String?,
    link: json['link'] as String?,
  );
}

rust_online.UiOnlineAlbum _albumFromJson(Map<String, dynamic> json) {
  return rust_online.UiOnlineAlbum(
    source: json['source'] as String? ?? 'netease',
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    coverUrl: json['cover'] as String?,
    trackCount: _asInt(json['track_count']),
    artist: json['creator'] as String?,
  );
}

List<rust_online.UiOnlinePlaylist> _playlistsFromData(
  Map<String, dynamic> data,
) {
  final playlists = data['playlists'];
  if (playlists is! List) return const <rust_online.UiOnlinePlaylist>[];
  return playlists
      .whereType<Map>()
      .map((value) => _playlistFromJson(Map<String, dynamic>.from(value)))
      .toList(growable: false);
}

typedef OnlinePageKey = ({int page, int limit});

final onlineCreatedPlaylistsPageProvider =
    FutureProvider.family<List<rust_online.UiOnlinePlaylist>, OnlinePageKey>((
      ref,
      key,
    ) async {
      final data = await _onlineGetData(ref, '/api/v1/playlist/user', {
        'kind': 'created',
        'page': '${key.page}',
        'limit': '${key.limit}',
      });
      return _playlistsFromData(data);
    });

final onlineCollectedPlaylistsPageProvider =
    FutureProvider.family<List<rust_online.UiOnlinePlaylist>, OnlinePageKey>((
      ref,
      key,
    ) async {
      final data = await _onlineGetData(ref, '/api/v1/playlist/user', {
        'kind': 'collected',
        'page': '${key.page}',
        'limit': '${key.limit}',
      });
      return _playlistsFromData(data);
    });

final onlineLikedPlaylistProvider =
    FutureProvider<rust_online.UiOnlinePlaylist?>((ref) async {
      final data = await _onlineGetData(ref, '/api/v1/playlist/user', const {
        'kind': 'liked',
        'page': '1',
        'limit': '1',
      });
      final playlists = _playlistsFromData(data);
      return playlists.isEmpty ? null : playlists.first;
    });

final onlineCollectedAlbumsPageProvider =
    FutureProvider.family<List<rust_online.UiOnlineAlbum>, OnlinePageKey>((
      ref,
      key,
    ) async {
      final data = await _onlineGetData(ref, '/api/v1/album/sublist', {
        'page': '${key.page}',
        'limit': '${key.limit}',
      });
      final albums = data['albums'];
      if (albums is! List) return const <rust_online.UiOnlineAlbum>[];
      return albums
          .whereType<Map>()
          .map((value) => _albumFromJson(Map<String, dynamic>.from(value)))
          .toList(growable: false);
    });

final onlineAlbumMetaProvider = FutureProvider.family<OnlineAlbumMeta, String>((
  ref,
  id,
) async {
  final data = await _onlineGetData(ref, '/api/v1/album/meta', {'id': id});
  return OnlineAlbumMeta.fromJson(data);
});

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

typedef OnlineTrackPageKey = ({
  String source,
  String id,
  int limit,
  int offset,
});

final onlinePlaylistTracksPageProvider =
    FutureProvider.family<List<rust.UiTrack>, OnlineTrackPageKey>((
      ref,
      key,
    ) async {
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
        limit: key.limit,
        offset: key.offset,
      );
    });

final onlineAlbumTracksPageProvider =
    FutureProvider.family<List<rust.UiTrack>, OnlineTrackPageKey>((
      ref,
      key,
    ) async {
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
        limit: key.limit,
        offset: key.offset,
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
