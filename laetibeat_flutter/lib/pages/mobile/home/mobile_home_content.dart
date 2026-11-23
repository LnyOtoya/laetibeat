import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../src/rust/api/simple.dart' as rust;
import '../../../src/rust/api/subsonic.dart' as rust_subsonic;
import '../../../widgets/player/cover_provider.dart';
import '../../../widgets/player/player_provider.dart';
import '../../../widgets/recommendation_provider.dart';
import '../../../widgets/remote_browser_provider.dart';
import '../../../widgets/settings/music_library_provider.dart';
import '../../../widgets/settings/subsonic_provider.dart';

/// Mobile Home content.
///
/// Current sections:
/// - 继续听: contained horizontal carousel
/// - 最新添加: recent local / Subsonic albums
class MobileHomeContent extends ConsumerWidget {
  const MobileHomeContent({super.key});

  static const String _latestTitle = '最新添加';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double pageGutter = AppLayout.gutterFor(
      MediaQuery.sizeOf(context).width,
    );
    final player = ref.watch(
      playerProvider.select((state) => (state.queue, state.currentIndex)),
    );
    final List<rust.UiTrack> queue = player.$1;
    final library = ref.watch(musicLibraryProvider).value;
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final latestAlbums = _latestAlbums(ref, library, servers);
    final longLostAlbums =
        ref
            .watch(albumRecommendationsProvider(RecommendMode.longTimeNoSee))
            .value ??
        const <RecommendedAlbum>[];
    final longLostArtists = _artistsFromRecommendations(longLostAlbums);
    final recommendedTracks = _recommendedTracks(ref);

