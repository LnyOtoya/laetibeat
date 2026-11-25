import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';
import 'package:laetibeat/widgets/settings/song_sort_settings.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../library_source_filter.dart';
import '../playlists/playlist_actions.dart';

/// 歌曲分类内容。
class SongsLibraryView extends ConsumerStatefulWidget {
  const SongsLibraryView({super.key});

  @override
  ConsumerState<SongsLibraryView> createState() => _SongsLibraryViewState();
}

class _SongsLibraryViewState extends ConsumerState<SongsLibraryView> {
  final Set<String> _selectedTrackIds = <String>{};
  final ScrollController _scrollController = ScrollController();
  late final M3EToolbarVisibilityController _toolbarVisibilityController;
  late final M3EToolbarScrollBehavior _toolbarScrollBehavior;

  @override
  void initState() {
    super.initState();
    _toolbarVisibilityController = M3EToolbarVisibilityController();
    _toolbarScrollBehavior = M3EToolbarScrollBehavior.exitAlways(
      exitDirection: M3EToolbarExitDirection.top,
      controller: _toolbarVisibilityController,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _toolbarVisibilityController.dispose();
    super.dispose();
  }

  void _clearSelection() {
    if (_selectedTrackIds.isEmpty) return;
    setState(_selectedTrackIds.clear);
  }

  List<rust.UiTrack> _currentTracks() {
    final tracks = <rust.UiTrack>[];
    final filter = ref.read(librarySourceFilterProvider);
    final includeLocal =
        filter == LibrarySourceFilter.local ||
        filter == LibrarySourceFilter.all;
    final includeRemote =
        filter == LibrarySourceFilter.navidrome ||
        filter == LibrarySourceFilter.all;

    if (includeLocal) {
      tracks.addAll(
        ref.read(musicLibraryProvider).value?.tracks ?? const <rust.UiTrack>[],
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
          remote.map((track) => remoteTrackToUiTrack(track, server.id)),
        );
      }
    }

    return sortTracksByMode(tracks, ref.read(defaultSongSortProvider));
  }

  String get _playbackSourceName {
    final filter = ref.read(librarySourceFilterProvider);
    if (filter == LibrarySourceFilter.all) {
      return AppLocalizations.of(context).libraryAllSongs;
    }
    if (filter == LibrarySourceFilter.local) {
      return AppLocalizations.of(context).librarySourceLocal;
    }
    if (filter == LibrarySourceFilter.lx) {
      return AppLocalizations.of(context).librarySourceLx;
    }
    final servers =
        ref.read(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    return servers.isEmpty ? 'Navidrome' : servers.first.name;
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

  Widget _buildSongContent(
    M3EThemeData theme,
    MusicLibraryState? localState,
    SubsonicServerConfig? server,
  ) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(librarySourceFilterProvider);
    final includeLocal =
        filter == LibrarySourceFilter.local ||
        filter == LibrarySourceFilter.all;
    final includeRemote =
        filter == LibrarySourceFilter.navidrome ||
        filter == LibrarySourceFilter.all;

    final localTracks = includeLocal
        ? (localState?.tracks ?? const <rust.UiTrack>[])
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
        final remoteUi = remoteTracks.map(
          (track) => remoteTrackToUiTrack(track, server.id),
        );
        final tracks = <rust.UiTrack>[...localTracks, ...remoteUi];
        return _buildTrackList(
          theme,
          tracks,
          filter == LibrarySourceFilter.navidrome
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
    final selectedIndices = <int>{
      for (var index = 0; index < tracks.length; index++)
        if (_selectedTrackIds.contains(tracks[index].id)) index,
    };

    return M3EToolbarScrollWrapper(
      behavior: _toolbarScrollBehavior,
      child: m3e_core.M3ESegmentedList.builder(
        controller: _scrollController,
        itemCount: tracks.length,
        selectionMode: m3e_core.M3ESelectionMode.multiple,
        // First gesture must be a long press. Once selection exists, ordinary
        // taps toggle more items without requiring another long press.
        selectionTrigger: selectionActive
            ? m3e_core.M3ESelectionTrigger.tap
            : m3e_core.M3ESelectionTrigger.longPress,
        selectedIndices: selectedIndices,
        onSelectionChanged: (indices) {
          setState(() {
            _selectedTrackIds
              ..clear()
              ..addAll(<String>[for (final index in indices) tracks[index].id]);
          });
          if (_selectedTrackIds.isNotEmpty) {
            _toolbarVisibilityController.show();
          }
        },
        onTap: (index) {
          if (!selectionActive) {
            _playTracks(tracks, index);
          }
        },
        emptyBuilder: Center(child: Text(emptyText)),
        listPadding: EdgeInsets.only(bottom: bottomInset),
        decoration: const m3e_core.M3ESegmentedListDecoration(
          outerRadius: 24,
          innerRadius: 16,
          pressedRadius: 8,
          pressedScale: 0.98,
          hoveredRadius: 16,
          selectedRadius: 28,
          gap: 6,
          padding: EdgeInsets.all(4),
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        ),
        itemBuilder: (BuildContext context, int index) {
          final track = tracks[index];
          return m3e_core.M3EListItem(
            headline: Text(track.title),
            supportingText: Text(track.artist),
            leading: _TrackCover(track: track),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
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
