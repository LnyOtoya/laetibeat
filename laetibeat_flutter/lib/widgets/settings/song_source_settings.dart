import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persistence.dart';

/// 歌曲来源名称。当前支持本地音乐、Subsonic 和洛雪。
abstract final class SongSources {
  static const String allSources = '全部来源';
  static const String local = '本地音乐';
  static const String subsonic = 'Subsonic';
  static const String jellyfin = 'Jellyfin';
  static const String emby = 'Emby音乐';
  static const String lx = '洛雪音源';

  /// 当前真正可筛选的来源。未实现来源不放入设置，避免死选项。
  static const List<String> all = <String>[allSources, local, subsonic, lx];
}

const String kDefaultSongSourceKey = 'mobile.defaultSongSource';

/// 歌曲列表默认来源。未设置时回退到本地音乐。
class DefaultSongSourceNotifier extends Notifier<String> {
  @override
  String build() {
    final saved = ref
        .read(sharedPreferencesProvider)
        .getString(kDefaultSongSourceKey);
    return SongSources.all.contains(saved) ? saved! : SongSources.allSources;
  }

  void setSource(String source) {
    if (!SongSources.all.contains(source) || source == state) return;
    state = source;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(kDefaultSongSourceKey, source),
    );
  }
}

final defaultSongSourceProvider =
    NotifierProvider<DefaultSongSourceNotifier, String>(
      DefaultSongSourceNotifier.new,
    );
