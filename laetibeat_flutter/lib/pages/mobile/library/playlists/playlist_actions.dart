import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/playlists.dart' as rust_playlists;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:laetibeat/widgets/playlist_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../widgets/library_source_badge.dart';
import 'playlist_dialogs.dart';

/// 把当前选中的曲目加入本地或同服务器的 Subsonic 歌单。
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  List<rust.UiTrack> tracks,
) async {
  if (tracks.isEmpty) return;
  final l10n = AppLocalizations.of(context);
  final localPlaylists = await ref.read(localPlaylistsProvider.future);
  if (!context.mounted) return;

  final servers =
      ref.read(subsonicServersProvider).value ?? const <SubsonicServerConfig>[];
  final server = servers.isEmpty ? null : servers.first;
  final remoteCompatible =
      server != null &&
      tracks.every(
        (track) =>
            track.source == 'opensubsonic' && track.sourceId == server.id,
      );
  final remotePlaylists = remoteCompatible
      ? await ref.read(remotePlaylistsProvider(server.id).future)
      : const <rust_subsonic.UiRemotePlaylist>[];
  if (!context.mounted) return;

  final choices = <_PlaylistChoice>[
    for (final playlist in localPlaylists)
      _PlaylistChoice(
        name: playlist.name,
        count: playlist.itemCount.toInt(),
        localId: playlist.id,
      ),
    if (server != null)
      for (final playlist in remotePlaylists)
        _PlaylistChoice(
          name: playlist.name,
          count: playlist.songCount?.toInt(),
          remoteId: playlist.id,
        ),
    const _PlaylistChoice.createLocal(),
  ];

  final choice = await showModalBottomSheet<_PlaylistChoice>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      final theme = M3ETheme.of(sheetContext);
      return SafeArea(
        top: false,
        child: M3EList(
          itemCount: choices.length,
          color: theme.colorScheme.surfaceContainerHigh,
          variant: M3ECardVariant.filled,
          onTap: (int index) => Navigator.of(sheetContext).pop(choices[index]),
          itemBuilder: (BuildContext context, int index) {
            final choice = choices[index];
            if (choice.isCreate) {
              return M3EListItem(
                leading: const Icon(M3EIcons.playlist_add),
                headline: l10n.playlistNew,
              );
            }
            return M3EListItem(
              leading: Icon(
                choice.localId != null ? M3EIcons.queue_music : M3EIcons.cloud,
              ),
              headline: choice.name,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LibrarySourceBadge(
                    label: choice.localId != null
                        ? l10n.librarySourceLocal
                        : 'Subsonic',
                    remote: choice.localId == null,
                  ),
                  if (choice.count != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      l10n.librarySongsCount(choice.count!),
                      style: theme.typeScale.labelMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              showDivider: index < choices.length - 1,
            );
          },
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return;

  final remoteId = choice.remoteId;
  if (remoteId != null && server != null) {
    try {
      await rust_subsonic.subsonicUpdatePlaylist(
        sourceId: server.id,
        playlistId: remoteId,
        addSongIds: tracks.map((track) => track.id).toList(),
        removeIndexes: const [],
      );
      ref.invalidate(remotePlaylistsProvider(server.id));
      ref.invalidate(
        remotePlaylistDetailProvider((
          sourceId: server.id,
          playlistId: remoteId,
        )),
      );
      if (context.mounted) {
        _message(context, l10n.playlistAddedCount(tracks.length));
      }
    } catch (error) {
      if (context.mounted) _message(context, error.toString());
    }
    return;
  }

  var targetId = choice.localId;
  if (choice.isCreate) {
    final name = await showPlaylistNameDialog(context);
    if (name == null || !context.mounted) return;
    try {
      final created = await rust_playlists.createLocalPlaylist(name: name);
      targetId = created.id;
    } catch (error) {
      if (context.mounted) _message(context, error.toString());
      return;
    }
  }
  if (targetId == null) return;

  try {
    final inputs = tracks.map(playlistTrackInputFromTrack).toList();
    final added = await rust_playlists.addLocalPlaylistTracks(
      playlistId: targetId,
      tracks: inputs,
    );
    ref.invalidate(localPlaylistsProvider);
    if (!context.mounted) return;
    _message(
      context,
      added == BigInt.zero
          ? l10n.playlistAlreadyContains
          : l10n.playlistAddedCount(added.toInt()),
    );
  } catch (error) {
    if (context.mounted) _message(context, error.toString());
  }
}

class _PlaylistChoice {
  const _PlaylistChoice({
    required this.name,
    this.count,
    this.localId,
    this.remoteId,
  }) : isCreate = false;

  const _PlaylistChoice.createLocal()
    : name = '',
      count = null,
      localId = null,
      remoteId = null,
      isCreate = true;

  final String name;
  final int? count;
  final int? localId;
  final String? remoteId;
  final bool isCreate;
}

void _message(BuildContext context, String text) {
  M3ESnackbar.show(context, message: text);
}
