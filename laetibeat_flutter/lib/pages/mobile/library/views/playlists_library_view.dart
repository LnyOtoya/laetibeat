import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/src/rust/api/playlists.dart' as rust_playlists;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/playlist_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../playlists/local_playlist_detail_page.dart';
import '../playlists/playlist_cover.dart';
import '../playlists/playlist_dialogs.dart';
import 'package:laetibeat/widgets/player/lx_search_provider.dart';
import '../playlists/remote_playlist_detail_page.dart';
import '../widgets/library_layout_control_bar.dart';
import '../widgets/library_source_badge.dart';

/// 歌单分类内容。统一本地歌单 + OpenSubsonic 歌单。
class PlaylistsLibraryView extends ConsumerStatefulWidget {
  const PlaylistsLibraryView({super.key});

  @override
  ConsumerState<PlaylistsLibraryView> createState() =>
      _PlaylistsLibraryViewState();
}

class _PlaylistsLibraryViewState extends ConsumerState<PlaylistsLibraryView> {
  static const String _allSource = '__all__';
  static const String _localSource = 'local';
  static const String _remoteSource = 'remote';

  bool _isGrid = true;
  String _selectedSource = _allSource;

  void _openEntry(_PlaylistEntry entry) {
    final local = entry.local;
    if (local != null) {
      pushMobileRootPage(
        context,
        LocalPlaylistDetailPage(playlistId: local.id),
        name: MobileRoutes.libraryPlaylists,
      );
      return;
    }
    final remote = entry.remote;
    if (remote != null) {
      pushMobileRootPage(
        context,
        RemotePlaylistDetailPage(sourceId: entry.sourceId, playlist: remote),
        name: MobileRoutes.libraryPlaylists,
      );
    }
  }

