import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/netease.dart' as rust_netease;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

import '../cache/netease_cover_cache.dart';
import 'netease_session.dart';
import 'netease_settings.dart';

const int neteasePlaylistTracksPageSize = 25;
const int neteaseSubscriptionPageSize = 25;

/// 当前配置的网易云 Node API 地址。
final neteaseBaseUrlProvider = Provider<String>((ref) {
  return ref.watch(
    neteaseSettingsProvider.select((settings) => settings.apiBaseUrl),
  );
});

/// 网易云 Node API 的连接/登录状态。
final neteaseStatusProvider =
    FutureProvider.autoDispose<rust_netease.UiNeteaseStatus>((ref) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      final cookie = await ref.watch(neteaseCookieProvider.future);
      return rust_netease.neteaseStatus(baseUrl: baseUrl, cookie: cookie);
    });

/// 网易云每日推荐。需要登录，返回当前账号的个性化日推。
final neteaseDailyProvider = FutureProvider.autoDispose<List<rust.UiTrack>>((
  ref,
) async {
  final baseUrl = ref.watch(neteaseBaseUrlProvider);
  if (baseUrl.isEmpty) {
    throw StateError('请先配置网易云 API 地址');
  }
  final cookie = await ref.watch(neteaseCookieProvider.future);
  if (cookie == null || cookie.isEmpty) {
    throw StateError('请先登录网易云');
  }
  return rust_netease.neteaseDailyRecommendations(
    baseUrl: baseUrl,
    cookie: cookie,
  );
});

const int neteaseDiscoverPlaylistLimit = 6;

/// 发现页推荐歌单。需要登录；接口默认最多 30，这里只取卡片所需的 6 个。
final neteasePersonalizedPlaylistsProvider =
    FutureProvider.autoDispose<List<rust_netease.UiNeteasePlaylist>>((
      ref,
    ) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      final cookie = await ref.watch(neteaseCookieProvider.future);
      if (cookie == null || cookie.isEmpty) {
        throw StateError('请先登录网易云');
      }
      return rust_netease.neteasePersonalizedPlaylists(
        baseUrl: baseUrl,
        limit: neteaseDiscoverPlaylistLimit,
        cookie: cookie,
      );
    });

/// 首页雷达歌单。需要登录；接口从首页 block 中提取，通常返回 6 个。
final neteaseRadarPlaylistsProvider =
    FutureProvider.autoDispose<List<rust_netease.UiNeteasePlaylist>>((
      ref,
    ) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      final cookie = await ref.watch(neteaseCookieProvider.future);
      if (cookie == null || cookie.isEmpty) {
        throw StateError('请先登录网易云');
      }
      return rust_netease.neteaseRadarPlaylists(
        baseUrl: baseUrl,
        cookie: cookie,
      );
    });

/// 私人 FM。需要登录；接口每次只返回 1 首。
final neteasePersonalFmProvider =
    FutureProvider.autoDispose<List<rust.UiTrack>>((ref) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      final cookie = await ref.watch(neteaseCookieProvider.future);
      if (cookie == null || cookie.isEmpty) {
        throw StateError('请先登录网易云');
      }
      return rust_netease.neteasePersonalFm(baseUrl: baseUrl, cookie: cookie);
    });

/// 当前用户的「我喜欢的音乐」歌单。需要登录；没有歌单时返回 null。
final neteaseLikedPlaylistProvider =
    FutureProvider.autoDispose<rust_netease.UiNeteasePlaylist?>((ref) async {
      final cookie = await ref.watch(neteaseCookieProvider.future);
      if (cookie == null || cookie.isEmpty) {
        throw StateError('请先登录网易云');
      }
      final playlists = await ref.watch(neteaseUserPlaylistsProvider.future);
      for (final playlist in playlists) {
        if (playlist.specialType == 5) return playlist;
      }
      return playlists.isEmpty ? null : playlists.first;
    });

