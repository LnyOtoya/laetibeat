import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/online.dart' as rust_online;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../widgets/player/player_provider.dart';
import '../../../../widgets/settings/online_provider.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';
import 'online_widgets.dart';

class OnlinePlaylistDetailPage extends ConsumerWidget {
  const OnlinePlaylistDetailPage({super.key, required this.playlist});

  final rust_online.UiOnlinePlaylist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(
      onlinePlaylistTracksProvider((source: playlist.source, id: playlist.id)),
    );
    return _OnlineTracksScaffold(
      title: playlist.name,
      subtitle: [
        if (playlist.creator != null && playlist.creator!.isNotEmpty)
          playlist.creator!,
        if (playlist.trackCount > 0) '${playlist.trackCount} 首',
      ].join(' · '),
      coverUrl: playlist.coverUrl,
      source: playlist.source,
      tracks: tracks,
    );
  }
}

class OnlineAlbumDetailPage extends ConsumerWidget {
  const OnlineAlbumDetailPage({super.key, required this.album});

  final rust_online.UiOnlineAlbum album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(
      onlineAlbumTracksProvider((source: album.source, id: album.id)),
    );
    return _OnlineTracksScaffold(
      title: album.name,
      subtitle: [
        if (album.artist != null && album.artist!.isNotEmpty) album.artist!,
        if (album.trackCount > 0) '${album.trackCount} 首',
      ].join(' · '),
      coverUrl: album.coverUrl,
      source: album.source,
      tracks: tracks,
    );
  }
}

class _OnlineTracksScaffold extends ConsumerWidget {
  const _OnlineTracksScaffold({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.source,
    required this.tracks,
  });

  final String title;
  final String subtitle;
  final String? coverUrl;
  final String source;
  final AsyncValue<List<rust.UiTrack>> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: title),
      body: tracks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace? stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '加载失败：$error',
              textAlign: TextAlign.center,
              style: theme.typeScale.bodyMedium,
            ),
          ),
        ),
        data: (List<rust.UiTrack> items) {
          if (items.isEmpty) {
            return const Center(child: Text('暂无歌曲'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: <Widget>[
              Row(
                children: <Widget>[
                  OnlineCover(url: coverUrl, size: 88),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: theme.typeScale.titleLarge),
                        if (subtitle.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.typeScale.bodySmall.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              M3EButton(
                style: M3EButtonStyle.filled,
                label: const Text('播放全部'),
                onPressed: () => ref
                    .read(playerProvider.notifier)
                    .load(items, 0, source: onlineSourceLabel(source)),
              ),
              const SizedBox(height: AppSpacing.md),
              M3EList(
                color: scheme.surface,
                variant: M3ECardVariant.filled,
                itemCount: items.length,
                onTap: (int index) => ref
                    .read(playerProvider.notifier)
                    .load(items, index, source: onlineSourceLabel(source)),
                itemBuilder: (BuildContext context, int index) {
                  final track = items[index];
                  return M3EListItem(
                    headline: track.title,
                    supportingText: track.artist,
                    leading: OnlineCover(url: track.coverId),
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
