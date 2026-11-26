import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/layout/app_bottom_inset.dart';
import '../../../../src/rust/api/netease.dart' as rust_netease;
import '../../../../src/rust/api/simple.dart' as rust;
import '../../../../widgets/cache/netease_cover_cache.dart';
import '../../../../widgets/player/player_provider.dart';
import '../../../../widgets/settings/favorites_provider.dart';
import '../../../../widgets/settings/netease_provider.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import 'netease_detail_widgets.dart';

String _releaseLabel(int? milliseconds) {
  if (milliseconds == null || milliseconds <= 0) return '发行日期: 未知';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '发行日期: ${date.year}-$month-$day';
}

String _releaseYearLabel(int? milliseconds, String unknownLabel) {
  if (milliseconds == null || milliseconds <= 0) return unknownLabel;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds).year.toString();
}

/// 网易云专辑详情。
class NeteaseAlbumDetailPage extends ConsumerStatefulWidget {
  const NeteaseAlbumDetailPage({super.key, required this.album});

  final rust_netease.UiNeteaseAlbum album;

  @override
  ConsumerState<NeteaseAlbumDetailPage> createState() =>
      _NeteaseAlbumDetailPageState();
}

class _NeteaseAlbumDetailPageState
    extends ConsumerState<NeteaseAlbumDetailPage> {
  static const double _barTintDistance = 120;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _barProgress = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _barProgress.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final double value = (_scrollController.offset / _barTintDistance).clamp(
      0.0,
      1.0,
    );
    if ((_barProgress.value - value).abs() > 0.01) {
      _barProgress.value = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final detailAsync = ref.watch(neteaseAlbumDetailProvider(widget.album.id));
    final album = detailAsync.value?.album ?? widget.album;
    final tracks = detailAsync.value?.tracks ?? const <rust.UiTrack>[];

    final coverUrl = album.coverUrl;
    final coverAsset = coverUrl == null || coverUrl.isEmpty
        ? null
        : ref.watch(neteaseCoverAssetProvider(coverUrl)).value;
    final bytes = coverAsset?.bytes;

    final trackIds = <String>{for (final track in tracks) track.id};
    final isCurrent = ref.watch(
      playerProvider.select((PlayerState player) {
        final current = player.current;
        return current != null &&
            current.source == 'netease' &&
            trackIds.contains(current.id);
      }),
    );
    final isPlaying =
        ref.watch(
          playerProvider.select((PlayerState player) => player.isPlaying),
        ) &&
        isCurrent;

    final favoriteKey = 'netease:album:${album.id}';
    final isFavorite = ref.watch(
      favoriteAlbumsProvider.select((ids) => ids.contains(favoriteKey)),
    );

    void togglePlayback() {
      final notifier = ref.read(playerProvider.notifier);
      if (isCurrent) {
        notifier.toggle();
        return;
      }
      if (tracks.isEmpty) return;
      notifier.load(tracks, 0, source: '网易云专辑');
    }

    void shufflePlay() {
      if (tracks.isEmpty) return;
      ref.read(playerProvider.notifier).playShuffled(tracks, source: '网易云专辑');
    }

    return NeteaseAnimatedTheme(
      coverColor: coverAsset?.color,
      child: Builder(
        builder: (BuildContext themedContext) {
          final scheme = M3ETheme.of(themedContext).colorScheme;
          final contentColor = detailContentColor(scheme);
          return Scaffold(
            backgroundColor: contentColor,
            extendBodyBehindAppBar: true,
            appBar: NeteaseDetailAppBar(
              progress: _barProgress,
              tint: contentColor,
            ),
            body: CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: NeteaseDetailHero(
                    bytes: bytes,
                    fallbackIcon: M3EIcons.album,
                  ),
                ),
                SliverToBoxAdapter(
                  child: NeteaseSummary(
                    title: album.name,
                    subtitle: album.artist,
                    meta: _releaseLabel(album.publishTimeMs?.toInt()),
                    isPlaying: isPlaying,
                    playEnabled: tracks.isNotEmpty,
                    isFavorite: isFavorite,
                    onShuffle: shufflePlay,
                    onPlayPause: togglePlayback,
                    onFavorite: () => ref
                        .read(favoriteAlbumsProvider.notifier)
                        .toggle(favoriteKey),
                  ),
                ),
                if (detailAsync.isLoading && !detailAsync.hasValue)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(child: NeteaseLoadingIndicator()),
                    ),
                  )
                else if (detailAsync.hasError && !detailAsync.hasValue)
                  SliverToBoxAdapter(
                    child: AppEmptyState(
                      title: '专辑加载失败',
                      message: '${detailAsync.error}',
                      icon: M3EIcons.error,
                      action: M3EButton(
                        style: M3EButtonStyle.tonal,
                        label: const Text('重试'),
                        onPressed: () => ref.invalidate(
                          neteaseAlbumDetailProvider(widget.album.id),
                        ),
                      ),
                    ),
                  )
                else
                  NeteaseTrackSliver(tracks: tracks, source: '网易云专辑'),
                SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxl + bottomInset),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 网易云艺人详情。
class NeteaseArtistDetailPage extends ConsumerStatefulWidget {
  const NeteaseArtistDetailPage({super.key, required this.artist});

  final rust_netease.UiNeteaseArtist artist;

  @override
  ConsumerState<NeteaseArtistDetailPage> createState() =>
      _NeteaseArtistDetailPageState();
}

class _NeteaseArtistDetailPageState
    extends ConsumerState<NeteaseArtistDetailPage> {
  static const double _barTintDistance = 120;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _barProgress = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _barProgress.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final double value = (_scrollController.offset / _barTintDistance).clamp(
      0.0,
      1.0,
    );
    if ((_barProgress.value - value).abs() > 0.01) {
      _barProgress.value = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final detailAsync = ref.watch(
      neteaseArtistDetailProvider(widget.artist.id),
    );
    final artist = detailAsync.value?.artist ?? widget.artist;
    final tracks = detailAsync.value?.tracks ?? const <rust.UiTrack>[];

    final coverUrl = artist.coverUrl;
    final coverAsset = coverUrl == null || coverUrl.isEmpty
        ? null
        : ref.watch(neteaseCoverAssetProvider(coverUrl)).value;
    final bytes = coverAsset?.bytes;

    final trackIds = <String>{for (final track in tracks) track.id};
    final isCurrent = ref.watch(
      playerProvider.select((PlayerState player) {
        final current = player.current;
        return current != null &&
            current.source == 'netease' &&
            trackIds.contains(current.id);
      }),
    );
    final isPlaying =
        ref.watch(
          playerProvider.select((PlayerState player) => player.isPlaying),
        ) &&
        isCurrent;

    final favoriteKey = 'netease:artist:${artist.id}';
    final isFavorite = ref.watch(
      favoriteArtistsProvider.select((ids) => ids.contains(favoriteKey)),
    );
    final l10n = AppLocalizations.of(context);

    void togglePlayback() {
      final notifier = ref.read(playerProvider.notifier);
      if (isCurrent) {
        notifier.toggle();
        return;
      }
      if (tracks.isEmpty) return;
      notifier.load(tracks, 0, source: '网易云艺人');
    }

    void shufflePlay() {
      if (tracks.isEmpty) return;
      ref.read(playerProvider.notifier).playShuffled(tracks, source: '网易云艺人');
    }

    return NeteaseAnimatedTheme(
      coverColor: coverAsset?.color,
      child: Builder(
        builder: (BuildContext themedContext) {
          final scheme = M3ETheme.of(themedContext).colorScheme;
          final contentColor = detailContentColor(scheme);
          final alias = artist.alias.isEmpty
              ? '网易云艺人'
              : artist.alias.join(' / ');
          return Scaffold(
            backgroundColor: contentColor,
            extendBodyBehindAppBar: true,
            appBar: NeteaseDetailAppBar(
              progress: _barProgress,
              tint: contentColor,
            ),
            body: CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: NeteaseDetailHero(
                    bytes: bytes,
                    fallbackIcon: M3EIcons.person,
                  ),
                ),
                SliverToBoxAdapter(
                  child: NeteaseSummary(
                    title: artist.name,
                    subtitle: alias,
                    meta: '${artist.albumSize} 张专辑',
                    isPlaying: isPlaying,
                    playEnabled: tracks.isNotEmpty,
                    isFavorite: isFavorite,
                    onShuffle: shufflePlay,
                    onPlayPause: togglePlayback,
                    onFavorite: () => ref
                        .read(favoriteArtistsProvider.notifier)
                        .toggle(favoriteKey),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppLayout.pageGutter,
                    ),
                    child: AppSectionHeader(
                      title: l10n.topSongs,
                      titleRole: AppTextRole.titleMedium,
                      padding: AppInsets.sectionHeader,
                      trailing: M3EButton(
                        style: M3EButtonStyle.tonal,
                        label: Text(l10n.more),
                        onPressed: () => pushMobileRootPage(
                          context,
                          NeteaseArtistHotSongsPage(artist: artist),
                          name: MobileRoutes.artistHotSongs,
                        ),
                      ),
                    ),
                  ),
                ),
                if (detailAsync.isLoading && !detailAsync.hasValue)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(child: NeteaseLoadingIndicator()),
                    ),
                  )
                else if (detailAsync.hasError && !detailAsync.hasValue)
                  SliverToBoxAdapter(
                    child: AppEmptyState(
                      title: '艺人加载失败',
                      message: '${detailAsync.error}',
                      icon: M3EIcons.error,
                      action: M3EButton(
                        style: M3EButtonStyle.tonal,
                        label: const Text('重试'),
                        onPressed: () => ref.invalidate(
                          neteaseArtistDetailProvider(widget.artist.id),
                        ),
                      ),
                    ),
                  )
                else
                  NeteaseTrackSliver(tracks: tracks, source: '网易云艺人'),
                SliverToBoxAdapter(
                  child: _ArtistAlbumsSection(artistId: artist.id),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxl + bottomInset),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class NeteaseArtistHotSongsPage extends ConsumerWidget {
  const NeteaseArtistHotSongsPage({super.key, required this.artist});

  final rust_netease.UiNeteaseArtist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final tracksAsync = ref.watch(neteaseArtistTopSongsProvider(artist.id));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageBar.subpage(
        title: l10n.topSongs,
        onSearch: () => openMobileSearch(context),
      ),
      body: tracksAsync.when(
        loading: () => const Center(
          child: NeteaseLoadingIndicator(semanticLabel: '正在加载艺人热门歌曲'),
        ),
        error: (error, _) => AppEmptyState(
          title: l10n.topSongs,
          message: '$error',
          icon: M3EIcons.error,
          action: M3EButton(
            style: M3EButtonStyle.tonal,
            label: const Text('重试'),
            onPressed: () =>
                ref.invalidate(neteaseArtistTopSongsProvider(artist.id)),
          ),
        ),
        data: (items) {
          final tracks = items.take(50).toList(growable: false);
          if (tracks.isEmpty) {
            return AppEmptyState(
              title: l10n.topSongs,
              message: '网易云没有返回热门歌曲',
              icon: M3EIcons.music_note,
            );
          }
          return CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.pageGutter,
                  ),
                  child: AppSectionHeader(
                    title: artist.name,
                    titleRole: AppTextRole.titleMedium,
                    padding: AppInsets.sectionHeader,
                  ),
                ),
              ),
              NeteaseTrackSliver(tracks: tracks, source: '网易云艺人'),
              SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxl + bottomInset),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArtistAlbumsSection extends ConsumerWidget {
  const _ArtistAlbumsSection({required this.artistId});

  final BigInt artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final albums = ref.watch(neteaseArtistAlbumsProvider(artistId));

    return albums.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: NeteaseLoadingIndicator(size: 40, semanticLabel: '正在加载艺人专辑'),
        ),
      ),
      error: (Object error, StackTrace stackTrace) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.pageGutter,
          vertical: AppSpacing.md,
        ),
        child: Text(
          '专辑加载失败：$error',
          style: theme.typeScale.bodySmall.copyWith(color: scheme.error),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.pageGutter,
              vertical: AppSpacing.md,
            ),
            child: Text('暂无专辑'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppLayout.pageGutter,
              ),
              child: AppSectionHeader(
                title: '专辑',
                titleRole: AppTextRole.titleMedium,
                padding: AppInsets.sectionHeader,
              ),
            ),
            SizedBox(
              height: 212,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: items.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (BuildContext context, int index) {
                  final album = items[index];
                  const cardWidth = 148.0;
                  return SizedBox(
                    width: cardWidth,
                    child: M3ECard(
                      variant: M3ECardVariant.filled,
                      padding: EdgeInsets.zero,
                      borderRadius: M3EDimensions.borderRadiusLarge,
                      clipBehavior: Clip.antiAlias,
                      onPressed: () {
                        prefetchNeteaseCover(ref, album.coverUrl);
                        pushMobileRootPage(
                          context,
                          NeteaseAlbumDetailPage(album: album),
                          name: MobileRoutes.libraryAlbums,
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          NeteaseCover(
                            url: album.coverUrl,
                            size: cardWidth,
                            fallbackIcon: M3EIcons.album,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  album.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.typeScale.titleSmall.copyWith(
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  _releaseYearLabel(
                                    album.publishTimeMs?.toInt(),
                                    l10n.yearUnknown,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.typeScale.bodySmall.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
