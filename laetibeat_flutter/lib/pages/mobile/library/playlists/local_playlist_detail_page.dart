import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:laetibeat/src/rust/api/lx.dart' as rust_lx;
import 'package:laetibeat/src/rust/api/playlists.dart' as rust_playlists;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/lx_search_provider.dart';
import 'package:laetibeat/widgets/player/lx_track.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/playlist_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';
import '../widgets/library_source_badge.dart';
import 'playlist_cover.dart';
import 'playlist_dialogs.dart';

class LocalPlaylistDetailPage extends ConsumerWidget {
  const LocalPlaylistDetailPage({super.key, required this.playlistId});

  final int playlistId;

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    rust_playlists.UiLocalPlaylistSummary playlist,
  ) async {
    final name = await showPlaylistNameDialog(
      context,
      initialName: playlist.name,
      title: AppLocalizations.of(context).playlistRename,
    );
    if (name == null || !context.mounted) return;
    try {
      await rust_playlists.renameLocalPlaylist(id: playlistId, name: name);
      ref.invalidate(localPlaylistDetailProvider(playlistId));
      ref.invalidate(localPlaylistsProvider);
    } catch (error) {
      if (context.mounted) _message(context, error.toString());
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    rust_playlists.UiLocalPlaylistSummary playlist,
  ) async {
    final confirmed = await showDeletePlaylistConfirm(
      context,
      name: playlist.name,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await rust_playlists.deleteLocalPlaylist(id: playlistId);
      ref.invalidate(localPlaylistsProvider);
      if (context.mounted) Navigator.of(context).maybePop();
    } catch (error) {
      if (context.mounted) _message(context, error.toString());
    }
  }

  Future<void> _sync(
    BuildContext context,
    WidgetRef ref,
    rust_playlists.UiLocalPlaylistSummary playlist,
  ) async {
    final source = playlist.source;
    final sourceListId = playlist.sourceListId;
    if (source == null || sourceListId == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await M3EDialog.show<bool>(
      context,
      dialog: M3EDialog(
        title: l10n.playlistSync,
        icon: const Icon(M3EIcons.sync),
        content: Text(l10n.playlistSyncConfirm),
        actions: <Widget>[
          M3EButton(
            label: Text(l10n.actionCancel),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          M3EButton(
            label: Text(l10n.playlistSync),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final detail = await rust_lx.getLxPlaylistAll(
        platform: source,
        playlistId: sourceListId,
      );
      final inputs = detail.tracks
          .map(lxSearchTrackToUiTrack)
          .map(playlistTrackInputFromTrack)
          .toList(growable: false);
      await rust_playlists.replaceLocalPlaylistTracks(
        playlistId: playlistId,
        tracks: inputs,
      );
      ref.invalidate(localPlaylistDetailProvider(playlistId));
      ref.invalidate(localPlaylistsProvider);
      if (context.mounted) _message(context, l10n.playlistSyncSuccess);
    } catch (error) {
      if (context.mounted) _message(context, error.toString());
    }
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    rust_playlists.UiLocalPlaylistSummary playlist,
  ) async {
    final l10n = AppLocalizations.of(context);
    final canSync = playlist.source != null && playlist.sourceListId != null;
    final actions = <String>[
      l10n.actionRename,
      if (canSync) l10n.playlistSync,
      l10n.actionDelete,
    ];
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final theme = M3ETheme.of(sheetContext);
        return SafeArea(
          top: false,
          child: M3EList(
            itemCount: actions.length,
            color: theme.colorScheme.surfaceContainerHigh,
            variant: M3ECardVariant.filled,
            onTap: (int index) {
              Navigator.of(sheetContext).pop();
              if (index == 0) {
                _rename(context, ref, playlist);
              } else if (canSync && index == 1) {
                _sync(context, ref, playlist);
              } else {
                _delete(context, ref, playlist);
              }
            },
            itemBuilder: (BuildContext context, int index) {
              final isDelete = index == actions.length - 1;
              final isSync = canSync && index == 1;
              return M3EListItem(
                leading: Icon(
                  isDelete
                      ? M3EIcons.delete
                      : isSync
                      ? M3EIcons.sync
                      : M3EIcons.edit,
                ),
                headline: actions[index],
                showDivider: index < actions.length - 1,
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
    final detailAsync = ref.watch(localPlaylistDetailProvider(playlistId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileLargeSubpageAppBar(
        context,
        title: detailAsync.value?.playlist.name ?? l10n.libraryPlaylists,
        variant: M3EAppBarVariant.mediumFlexible,
        actions: detailAsync.value == null
            ? const <Widget>[]
            : [
                M3EIconButton(
                  icon: const Icon(M3EIcons.more_vert),
                  tooltip: l10n.more,
                  onPressed: () =>
                      _showActions(context, ref, detailAsync.value!.playlist),
                ),
              ],
      ),
      body: detailAsync.when(
        loading: () => Center(
          child: M3ELoadingIndicator(
            color: theme.colorScheme.primary,
            containerColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        error: (Object error, StackTrace stackTrace) =>
            Center(child: Text('${l10n.loadPlaylistsFailed}\n$error')),
        data: (detail) {
          if (detail == null) {
            return Center(child: Text(l10n.playlistEmpty));
          }
          final resolved = resolveLocalPlaylistTracks(ref, detail);
          final playable = <rust.UiTrack>[];
          final playableIndexByItem = <int, int>{};
          for (var index = 0; index < resolved.length; index += 1) {
            final track = resolved[index];
            if (track != null) {
              playableIndexByItem[index] = playable.length;
              playable.add(track);
            }
          }

          void playItem(int itemIndex) {
            final playIndex = playableIndexByItem[itemIndex];
            if (playIndex == null) {
              _message(context, l10n.sourceUnavailable);
              return;
            }
            ref
                .read(playerProvider.notifier)
                .load(playable, playIndex, source: detail.playlist.name);
          }

          return RefreshIndicator(
            onRefresh: () => _sync(context, ref, detail.playlist),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: LocalPlaylistCover(
                        playlist: detail.playlist,
                        radius: 20,
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
                              LibrarySourceBadge(
                                label:
                                    detail.playlist.source != null ||
                                        detail.playlist.coverSource == 'lx'
                                    ? 'LX · ${lxPlatformLabel(l10n, detail.playlist.source ?? detail.playlist.coverSourceId ?? 'kw')}'
                                    : l10n.librarySourceLocal,
                                remote:
                                    detail.playlist.source != null ||
                                    detail.playlist.coverSource == 'lx',
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.librarySongsCount(
                                  detail.playlist.itemCount.toInt(),
                                ),
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
                        onPressed: playable.isEmpty
                            ? null
                            : () => ref
                                  .read(playerProvider.notifier)
                                  .load(
                                    playable,
                                    0,
                                    source: detail.playlist.name,
                                  ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: M3EButton.icon(
                        icon: const Icon(M3EIcons.shuffle),
                        label: Text(l10n.shufflePlay),
                        style: M3EButtonStyle.tonal,
                        onPressed: playable.isEmpty
                            ? null
                            : () => ref
                                  .read(playerProvider.notifier)
                                  .playShuffled(
                                    playable,
                                    source: detail.playlist.name,
                                  ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (detail.items.isEmpty)
                  M3ECard(
                    variant: M3ECardVariant.filled,
                    color: theme.colorScheme.surfaceContainerHigh,
                    expanded: true,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            M3EIcons.queue_music,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.playlistNoTracks,
                            style: theme.typeScale.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  M3EList.scrollable(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    color: theme.colorScheme.surface,
                    variant: M3ECardVariant.filled,
                    itemCount: detail.items.length,
                    reorder: true,
                    onReorder: (int oldIndex, int newIndex) {
                      final ids = detail.items.map((item) => item.id).toList();
                      final item = ids.removeAt(oldIndex);
                      ids.insert(
                        newIndex > oldIndex ? newIndex - 1 : newIndex,
                        item,
                      );
                      rust_playlists
                          .reorderLocalPlaylistItems(
                            playlistId: playlistId,
                            itemIds: Int64List.fromList(ids),
                          )
                          .then((_) {
                            ref.invalidate(
                              localPlaylistDetailProvider(playlistId),
                            );
                            ref.invalidate(localPlaylistsProvider);
                          })
                          .catchError((Object error) {
                            if (context.mounted) {
                              _message(context, error.toString());
                            }
                          });
                    },
                    onTap: playItem,
                    itemBuilder: (BuildContext context, int index) {
                      final item = detail.items[index];
                      final track = resolved[index];
                      return M3EListItem(
                        leading: _PlaylistTrackCover(track: track),
                        headline: item.title,
                        supportingText: [
                          item.artist,
                          item.album,
                        ].where((value) => value.isNotEmpty).join(' · '),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LibrarySourceBadge(
                              label: item.source == 'local'
                                  ? l10n.librarySourceLocal
                                  : item.source == 'lx'
                                  ? 'LX · ${lxPlatformLabel(l10n, item.sourceId)}'
                                  : 'Subsonic',
                              remote: item.source != 'local',
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(item.durationSeconds.toInt()),
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
                            await rust_playlists.removeLocalPlaylistItem(
                              playlistId: playlistId,
                              itemId: item.id,
                            );
                            ref.invalidate(
                              localPlaylistDetailProvider(playlistId),
                            );
                            ref.invalidate(localPlaylistsProvider);
                            return true;
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void _message(BuildContext context, String text) {
  M3ESnackbar.show(context, message: text);
}

String _formatDuration(int seconds) {
  if (seconds <= 0) return '--';
  final minutes = seconds ~/ 60;
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _PlaylistTrackCover extends ConsumerWidget {
  const _PlaylistTrackCover({required this.track});

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