    return ListView(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.xxl,
      ),
      children: <Widget>[
        if (queue.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: pageGutter,
              vertical: AppSpacing.xl,
            ),
            child: const AppEmptyState(
              title: '还没有继续播放的歌曲',
              message: '播放一首歌后，会出现在这里',
              icon: M3EIcons.music_note,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.carouselGutter,
            ),
            child: SizedBox(
              height: 228,
              child: _ContinueListeningCarousel(
                queue: queue,
                currentIndex: player.$2.clamp(0, queue.length - 1),
                onTrackSelected: (int index) {
                  ref.read(playerProvider.notifier).play(index);
                },
              ),
            ),
          ),
        if (queue.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.carouselGutter,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: const _SeeMoreButton(),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pageGutter),
          child: const AppSectionHeader(
            title: _latestTitle,
            padding: AppInsets.sectionHeader,
          ),
        ),
        if (latestAlbums.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: pageGutter,
              vertical: AppSpacing.xl,
            ),
            child: const AppEmptyState(
              title: '暂无最近添加的专辑',
              message: '扫描本地音乐库或同步 Subsonic 后会出现在这里',
              icon: M3EIcons.album,
            ),
          )
        else
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pageGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (
                  var index = 0;
                  index < latestAlbums.length;
                  index++
                ) ...<Widget>[
                  _LatestAlbumCard(album: latestAlbums[index]),
                  const SizedBox(height: AppSpacing.xs),
                  const M3EDivider(),
                  if (index != latestAlbums.length - 1)
                    const SizedBox(height: AppSpacing.lg),
                ],
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: const _SeeMoreButton(),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pageGutter),
          child: const AppSectionHeader(
            title: '重拾旧爱',
            padding: AppInsets.sectionHeader,
          ),
        ),
        if (longLostArtists.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: pageGutter,
              vertical: AppSpacing.xl,
            ),
            child: const AppEmptyState(
              title: '还没有很久没听的艺术家',
              message: '播放记录积累后会出现在这里',
              icon: M3EIcons.person,
            ),
          )
        else
          SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pageGutter),
              itemCount: longLostArtists.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.lg),
              itemBuilder: (BuildContext context, int index) {
                return _LongLostArtist(album: longLostArtists[index]);
              },
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pageGutter),
          child: const AppSectionHeader(
            title: '为你推荐',
            padding: AppInsets.sectionHeader,
          ),
        ),
        if (recommendedTracks.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: pageGutter,
              vertical: AppSpacing.xl,
            ),
            child: const AppEmptyState(
              title: '还没有为你推荐的歌曲',
              message: '播放一些歌曲后，会根据收听记录生成推荐',
              icon: M3EIcons.music_note,
            ),
          )
        else
          SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pageGutter),
              itemCount: recommendedTracks.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.lg),
              itemBuilder: (BuildContext context, int index) {
                return _RecommendedSong(
                  track: recommendedTracks[index],
                  onTap: () {
                    ref
                        .read(playerProvider.notifier)
                        .load(recommendedTracks, index, source: '为你推荐');
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SeeMoreButton extends StatelessWidget {
  const _SeeMoreButton();

  @override
  Widget build(BuildContext context) {
    return m3e_core.M3EButton.icon(
      style: m3e_core.M3EButtonStyle.tonal,
      size: m3e_core.M3EButtonSize.sm,
      shape: m3e_core.M3EButtonShape.round,
      tooltip: '查看更多',
      decoration: m3e_core.M3EButtonDecoration.styleFrom(),
      icon: const Icon(M3EIcons.visibility),
      label: const Text('查看更多'),
      onPressed: () {},
    );
  }
}

class _ContinueListeningCarousel extends StatelessWidget {
  const _ContinueListeningCarousel({
    required this.queue,
    required this.currentIndex,
    required this.onTrackSelected,
  });

  final List<rust.UiTrack> queue;
  final int currentIndex;
  final ValueChanged<int> onTrackSelected;

  @override
  Widget build(BuildContext context) {
    final List<int> indices = <int>[
      for (var offset = 0; offset < queue.length; offset++)
        (currentIndex + offset) % queue.length,
    ];

    return M3ECarousel(
      // Hero-left gives the focal first card more width while keeping the
      // theme's item gap between cards.
      type: M3ECarouselType.hero,
      heroAlignment: M3ECarouselHeroAlignment.left,
      axis: Axis.horizontal,
      height: 228,
      childElementBorderRadius: AppRadii.xl,
      haptic: M3EHapticFeedback.light,
      children: <M3ECarouselItem>[
        for (var position = 0; position < indices.length; position++)
          M3ECarouselItem(
            image: _TrackCover(track: queue[indices[position]]),
            applyDynamicTextContentTransform: false,
            subtitle: AppText(
              queue[indices[position]].title,
              role: AppTextRole.titleMedium,
              colorRole: AppColorRole.onSurface,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            showScrim: null,
            semanticLabel: queue[indices[position]].title,
            onTap: () => onTrackSelected(indices[position]),
          ),
      ],
    );
  }
}

List<RecommendedAlbum> _artistsFromRecommendations(
  List<RecommendedAlbum> albums,
) {
  final seen = <String>{};
  final artists = <RecommendedAlbum>[];
  for (final album in albums) {
    if (!seen.add(album.artist)) continue;
    artists.add(album);
    if (artists.length >= 8) break;
  }
  return artists;
}

List<rust.UiTrack> _recommendedTracks(WidgetRef ref) {
  final albums =
      ref
          .watch(albumRecommendationsProvider(RecommendMode.neverPlayed))
          .value ??
      const <RecommendedAlbum>[];
  final seen = <String>{};
  final tracks = <rust.UiTrack>[];
  for (final album in albums) {
    for (final track in album.tracks) {
      if (!seen.add(track.id)) continue;
      tracks.add(track);
      if (tracks.length >= 10) return tracks;
    }
  }
  return tracks;
}

class _RecommendedSong extends StatelessWidget {
  const _RecommendedSong({required this.track, required this.onTap});

  final rust.UiTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 112,
        child: Column(
          children: <Widget>[
            M3EShapeContainer.square(
              width: 112,
              height: 112,
              color: M3ETheme.of(context).colorScheme.secondaryContainer,
              child: _TrackCover(track: track),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppText(
              track.title,
              role: AppTextRole.labelLarge,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _LongLostArtist extends StatelessWidget {
  const _LongLostArtist({required this.album});

  final RecommendedAlbum album;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Column(
        children: <Widget>[
          M3EShapeContainer.cookie9Sided(
            width: 112,
            height: 112,
            color: M3ETheme.of(context).colorScheme.secondaryContainer,
            child: _RecommendedAlbumCover(album: album),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppText(
            album.artist,
            role: AppTextRole.labelLarge,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RecommendedAlbumCover extends ConsumerWidget {
  const _RecommendedAlbumCover({required this.album});

  final RecommendedAlbum album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = _coverBytes(ref);
    final scheme = M3ETheme.of(context).colorScheme;

    if (bytes == null || bytes.isEmpty) {
      return Center(
        child: Icon(
          M3EIcons.person,
          size: AppIconSize.xl,
          color: scheme.onSecondaryContainer,
        ),
      );
    }

    return SizedBox.expand(
      child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }

  Uint8List? _coverBytes(WidgetRef ref) {
    final track = album.coverTrack;
    if (track != null) {
      return ref.watch(trackCoverProvider(track)).value;
    }
    final sourceId = album.remoteSourceId;
    final coverId = album.remoteCoverId;
    if (sourceId != null && coverId != null && coverId.isNotEmpty) {
      return ref
          .watch(remoteCoverProvider((sourceId: sourceId, coverId: coverId)))
          .value;
    }
    return null;
  }
}

class _TrackCover extends ConsumerWidget {
  const _TrackCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final scheme = M3ETheme.of(context).colorScheme;

    if (bytes == null || bytes.isEmpty) {
      return ColoredBox(
        color: scheme.secondaryContainer,
        child: Center(
          child: Icon(
            M3EIcons.music_note,
            size: AppIconSize.xl,
            color: scheme.onSecondaryContainer,
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }
}

class _LatestAlbum {
  const _LatestAlbum({
    required this.id,
    required this.title,
    required this.artist,
    required this.year,
    required this.sourceLabel,
    required this.addedAt,
    this.localTrack,
    this.remoteSourceId,
    this.remoteCoverId,
  });

  final String id;
  final String title;
  final String artist;
  final int? year;
  final String sourceLabel;
  final DateTime? addedAt;

  final rust.UiTrack? localTrack;
  final String? remoteSourceId;
  final String? remoteCoverId;
}

List<_LatestAlbum> _latestAlbums(
  WidgetRef ref,
  MusicLibraryState? library,
  List<SubsonicServerConfig> servers,
) {
  final entries = <_LatestAlbum>[];

  if (library != null) {
    final tracksById = <String, rust.UiTrack>{
      for (final track in library.tracks) track.id: track,
    };
    for (final album in library.albums) {
      int? latestMs;
      for (final trackId in album.trackIds) {
        final ms = tracksById[trackId]?.modifiedMs?.toInt();
        if (ms != null && (latestMs == null || ms > latestMs)) {
          latestMs = ms;
        }
      }
      final coverTrack =
          tracksById[album.coverTrackId] ??
          (album.trackIds.isEmpty ? null : tracksById[album.trackIds.first]);
      entries.add(
        _LatestAlbum(
          id: 'local:${album.id}',
          title: album.title,
          artist: album.artist,
          year: album.year,
          sourceLabel: '本地',
          addedAt: latestMs == null || latestMs <= 0
              ? null
              : DateTime.fromMillisecondsSinceEpoch(latestMs),
          localTrack: coverTrack,
        ),
      );
    }
  }

  for (final server in servers) {
    final albums =
        ref.watch(remoteAllAlbumsProvider(server.id)).value ??
        const <rust_subsonic.UiRemoteAlbum>[];
    for (final album in albums) {
      entries.add(
        _LatestAlbum(
          id: 'remote:${server.id}:${album.id}',
          title: album.title,
          artist: album.artist,
          year: album.year,
          sourceLabel: 'Subsonic',
          addedAt: DateTime.tryParse(album.created ?? ''),
          remoteSourceId: server.id,
          remoteCoverId: album.coverId,
        ),
      );
    }
  }

  entries.sort((a, b) {
    final aTime = a.addedAt?.millisecondsSinceEpoch ?? 0;
    final bTime = b.addedAt?.millisecondsSinceEpoch ?? 0;
    if (aTime != bTime) return bTime.compareTo(aTime);
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });

  return entries.take(3).toList(growable: false);
}

class _LatestAlbumCard extends StatelessWidget {
  const _LatestAlbumCard({required this.album});

  final _LatestAlbum album;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final sourceAndYear =
        '${album.sourceLabel} · ${album.year?.toString() ?? '未知年份'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 44,
              child: ClipOval(child: _AlbumCover(album: album)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppText(
                    album.artist,
                    role: AppTextRole.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  AppText(
                    sourceAndYear,
                    role: AppTextRole.labelMedium,
                    colorRole: AppColorRole.onSurfaceVariant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 200,
          child: M3ECard(
            variant: M3ECardVariant.filled,
            padding: EdgeInsets.zero,
            borderRadius: AppRadii.xlAll,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned.fill(child: _AlbumCover(album: album)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          theme.colorScheme.surface.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: AppText(
                        album.title,
                        role: AppTextRole.titleMedium,
                        colorRole: AppColorRole.onSurface,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            Expanded(
              child: AppText(
                _relativeAdded(album.addedAt),
                role: AppTextRole.labelMedium,
                colorRole: AppColorRole.onSurfaceVariant,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            M3EIconButton(
              variant: M3EIconButtonVariant.standard,
              size: M3EIconButtonSize.sm,
              icon: const Icon(M3EIcons.favorite_border),
              semanticLabel: l10n.addToFavorites,
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }

  static String _relativeAdded(DateTime? date) {
    if (date == null) return '添加时间未知';
    final days = DateTime.now().difference(date).inDays;
    if (days <= 0) return '今天';
    if (days <= 12) return '$days 天前';
    if (days < 365) {
      final months = (days / 30).floor().clamp(1, 12);
      return '$months 个月前';
    }
    final years = (days / 365).floor().clamp(1, 99);
    return '$years 年前';
  }
}

class _AlbumCover extends ConsumerWidget {
  const _AlbumCover({required this.album});

  final _LatestAlbum album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = _coverBytes(ref);
    final scheme = M3ETheme.of(context).colorScheme;

    if (bytes == null || bytes.isEmpty) {
      return ColoredBox(
        color: scheme.secondaryContainer,
        child: Center(
          child: Icon(
            M3EIcons.album,
            size: AppIconSize.lg,
            color: scheme.onSecondaryContainer,
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }

  Uint8List? _coverBytes(WidgetRef ref) {
    final local = album.localTrack;
    if (local != null) {
      return ref.watch(trackCoverProvider(local)).value;
    }
    final sourceId = album.remoteSourceId;
    final coverId = album.remoteCoverId;
    if (sourceId != null && coverId != null && coverId.isNotEmpty) {
      return ref
          .watch(remoteCoverProvider((sourceId: sourceId, coverId: coverId)))
          .value;
    }
    return null;
  }
}
