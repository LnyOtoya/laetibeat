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
import '../library/albums/album_detail_page.dart';
import '../library/albums/local_album_detail_page.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import 'discovery_page.dart';

/// Mobile Home content.
///
/// Current sections:
/// - 最新发行: newest-release album covers
/// - 最近加入: recently added songs
class MobileHomeContent extends ConsumerWidget {
  const MobileHomeContent({super.key});

  static const String _recentTitle = '最近加入';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double pageGutter = AppLayout.gutterFor(
      MediaQuery.sizeOf(context).width,
    );
    final library = ref.watch(musicLibraryProvider).value;
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final albumEntries = _collectAlbums(ref, library, servers);
    final newReleases = _newReleases(albumEntries);
    final recentSongs = _recentSongs(ref, library, servers);
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
        if (newReleases.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: pageGutter,
              vertical: AppSpacing.xl,
            ),
            child: const AppEmptyState(
              title: '暂无最新发行',
              message: '扫描本地音乐库或同步 Subsonic 后会出现在这里',
              icon: M3EIcons.album,
            ),
          )
        else
          SizedBox(
            height: 228,
            child: _NewReleaseCarousel(
              albums: newReleases,
              edgeInset: pageGutter,
              onAlbumSelected: (album) => _openAlbum(context, album),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        const _DiscoverySection(),
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pageGutter),
          child: AppSectionHeader(
            title: _recentTitle,
            padding: AppInsets.sectionHeader,
            trailing: recentSongs.isEmpty ? null : const _SeeMoreButton(),
          ),
        ),
        if (recentSongs.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: pageGutter,
              vertical: AppSpacing.xl,
            ),
            child: const AppEmptyState(
              title: '暂无最近加入的歌曲',
              message: '扫描本地音乐库或同步 Subsonic 后会出现在这里',
              icon: M3EIcons.music_note,
            ),
          )
        else
          _RecentSongsList(
            tracks: recentSongs,
            onPlay: (index) => ref
                .read(playerProvider.notifier)
                .load(recentSongs, index, source: '最近加入'),
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

  void _openAlbum(BuildContext context, _LatestAlbum album) {
    final localAlbum = album.localAlbum;
    if (localAlbum != null) {
      pushMobileRootPage(
        context,
        LocalAlbumDetailPage(album: localAlbum),
        name: MobileRoutes.albumDetail,
      );
      return;
    }
    final remoteAlbum = album.remoteAlbum;
    final sourceId = album.remoteSourceId;
    if (remoteAlbum != null && sourceId != null) {
      pushMobileRootPage(
        context,
        AlbumDetailPage(sourceId: sourceId, album: remoteAlbum),
        name: MobileRoutes.albumDetail,
      );
    }
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

class _RecentSongsList extends StatelessWidget {
  const _RecentSongsList({required this.tracks, required this.onPlay});

  final List<rust.UiTrack> tracks;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return m3e_core.M3ESegmentedList.builder(
      itemCount: tracks.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onTap: onPlay,
      listPadding: EdgeInsets.zero,
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
          leading: _RecentSongCover(track: track),
          trailing: M3EIconButton(
            variant: M3EIconButtonVariant.standard,
            size: M3EIconButtonSize.sm,
            icon: const Icon(M3EIcons.favorite_border),
            semanticLabel: l10n.addToFavorites,
            onPressed: () {},
          ),
        );
      },
    );
  }
}

class _RecentSongCover extends ConsumerWidget {
  const _RecentSongCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ClipRRect(
      borderRadius: AppRadii.xsAll,
      child: SizedBox.square(
        dimension: 40,
        child: hasArt
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  M3EIcons.music_note,
                  size: AppIconSize.sm,
                  color: scheme.onSecondaryContainer,
                ),
              ),
      ),
    );
  }
}

