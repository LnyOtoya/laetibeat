import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../albums/local_album_detail_page.dart';
import '../widgets/library_source_badge.dart';

/// 本地艺术家详情页。
class LocalArtistDetailPage extends ConsumerWidget {
  const LocalArtistDetailPage({super.key, required this.artist});

  final rust.UiArtist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final state = ref.watch(musicLibraryProvider).value;
    final allTracks = state?.tracks ?? const <rust.UiTrack>[];
    final tracks = allTracks
        .where(
          (track) =>
              track.artistId == artist.id ||
              track.artist == artist.name ||
              track.albumArtist == artist.name,
        )
        .toList(growable: false);
    final albumIds = tracks.map((track) => track.albumId).toSet();
    final albums = (state?.albums ?? const <rust.UiAlbum>[])
        .where(
          (album) => album.artist == artist.name || albumIds.contains(album.id),
        )
        .toList(growable: false);
    final coverTrack = allTracks
        .where((track) => track.id == artist.coverTrackId)
        .firstOrNull;

    void play(int index) {
      if (tracks.isEmpty) return;
      ref
          .read(playerProvider.notifier)
          .load(tracks, index, source: artist.name);
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageBar.detail(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
        children: [
          Row(
            children: [
              _LocalArtistAvatar(track: coverTrack),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typeScale.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        LibrarySourceBadge(
                          label: l10n.librarySourceLocal,
                          remote: false,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l10n.librarySongsCount(tracks.length),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typeScale.bodyMedium.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
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
                            .playShuffled(tracks, source: artist.name),
                ),
              ),
            ],
          ),
          if (albums.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.artistAlbums,
                    style: theme.typeScale.titleLarge,
                  ),
                ),
                Text(
                  l10n.totalAlbums('${albums.length}'),
                  style: theme.typeScale.labelMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: albums.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (BuildContext context, int index) {
                  final album = albums[index];
                  return _LocalAlbumCard(
                    album: album,
                    onTap: () => pushMobileRootPage(
                      context,
                      LocalAlbumDetailPage(album: album),
                      name: MobileRoutes.albumDetail,
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(l10n.topSongs, style: theme.typeScale.titleLarge),
          const SizedBox(height: 8),
          M3EList(
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
                supportingText: track.album,
                trailingText: track.duration,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LocalArtistAvatar extends ConsumerWidget {
  const _LocalArtistAvatar({required this.track});

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
      child: SizedBox.square(
        dimension: 88,
        child: hasArt
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  M3EIcons.person,
                  size: 38,
                  color: scheme.onSecondaryContainer,
                ),
              ),
      ),
    );
  }
}

class _LocalAlbumCard extends ConsumerWidget {
  const _LocalAlbumCard({required this.album, required this.onTap});

  final rust.UiAlbum album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final state = ref.watch(musicLibraryProvider).value;
    final coverTrack = (state?.tracks ?? const <rust.UiTrack>[])
        .where((track) => track.id == album.coverTrackId)
        .firstOrNull;

    return SizedBox(
      width: 140,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: _LocalAlbumCover(track: coverTrack),
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typeScale.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              AppLocalizations.of(
                context,
              ).librarySongsCount(album.trackCount.toInt()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typeScale.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
