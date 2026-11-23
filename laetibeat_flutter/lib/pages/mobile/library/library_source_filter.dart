import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/settings/song_source_settings.dart';

/// Library source selected from the Media Library app bar.
///
/// This is a projection of the persisted appearance setting
/// `defaultSongSourceProvider`; child pages read it instead of showing their
/// own filter chips.
enum LibrarySourceFilter { all, local, navidrome, lx }

final librarySourceFilterProvider = Provider<LibrarySourceFilter>((ref) {
  final source = ref.watch(defaultSongSourceProvider);
  return switch (source) {
    SongSources.local => LibrarySourceFilter.local,
    SongSources.subsonic => LibrarySourceFilter.navidrome,
    SongSources.lx => LibrarySourceFilter.lx,
    _ => LibrarySourceFilter.all,
  };
});

extension LibrarySourceFilterLabel on LibrarySourceFilter {
  String get label => switch (this) {
    LibrarySourceFilter.all => '全部',
    LibrarySourceFilter.local => '本地',
    LibrarySourceFilter.navidrome => 'Navidrome',
    LibrarySourceFilter.lx => '洛雪',
  };
}
