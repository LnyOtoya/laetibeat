import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persistence.dart';

/// 收藏的艺人 id 集合。
///
/// 目前只有本地艺人详情页的收藏按钮使用；后续专辑/歌曲收藏可以复用同一套
/// 本地 persisted 集合，或拆成独立 provider。
const String kFavoriteArtistsKey = 'library.favorite_artists';

class FavoriteArtistsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final saved = ref
        .read(sharedPreferencesProvider)
        .getStringList(kFavoriteArtistsKey);
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
          .setStringList(kFavoriteArtistsKey, next.toList()),
    );
  }
}

final favoriteArtistsProvider =
    NotifierProvider<FavoriteArtistsNotifier, Set<String>>(
      FavoriteArtistsNotifier.new,
    );
