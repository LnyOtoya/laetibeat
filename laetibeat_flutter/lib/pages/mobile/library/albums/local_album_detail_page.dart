import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// 本地专辑详情页。
class LocalAlbumDetailPage extends ConsumerWidget {
  const LocalAlbumDetailPage({super.key, required this.album});

  final rust.UiAlbum album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final state = ref.watch(musicLibraryProvider).value;
    final tracksById = <String, rust.UiTrack>{
      for (final track in state?.tracks ?? const <rust.UiTrack>[])
        track.id: track,
    };
    final tracks = <rust.UiTrack>[
      for (final id in album.trackIds)
        if (tracksById[id] != null) tracksById[id]!,
    ];
    if (tracks.isEmpty) {
      tracks.addAll(
        (state?.tracks ?? const <rust.UiTrack>[]).where(
          (track) => track.albumId == album.id,
        ),
      );
    }
    final coverTrack =
        tracksById[album.coverTrackId] ??
        (tracks.isEmpty ? null : tracks.first);
    final totalSeconds = tracks.fold<int>(
      0,
      (sum, track) => sum + track.durationSeconds.toInt(),
    );

    void play(int index) {
      if (tracks.isEmpty) return;
      ref
          .read(playerProvider.notifier)
          .load(tracks, index, source: album.title);
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageBar.detail(),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: _LocalAlbumBanner(track: coverTrack),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typeScale.headlineSmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      album.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typeScale.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        M3EChip(
                          label: l10n.playNow,
                          leading: const Icon(M3EIcons.play_arrow),
                          elevated: true,
                          onPressed: tracks.isEmpty ? null : () => play(0),
                        ),
                        const SizedBox(width: 8),
                        M3EChip(
                          label: l10n.shufflePlay,
                          leading: const Icon(M3EIcons.shuffle),
                          elevated: true,
                          onPressed: tracks.isEmpty
                              ? null
                              : () => ref
                                    .read(playerProvider.notifier)
                                    .playShuffled(tracks, source: album.title),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  l10n.releaseDate(album.year?.toString() ?? l10n.unknown),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.typeScale.titleLarge.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.albumSummary(
                    '${tracks.length}',
                    _formatDuration(totalSeconds, l10n.durationUnknown),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.typeScale.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: M3ETheme(
              data: AppTheme.withDetailTextEmphasis(theme),
              child: M3EList(
                itemCount: tracks.length,
                color: theme.colorScheme.surface,
                variant: M3ECardVariant.filled,
                emptyBuilder: Center(child: Text(l10n.noSongs)),
                onTap: play,
                itemBuilder: (BuildContext context, int index) {
                  final track = tracks[index];
                  return M3EListItem(
                    leading: _LocalTrackCover(track: track),
                    headline: track.title,
                    supportingText: track.artist,
                    trailingText: track.duration,
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 24 + bottomInset),
        ],
      ),
    );
  }

  String _formatDuration(int seconds, String unknown) {
    if (seconds <= 0) return unknown;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:00';
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class _LocalAlbumBanner extends ConsumerWidget {
  const _LocalAlbumBanner({required this.track});

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

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasArt)
          Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
        else
          ColoredBox(
            color: scheme.secondaryContainer,
            child: Center(
              child: Icon(
                M3EIcons.album,
                size: 56,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xCC000000)],
              stops: [0.45, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _LocalTrackCover extends ConsumerWidget {
  const _LocalTrackCover({required this.track});

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
