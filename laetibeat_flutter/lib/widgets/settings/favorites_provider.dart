import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persistence.dart';

/// 收藏的艺人 id 集合（本地持久化）。
const String kFavoriteArtistsKey = 'library.favorite_artists';

/// 收藏的专辑 id 集合（本地持久化，key 形如 `sourceId:albumId`）。
const String kFavoriteAlbumsKey = 'library.favorite_albums';

/// 收藏的歌单 id 集合（本地持久化，key 形如 `local:playlistId`）。
const String kFavoritePlaylistsKey = 'library.favorite_playlists';

/// 通用的“收藏 id 集合”存储。
///
/// 目前用于艺人、专辑和歌单；后续歌曲收藏可以再加一个子类，避免重复实现持久化。
abstract class _FavoriteIdsNotifier extends Notifier<Set<String>> {
  _FavoriteIdsNotifier(this.storageKey);

  final String storageKey;

  @override
  Set<String> build() {
    final saved = ref.read(sharedPreferencesProvider).getStringList(storageKey);
    return (saved ?? const <String>[]).toSet();
  }

  void toggle(String id) {
    final next = <String>{...state};
    if (!next.add(id)) {
      next.remove(id);
    }
    state = next;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setStringList(storageKey, next.toList()),
    );
  }
}

class FavoriteArtistsNotifier extends _FavoriteIdsNotifier {
  FavoriteArtistsNotifier() : super(kFavoriteArtistsKey);
}

class FavoriteAlbumsNotifier extends _FavoriteIdsNotifier {
  FavoriteAlbumsNotifier() : super(kFavoriteAlbumsKey);
}

class FavoritePlaylistsNotifier extends _FavoriteIdsNotifier {
  FavoritePlaylistsNotifier() : super(kFavoritePlaylistsKey);
}

final favoriteArtistsProvider =
    NotifierProvider<FavoriteArtistsNotifier, Set<String>>(
      FavoriteArtistsNotifier.new,
    );

final favoriteAlbumsProvider =
    NotifierProvider<FavoriteAlbumsNotifier, Set<String>>(
      FavoriteAlbumsNotifier.new,
    );

final favoritePlaylistsProvider =
    NotifierProvider<FavoritePlaylistsNotifier, Set<String>>(
      FavoritePlaylistsNotifier.new,
    );
