import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import '../search/mobile_search_page.dart';
import '../widgets/mobile_app_bar.dart';
import 'mobile_library_subpages.dart';

/// 媒体库首页。
///
/// 只做内容入口，不再直接展示歌曲/专辑/艺术家列表。具体内容页保留原有
/// 布局，后续在各自页面内接入来源筛选。
class MobileLibraryPage extends ConsumerWidget {
  const MobileLibraryPage({super.key});

  void _openSearchPage(BuildContext context) {
    pushMobileRootPage(
      context,
      const MobileSearchPage(),
      name: MobileRoutes.search,
    );
  }

  void _openEntry(BuildContext context, _LibraryEntry entry) {
    pushMobileRootPage(context, entry.page, name: entry.routeName);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    final local = ref.watch(musicLibraryProvider).value;
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final server = servers.isEmpty ? null : servers.first;

    final localReady = local != null;
    final localTracks = local?.tracks.length ?? 0;
    final remoteTracks = server == null ? 0 : _cachedTrackCount(ref, server.id);
    final remoteAlbums = server == null ? 0 : _cachedAlbumCount(ref, server.id);
    final remoteArtists = server == null
        ? 0
        : _cachedArtistCount(ref, server.id);
    final remotePlaylists = server == null
        ? 0
        : _cachedPlaylistCount(ref, server.id);

    final songsCount = !localReady
        ? null
        : server != null && remoteTracks == null
        ? null
        : localTracks + (remoteTracks ?? 0);
    final albumsCount = !localReady
        ? null
        : server != null && remoteAlbums == null
        ? null
        : (local.albums.length) + (remoteAlbums ?? 0);
    final artistsCount = !localReady
        ? null
        : server != null && remoteArtists == null
        ? null
        : (local.artists.length) + (remoteArtists ?? 0);
    final playlistsCount = server == null ? null : remotePlaylists;

    final sourceParts = <String>[
      if (local?.directory != null) l10n.librarySourceLocal,
      if (server != null) server.name,
    ];
    final subtitle = !localReady && server == null
        ? '—'
        : sourceParts.isEmpty
        ? l10n.libraryNoSources
        : sourceParts.join(' · ');

    final entries = <_LibraryEntry>[
      _LibraryEntry(
        icon: M3EIcons.album,
        label: l10n.libraryAlbums,
        countText: _formatCount(albumsCount, l10n.libraryAlbumsCount),
        routeName: MobileRoutes.libraryAlbums,
        page: const MobileLibraryAlbumsPage(),
      ),
      _LibraryEntry(
        icon: M3EIcons.person,
        label: l10n.libraryArtists,
        countText: _formatCount(artistsCount, l10n.libraryArtistsCount),
        routeName: MobileRoutes.libraryArtists,
        page: const MobileLibraryArtistsPage(),
      ),
      _LibraryEntry(
        icon: M3EIcons.queue_music,
        label: l10n.libraryPlaylists,
        countText: _formatCount(playlistsCount, l10n.libraryPlaylistsCount),
        routeName: MobileRoutes.libraryPlaylists,
        page: const MobileLibraryPlaylistsPage(),
      ),
    ];

    return Scaffold(
      backgroundColor: scheme.surfaceContainer,
      appBar: M3EAppBar.top(
        backgroundColor: scheme.surfaceContainer,
        variant: M3EAppBarVariant.largeFlexible,
        shapeFamily: M3EAppBarShapeFamily.square,
        safeArea: true,
        titleText: l10n.libraryTitle,
        subtitleText: subtitle,
        actions: mobileHomeAppBarActions(context),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
        children: [
          M3ESearchBar(
            hintText: l10n.searchHint,
            leading: const Icon(M3EIcons.search),
            readOnly: true,
            expandOnFocus: false,
            constraints: const BoxConstraints.tightFor(height: 52),
            backgroundColor: WidgetStatePropertyAll<Color?>(
              scheme.surfaceContainerHigh,
            ),
            onTap: () => _openSearchPage(context),
          ),
          const SizedBox(height: 20),
          M3ECard(
            variant: M3ECardVariant.filled,
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(24),
            expanded: true,
            openBuilder: (_) => const MobileLibrarySongsPage(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: scheme.onPrimaryContainer.withValues(
                          alpha: 0.12,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        M3EIcons.music_note,
                        size: 30,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      M3EIcons.arrow_forward,
                      color: scheme.onPrimaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.libraryAllSongs,
                  style: theme.typeScale.headlineMedium.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCount(songsCount, l10n.librarySongsCount),
                  style: theme.typeScale.displaySmall.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.libraryBrowse, style: theme.typeScale.titleLarge),
          const SizedBox(height: 8),
          M3EList(
            itemCount: entries.length,
            color: scheme.surfaceContainerHigh,
            variant: M3ECardVariant.filled,
            // M3EList 会在行表面统一绑定点击；只设置 M3EListItem.onTap
            // 不会生效。
            onTap: (int index) => _openEntry(context, entries[index]),
            itemBuilder: (BuildContext context, int index) {
              final entry = entries[index];
              return M3EListItem(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(entry.icon, color: scheme.onSecondaryContainer),
                ),
                headline: entry.label,
                trailingText: entry.countText,
                trailing: Icon(
                  M3EIcons.chevron_right,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                showDivider: index < entries.length - 1,
                onTap: () => _openEntry(context, entry),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatCount(int? count, String Function(int) format) {
    return count == null ? '—' : format(count);
  }

  int? _cachedTrackCount(WidgetRef ref, String sourceId) {
    final provider = remoteAllTracksProvider(sourceId);
    final container = ProviderScope.containerOf(ref.context, listen: false);
    // ignore: deprecated_member_use
    if (!container.exists(provider)) return null;
    return container.read(provider).value?.length;
  }

  int? _cachedAlbumCount(WidgetRef ref, String sourceId) {
    final provider = remoteAllAlbumsProvider(sourceId);
    final container = ProviderScope.containerOf(ref.context, listen: false);
    // ignore: deprecated_member_use
    if (!container.exists(provider)) return null;
    return container.read(provider).value?.length;
  }

  int? _cachedArtistCount(WidgetRef ref, String sourceId) {
    final provider = remoteArtistsProvider(sourceId);
    final container = ProviderScope.containerOf(ref.context, listen: false);
    // ignore: deprecated_member_use
    if (!container.exists(provider)) return null;
    return container.read(provider).value?.length;
  }

  int? _cachedPlaylistCount(WidgetRef ref, String sourceId) {
    final provider = remotePlaylistsProvider(sourceId);
    final container = ProviderScope.containerOf(ref.context, listen: false);
    // ignore: deprecated_member_use
    if (!container.exists(provider)) return null;
    return container.read(provider).value?.length;
  }
}

class _LibraryEntry {
  const _LibraryEntry({
    required this.icon,
    required this.label,
    required this.countText,
    required this.routeName,
    required this.page,
  });

  final IconData icon;
  final String label;
  final String countText;
  final String routeName;
  final Widget page;
}
