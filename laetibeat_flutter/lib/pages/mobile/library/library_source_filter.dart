import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Library source selected from the Media Library app bar.
///
/// Child pages read this provider instead of showing their own filter chips.
enum LibrarySourceFilter { local, navidrome, lx }

class LibrarySourceFilterNotifier extends Notifier<LibrarySourceFilter> {
  @override
  LibrarySourceFilter build() => LibrarySourceFilter.local;

  void select(LibrarySourceFilter source) {
    if (source == state) return;
    state = source;
  }
}

final librarySourceFilterProvider =
    NotifierProvider<LibrarySourceFilterNotifier, LibrarySourceFilter>(
      LibrarySourceFilterNotifier.new,
    );

extension LibrarySourceFilterLabel on LibrarySourceFilter {
  String get label => switch (this) {
    LibrarySourceFilter.local => '本地',
    LibrarySourceFilter.navidrome => 'Navidrome',
    LibrarySourceFilter.lx => '洛雪',
  };
}