/// 心动模式队列。需要登录；使用「我喜欢的音乐」首曲作为种子。
final neteaseHeartModeProvider = FutureProvider.autoDispose<List<rust.UiTrack>>(
  (ref) async {
    final baseUrl = ref.watch(neteaseBaseUrlProvider);
    final cookie = await ref.watch(neteaseCookieProvider.future);
    if (cookie == null || cookie.isEmpty) {
      throw StateError('请先登录网易云');
    }
    final liked = await ref.watch(neteaseLikedPlaylistProvider.future);
    if (liked == null) {
      throw StateError('没有找到「我喜欢的音乐」歌单');
    }
    final seeds = await rust_netease.neteasePlaylistTracks(
      baseUrl: baseUrl,
      playlistId: liked.id,
      cookie: cookie,
      limit: 1,
      offset: 0,
    );
    if (seeds.isEmpty) {
      throw StateError('红心歌曲为空');
    }
    final seedId = BigInt.parse(neteaseSongIdFromTrack(seeds.first));
    return rust_netease.neteaseIntelligenceList(
      baseUrl: baseUrl,
      cookie: cookie,
      songId: seedId,
      playlistId: liked.id,
      startSongId: seedId,
    );
  },
);

/// 相似歌曲。需要登录；使用「我喜欢的音乐」首曲作为种子。
final neteaseSimilarSongsProvider =
    FutureProvider.autoDispose<List<rust.UiTrack>>((ref) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      final cookie = await ref.watch(neteaseCookieProvider.future);
      if (cookie == null || cookie.isEmpty) {
        throw StateError('请先登录网易云');
      }
      final liked = await ref.watch(neteaseLikedPlaylistProvider.future);
      if (liked == null) {
        throw StateError('没有找到「我喜欢的音乐」歌单');
      }
      final seeds = await rust_netease.neteasePlaylistTracks(
        baseUrl: baseUrl,
        playlistId: liked.id,
        cookie: cookie,
        limit: 1,
        offset: 0,
      );
      if (seeds.isEmpty) {
        throw StateError('红心歌曲为空');
      }
      final seedId = BigInt.parse(neteaseSongIdFromTrack(seeds.first));
      return rust_netease.neteaseSimilarSongs(
        baseUrl: baseUrl,
        songId: seedId,
        cookie: cookie,
      );
    });

/// 当前登录用户的网易云歌单。
final neteaseUserPlaylistsProvider =
    FutureProvider.autoDispose<List<rust_netease.UiNeteasePlaylist>>((
      ref,
    ) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      final cookie = await ref.watch(neteaseCookieProvider.future);
      if (cookie == null || cookie.isEmpty) {
        throw StateError('请先登录网易云');
      }
      final status = await rust_netease.neteaseStatus(
        baseUrl: baseUrl,
        cookie: cookie,
      );
      final uid = status.userId;
      if (uid == null) {
        throw StateError('没有获取到网易云用户 ID');
      }
      return rust_netease.neteaseUserPlaylists(
        baseUrl: baseUrl,
        uid: uid,
        cookie: cookie,
      );
    });

/// 当前登录用户收藏的艺人。
final neteaseSubscribedArtistsProvider =
    FutureProvider.autoDispose<List<rust_netease.UiNeteaseArtist>>((ref) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      final cookie = await ref.watch(neteaseCookieProvider.future);
      if (cookie == null || cookie.isEmpty) {
        throw StateError('请先登录网易云');
      }
      debugPrint(
        '[NeteaseSubscriptions] requesting artists: '
        'limit=$neteaseSubscriptionPageSize, offset=0',
      );
      final artists = await rust_netease.neteaseSubscribedArtists(
        baseUrl: baseUrl,
        cookie: cookie,
        limit: neteaseSubscriptionPageSize,
        offset: 0,
      );
      debugPrint(
        '[NeteaseSubscriptions] artists first page received: '
        'returned=${artists.length}',
      );
      return artists;
    });

typedef NeteaseSubscriptionPageKey = ({int limit, int offset});

/// A page of artists subscribed by the current user.
final neteaseSubscribedArtistsPageProvider = FutureProvider.autoDispose
    .family<List<rust_netease.UiNeteaseArtist>, NeteaseSubscriptionPageKey>((
      ref,
      key,
    ) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      final cookie = await ref.watch(neteaseCookieProvider.future);
      if (cookie == null || cookie.isEmpty) {
        throw StateError('请先登录网易云');
      }
      debugPrint(
        '[NeteaseSubscriptions] requesting artists page: '
        'limit=${key.limit}, offset=${key.offset}',
      );
      final artists = await rust_netease.neteaseSubscribedArtists(
        baseUrl: baseUrl,
        cookie: cookie,
        limit: key.limit,
        offset: key.offset,
      );
      debugPrint(
        '[NeteaseSubscriptions] artists page received: '
        'offset=${key.offset}, returned=${artists.length}',
      );
      return artists;
    });

