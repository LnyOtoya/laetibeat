import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../widgets/mobile_large_subpage_app_bar.dart';
import 'library_source_filter.dart';
import 'views/albums_library_view.dart';
import 'views/artists_library_view.dart';
import 'views/playlists_library_view.dart';
import 'views/songs_library_view.dart';

/// 媒体库子页面共用 Scaffold。
///
/// 内容视图保持原有布局，只增加统一的大标题 AppBar 和返回路径。
class _MobileLibrarySubpage extends StatelessWidget {
  const _MobileLibrarySubpage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: mobileLargeSubpageAppBar(
        context,
        title: title,
        variant: M3EAppBarVariant.mediumFlexible,
      ),
      body: child,
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
      child: content,
    );
  }
}

class MobileLibraryAlbumsPage extends StatelessWidget {
  const MobileLibraryAlbumsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _MobileLibrarySubpage(
      title: AppLocalizations.of(context).libraryAlbums,
      child: const AlbumsLibraryView(),
    );
  }
}

class MobileLibraryArtistsPage extends StatelessWidget {
  const MobileLibraryArtistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _MobileLibrarySubpage(
      title: AppLocalizations.of(context).libraryArtists,
      child: const ArtistsLibraryView(),
    );
  }
}

class MobileLibraryPlaylistsPage extends StatelessWidget {
  const MobileLibraryPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _MobileLibrarySubpage(
      title: AppLocalizations.of(context).libraryPlaylists,
      child: const PlaylistsLibraryView(),
    );
  }
}
