import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/playlist_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';
import 'package:laetibeat/widgets/settings/song_source_settings.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../src/rust/api/simple.dart' as rust;
import '../mobile_navigation.dart';
import '../routes.dart';
import 'library_source_filter.dart';
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

    final sourceFilter = ref.watch(librarySourceFilterProvider);
    final includeLocal =
        sourceFilter == LibrarySourceFilter.local ||
        sourceFilter == LibrarySourceFilter.all;
    final includeRemote =
        (sourceFilter == LibrarySourceFilter.navidrome ||
            sourceFilter == LibrarySourceFilter.all) &&
        server != null;

    final localTracksById = <String, rust.UiTrack>{
      for (final track in local?.tracks ?? const <rust.UiTrack>[])
        track.id: track,
    };
    final remoteTrackPreviews = includeRemote
        ? ref.watch(remoteAllTracksProvider(server.id)).value ?? const []
        : const [];
    final remoteAlbumPreviews = includeRemote
        ? ref.watch(remoteAllAlbumsProvider(server.id)).value ?? const []
        : const [];
    final remoteArtistPreviews = includeRemote
        ? ref.watch(remoteArtistsProvider(server.id)).value ?? const []
        : const [];
    final remotePlaylistPreviews = includeRemote
        ? ref.watch(remotePlaylistsProvider(server.id)).value ?? const []
        : const [];
    final localPlaylistPreviews =
        ref.watch(localPlaylistsProvider).value ?? const [];

    final songPreviews = <Widget>[
      if (includeLocal)
        for (final track in (local?.tracks ?? const <rust.UiTrack>[]).take(10))
          _PreviewCover(localTrack: track, fallbackIcon: M3EIcons.music_note),
      if (includeRemote)
        for (final track in remoteTrackPreviews.take(10))
          _PreviewCover(
            remoteSourceId: server.id,
            remoteCoverId: track.coverId,
            fallbackIcon: M3EIcons.music_note,
          ),
    ];
    final albumPreviews = <Widget>[
      if (includeLocal)
        for (final album in (local?.albums ?? const []).take(10))
          _PreviewCover(
            localTrack: localTracksById[album.coverTrackId],
            fallbackIcon: M3EIcons.album,
          ),
      if (includeRemote)
        for (final album in remoteAlbumPreviews.take(10))
          _PreviewCover(
            remoteSourceId: server.id,
            remoteCoverId: album.coverId,
            fallbackIcon: M3EIcons.album,
          ),
    ];
    final artistPreviews = <Widget>[
      if (includeLocal)
        for (final artist in (local?.artists ?? const []).take(10))
          _PreviewCover(
            localTrack: localTracksById[artist.coverTrackId],
            fallbackIcon: M3EIcons.person,
          ),
      if (includeRemote)
        for (final artist in remoteArtistPreviews.take(10))
          _PreviewCover(
            remoteSourceId: server.id,
            remoteCoverId: artist.coverId,
            fallbackIcon: M3EIcons.person,
          ),
    ];
    final playlistPreviews = <Widget>[
      if (includeLocal)
        for (final playlist in localPlaylistPreviews.take(10))
          _PreviewCover(
            localTrack: playlist.coverSource == 'local'
                ? localTracksById[playlist.coverTrackId]
                : null,
            remoteSourceId: playlist.coverSource == 'lx'
                ? null
                : playlist.coverSourceId,
            remoteCoverId: playlist.coverSource == 'lx'
                ? null
                : playlist.coverId,
            fallbackIcon: M3EIcons.queue_music,
          ),
      if (includeRemote)
        for (final playlist in remotePlaylistPreviews.take(10))
          _PreviewCover(
            remoteSourceId: server.id,
            remoteCoverId: playlist.coverId,
            fallbackIcon: M3EIcons.queue_music,
          ),
    ];

    return AppScaffold(
      background: AppSurfaceLevel.base,
      safeArea: false,
      appBar: M3EAppBar.top(
        backgroundColor: AppSurfaceLevel.base.resolve(scheme),
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
                previews: songPreviews,
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
                previews: albumPreviews,
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
                previews: artistPreviews,
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
                previews: playlistPreviews,
                routeName: MobileRoutes.libraryPlaylists,
                page: const MobileLibraryPlaylistsPage(),
              ),
              _LibrarySegment(
                icon: M3EIcons.radio,
                title: '电台',
                supportingText: '暂无',
                previews: const <Widget>[],
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

class _LibrarySourceSplitButton extends ConsumerWidget {
  const _LibrarySourceSplitButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(defaultSongSourceProvider);

    return m3e_core.M3ESplitButton<String>(
      style: m3e_core.M3EButtonStyle.tonal,
      size: m3e_core.M3EButtonSize.md,
      shape: m3e_core.M3EButtonShape.round,
      label: _labelForSongSource(source),
      selectedValue: source,
      leadingTooltip: '当前来源',
      trailingTooltip: '选择来源',
      decoration: m3e_core.M3ESplitButtonDecoration.styleFrom(),
      items: <m3e_core.M3ESplitButtonItem<String>>[
        for (final value in SongSources.all)
          m3e_core.M3ESplitButtonItem<String>(
            value: value,
            child: Text(_labelForSongSource(value)),
          ),
      ],
      onPressed: () {},
      onSelected: (String value) {
        ref.read(defaultSongSourceProvider.notifier).setSource(value);
      },
    );
  }
}

String _labelForSongSource(String source) {
  return switch (source) {
    SongSources.local => '本地',
    SongSources.subsonic => 'Navidrome',
    SongSources.lx => '洛雪',
    _ => '全部',
  };
}

class _LibrarySegment {
  const _LibrarySegment({
    required this.icon,
    required this.title,
    required this.supportingText,
    required this.previews,
    required this.routeName,
    this.page,
  });

  final IconData icon;
  final String title;
  final String supportingText;
  final List<Widget> previews;
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
            onToggle: () => _toggle(index),
            onChildTap: (_) => _toggle(index),
            header: m3e_core.M3EListItem(
              leading: Icon(widget.segments[index].icon),
              headline: Text(
                widget.segments[index].title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              supportingText: Text(widget.segments[index].supportingText),
            ),
            childPadding: EdgeInsets.zero,
            children: <Widget>[
              _SegmentPreviewRow(
                previews: widget.segments[index].previews,
                onBrowse: () => widget.onOpen(widget.segments[index]),
              ),
            ],
          ),
      ],
    );
  }
}

