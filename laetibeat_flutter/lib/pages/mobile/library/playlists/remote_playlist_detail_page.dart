import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/playlist_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';
import '../widgets/library_source_badge.dart';
import 'playlist_dialogs.dart';

class RemotePlaylistDetailPage extends ConsumerWidget {
  const RemotePlaylistDetailPage({
    super.key,
    required this.sourceId,
    required this.playlist,
  });

  final String sourceId;
  final rust_subsonic.UiRemotePlaylist playlist;

  RemotePlaylistKey get _key => (sourceId: sourceId, playlistId: playlist.id);

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    rust_subsonic.UiRemotePlaylist current,
  ) async {
    final name = await showPlaylistNameDialog(
      context,
      initialName: current.name,
      title: AppLocalizations.of(context).playlistRename,
    );
    if (name == null || !context.mounted) return;
    try {
      await rust_subsonic.subsonicUpdatePlaylist(
        sourceId: sourceId,
        playlistId: current.id,
        name: name,
        addSongIds: const [],
        removeIndexes: const [],
      );
      ref.invalidate(remotePlaylistDetailProvider(_key));
      ref.invalidate(remotePlaylistsProvider(sourceId));
    } catch (error) {
      if (context.mounted) _message(context, error.toString());
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    rust_subsonic.UiRemotePlaylist current,
  ) async {
    final confirmed = await showDeletePlaylistConfirm(
      context,
      name: current.name,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await rust_subsonic.subsonicDeletePlaylist(
        sourceId: sourceId,
        playlistId: current.id,
      );
      ref.invalidate(remotePlaylistsProvider(sourceId));
      if (context.mounted) Navigator.of(context).maybePop();
    } catch (error) {
      if (context.mounted) _message(context, error.toString());
    }
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    rust_subsonic.UiRemotePlaylist current,
  ) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
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
            onTap: (int index) {
              Navigator.of(sheetContext).pop();
              if (index == 0) {
                _rename(context, ref, current);
              } else {
                _delete(context, ref, current);
              }
            },
            itemBuilder: (BuildContext context, int index) {
              return M3EListItem(
                leading: Icon(index == 0 ? M3EIcons.edit : M3EIcons.delete),
                headline: index == 0 ? l10n.actionRename : l10n.actionDelete,
                showDivider: index == 0,
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final async = ref.watch(remotePlaylistDetailProvider(_key));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: mobileLargeSubpageAppBar(
        context,
        title: async.value?.playlist.name ?? playlist.name,
        variant: M3EAppBarVariant.mediumFlexible,
        actions: async.value == null
            ? const <Widget>[]
            : [
                M3EIconButton(
                  icon: const Icon(M3EIcons.more_vert),
                  tooltip: l10n.more,
                  onPressed: () =>
                      _showActions(context, ref, async.value!.playlist),
                ),
              ],
      ),
      body: async.when(
        loading: () => Center(
          child: M3ELoadingIndicator(
            color: theme.colorScheme.primary,
            containerColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        error: (Object error, StackTrace stackTrace) =>
            Center(child: Text('${l10n.loadPlaylistsFailed}\n$error')),
        data: (detail) {
          final tracks = detail.tracks
              .map((track) => remoteTrackToUiTrack(track, sourceId))
              .toList(growable: false);

          void play(int index) {
            ref
                .read(playerProvider.notifier)
                .load(tracks, index, source: detail.playlist.name);
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
            children: [
              Row(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      M3EIcons.queue_music,
                      size: 38,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.playlist.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typeScale.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const LibrarySourceBadge(
                              label: 'Subsonic',
                              remote: true,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.librarySongsCount(tracks.length),
                              style: theme.typeScale.bodyMedium.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: M3EButton.icon(
                      icon: const Icon(M3EIcons.play_arrow),
                      label: Text(l10n.playNow),
                      style: M3EButtonStyle.filled,
                      onPressed: tracks.isEmpty ? null : () => play(0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: M3EButton.icon(
                      icon: const Icon(M3EIcons.shuffle),
                      label: Text(l10n.shufflePlay),
                      style: M3EButtonStyle.tonal,
                      onPressed: tracks.isEmpty
                          ? null
                          : () => ref
                                .read(playerProvider.notifier)
                                .playShuffled(
                                  tracks,
                                  source: detail.playlist.name,
                                ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              M3EList.scrollable(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                color: theme.colorScheme.surface,
                variant: M3ECardVariant.filled,
                itemCount: tracks.length,
                onTap: play,
                itemBuilder: (BuildContext context, int index) {
                  final track = tracks[index];
                  return M3EListItem(
                    leading: _RemoteTrackCover(track: track),
                    headline: track.title,
                    supportingText: [
                      track.artist,
                      track.album,
                    ].where((value) => value.isNotEmpty).join(' · '),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LibrarySourceBadge(
                          label: 'Subsonic',
                          remote: true,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          track.duration,
                          style: theme.typeScale.labelMedium.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    swipe: M3EListItemSwipe(
                      mode: M3EListSwipeMode.dismiss,
                      edge: M3EListSwipeEdge.end,
                      onDismiss: (DismissDirection direction) async {
                        await rust_subsonic.subsonicUpdatePlaylist(
                          sourceId: sourceId,
                          playlistId: detail.playlist.id,
                          addSongIds: const [],
                          removeIndexes: [index],
                        );
                        ref.invalidate(remotePlaylistDetailProvider(_key));
                        ref.invalidate(remotePlaylistsProvider(sourceId));
                        return true;
                      },
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

void _message(BuildContext context, String text) {
  M3ESnackbar.show(context, message: text);
}

class _RemoteTrackCover extends ConsumerWidget {
  const _RemoteTrackCover({required this.track});

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
                color: scheme.tertiaryContainer,
                child: Icon(
                  M3EIcons.music_note,
                  size: 20,
                  color: scheme.onTertiaryContainer,
                ),
              ),
      ),
    );
  }
}
