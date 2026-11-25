import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../mobile_navigation.dart';
import 'library_source_filter.dart';
import 'views/albums_library_view.dart';
import 'views/artists_library_view.dart';
import 'views/playlists_library_view.dart';
import 'views/songs_library_view.dart';
import 'widgets/song_sort_sheet.dart';

/// 子页面排序动作。
///
/// 需要 `ref` 才能读写排序设置，因此由页面壳统一注入，视图本身不再持有
/// 排序入口。
typedef _SubpageSortHandler = Future<void> Function(
  BuildContext context,
  WidgetRef ref,
);

/// 媒体库子页面共用 Scaffold。
///
/// 顶部栏由 [AppPageBar.subpage] 统一提供；布局状态（网格/列表）上提到这里，
/// 这样顶部栏的布局按钮和页面内容读的是同一份状态。
class _MobileLibrarySubpage extends ConsumerStatefulWidget {
  const _MobileLibrarySubpage({
    required this.title,
    required this.childBuilder,
    this.showLayout = false,
    this.onSort,
  });

  final String title;
  final Widget Function(bool isGrid) childBuilder;

  /// 是否显示布局切换按钮。歌曲类页面不显示。
  final bool showLayout;

  /// 为空时排序按钮显示但禁用。
  final _SubpageSortHandler? onSort;

  @override
  ConsumerState<_MobileLibrarySubpage> createState() =>
      _MobileLibrarySubpageState();
}

class _MobileLibrarySubpageState extends ConsumerState<_MobileLibrarySubpage> {
  bool _isGrid = true;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final sortHandler = widget.onSort;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageBar.subpage(
        title: widget.title,
        onSearch: () => openMobileSearch(context),
        onSort: sortHandler == null
            ? null
            : () => sortHandler(context, ref),
        showLayout: widget.showLayout,
        isGrid: _isGrid,
        onToggleLayout: widget.showLayout
            ? () => setState(() => _isGrid = !_isGrid)
            : null,
      ),
      body: widget.childBuilder(_isGrid),
    );
  }
}

class MobileLibrarySongsPage extends StatelessWidget {
  const MobileLibrarySongsPage({super.key, this.sourceFilter, this.title});

  /// 当入口需要固定来源时注入；为空则使用全局来源设置。
  final LibrarySourceFilter? sourceFilter;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final Widget content = sourceFilter == null
        ? const SongsLibraryView()
        : ProviderScope(
            overrides: [
              librarySourceFilterProvider.overrideWithValue(sourceFilter!),
            ],
            child: const SongsLibraryView(),
          );

    return _MobileLibrarySubpage(
      title: title ?? AppLocalizations.of(context).libraryAllSongs,
      onSort: showSongSortSheet,
      childBuilder: (_) => content,
    );
  }
}

class MobileLibraryAlbumsPage extends StatelessWidget {
  const MobileLibraryAlbumsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _MobileLibrarySubpage(
      title: AppLocalizations.of(context).libraryAlbums,
      showLayout: true,
      childBuilder: (bool isGrid) => AlbumsLibraryView(isGrid: isGrid),
    );
  }
}

class MobileLibraryArtistsPage extends StatelessWidget {
  const MobileLibraryArtistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _MobileLibrarySubpage(
      title: AppLocalizations.of(context).libraryArtists,
      showLayout: true,
      childBuilder: (bool isGrid) => ArtistsLibraryView(isGrid: isGrid),
    );
  }
}

class MobileLibraryPlaylistsPage extends StatelessWidget {
  const MobileLibraryPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _MobileLibrarySubpage(
      title: AppLocalizations.of(context).libraryPlaylists,
      showLayout: true,
      childBuilder: (bool isGrid) => PlaylistsLibraryView(isGrid: isGrid),
    );
  }
}
