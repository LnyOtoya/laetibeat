import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';
import 'package:laetibeat/widgets/settings/song_sort_settings.dart';
import 'package:laetibeat/widgets/settings/song_source_settings.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../playlists/playlist_actions.dart';

/// 歌曲分类内容。
class SongsLibraryView extends ConsumerStatefulWidget {
  const SongsLibraryView({super.key});

  @override
  ConsumerState<SongsLibraryView> createState() => _SongsLibraryViewState();
}

class _SongsLibraryViewState extends ConsumerState<SongsLibraryView> {
  static const String _allSource = '__all__';
  static const String _localSource = SongSources.local;
  static const String _subsonicSource = SongSources.subsonic;

  late String _selectedSource;
  final Set<String> _selectedTrackIds = <String>{};
  final Set<String> _dismissedTrackIds = <String>{};
  late final M3EToolbarVisibilityController _toolbarVisibilityController;
  late final M3EToolbarScrollBehavior _toolbarScrollBehavior;

  @override
  void initState() {
    super.initState();
    _selectedSource = switch (ref.read(defaultSongSourceProvider)) {
      SongSources.local => _localSource,
      SongSources.subsonic => _subsonicSource,
      _ => _allSource,
    };
    _toolbarVisibilityController = M3EToolbarVisibilityController();
    _toolbarScrollBehavior = M3EToolbarScrollBehavior.exitAlways(
      exitDirection: M3EToolbarExitDirection.top,
      controller: _toolbarVisibilityController,
    );
  }

  @override
  void dispose() {
    _toolbarVisibilityController.dispose();
    super.dispose();
  }

  void _clearSelection() {
    if (_selectedTrackIds.isEmpty) return;
    setState(_selectedTrackIds.clear);
  }

  void _toggleSelection(String trackId) {
    setState(() {
      if (!_selectedTrackIds.add(trackId)) {
        _selectedTrackIds.remove(trackId);
      }
    });
    if (_selectedTrackIds.isNotEmpty) {
      _toolbarVisibilityController.show();
    }
  }

  void _dismissTrack(String trackId) {
    setState(() {
      _dismissedTrackIds.add(trackId);
      _selectedTrackIds.remove(trackId);
    });
  }

  List<rust.UiTrack> _currentTracks() {
    final tracks = <rust.UiTrack>[];
    final includeLocal =
        _selectedSource == _allSource || _selectedSource == _localSource;
    final includeRemote =
        _selectedSource == _allSource || _selectedSource == _subsonicSource;

    if (includeLocal) {
      tracks.addAll(
        (ref.read(musicLibraryProvider).value?.tracks ?? const <rust.UiTrack>[])
            .where((track) => !_dismissedTrackIds.contains(track.id)),
      );
    }

    if (includeRemote) {
      final servers =
          ref.read(subsonicServersProvider).value ??
          const <SubsonicServerConfig>[];
      if (servers.isNotEmpty) {
        final server = servers.first;
        final remote =
            ref.read(remoteAllTracksProvider(server.id)).value ?? const [];
        tracks.addAll(
          remote
              .map((track) => remoteTrackToUiTrack(track, server.id))
              .where((track) => !_dismissedTrackIds.contains(track.id)),
        );
      }
    }

    return sortTracksByMode(tracks, ref.read(defaultSongSortProvider));
  }

