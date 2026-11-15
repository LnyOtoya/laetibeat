import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/lx.dart' as rust_lx;
import 'package:laetibeat/src/rust/api/playlists.dart' as rust_playlists;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/lx_track.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/player/lx_search_provider.dart';
import 'package:laetibeat/widgets/playlist_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';
import '../widgets/library_source_badge.dart';

class LxPlaylistPreviewPage extends ConsumerStatefulWidget {
  const LxPlaylistPreviewPage({
    super.key,
    required this.platform,
    required this.playlist,
  });

  final String platform;
  final rust_lx.UiLxPlaylistSummary playlist;

  @override
  ConsumerState<LxPlaylistPreviewPage> createState() =>
      _LxPlaylistPreviewPageState();
}

class _LxPlaylistPreviewPageState extends ConsumerState<LxPlaylistPreviewPage> {
  bool _busy = false;

  LxPlaylistKey get _key =>
      (platform: widget.platform, playlistId: widget.playlist.id);

  Future<rust_lx.UiLxPlaylistDetail> _loadAll() {
    return rust_lx.getLxPlaylistAll(
      platform: widget.platform,
      playlistId: widget.playlist.id,
    );
  }

  List<rust_playlists.UiPlaylistTrackInput> _inputs(
    rust_lx.UiLxPlaylistDetail detail,
  ) {
    return detail.tracks
        .map(lxSearchTrackToUiTrack)
        .map(playlistTrackInputFromTrack)
        .toList(growable: false);
  }

  Future<void> _subscribe() async {
    final l10n = AppLocalizations.of(context);
    final existing = (ref.read(localPlaylistsProvider).value ?? const [])
        .where(
          (playlist) =>
              playlist.source == widget.platform &&
              playlist.sourceListId == widget.playlist.id,
        )
        .firstOrNull;
    if (existing != null) {
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
      if (confirmed != true || !mounted) return;
      setState(() => _busy = true);
      try {
        final detail = await _loadAll();
        await rust_playlists.replaceLocalPlaylistTracks(
          playlistId: existing.id,
          tracks: _inputs(detail),
        );
        ref.invalidate(localPlaylistDetailProvider(existing.id));
        ref.invalidate(localPlaylistsProvider);
        if (mounted) _message(l10n.playlistSyncSuccess);
      } catch (error) {
        if (mounted) _message(error.toString());
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final detail = await _loadAll();
      final created = await rust_playlists.createLocalPlaylist(
        name: widget.playlist.name,
      );
      await rust_playlists.addLocalPlaylistTracks(
        playlistId: created.id,
        tracks: _inputs(detail),
      );
      await rust_playlists.markLocalPlaylistSubscribed(
        id: created.id,
        source: widget.platform,
        sourceListId: widget.playlist.id,
      );
      ref.invalidate(localPlaylistsProvider);
      ref.invalidate(localPlaylistDetailProvider(created.id));
      if (mounted) _message(l10n.playlistSubscribeSuccess);
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    M3ESnackbar.show(context, message: text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(lxPlaylistAllProvider(_key));
    final tracks = async.value?.tracks
        .map(lxSearchTrackToUiTrack)
        .toList(growable: false);
    final platformLabel = lxPlatformLabel(l10n, widget.platform);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileLargeSubpageAppBar(
        context,
        title: widget.playlist.name,
        variant: M3EAppBarVariant.mediumFlexible,
      ),
      body: async.when(
        loading: () => Center(
          child: M3ELoadingIndicator(
            color: theme.colorScheme.primary,
            containerColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        error: (Object error, StackTrace stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$error', textAlign: TextAlign.center),
          ),
        ),
        data: (detail) {
          final playable = tracks ?? const <rust.UiTrack>[];
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: detail.info.coverUrl == null
                          ? ColoredBox(
                              color: theme.colorScheme.secondaryContainer,
                              child: Icon(
                                M3EIcons.queue_music,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            )
                          : Image.network(
                              detail.info.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => ColoredBox(
                                color: theme.colorScheme.secondaryContainer,
                                child: Icon(
                                  M3EIcons.queue_music,
                                  color: theme
                                      .colorScheme
                                      .onSecondaryContainer,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.info.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typeScale.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            LibrarySourceBadge(
                              label: 'LX · $platformLabel',
                              remote: true,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.librarySongsCount(detail.info.total.toInt()),
                              style: theme.typeScale.bodyMedium.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if (detail.info.author.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            detail.info.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typeScale.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (detail.info.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  detail.info.description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typeScale.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 20),
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
                                  source:
                                      '洛雪 · $platformLabel · ${detail.info.name}',
                                ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: M3EButton.icon(
                      icon: Icon(
                        _busy ? M3EIcons.hourglass_top : M3EIcons.add,
                      ),
                      label: Text(l10n.playlistSubscribe),
                      style: M3EButtonStyle.tonal,
                      onPressed: _busy ? null : _subscribe,
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
                itemCount: playable.length,
                onTap: (int index) => ref
                    .read(playerProvider.notifier)
                    .load(
                      playable,
                      index,
                      source: '洛雪 · $platformLabel · ${detail.info.name}',
                    ),
                itemBuilder: (BuildContext context, int index) {
                  final track = playable[index];
                  return M3EListItem(
                    leading: _LxTrackCover(track: track),
                    headline: track.title,
                    supportingText: [track.artist, track.album]
                        .where((value) => value.isNotEmpty)
                        .join(' · '),
                    trailingText: track.duration,
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

class _LxTrackCover extends ConsumerWidget {
  const _LxTrackCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final theme = M3ETheme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: 40,
        child: bytes == null
            ? ColoredBox(
                color: theme.colorScheme.tertiaryContainer,
                child: Icon(
                  M3EIcons.music_note,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              )
            : Image.memory(bytes, fit: BoxFit.cover),
      ),
    );
  }
}