  Future<void> _createPlaylist(SubsonicServerConfig? server) async {
    final l10n = AppLocalizations.of(context);
    var createRemote = false;
    if (server != null) {
      createRemote =
          await showModalBottomSheet<bool>(
            context: context,
            useRootNavigator: true,
            showDragHandle: true,
            builder: (BuildContext sheetContext) {
              final theme = M3ETheme.of(sheetContext);
              return SafeArea(
                top: false,
                child: M3EList(
                  itemCount: 2,
                  color: theme.colorScheme.surfaceContainerHigh,
                  variant: M3ECardVariant.filled,
                  onTap: (int index) =>
                      Navigator.of(sheetContext).pop(index == 1),
                  itemBuilder: (BuildContext context, int index) {
                    return M3EListItem(
                      leading: Icon(
                        index == 0 ? M3EIcons.phone_android : M3EIcons.cloud,
                      ),
                      headline: index == 0
                          ? l10n.playlistCreateLocal
                          : l10n.playlistCreateSubsonic,
                      showDivider: index == 0,
                    );
                  },
                ),
              );
            },
          ) ??
          false;
    }
    if (!mounted) return;
    final name = await showPlaylistNameDialog(
      context,
      title: createRemote
          ? l10n.playlistCreateSubsonic
          : l10n.playlistCreateLocal,
    );
    if (name == null || !mounted) return;
    try {
      if (createRemote && server != null) {
        await rust_subsonic.subsonicCreatePlaylist(
          sourceId: server.id,
          name: name,
          songIds: const [],
        );
        ref.invalidate(remotePlaylistsProvider(server.id));
      } else {
        await rust_playlists.createLocalPlaylist(name: name);
        ref.invalidate(localPlaylistsProvider);
      }
    } catch (error) {
      if (mounted) {
        M3ESnackbar.show(context, message: error.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final server = servers.isEmpty ? null : servers.first;
    final localAsync = ref.watch(localPlaylistsProvider);
    final includeRemote =
        (_selectedSource == _allSource || _selectedSource == _remoteSource) &&
        server != null;
    final remoteAsync = includeRemote
        ? ref.watch(remotePlaylistsProvider(server.id))
        : null;

    final localEntries = (localAsync.value ?? const [])
        .map((playlist) => _PlaylistEntry(local: playlist, sourceId: ''))
        .toList(growable: false);
    final lxSources =
        localEntries.map(_lxSourceOf).whereType<String>().toSet().toList()
          ..sort();
    final remoteEntries =
        remoteAsync?.value
            ?.map(
              (playlist) =>
                  _PlaylistEntry(remote: playlist, sourceId: server!.id),
            )
            .toList(growable: false) ??
        const <_PlaylistEntry>[];

    final filteredLocal = switch (_selectedSource) {
      _ when _selectedSource == _allSource => localEntries,
      _ when _selectedSource == _localSource =>
        localEntries
            .where((entry) => _lxSourceOf(entry) == null)
            .toList(growable: false),
      _ when _selectedSource == _remoteSource => const <_PlaylistEntry>[],
      _ when _selectedSource.startsWith('lx:') =>
        localEntries
            .where(
              (entry) =>
                  _lxSourceOf(entry) == _selectedSource.substring('lx:'.length),
            )
            .toList(growable: false),
      _ => const <_PlaylistEntry>[],
    };
    final entries = <_PlaylistEntry>[
      ...filteredLocal,
      if ((_selectedSource == _allSource || _selectedSource == _remoteSource) &&
          server != null)
        ...remoteEntries,
    ];

    Widget content;
    if (!includeRemote) {
      content = _buildContent(theme, l10n, entries, bottomInset);
    } else if (remoteAsync!.hasError && entries.isEmpty) {
      content = Center(
        child: Text(
          '${l10n.loadPlaylistsFailed}\n${remoteAsync.error}',
          textAlign: TextAlign.center,
        ),
      );
    } else if (remoteAsync.isLoading && localEntries.isEmpty) {
      content = Center(
        child: M3ELoadingIndicator(
          color: theme.colorScheme.primary,
          containerColor: theme.colorScheme.surfaceContainerHighest,
        ),
      );
    } else {
      content = Column(
        children: [
          if (remoteAsync.isLoading)
            M3EProgressIndicator.linear(
              value: null,
              linearSize: M3EProgressIndicatorSize.s,
              strokeWidth: 4,
              trackStrokeWidth: 4,
            ),
          Expanded(child: _buildContent(theme, l10n, entries, bottomInset)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: M3EChipGroup(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        M3EChip(
                          type: M3EChipType.filter,
                          label: l10n.librarySourceAll,
                          selected: _selectedSource == _allSource,
                          onPressed: () => _selectSource(_allSource),
                        ),
                        const SizedBox(width: 8),
                        M3EChip(
                          type: M3EChipType.filter,
                          label: l10n.librarySourceLocal,
                          selected: _selectedSource == _localSource,
                          onPressed: () => _selectSource(_localSource),
                        ),
                        if (server != null) ...[
                          const SizedBox(width: 8),
                          M3EChip(
                            type: M3EChipType.filter,
                            label: server.name,
                            selected: _selectedSource == _remoteSource,
                            onPressed: () => _selectSource(_remoteSource),
                          ),
                        ],
                        for (final source in lxSources) ...[
                          const SizedBox(width: 8),
                          M3EChip(
                            type: M3EChipType.filter,
                            label: 'LX · ${lxPlatformLabel(l10n, source)}',
                            selected: _selectedSource == 'lx:$source',
                            onPressed: () => _selectSource('lx:$source'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              M3EIconButton(
                variant: M3EIconButtonVariant.tonal,
                shape: M3EIconButtonShapeVariant.round,
                icon: const Icon(M3EIcons.add),
                tooltip: l10n.playlistNew,
                onPressed: () => _createPlaylist(server),
              ),
            ],
          ),
        ),
        LibraryLayoutControlBar(
          isGrid: _isGrid,
          onToggleLayout: () => setState(() => _isGrid = !_isGrid),
        ),
        Expanded(child: content),
      ],
    );
  }

  String? _lxSourceOf(_PlaylistEntry entry) {
    final local = entry.local;
    if (local == null) return null;
    if (local.source != null) return local.source;
    if (local.coverSource == 'lx') return local.coverSourceId;
    return null;
  }

  void _selectSource(String source) {
    if (source == _selectedSource) return;
    setState(() => _selectedSource = source);
  }

  Widget _buildContent(
    M3EThemeData theme,
    AppLocalizations l10n,
    List<_PlaylistEntry> entries,
    double bottomInset,
  ) {
    if (entries.isEmpty) {
      return Center(
        child: M3ECard(
          variant: M3ECardVariant.filled,
          color: theme.colorScheme.surfaceContainerHigh,
          expanded: true,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  M3EIcons.queue_music,
                  size: 44,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(l10n.playlistEmpty, style: theme.typeScale.titleLarge),
                const SizedBox(height: 4),
                Text(
                  l10n.playlistEmptySubtitle,
                  textAlign: TextAlign.center,
                  style: theme.typeScale.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _isGrid
        ? _buildGrid(theme, l10n, entries, bottomInset)
        : _buildList(theme, l10n, entries, bottomInset);
  }

  Widget _buildGrid(
    M3EThemeData theme,
    AppLocalizations l10n,
    List<_PlaylistEntry> entries,
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
                    Positioned.fill(
                      child: _PlaylistCoverForEntry(entry: entry),
                    ),
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
                _formatSongCount(l10n, entry.itemCount),
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
    List<_PlaylistEntry> entries,
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
            child: _PlaylistCoverForEntry(entry: entry),
          ),
          headline: entry.name,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EntryBadge(entry: entry),
              const SizedBox(width: 8),
              Text(
                _formatSongCount(l10n, entry.itemCount),
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

class _PlaylistEntry {
  const _PlaylistEntry({this.local, this.remote, required this.sourceId});

  final rust_playlists.UiLocalPlaylistSummary? local;
  final rust_subsonic.UiRemotePlaylist? remote;
  final String sourceId;

  bool get isRemote => remote != null;
  String get name => local?.name ?? remote?.name ?? '';
  int? get itemCount => local?.itemCount.toInt() ?? remote?.songCount?.toInt();
}

class _EntryBadge extends StatelessWidget {
  const _EntryBadge({required this.entry});

  final _PlaylistEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final local = entry.local;
    if (local?.source != null ||
        (local?.source == null && local?.coverSource == 'lx')) {
      final platform = local!.source ?? local.coverSourceId ?? 'kw';
      return LibrarySourceBadge(
        label: 'LX · ${lxPlatformLabel(l10n, platform)}',
        remote: true,
      );
    }
    return LibrarySourceBadge(
      label: entry.isRemote ? 'Subsonic' : l10n.librarySourceLocal,
      remote: entry.isRemote,
    );
  }
}

class _PlaylistCoverForEntry extends StatelessWidget {
  const _PlaylistCoverForEntry({required this.entry});

  final _PlaylistEntry entry;

  @override
  Widget build(BuildContext context) {
    final remote = entry.remote;
    if (remote != null) {
      return _PlaylistCover(
        sourceId: entry.sourceId,
        coverId: remote.coverId,
        radius: 12,
      );
    }
    final local = entry.local;
    if (local != null) {
      return LocalPlaylistCover(playlist: local);
    }
    final theme = M3ETheme.of(context);
    return ColoredBox(
      color: theme.colorScheme.secondaryContainer,
      child: Center(
        child: Icon(
          M3EIcons.queue_music,
          size: 28,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// OpenSubsonic 歌单封面；无封面时显示占位图标。
class _PlaylistCover extends ConsumerWidget {
  const _PlaylistCover({
    required this.sourceId,
    required this.coverId,
    required this.radius,
  });

  final String sourceId;
  final String? coverId;
  final double radius;

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

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
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
                  M3EIcons.queue_music,
                  size: 28,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
    );
  }
}