  String get _playbackSourceName {
    if (_selectedSource == _allSource) {
      return AppLocalizations.of(context).libraryAllSongs;
    }
    if (_selectedSource == _localSource) {
      return AppLocalizations.of(context).librarySourceLocal;
    }
    final servers =
        ref.read(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    return servers.isEmpty ? _selectedSource : servers.first.name;
  }

  void _playTracks(List<rust.UiTrack> tracks, int index) {
    if (tracks.isEmpty) return;
    ref
        .read(playerProvider.notifier)
        .load(tracks, index, source: _playbackSourceName);
  }

  void _playRandom() {
    final tracks = _currentTracks();
    if (tracks.isEmpty) return;
    ref
        .read(playerProvider.notifier)
        .playShuffled(tracks, source: _playbackSourceName);
  }

  List<rust.UiTrack> _selectedTracksInOrder() {
    final selected = _currentTracks()
        .where((track) => _selectedTrackIds.contains(track.id))
        .toList(growable: false);
    return selected;
  }

  void _playSelectedNow() {
    final tracks = _selectedTracksInOrder();
    if (tracks.isEmpty) return;
    ref
        .read(playerProvider.notifier)
        .load(tracks, 0, source: _playbackSourceName, shuffle: false);
    _clearSelection();
  }

  void _playSelectedNext() {
    final tracks = _selectedTracksInOrder();
    if (tracks.isEmpty) return;
    ref.read(playerProvider.notifier).insertNext(tracks);
    _clearSelection();
  }

  void _selectSource(String source) {
    if (source == _selectedSource) return;
    setState(() {
      _selectedSource = source;
      _selectedTrackIds.clear();
      _dismissedTrackIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    ref.watch(defaultSongSortProvider);
    final localState = ref.watch(musicLibraryProvider).value;
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final server = servers.isEmpty ? null : servers.first;
    final selectionActive = _selectedTrackIds.isNotEmpty;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                          selected: _selectedSource == _subsonicSource,
                          onPressed: () => _selectSource(_subsonicSource),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  M3EButton.icon(
                    icon: const Icon(M3EIcons.shuffle),
                    label: Text(l10n.randomPlay),
                    style: M3EButtonStyle.filled,
                    size: M3EButtonSize.sm,
                    shape: M3EButtonShape.round,
                    onPressed: _playRandom,
                  ),
                  const Spacer(),
                  M3EButton.icon(
                    icon: const Icon(M3EIcons.sort),
                    label: Text(l10n.sortLabel),
                    style: M3EButtonStyle.tonal,
                    size: M3EButtonSize.sm,
                    shape: M3EButtonShape.round,
                    onPressed: _showSortSheet,
                  ),
                ],
              ),
            ),
            Expanded(child: _buildSongContent(theme, localState, server)),
          ],
        ),
        if (selectionActive)
          Positioned(
            top: 96,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: M3EToolbar.floating(
                colorStyle: M3EToolbarColorStyle.standard,
                axis: Axis.horizontal,
                alignment: Alignment.topCenter,
                expanded: true,
                maxInlineActions: 2,
                screenOffset: 24,
                scrollBehavior: _toolbarScrollBehavior,
                leading: M3EToolbarIconButton(
                  action: M3EToolbarAction(
                    icon: M3EIcons.close,
                    tooltip: l10n.exitSelection,
                    onPressed: _clearSelection,
                  ),
                  size: M3EIconButtonSize.sm,
                  colorStyle: M3EToolbarColorStyle.standard,
                ),
                actions: <M3EToolbarItem>[
                  M3EToolbarAction(
                    icon: M3EIcons.play_arrow,
                    tooltip: l10n.playNow,
                    onPressed: _playSelectedNow,
                  ),
                  M3EToolbarAction(
                    icon: M3EIcons.queue_play_next,
                    tooltip: l10n.playNext,
                    onPressed: _playSelectedNext,
                  ),
                  M3EToolbarAction(
                    icon: M3EIcons.playlist_add,
                    tooltip: l10n.addToPlaylist,
                    onPressed: () => showAddToPlaylistSheet(
                      context,
                      ref,
                      _selectedTracksInOrder(),
                    ),
                  ),
                  M3EToolbarWidget(
                    child: M3EIconButton(
                      variant: M3EIconButtonVariant.tonal,
                      shape: M3EIconButtonShapeVariant.round,
                      icon: const Icon(M3EIcons.favorite_border),
                      tooltip: l10n.addToFavorites,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showSortSheet() async {
    final current = ref.read(defaultSongSortProvider);
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final theme = M3ETheme.of(sheetContext);
        final scheme = theme.colorScheme;
        return SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(theme.spacing.lg),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.lg,
                theme.spacing.md,
                theme.spacing.md,
                theme.spacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(sheetContext).sortBy,
                          style: theme.typeScale.titleLarge,
                        ),
                      ),
                      M3EIconButton(
                        size: M3EIconButtonSize.xs,
                        icon: const Icon(M3EIcons.close),
                        tooltip: AppLocalizations.of(sheetContext).closeSort,
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  SizedBox(height: theme.spacing.sm),
                  M3EList.scrollable(
                    shrinkWrap: true,
                    itemCount: SongSortModes.all.length,
                    onTap: (int index) => Navigator.of(
                      sheetContext,
                    ).pop(SongSortModes.all[index]),
                    itemBuilder: (BuildContext context, int index) {
                      final mode = SongSortModes.all[index];
                      final selected = mode == current;
                      return M3EListItem(
                        selected: selected,
                        headline: mode,
                        trailing: selected
                            ? Icon(M3EIcons.check, color: scheme.primary)
                            : null,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    ref.read(defaultSongSortProvider.notifier).setMode(picked);
  }

  Widget _buildSongContent(
    M3EThemeData theme,
    MusicLibraryState? localState,
    SubsonicServerConfig? server,
  ) {
    final l10n = AppLocalizations.of(context);
    final includeLocal =
        _selectedSource == _allSource || _selectedSource == _localSource;
    final includeRemote =
        _selectedSource == _allSource || _selectedSource == _subsonicSource;

    final localTracks = includeLocal
        ? (localState?.tracks ?? const <rust.UiTrack>[])
              .where((track) => !_dismissedTrackIds.contains(track.id))
              .toList(growable: false)
        : const <rust.UiTrack>[];

    if (!includeRemote) {
      return _buildTrackList(theme, localTracks, l10n.noSongs);
    }

    if (server == null) {
      if (includeLocal) {
        return _buildTrackList(theme, localTracks, l10n.noSongs);
      }
      return Center(child: Text(l10n.configureSubsonicFirst));
    }

    final remote = ref.watch(remoteAllTracksProvider(server.id));
    return remote.when(
      loading: () {
        if (localTracks.isNotEmpty) {
          return Column(
            children: [
              M3EProgressIndicator.linear(
                value: null,
                linearSize: M3EProgressIndicatorSize.s,
                strokeWidth: 4,
                trackStrokeWidth: 4,
              ),
              Expanded(
                child: _buildTrackList(theme, localTracks, l10n.noSongs),
              ),
            ],
          );
        }
        return Center(
          child: M3ELoadingIndicator(
            color: theme.colorScheme.primary,
            containerColor: theme.colorScheme.surfaceContainerHighest,
          ),
        );
      },
      error: (Object error, StackTrace stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${l10n.loadRemoteSongsFailed}\n$error',
            textAlign: TextAlign.center,
            style: theme.typeScale.bodyMedium.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ),
      data: (remoteTracks) {
        final remoteUi = remoteTracks
            .map((track) => remoteTrackToUiTrack(track, server.id))
            .where((track) => !_dismissedTrackIds.contains(track.id));
        final tracks = <rust.UiTrack>[...localTracks, ...remoteUi];
        return _buildTrackList(
          theme,
          tracks,
          _selectedSource == _subsonicSource
              ? l10n.noRemoteSongsScan
              : l10n.noSongs,
        );
      },
    );
  }

  Widget _buildTrackList(
    M3EThemeData theme,
    List<rust.UiTrack> inputTracks,
    String emptyText,
  ) {
    final tracks = sortTracksByMode(
      inputTracks,
      ref.read(defaultSongSortProvider),
    );
    final selectionActive = _selectedTrackIds.isNotEmpty;
    final scheme = theme.colorScheme;
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return M3EToolbarScrollWrapper(
      behavior: _toolbarScrollBehavior,
      child: M3EList.scrollable(
        color: scheme.surface,
        variant: M3ECardVariant.filled,
        itemCount: tracks.length,
        listPadding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        emptyBuilder: Center(child: Text(emptyText)),
        colorBuilder: (int index) {
          return _selectedTrackIds.contains(tracks[index].id)
              ? scheme.secondaryContainer
              : scheme.surface;
        },
        borderRadiusBuilder: (int index, M3ECardPosition position) {
          return _selectedTrackIds.contains(tracks[index].id)
              ? BorderRadius.circular(16)
              : null;
        },
        itemBuilder: (BuildContext context, int index) {
          final track = tracks[index];
          final selected = _selectedTrackIds.contains(track.id);

          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: () => _toggleSelection(track.id),
                onTap: selectionActive
                    ? () => _toggleSelection(track.id)
                    : () => _playTracks(tracks, index),
                child: M3EListItem(
                  selected: selected,
                  headline: track.title,
                  supportingText: track.artist,
                  leading: _TrackCover(track: track),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SourcePill(
                        label: track.source == 'opensubsonic'
                            ? 'Subsonic'
                            : AppLocalizations.of(context).librarySourceLocal,
                        remote: track.source == 'opensubsonic',
                      ),
                      const SizedBox(width: 8),
                      Text(
                        track.duration,
                        style: theme.typeScale.labelMedium.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  swipe: M3EListItemSwipe(
                    mode: M3EListSwipeMode.dismiss,
                    edge: M3EListSwipeEdge.end,
                    onDismiss: (DismissDirection direction) async {
                      _dismissTrack(track.id);
                      return true;
                    },
                  ),
                ),
              ),
              if (selected)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.primary, width: 2),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.label, required this.remote});

  final String label;
  final bool remote;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final background = remote
        ? scheme.tertiaryContainer
        : scheme.secondaryContainer;
    final foreground = remote
        ? scheme.onTertiaryContainer
        : scheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: theme.typeScale.labelSmall.copyWith(color: foreground),
      ),
    );
  }
}

class _TrackCover extends ConsumerWidget {
  const _TrackCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: 40,
        child: hasArt
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  M3EIcons.music_note,
                  size: 20,
                  color: scheme.onSecondaryContainer,
                ),
              ),
      ),
    );
  }
}
