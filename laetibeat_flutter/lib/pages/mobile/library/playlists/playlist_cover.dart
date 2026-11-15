import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/playlists.dart' as rust_playlists;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// 本地歌单封面。
///
/// 本地曲目复用 trackCoverProvider；远端曲目复用 remoteCoverProvider，
/// 与专辑/歌曲封面走同一套解析与缓存逻辑。
class LocalPlaylistCover extends ConsumerWidget {
  const LocalPlaylistCover({
    super.key,
    required this.playlist,
    this.radius = 12,
  });

  final rust_playlists.UiLocalPlaylistSummary playlist;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final source = playlist.coverSource;
    final trackId = playlist.coverTrackId;
    final sourceId = playlist.coverSourceId;
    final coverId = playlist.coverId;

    Uint8List? bytes;
    if (source == 'lx' && coverId != null && coverId.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          coverId,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => _fallback(theme),
        ),
      );
    }
    if (source == 'local' && trackId != null) {
      final track = _findLocalTrack(ref, trackId);
      if (track != null) {
        bytes = ref.watch(trackCoverProvider(track)).value;
      }
    } else if (source != null && sourceId != null && coverId != null) {
      bytes = ref
          .watch(remoteCoverProvider((sourceId: sourceId, coverId: coverId)))
          .value;
    }

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
          : _fallback(theme),
    );
  }

  Widget _fallback(M3EThemeData theme) {
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

rust.UiTrack? _findLocalTrack(WidgetRef ref, String trackId) {
  final tracks =
      ref.watch(musicLibraryProvider).value?.tracks ?? const <rust.UiTrack>[];
  for (final track in tracks) {
    if (track.id == trackId) return track;
  }
  return null;
}