class _SegmentPreviewRow extends StatelessWidget {
  const _SegmentPreviewRow({required this.previews, required this.onBrowse});

  final List<Widget> previews;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    const double size = 64;
    const double gap = 8;
    const double horizontalPadding = 16;
    const double buttonWidth = 52;

    final browseButton = m3e_core.M3EButton(
      style: m3e_core.M3EButtonStyle.tonal,
      size: m3e_core.M3EButtonSize.custom(
        height: 48,
        hPadding: 16,
        iconSize: 20,
        iconGap: 8,
      ),
      shape: m3e_core.M3EButtonShape.round,
      onPressed: onBrowse,
      decoration: m3e_core.M3EButtonDecoration.styleFrom(
        haptic: m3e_core.M3EHapticFeedback.light,
      ),
      semanticLabel: '浏览全部',
      child: const Icon(M3EIcons.arrow_forward),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 8,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final available = constraints.maxWidth;
          final count = previews.isEmpty
              ? 0
              : ((available - buttonWidth - gap) / (size + gap)).floor().clamp(
                  1,
                  previews.length,
                );

          return Row(
            children: <Widget>[
              if (count == 0)
                Expanded(
                  child: Text(
                    '暂无内容',
                    style: M3ETheme.of(context).typeScale.bodyMedium.copyWith(
                      color: M3ETheme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (var index = 0; index < count; index++) ...<Widget>[
                  previews[index],
                  const SizedBox(width: gap),
                ],
              browseButton,
            ],
          );
        },
      ),
    );
  }
}

class _PreviewCover extends ConsumerWidget {
  const _PreviewCover({
    this.localTrack,
    this.remoteSourceId,
    this.remoteCoverId,
    required this.fallbackIcon,
  });

  final rust.UiTrack? localTrack;
  final String? remoteSourceId;
  final String? remoteCoverId;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final track = localTrack;
    final sourceId = remoteSourceId;
    final coverId = remoteCoverId;
    final bytes = track != null
        ? ref.watch(trackCoverProvider(track)).value
        : sourceId != null && coverId != null && coverId.isNotEmpty
        ? ref
              .watch(
                remoteCoverProvider((sourceId: sourceId, coverId: coverId)),
              )
              .value
        : null;

    return M3EShapeContainer.square(
      width: 64,
      height: 64,
      color: scheme.secondaryContainer,
      child: bytes == null || bytes.isEmpty
          ? Center(
              child: Icon(
                fallbackIcon,
                size: AppIconSize.lg,
                color: scheme.onSecondaryContainer,
              ),
            )
          : SizedBox.expand(
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
    );
  }
}
