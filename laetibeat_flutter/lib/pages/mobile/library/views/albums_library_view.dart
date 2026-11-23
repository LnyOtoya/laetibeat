import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../albums/album_detail_page.dart';
import '../albums/local_album_detail_page.dart';
import '../library_source_filter.dart';
import '../widgets/library_layout_control_bar.dart';
import '../widgets/library_source_badge.dart';

/// 专辑分类内容。统一本地 + OpenSubsonic，按来源筛选。
class AlbumsLibraryView extends ConsumerStatefulWidget {
  const AlbumsLibraryView({super.key});

  @override
  ConsumerState<AlbumsLibraryView> createState() => _AlbumsLibraryViewState();
}

class _AlbumsLibraryViewState extends ConsumerState<AlbumsLibraryView> {
  bool _isGrid = true;

  void _openEntry(_AlbumEntry entry) {
    final local = entry.local;
    if (local != null) {
      pushMobileRootPage(
        context,
        LocalAlbumDetailPage(album: local),
        name: MobileRoutes.albumDetail,
      );
      return;
    }
    final remote = entry.remote;
    if (remote != null) {
      pushMobileRootPage(
        context,
        AlbumDetailPage(sourceId: entry.sourceId, album: remote),
        name: MobileRoutes.albumDetail,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final localState = ref.watch(musicLibraryProvider).value;
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final server = servers.isEmpty ? null : servers.first;
    final filter = ref.watch(librarySourceFilterProvider);
    final includeRemote =
        (filter == LibrarySourceFilter.navidrome ||
            filter == LibrarySourceFilter.all) &&
        server != null;

    final localEntries = _localEntries(localState);
    final remoteAsync = includeRemote
        ? ref.watch(remoteAllAlbumsProvider(server.id))
        : null;
    final remoteEntries = server == null || remoteAsync == null
        ? const <_AlbumEntry>[]
        : _remoteEntries(server.id, remoteAsync.value);

    final entries = <_AlbumEntry>[
      if (filter == LibrarySourceFilter.local ||
          filter == LibrarySourceFilter.all)
        ...localEntries,
      if ((filter == LibrarySourceFilter.navidrome ||
              filter == LibrarySourceFilter.all) &&
          server != null)
        ...remoteEntries,
    ];

    Widget content;
    if (server == null || remoteAsync == null) {
      content = _buildEntriesContent(theme, l10n, entries, bottomInset);
    } else {
      content = remoteAsync.when(
        loading: () {
          if (localEntries.isEmpty) {
            return Center(
              child: M3ELoadingIndicator(
                color: theme.colorScheme.primary,
                containerColor: theme.colorScheme.surfaceContainerHighest,
              ),
            );
          }
          return Column(
            children: [
              M3EProgressIndicator.linear(
                value: null,
                linearSize: M3EProgressIndicatorSize.s,
                strokeWidth: 4,
                trackStrokeWidth: 4,
              ),
              Expanded(
                child: _buildEntriesContent(theme, l10n, entries, bottomInset),
              ),
            ],
          );
        },
        error: (Object error, StackTrace stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '${l10n.loadAlbumsFailed}\n$error',
              textAlign: TextAlign.center,
              style: theme.typeScale.bodyMedium.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ),
        data: (_) => _buildEntriesContent(theme, l10n, entries, bottomInset),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LibraryLayoutControlBar(
          isGrid: _isGrid,
          onToggleLayout: () => setState(() => _isGrid = !_isGrid),
        ),
        Expanded(child: content),
      ],
    );
  }

  List<_AlbumEntry> _localEntries(MusicLibraryState? state) {
    if (state == null) return const <_AlbumEntry>[];
    final tracksById = <String, rust.UiTrack>{
      for (final track in state.tracks) track.id: track,
    };
    return [
      for (final album in state.albums)
        _AlbumEntry(
          local: album,
          sourceId: '',
          coverTrack: tracksById[album.coverTrackId],
        ),
    ];
  }

  List<_AlbumEntry> _remoteEntries(
    String sourceId,
    List<rust_subsonic.UiRemoteAlbum>? albums,
  ) {
    return [
      for (final album in albums ?? const <rust_subsonic.UiRemoteAlbum>[])
        _AlbumEntry(remote: album, sourceId: sourceId),
    ];
  }

  Widget _buildEntriesContent(
    M3EThemeData theme,
    AppLocalizations l10n,
    List<_AlbumEntry> entries,
    double bottomInset,
  ) {
    if (entries.isEmpty) {
      return Center(child: Text(l10n.noAlbums));
    }
    return _isGrid
        ? _buildGrid(theme, entries, bottomInset)
        : _buildList(theme, l10n, entries, bottomInset);
  }

  Widget _buildGrid(
    M3EThemeData theme,
    List<_AlbumEntry> entries,
    double bottomInset,
  ) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) {
        final entry = entries[index];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openEntry(entry),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    Positioned.fill(child: _AlbumCoverForEntry(entry: entry)),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _EntryBadge(entry: entry),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typeScale.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                entry.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typeScale.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(
    M3EThemeData theme,
    AppLocalizations l10n,
    List<_AlbumEntry> entries,
    double bottomInset,
  ) {
    return M3EList.scrollable(
      color: theme.colorScheme.surface,
      variant: M3ECardVariant.filled,
      itemCount: entries.length,
      onTap: (int index) => _openEntry(entries[index]),
      listPadding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      itemBuilder: (BuildContext context, int index) {
        final entry = entries[index];
        return M3EListItem(
          leading: SizedBox.square(
            dimension: 40,
            child: _AlbumCoverForEntry(entry: entry),
          ),
          headline: entry.title,
          supportingText: entry.artist,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EntryBadge(entry: entry),
              const SizedBox(width: 8),
              Text(
                _formatSongCount(l10n, entry.trackCount),
                style: theme.typeScale.labelMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatSongCount(AppLocalizations l10n, int? count) {
    if (count == null || count < 0) return '--';
    return l10n.librarySongsCount(count);
  }
}

class _AlbumEntry {
  const _AlbumEntry({
    this.local,
    this.remote,
    required this.sourceId,
    this.coverTrack,
  });

  final rust.UiAlbum? local;
  final rust_subsonic.UiRemoteAlbum? remote;
  final String sourceId;
  final rust.UiTrack? coverTrack;

  bool get isRemote => remote != null;
  String get title => local?.title ?? remote?.title ?? '';
  String get artist => local?.artist ?? remote?.artist ?? '';
  int? get trackCount =>
      local?.trackCount.toInt() ?? remote?.songCount?.toInt();
}

class _EntryBadge extends StatelessWidget {
  const _EntryBadge({required this.entry});

  final _AlbumEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LibrarySourceBadge(
      label: entry.isRemote ? 'Subsonic' : l10n.librarySourceLocal,
      remote: entry.isRemote,
    );
  }
}

class _AlbumCoverForEntry extends StatelessWidget {
  const _AlbumCoverForEntry({required this.entry});

  final _AlbumEntry entry;

  @override
  Widget build(BuildContext context) {
    final remote = entry.remote;
    if (remote != null) {
      return _AlbumCover(sourceId: entry.sourceId, coverId: remote.coverId);
    }
    return _LocalAlbumCover(track: entry.coverTrack);
  }
}

class _AlbumCover extends ConsumerWidget {
  const _AlbumCover({required this.sourceId, required this.coverId});

  final String sourceId;
  final String? coverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final id = coverId;
    final bytes = id == null || id.isEmpty
        ? null
        : ref
              .watch(remoteCoverProvider((sourceId: sourceId, coverId: id)))
              .value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return M3EShapeContainer.cookie12Sided(
      child: hasArt
          ? Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            )
          : ColoredBox(
              color: theme.colorScheme.secondaryContainer,
              child: Center(
                child: Icon(
                  M3EIcons.album,
                  size: 28,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
    );
  }
}

class _LocalAlbumCover extends ConsumerWidget {
  const _LocalAlbumCover({required this.track});

  final rust.UiTrack? track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final track = this.track;
    final bytes = track == null
        ? null
        : ref.watch(trackCoverProvider(track)).value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return M3EShapeContainer.cookie12Sided(
      child: hasArt
          ? Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            )
          : ColoredBox(
              color: scheme.secondaryContainer,
              child: Center(
                child: Icon(
                  M3EIcons.album,
                  size: 28,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
    );
  }
}