class _DiscoverySection extends ConsumerWidget {
  const _DiscoverySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final pageGutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    final discovery = ref.watch(discoveryProvider);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pageGutter),
      child: AppSurface(
        level: AppSurfaceLevel.container,
        borderRadius: AppRadii.xlAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: AppSectionHeader(
                title: '为你发现',
                leading: const _DiscoveryGlyph(),
                padding: AppInsets.sectionHeader,
                trailing: m3e_core.M3EButton.icon(
                  style: m3e_core.M3EButtonStyle.tonal,
                  size: m3e_core.M3EButtonSize.sm,
                  shape: m3e_core.M3EButtonShape.round,
                  tooltip: '换一个艺术家',
                  icon: const Icon(M3EIcons.refresh),
                  label: const Text('换一个'),
                  onPressed: () {
                    ref.read(discoveryCacheServiceProvider).refresh();
                  },
                ),
              ),
            ),
            discovery.when(
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(
                  child: M3ELoadingIndicator(
                    color: theme.colorScheme.primary,
                    containerColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: AppEmptyState(
                  title: '暂时无法为你发现',
                  message: '检查 Subsonic 连接后再试',
                  icon: M3EIcons.auto_awesome,
                ),
              ),
              data: (result) {
                if (result == null || result.tracks.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xl,
                    ),
                    child: AppEmptyState(
                      title: '还没有为你发现的内容',
                      message: '在 Subsonic 上播放一些歌曲后，会根据最近聆听的艺术家推荐',
                      icon: M3EIcons.auto_awesome,
                    ),
                  );
                }
                return _DiscoveryContent(result: result);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryGlyph extends StatelessWidget {
  const _DiscoveryGlyph();

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;

    return SizedBox.square(
      dimension: 32,
      child: M3EShapeContainer(
        kind: M3EShapeKind.sunny,
        color: scheme.primaryContainer,
        child: Center(
          child: Icon(
            M3EIcons.auto_awesome,
            size: AppIconSize.sm,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _DiscoveryContent extends ConsumerWidget {
  const _DiscoveryContent({required this.result});

  final DiscoveryResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 240,
          child: M3ECard(
            variant: M3ECardVariant.filled,
            padding: EdgeInsets.zero,
            borderRadius: AppRadii.xlAll,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _DiscoveryArtistCover(
                  sourceId: result.artist.sourceId,
                  coverId: result.artist.coverId,
                ),
                const _DiscoveryScrim(),
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '根据最近聆听的歌手为你推荐',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typeScale.titleSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      m3e_core.M3EButton(
                        style: m3e_core.M3EButtonStyle.filled,
                        size: m3e_core.M3EButtonSize.sm,
                        shape: m3e_core.M3EButtonShape.round,
                        onPressed: () {
                          pushMobileRootPage(
                            context,
                            DiscoveryPage(result: result),
                            name: MobileRoutes.discovery,
                          );
                        },
                        child: const Text('为你发现'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _DiscoverySongRow(tracks: result.tracks),
      ],
    );
  }
}

class _DiscoveryScrim extends StatelessWidget {
  const _DiscoveryScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.transparent,
              Colors.black.withValues(alpha: 0.78),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverySongRow extends ConsumerWidget {
  const _DiscoverySongRow({required this.tracks});

  final List<rust.UiTrack> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = tracks.take(3).toList(growable: false);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = AppSpacing.sm;
        // 卡片放大到约 42% 视口宽：前两张完整显示，第三张露出一部分。
        final cardWidth = constraints.maxWidth * 0.42;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var index = 0; index < preview.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: gap),
                SizedBox(
                  width: cardWidth,
                  child: _DiscoverySongTile(
                    track: preview[index],
                    onTap: () {
                      ref
                          .read(playerProvider.notifier)
                          .load(tracks, index, source: '为你发现');
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DiscoverySongTile extends StatelessWidget {
  const _DiscoverySongTile({required this.track, required this.onTap});

  final rust.UiTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${track.title} · ${track.artist}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadii.mdAll,
          onTap: onTap,
          child: ClipRRect(
            borderRadius: AppRadii.mdAll,
            child: AspectRatio(
              aspectRatio: 1,
              child: _DiscoverySongCover(track: track),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryArtistCover extends ConsumerWidget {
  const _DiscoveryArtistCover({
    required this.sourceId,
    required this.coverId,
  });

  final String sourceId;
  final String? coverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final bytes = ref
        .watch(remoteCoverProvider((sourceId: sourceId, coverId: coverId)))
        .value;

    if (bytes == null || bytes.isEmpty) {
      return ColoredBox(
        color: scheme.secondaryContainer,
        child: Center(
          child: Icon(
            M3EIcons.person,
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

class _DiscoverySongCover extends ConsumerWidget {
  const _DiscoverySongCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final bytes = ref.watch(trackCoverProvider(track)).value;

    if (bytes == null || bytes.isEmpty) {
      return ColoredBox(
        color: scheme.secondaryContainer,
        child: Center(
          child: Icon(
            M3EIcons.music_note,
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
}

class _NewReleaseCarousel extends StatelessWidget {
  const _NewReleaseCarousel({
    required this.albums,
    required this.edgeInset,
    required this.onAlbumSelected,
  });

  final List<_LatestAlbum> albums;
  final double edgeInset;
  final ValueChanged<_LatestAlbum> onAlbumSelected;

  @override
  Widget build(BuildContext context) {
    final baseTheme = M3ETheme.of(context);

    // M3ECarousel 的 hero 布局把容器左右内边距写死为 16 - itemGap / 2。
    // 把 itemGap 设为 32 可让容器内边距归零，滚动视口因此占满整宽；
    // 再用 itemPadding 把 page gutter 补回每个 item 的起始边。
    final carouselTheme = baseTheme.carouselTheme.copyWith(
      itemGap: AppSpacing.xxl,
    );

    return M3ETheme(
      data: baseTheme.copyWith(carouselTheme: carouselTheme),
      child: M3ECarousel(
        // Hero-left gives the focal first album cover more width while keeping
        // the theme's item gap between cards.
        type: M3ECarouselType.hero,
        heroAlignment: M3ECarouselHeroAlignment.left,
        axis: Axis.horizontal,
        height: 228,
        childElementBorderRadius: AppRadii.xl,
        haptic: M3EHapticFeedback.light,
        itemPadding: EdgeInsetsDirectional.only(start: edgeInset),
        children: <M3ECarouselItem>[
          for (final album in albums)
            M3ECarouselItem(
              image: _AlbumCover(album: album, iconSize: AppIconSize.xl),
              applyDynamicTextContentTransform: false,
              subtitle: m3e_core.M3EButton(
                style: m3e_core.M3EButtonStyle.filled,
                size: m3e_core.M3EButtonSize.sm,
                shape: m3e_core.M3EButtonShape.round,
                onPressed: () => onAlbumSelected(album),
                child: Text(
                  album.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              showScrim: null,
              semanticLabel: '${album.title} · ${album.artist}',
              onTap: () => onAlbumSelected(album),
            ),
        ],
      ),
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
    this.localAlbum,
    this.remoteSourceId,
    this.remoteCoverId,
    this.remoteAlbum,
  });

  final String id;
  final String title;
  final String artist;
  final int? year;
  final String sourceLabel;
  final DateTime? addedAt;

  final rust.UiTrack? localTrack;
  final rust.UiAlbum? localAlbum;
  final String? remoteSourceId;
  final String? remoteCoverId;
  final rust_subsonic.UiRemoteAlbum? remoteAlbum;
}

List<_LatestAlbum> _collectAlbums(
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
          localAlbum: album,
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
          remoteAlbum: album,
        ),
      );
    }
  }

  return entries;
}

class _RecentSong {
  const _RecentSong({required this.track, this.addedAt});

  final rust.UiTrack track;
  final DateTime? addedAt;
}

List<rust.UiTrack> _recentSongs(
  WidgetRef ref,
  MusicLibraryState? library,
  List<SubsonicServerConfig> servers,
) {
  final entries = <_RecentSong>[];

  if (library != null) {
    for (final track in library.tracks) {
      final modifiedMs = track.modifiedMs?.toInt();
      entries.add(
        _RecentSong(
          track: track,
          addedAt: modifiedMs != null && modifiedMs > 0
              ? DateTime.fromMillisecondsSinceEpoch(modifiedMs)
              : null,
        ),
      );
    }
  }

  for (final server in servers) {
    final albums =
        ref.watch(remoteAllAlbumsProvider(server.id)).value ??
        const <rust_subsonic.UiRemoteAlbum>[];
    final createdByAlbum = <String, DateTime?>{
      for (final album in albums)
        album.id: DateTime.tryParse(album.created ?? ''),
    };
    final remoteTracks =
        ref.watch(remoteAllTracksProvider(server.id)).value ??
        const <rust_subsonic.UiRemoteTrack>[];
    for (final track in remoteTracks) {
      final albumId = track.albumId;
      final addedAt =
          DateTime.tryParse(track.created ?? '') ??
          (albumId == null ? null : createdByAlbum[albumId]);
      entries.add(
        _RecentSong(
          track: remoteTrackToUiTrack(track, server.id),
          addedAt: addedAt,
        ),
      );
    }
  }

  entries.sort((a, b) {
    final aTime = a.addedAt?.millisecondsSinceEpoch ?? 0;
    final bTime = b.addedAt?.millisecondsSinceEpoch ?? 0;
    if (aTime != bTime) return bTime.compareTo(aTime);
    return a.track.title.toLowerCase().compareTo(b.track.title.toLowerCase());
  });

  return entries.take(4).map((entry) => entry.track).toList(growable: false);
}

List<_LatestAlbum> _newReleases(List<_LatestAlbum> entries) {
  final withYear = entries
      .where((album) => album.year != null && album.year! > 0)
      .toList(growable: false);
  final candidates = withYear.isEmpty
      ? (<_LatestAlbum>[...entries]..sort(_compareByAddedAt))
      : (<_LatestAlbum>[...withYear]..sort(_compareByRelease));

  return candidates.take(10).toList(growable: false);
}

int _compareByAddedAt(_LatestAlbum a, _LatestAlbum b) {
  final aTime = a.addedAt?.millisecondsSinceEpoch ?? 0;
  final bTime = b.addedAt?.millisecondsSinceEpoch ?? 0;
  if (aTime != bTime) return bTime.compareTo(aTime);
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

int _compareByRelease(_LatestAlbum a, _LatestAlbum b) {
  final yearCompare = (b.year ?? 0).compareTo(a.year ?? 0);
  if (yearCompare != 0) return yearCompare;
  return _compareByAddedAt(a, b);
}

class _AlbumCover extends ConsumerWidget {
  const _AlbumCover({
    required this.album,
    this.iconSize = AppIconSize.lg,
  });

  final _LatestAlbum album;
  final double iconSize;

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
            size: iconSize,
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
