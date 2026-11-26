import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../src/rust/api/netease.dart' as rust_netease;
import '../../../../src/rust/api/simple.dart' as rust;
import '../../../../widgets/player/player_provider.dart';
import '../../../../widgets/settings/favorites_provider.dart';
import '../../../../widgets/settings/netease_provider.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import 'netease_detail_widgets.dart';

Uint8List? _coverBytes(WidgetRef ref, String? url) {
  if (url == null || url.isEmpty) return null;
  return ref.watch(neteaseImageProvider(url)).value;
}

String _releaseLabel(int? milliseconds) {
  if (milliseconds == null || milliseconds <= 0) return '发行日期: 未知';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '发行日期: ${date.year}-$month-$day';
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
    final baseTheme = M3ETheme.of(context);
    final detailAsync = ref.watch(neteaseAlbumDetailProvider(widget.album.id));
    final album = detailAsync.value?.album ?? widget.album;
    final tracks = detailAsync.value?.tracks ?? const <rust.UiTrack>[];

    final bytes = _coverBytes(ref, album.coverUrl);
    final coverColor = bytes == null
        ? null
        : ref.watch(neteaseCoverColorProvider(bytes)).value;
    final scheme = coverColor == null
        ? baseTheme.colorScheme
        : MaterialYouColorScheme.fromSeed(
            coverColor,
            brightness: baseTheme.colorScheme.brightness,
          );
    final contentColor = detailContentColor(scheme);

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

    return M3ETheme(
      data: baseTheme.withColorScheme(scheme),
      child: Scaffold(
        backgroundColor: contentColor,
        extendBodyBehindAppBar: true,
        appBar: NeteaseDetailAppBar(progress: _barProgress, tint: contentColor),
        body: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => AppEmptyState(
            title: '专辑加载失败',
            message: '$error',
            icon: M3EIcons.error,
            action: M3EButton(
              style: M3EButtonStyle.tonal,
              label: const Text('重试'),
              onPressed: () =>
                  ref.invalidate(neteaseAlbumDetailProvider(widget.album.id)),
            ),
          ),
          data: (value) {
            final loaded = value.album;
            return CustomScrollView(
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
                    title: loaded.name,
                    subtitle: loaded.artist,
                    meta: _releaseLabel(loaded.publishTimeMs?.toInt()),
                    isPlaying: isPlaying,
                    playEnabled: value.tracks.isNotEmpty,
                    isFavorite: isFavorite,
                    onShuffle: shufflePlay,
                    onPlayPause: togglePlayback,
                    onFavorite: () => ref
                        .read(favoriteAlbumsProvider.notifier)
                        .toggle(favoriteKey),
                  ),
                ),
                NeteaseTrackSliver(tracks: value.tracks, source: '网易云专辑'),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxl),
                ),
              ],
            );
          },
        ),
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
    final baseTheme = M3ETheme.of(context);
    final detailAsync = ref.watch(
      neteaseArtistDetailProvider(widget.artist.id),
    );
    final artist = detailAsync.value?.artist ?? widget.artist;
    final tracks = detailAsync.value?.tracks ?? const <rust.UiTrack>[];

    final bytes = _coverBytes(ref, artist.coverUrl);
    final coverColor = bytes == null
        ? null
        : ref.watch(neteaseCoverColorProvider(bytes)).value;
    final scheme = coverColor == null
        ? baseTheme.colorScheme
        : MaterialYouColorScheme.fromSeed(
            coverColor,
            brightness: baseTheme.colorScheme.brightness,
          );
    final contentColor = detailContentColor(scheme);

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

    return M3ETheme(
      data: baseTheme.withColorScheme(scheme),
      child: Scaffold(
        backgroundColor: contentColor,
        extendBodyBehindAppBar: true,
        appBar: NeteaseDetailAppBar(progress: _barProgress, tint: contentColor),
        body: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => AppEmptyState(
            title: '艺人加载失败',
            message: '$error',
            icon: M3EIcons.error,
            action: M3EButton(
              style: M3EButtonStyle.tonal,
              label: const Text('重试'),
              onPressed: () =>
                  ref.invalidate(neteaseArtistDetailProvider(widget.artist.id)),
            ),
          ),
          data: (value) {
            final loaded = value.artist;
            final alias = loaded.alias.isEmpty
                ? '网易云艺人'
                : loaded.alias.join(' / ');
            return CustomScrollView(
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
                    title: loaded.name,
                    subtitle: alias,
                    meta: '${loaded.albumSize} 张专辑',
                    isPlaying: isPlaying,
                    playEnabled: value.tracks.isNotEmpty,
                    isFavorite: isFavorite,
                    onShuffle: shufflePlay,
                    onPlayPause: togglePlayback,
                    onFavorite: () => ref
                        .read(favoriteArtistsProvider.notifier)
                        .toggle(favoriteKey),
                  ),
                ),
                NeteaseTrackSliver(tracks: value.tracks, source: '网易云艺人'),
                SliverToBoxAdapter(
                  child: _ArtistAlbumsSection(artistId: loaded.id),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxl),
                ),
              ],
            );
          },
        ),
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
    final albums = ref.watch(neteaseArtistAlbumsProvider(artistId));

    return albums.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
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
            m3e_core.M3ESegmentedList.builder(
              listPadding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              onTap: (int index) => pushMobileRootPage(
                context,
                NeteaseAlbumDetailPage(album: items[index]),
                name: MobileRoutes.libraryAlbums,
              ),
              decoration: m3e_core.M3ESegmentedListDecoration(
                color: scheme.secondaryContainer,
                splashColor: scheme.onSecondaryContainer.withValues(
                  alpha: 0.12,
                ),
                highlightColor: scheme.onSecondaryContainer.withValues(
                  alpha: 0.08,
                ),
                hoverColor: scheme.onSecondaryContainer.withValues(alpha: 0.08),
                outerRadius: 24,
                innerRadius: 12,
                pressedRadius: 8,
                pressedScale: 0.98,
                hoveredRadius: 16,
                gap: 4,
                padding: const EdgeInsets.all(4),
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
              ),
              itemBuilder: (BuildContext context, int index) {
                final album = items[index];
                return m3e_core.M3EListItem(
                  minHeight: 64,
                  leading: NeteaseCover(
                    url: album.coverUrl,
                    size: 48,
                    fallbackIcon: M3EIcons.album,
                  ),
                  headline: Text(album.name),
                  supportingText: Text(
                    '${album.artist} · ${album.trackCount} 首',
                  ),
                  headlineStyle: theme.typeScale.bodyLarge.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                  supportingTextStyle: theme.typeScale.bodyMedium.copyWith(
                    color: scheme.onSecondaryContainer.withValues(alpha: 0.75),
                  ),
                  trailing: Icon(
                    M3EIcons.chevron_right,
                    size: 20,
                    color: scheme.onSecondaryContainer,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