/// 当前登录用户收藏的专辑。
final neteaseSubscribedAlbumsProvider =
    FutureProvider.autoDispose<List<rust_netease.UiNeteaseAlbum>>((ref) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      final cookie = await ref.watch(neteaseCookieProvider.future);
      if (cookie == null || cookie.isEmpty) {
        throw StateError('请先登录网易云');
      }
      debugPrint(
        '[NeteaseSubscriptions] requesting albums: '
        'limit=$neteaseSubscriptionPageSize, offset=0',
      );
      final albums = await rust_netease.neteaseSubscribedAlbums(
        baseUrl: baseUrl,
        cookie: cookie,
        limit: neteaseSubscriptionPageSize,
        offset: 0,
      );
      debugPrint(
        '[NeteaseSubscriptions] albums first page received: '
        'returned=${albums.length}',
      );
      return albums;
    });

final neteaseSubscribedAlbumsPageProvider = FutureProvider.autoDispose
    .family<List<rust_netease.UiNeteaseAlbum>, NeteaseSubscriptionPageKey>((
      ref,
      key,
    ) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      final cookie = await ref.watch(neteaseCookieProvider.future);
      if (cookie == null || cookie.isEmpty) {
        throw StateError('请先登录网易云');
      }
      debugPrint(
        '[NeteaseSubscriptions] requesting albums page: '
        'limit=${key.limit}, offset=${key.offset}',
      );
      final albums = await rust_netease.neteaseSubscribedAlbums(
        baseUrl: baseUrl,
        cookie: cookie,
        limit: key.limit,
        offset: key.offset,
      );
      debugPrint(
        '[NeteaseSubscriptions] albums page received: '
        'offset=${key.offset}, returned=${albums.length}',
      );
      return albums;
    });

/// 歌单全部歌曲。
final neteasePlaylistTracksProvider = FutureProvider.autoDispose
    .family<List<rust.UiTrack>, BigInt>((ref, playlistId) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      final cookie = await ref.watch(neteaseCookieProvider.future);
      debugPrint(
        '[NeteasePlaylistTracks] requesting first page: '
        'playlist=$playlistId, limit=$neteasePlaylistTracksPageSize, offset=0',
      );
      try {
        final tracks = await rust_netease.neteasePlaylistTracks(
          baseUrl: baseUrl,
          playlistId: playlistId,
          cookie: cookie,
          limit: neteasePlaylistTracksPageSize,
          offset: 0,
        );
        debugPrint(
          '[NeteasePlaylistTracks] first page received: '
          'playlist=$playlistId, returned=${tracks.length}',
        );
        return tracks;
      } catch (error) {
        debugPrint(
          '[NeteasePlaylistTracks] first page request failed: '
          'playlist=$playlistId, error=$error',
        );
        rethrow;
      }
    });

typedef NeteasePlaylistTracksPageKey = ({
  BigInt playlistId,
  int limit,
  int offset,
});

/// A page of songs from a playlist, requested when the detail list nears its end.
final neteasePlaylistTracksPageProvider = FutureProvider.autoDispose
    .family<List<rust.UiTrack>, NeteasePlaylistTracksPageKey>((ref, key) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      final cookie = await ref.watch(neteaseCookieProvider.future);
      debugPrint(
        '[NeteasePlaylistTracksPage] requesting: '
        'playlist=${key.playlistId}, limit=${key.limit}, offset=${key.offset}',
      );
      try {
        final tracks = await rust_netease.neteasePlaylistTracks(
          baseUrl: baseUrl,
          playlistId: key.playlistId,
          cookie: cookie,
          limit: key.limit,
          offset: key.offset,
        );
        debugPrint(
          '[NeteasePlaylistTracksPage] response received: '
          'playlist=${key.playlistId}, offset=${key.offset}, '
          'returned=${tracks.length}',
        );
        return tracks;
      } catch (error) {
        debugPrint(
          '[NeteasePlaylistTracksPage] request failed: '
          'playlist=${key.playlistId}, offset=${key.offset}, error=$error',
        );
        rethrow;
      }
    });

