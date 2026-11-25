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
import '../artists/artist_detail_page.dart';
import '../artists/local_artist_detail_page.dart';
import '../library_source_filter.dart';
import '../widgets/library_source_badge.dart';

/// 艺术家分类内容。统一本地 + OpenSubsonic，按来源筛选。
///
/// 网格/列表状态由页面壳持有，视图只负责按给定布局渲染。
class ArtistsLibraryView extends ConsumerStatefulWidget {
  const ArtistsLibraryView({super.key, required this.isGrid});

  final bool isGrid;

  @override
  ConsumerState<ArtistsLibraryView> createState() => _ArtistsLibraryViewState();
}

class _ArtistsLibraryViewState extends ConsumerState<ArtistsLibraryView> {
  void _openEntry(_ArtistEntry entry) {
    final local = entry.local;
    if (local != null) {
      pushMobileRootPage(
        context,
        LocalArtistDetailPage(artist: local),
        name: MobileRoutes.artistDetail,
      );
      return;
    }
    final remote = entry.remote;
    if (remote != null) {
      pushMobileRootPage(
        context,
        ArtistDetailPage(sourceId: entry.sourceId, artist: remote),
        name: MobileRoutes.artistDetail,
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
        ? ref.watch(remoteArtistsProvider(server.id))
        : null;
    final remoteEntries = server == null || remoteAsync == null
        ? const <_ArtistEntry>[]
        : _remoteEntries(server.id, remoteAsync.value);

    final entries = <_ArtistEntry>[
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
              '${l10n.loadArtistsFailed}\n$error',
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

    return content;
  }

  List<_ArtistEntry> _localEntries(MusicLibraryState? state) {
    if (state == null) return const <_ArtistEntry>[];
    final tracksById = <String, rust.UiTrack>{
      for (final track in state.tracks) track.id: track,
    };
    final albumCounts = <String, int>{};
    for (final album in state.albums) {
      albumCounts[album.artist] = (albumCounts[album.artist] ?? 0) + 1;
    }
    return [
      for (final artist in state.artists)
        _ArtistEntry(
          local: artist,
          sourceId: '',
          coverTrack: tracksById[artist.coverTrackId],
          localAlbumCount: albumCounts[artist.name] ?? 0,
        ),
    ];
  }

  List<_ArtistEntry> _remoteEntries(
    String sourceId,
    List<rust_subsonic.UiRemoteArtist>? artists,
  ) {
    return [
      for (final artist in artists ?? const <rust_subsonic.UiRemoteArtist>[])
        _ArtistEntry(remote: artist, sourceId: sourceId),
    ];
  }

  Widget _buildEntriesContent(
    M3EThemeData theme,
    AppLocalizations l10n,
    List<_ArtistEntry> entries,
    double bottomInset,
  ) {
    if (entries.isEmpty) {
      return Center(child: Text(l10n.noArtists));
    }
    return widget.isGrid
        ? _buildGrid(theme, entries, bottomInset)
        : _buildList(theme, l10n, entries, bottomInset);
  }

  Widget _buildGrid(
    M3EThemeData theme,
    List<_ArtistEntry> entries,
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
                    Positioned.fill(child: _ArtistCoverForEntry(entry: entry)),
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
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typeScale.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                _formatCount(entry),
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
    List<_ArtistEntry> entries,
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
            child: _ArtistCoverForEntry(entry: entry),
          ),
          headline: entry.name,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EntryBadge(entry: entry),
              const SizedBox(width: 8),
              Text(
                _formatCount(entry),
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

  String _formatCount(_ArtistEntry entry) {
    final count = entry.albumCount;
    if (count == null || count < 0) return '--';
    return AppLocalizations.of(context).totalAlbums('$count');
  }
}

class _ArtistEntry {
  const _ArtistEntry({
    this.local,
    this.remote,
    required this.sourceId,
    this.coverTrack,
    this.localAlbumCount,
  });

  final rust.UiArtist? local;
  final rust_subsonic.UiRemoteArtist? remote;
  final String sourceId;
  final rust.UiTrack? coverTrack;
  final int? localAlbumCount;

  bool get isRemote => remote != null;
  String get name => local?.name ?? remote?.name ?? '';
  int? get albumCount => remote?.albumCount?.toInt() ?? localAlbumCount;
}

class _EntryBadge extends StatelessWidget {
  const _EntryBadge({required this.entry});

  final _ArtistEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LibrarySourceBadge(
      label: entry.isRemote ? 'Subsonic' : l10n.librarySourceLocal,
      remote: entry.isRemote,
    );
  }
}

class _ArtistCoverForEntry extends StatelessWidget {
  const _ArtistCoverForEntry({required this.entry});

  final _ArtistEntry entry;

  @override
  Widget build(BuildContext context) {
    final remote = entry.remote;
    if (remote != null) {
      return _ArtistCover(sourceId: entry.sourceId, coverId: remote.coverId);
    }
    return _LocalArtistCover(track: entry.coverTrack);
  }
}

class _ArtistCover extends ConsumerWidget {
  const _ArtistCover({required this.sourceId, required this.coverId});

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

    return ClipOval(
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
                  M3EIcons.person,
                  size: 28,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
    );
  }
}

class _LocalArtistCover extends ConsumerWidget {
  const _LocalArtistCover({required this.track});

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

    return ClipOval(
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
                  M3EIcons.person,
                  size: 28,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
    );
  }
}
