import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/widgets/playlist_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import 'mobile_library_subpages.dart';

/// 媒体库首页。
///
/// 只做内容入口，不再直接展示歌曲/专辑/艺术家列表。具体内容页保留原有
/// 布局，后续在各自页面内接入来源筛选。
class MobileLibraryPage extends ConsumerWidget {
  const MobileLibraryPage({super.key});

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
    final localPlaylists = ref.watch(localPlaylistsProvider).value?.length ?? 0;

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
    final playlistsCount = server == null
        ? localPlaylists
        : remotePlaylists == null
        ? null
        : localPlaylists + remotePlaylists;

    return AppScaffold(
      background: AppSurfaceLevel.container,
      safeArea: false,
      appBar: M3EAppBar.top(
        backgroundColor: AppSurfaceLevel.container.resolve(scheme),
        variant: M3EAppBarVariant.largeFlexible,
        shapeFamily: M3EAppBarShapeFamily.square,
        safeArea: true,
        titleText: l10n.libraryTitle,
        actions: const <Widget>[_LibrarySourceSplitButton()],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.lg + bottomInset,
        ),
        children: <Widget>[
          _LibrarySegmentedList(
            segments: <_LibrarySegment>[
              _LibrarySegment(
                icon: M3EIcons.library_music,
                title: '曲库',
                supportingText: _formatCount(
                  songsCount,
                  l10n.librarySongsCount,
                ),
                childText: '全部歌曲',
                routeName: MobileRoutes.librarySongs,
                page: const MobileLibrarySongsPage(),
              ),
              _LibrarySegment(
                icon: M3EIcons.album,
                title: '专辑',
                supportingText: _formatCount(
                  albumsCount,
                  l10n.libraryAlbumsCount,
                ),
                childText: '全部专辑',
                routeName: MobileRoutes.libraryAlbums,
                page: const MobileLibraryAlbumsPage(),
              ),
              _LibrarySegment(
                icon: M3EIcons.person,
                title: '艺术家',
                supportingText: _formatCount(
                  artistsCount,
                  l10n.libraryArtistsCount,
                ),
                childText: '全部艺术家',
                routeName: MobileRoutes.libraryArtists,
                page: const MobileLibraryArtistsPage(),
              ),
              _LibrarySegment(
                icon: M3EIcons.queue_music,
                title: '歌单',
                supportingText: _formatCount(
                  playlistsCount,
                  l10n.libraryPlaylistsCount,
                ),
                childText: '全部歌单',
                routeName: MobileRoutes.libraryPlaylists,
                page: const MobileLibraryPlaylistsPage(),
              ),
              _LibrarySegment(
                icon: M3EIcons.radio,
                title: '电台',
                supportingText: '暂无',
                childText: '暂无电台',
                routeName: MobileRoutes.libraryPodcasts,
              ),
            ],
            onOpen: (_LibrarySegment segment) {
              final page = segment.page;
              if (page == null) return;
              pushMobileRootPage(context, page, name: segment.routeName);
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

class _LibrarySourceSplitButton extends StatefulWidget {
  const _LibrarySourceSplitButton();

  @override
  State<_LibrarySourceSplitButton> createState() =>
      _LibrarySourceSplitButtonState();
}

class _LibrarySourceSplitButtonState extends State<_LibrarySourceSplitButton> {
  static const String _local = '本地';
  static const String _navidrome = 'Navidrome';
  static const String _lx = '洛雪';

  String _selected = _local;

  @override
  Widget build(BuildContext context) {
    // The app bar action row is end-aligned with an intrinsic-width child, so
    // a longer label naturally grows toward the left instead of overflowing.
    return m3e_core.M3ESplitButton<String>(
      style: m3e_core.M3EButtonStyle.tonal,
      size: m3e_core.M3EButtonSize.md,
      shape: m3e_core.M3EButtonShape.round,
      label: _selected,
      selectedValue: _selected,
      leadingTooltip: '当前来源',
      trailingTooltip: '选择来源',
      decoration: m3e_core.M3ESplitButtonDecoration.styleFrom(),
      items: const <m3e_core.M3ESplitButtonItem<String>>[
        m3e_core.M3ESplitButtonItem<String>(value: _local, child: Text(_local)),
        m3e_core.M3ESplitButtonItem<String>(
          value: _navidrome,
          child: Text(_navidrome),
        ),
        m3e_core.M3ESplitButtonItem<String>(value: _lx, child: Text(_lx)),
      ],
      onPressed: () {},
      onSelected: (String value) {
        setState(() => _selected = value);
      },
    );
  }
}

class _LibrarySegment {
  const _LibrarySegment({
    required this.icon,
    required this.title,
    required this.supportingText,
    required this.childText,
    required this.routeName,
    this.page,
  });

  final IconData icon;
  final String title;
  final String supportingText;
  final String childText;
  final String routeName;
  final Widget? page;
}

class _LibrarySegmentedList extends StatefulWidget {
  const _LibrarySegmentedList({required this.segments, required this.onOpen});

  final List<_LibrarySegment> segments;
  final ValueChanged<_LibrarySegment> onOpen;

  @override
  State<_LibrarySegmentedList> createState() => _LibrarySegmentedListState();
}

class _LibrarySegmentedListState extends State<_LibrarySegmentedList> {
  final Set<int> _expanded = <int>{};

  void _toggle(int index) {
    setState(() {
      if (!_expanded.remove(index)) {
        _expanded.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        for (var index = 0; index < widget.segments.length; index++)
          m3e_core.M3EExpandableSegmentedItem(
            index: index,
            totalCount: widget.segments.length,
            isExpanded: _expanded.contains(index),
            outerRadius: 24,
            innerRadius: 4,
            gap: 2,
            selectedRadius: 28,
            color: scheme.secondaryContainer,
            childColor: scheme.surfaceContainer,
            selectedColor: scheme.secondaryContainer,
            trailingPillColor: scheme.surfaceContainerHighest,
            onToggle: () => _toggle(index),
            onChildTap: (_) => widget.onOpen(widget.segments[index]),
            header: m3e_core.M3EListItem(
              leading: Icon(
                widget.segments[index].icon,
                color: scheme.onSecondaryContainer,
              ),
              headline: Text(
                widget.segments[index].title,
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              supportingText: Text(
                widget.segments[index].supportingText,
                style: TextStyle(
                  color: scheme.onSecondaryContainer.withValues(alpha: 0.78),
                ),
              ),
            ),
            children: <Widget>[
              m3e_core.M3EListItem(
                leading: Icon(widget.segments[index].icon),
                headline: Text(widget.segments[index].childText),
                enabled: widget.segments[index].page != null,
              ),
            ],
          ),
      ],
    );
  }
}