/// 网易云歌单封面字节。
final neteasePlaylistCoverProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, url) async {
      if (url.isEmpty) return null;
      return ref.read(neteaseCoverSourceProvider).coverUrl(url);
    });

typedef NeteaseSearchKey = ({String keywords, int limit, int offset});

/// 网易云单曲搜索。当前 UI 尚未接入，先保留给搜索页使用。
final neteaseSearchProvider = FutureProvider.autoDispose
    .family<List<rust.UiTrack>, NeteaseSearchKey>((ref, key) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      return rust_netease.neteaseSearch(
        baseUrl: baseUrl,
        keywords: key.keywords,
        limit: key.limit,
        offset: key.offset,
      );
    });

/// 网易云歌单搜索。
final neteasePlaylistSearchProvider = FutureProvider.autoDispose
    .family<List<rust_netease.UiNeteasePlaylist>, NeteaseSearchKey>((
      ref,
      key,
    ) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      return rust_netease.neteaseSearchPlaylists(
        baseUrl: baseUrl,
        keywords: key.keywords,
        limit: key.limit,
        offset: key.offset,
      );
    });

/// 网易云专辑搜索。
final neteaseAlbumSearchProvider = FutureProvider.autoDispose
    .family<List<rust_netease.UiNeteaseAlbum>, NeteaseSearchKey>((
      ref,
      key,
    ) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      return rust_netease.neteaseSearchAlbums(
        baseUrl: baseUrl,
        keywords: key.keywords,
        limit: key.limit,
        offset: key.offset,
      );
    });

/// 网易云艺人搜索。
final neteaseArtistSearchProvider = FutureProvider.autoDispose
    .family<List<rust_netease.UiNeteaseArtist>, NeteaseSearchKey>((
      ref,
      key,
    ) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      return rust_netease.neteaseSearchArtists(
        baseUrl: baseUrl,
        keywords: key.keywords,
        limit: key.limit,
        offset: key.offset,
      );
    });

/// 网易云专辑详情。
final neteaseAlbumDetailProvider = FutureProvider.autoDispose
    .family<rust_netease.UiNeteaseAlbumDetail, BigInt>((ref, albumId) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      return rust_netease.neteaseAlbumDetail(
        baseUrl: baseUrl,
        albumId: albumId,
      );
    });

/// 网易云艺人详情。
final neteaseArtistDetailProvider = FutureProvider.autoDispose
    .family<rust_netease.UiNeteaseArtistDetail, BigInt>((ref, artistId) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      return rust_netease.neteaseArtistDetail(
        baseUrl: baseUrl,
        artistId: artistId,
      );
    });

/// 网易云艺人热门歌曲（最多 50 首）。
final neteaseArtistTopSongsProvider = FutureProvider.autoDispose
    .family<List<rust.UiTrack>, BigInt>((ref, artistId) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      return rust_netease.neteaseArtistTopSongs(
        baseUrl: baseUrl,
        artistId: artistId,
      );
    });

/// 艺人专辑列表。
final neteaseArtistAlbumsProvider = FutureProvider.autoDispose
    .family<List<rust_netease.UiNeteaseAlbum>, BigInt>((ref, artistId) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      return rust_netease.neteaseArtistAlbums(
        baseUrl: baseUrl,
        artistId: artistId,
      );
    });

/// 网易云图片（歌单/专辑/艺人封面）字节。
final neteaseImageProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, url) async {
      if (url.isEmpty) return null;
      return ref.read(neteaseCoverSourceProvider).coverUrl(url);
    });

/// 从 UiTrack 中取出网易云 songId，兼容旧数据与 sourceExtraJson。
String neteaseSongIdFromTrack(rust.UiTrack track) {
  final extra = track.sourceExtraJson;
  if (extra != null && extra.isNotEmpty) {
    try {
      final decoded = jsonDecode(extra);
      if (decoded is Map) {
        final songId = decoded['songId'];
        if (songId is num) return songId.toInt().toString();
        if (songId is String && songId.isNotEmpty) return songId;
      }
    } catch (_) {
      // 快照损坏或旧格式，回退到 id。
    }
  }
  const prefix = 'netease:';
  if (track.id.startsWith(prefix)) {
    return track.id.substring(prefix.length);
  }
  return track.id;
}
