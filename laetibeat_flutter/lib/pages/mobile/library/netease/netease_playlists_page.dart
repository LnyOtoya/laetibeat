import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
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
import '../../settings/sources/netease/mobile_netease_login_page.dart';
import 'netease_detail_widgets.dart';

/// 当前登录用户的网易云歌单列表。
class NeteasePlaylistsPage extends ConsumerWidget {
  const NeteasePlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final playlists = ref.watch(neteaseUserPlaylistsProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppPageBar.subpage(
        title: '我的在线歌单',
        onSearch: () => openMobileSearch(context),
      ),
      body: playlists.when(
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(
              title: '我的在线歌单',
              message: '网易云没有返回歌单',
              icon: M3EIcons.queue_music,
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(neteaseUserPlaylistsProvider.future),
            child: m3e_core.M3ESegmentedList.builder(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              listPadding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xxl,
              ),
              onTap: (int index) {
                final playlist = items[index];
                pushMobileRootPage(
                  context,
                  NeteasePlaylistDetailPage(playlist: playlist),
                  name: MobileRoutes.libraryPlaylists,
                );
              },
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
                final playlist = items[index];
                return m3e_core.M3EListItem(
                  minHeight: 64,
                  headline: Text(playlist.name),
                  supportingText: Text(
                    <String>[
                      if (playlist.creator != null) playlist.creator!,
                      '${playlist.trackCount} 首',
                    ].join(' · '),
                  ),
                  headlineStyle: theme.typeScale.bodyLarge.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                  supportingTextStyle: theme.typeScale.bodyMedium.copyWith(
                    color: scheme.onSecondaryContainer.withValues(alpha: 0.75),
                  ),
                  leading: _NeteasePlaylistCover(url: playlist.coverUrl),
                  trailing: Icon(
                    M3EIcons.chevron_right,
                    size: 20,
                    color: scheme.onSecondaryContainer,
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: NeteaseLoadingIndicator()),
        error: (error, _) => _PlaylistError(
          message: '$error',
          onRetry: () => ref.invalidate(neteaseUserPlaylistsProvider),
          onLogin: () async {
            await pushMobileRootPage<bool>(
              context,
              const MobileNeteaseLoginPage(),
              name: MobileRoutes.neteaseLogin,
            );
            ref.invalidate(neteaseUserPlaylistsProvider);
          },
        ),
      ),
    );
  }
}

/// 网易云歌单详情。
class NeteasePlaylistDetailPage extends ConsumerStatefulWidget {
  const NeteasePlaylistDetailPage({super.key, required this.playlist});

  final rust_netease.UiNeteasePlaylist playlist;

  @override
  ConsumerState<NeteasePlaylistDetailPage> createState() =>
      _NeteasePlaylistDetailPageState();
}

class _NeteasePlaylistDetailPageState
    extends ConsumerState<NeteasePlaylistDetailPage> {
  static const double _barTintDistance = 120;
  static const int _trackPageSize = neteasePlaylistTracksPageSize;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _barProgress = ValueNotifier<double>(0);
  final List<rust.UiTrack> _additionalTracks = <rust.UiTrack>[];
  bool _isLoadingMoreTracks = false;
  bool _isNearPaginationThreshold = false;
  bool _hasMoreTracks = true;
  Object? _loadMoreTracksError;

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
    final extentAfter = _scrollController.position.extentAfter;
    if (extentAfter < 400) {
      if (!_isNearPaginationThreshold) {
        _isNearPaginationThreshold = true;
        debugPrint(
          '[NeteasePlaylistPagination] near end: '
          'playlist=${widget.playlist.id}, '
          'extentAfter=${extentAfter.toStringAsFixed(0)}, '
          'scrollOffset=${_scrollController.offset.toStringAsFixed(0)}',
        );
      }
      unawaited(_loadMoreTracks());
    } else {
      _isNearPaginationThreshold = false;
    }
  }

  Future<void> _loadMoreTracks() async {
    if (_isLoadingMoreTracks || !_hasMoreTracks || _loadMoreTracksError != null) {
      return;
    }

    final firstPage = ref
        .read(neteasePlaylistTracksProvider(widget.playlist.id))
        .value;
    if (firstPage == null) {
      debugPrint(
        '[NeteasePlaylistPagination] skipped: initial page not ready, '
        'playlist=${widget.playlist.id}',
      );
      return;
    }

    final offset = firstPage.length + _additionalTracks.length;
    if (offset >= widget.playlist.trackCount) {
      debugPrint(
        '[NeteasePlaylistPagination] reached trackCount: '
        'playlist=${widget.playlist.id}, loaded=$offset, '
        'trackCount=${widget.playlist.trackCount}',
      );
      _hasMoreTracks = false;
      return;
    }

    debugPrint(
      '[NeteasePlaylistPagination] requesting page: '
      'playlist=${widget.playlist.id}, offset=$offset, limit=$_trackPageSize, '
      'loaded=${firstPage.length + _additionalTracks.length}, '
      'trackCount=${widget.playlist.trackCount}',
    );
    setState(() => _isLoadingMoreTracks = true);
    try {
      final page = await ref.read(
        neteasePlaylistTracksPageProvider((
          playlistId: widget.playlist.id,
          limit: _trackPageSize,
          offset: offset,
        )).future,
      );
      if (!mounted) return;
      final hasMore =
          page.length == _trackPageSize &&
          offset + page.length < widget.playlist.trackCount;
      debugPrint(
        '[NeteasePlaylistPagination] page received: '
        'playlist=${widget.playlist.id}, offset=$offset, '
        'returned=${page.length}, '
        'totalLoaded=${firstPage.length + _additionalTracks.length + page.length}, '
        'hasMore=$hasMore',
      );
      setState(() {
        _additionalTracks.addAll(page);
        _hasMoreTracks = hasMore;
      });
    } catch (error) {
      debugPrint(
        '[NeteasePlaylistPagination] page request failed: '
        'playlist=${widget.playlist.id}, offset=$offset, error=$error',
      );
      if (!mounted) return;
      setState(() => _loadMoreTracksError = error);
    } finally {
      if (mounted) {
        setState(() => _isLoadingMoreTracks = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = M3ETheme.of(context);
    final playlist = widget.playlist;
    final tracksAsync = ref.watch(neteasePlaylistTracksProvider(playlist.id));
    final tracks = <rust.UiTrack>[
      ...tracksAsync.value ?? const <rust.UiTrack>[],
      ..._additionalTracks,
    ];

    final coverUrl = playlist.coverUrl;
    final bytes = coverUrl == null || coverUrl.isEmpty
        ? null
        : ref.watch(neteasePlaylistCoverProvider(coverUrl)).value;
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

    final favoriteKey = 'netease:playlist:${playlist.id}';
    final isFavorite = ref.watch(
      favoritePlaylistsProvider.select((ids) => ids.contains(favoriteKey)),
    );

    void togglePlayback() {
      final notifier = ref.read(playerProvider.notifier);
      if (isCurrent) {
        notifier.toggle();
        return;
      }
      if (tracks.isEmpty) return;
      notifier.load(tracks, 0, source: '网易云歌单');
    }

    void shufflePlay() {
      if (tracks.isEmpty) return;
      ref.read(playerProvider.notifier).playShuffled(tracks, source: '网易云歌单');
    }

    return M3ETheme(
      data: baseTheme.withColorScheme(scheme),
      child: Scaffold(
        backgroundColor: contentColor,
        extendBodyBehindAppBar: true,
        appBar: NeteaseDetailAppBar(progress: _barProgress, tint: contentColor),
        body: CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: NeteaseDetailHero(
                bytes: bytes,
                fallbackIcon: M3EIcons.queue_music,
              ),
            ),
            SliverToBoxAdapter(
              child: NeteaseSummary(
                title: playlist.name,
                subtitle: playlist.creator ?? '网易云歌单',
                meta: '${playlist.trackCount} 首',
                isPlaying: isPlaying,
                playEnabled: tracks.isNotEmpty,
                isFavorite: isFavorite,
                onShuffle: shufflePlay,
                onPlayPause: togglePlayback,
                onFavorite: () => ref
                    .read(favoritePlaylistsProvider.notifier)
                    .toggle(favoriteKey),
              ),
            ),
            tracksAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(
                    child: NeteaseLoadingIndicator(
                      size: 40,
                      semanticLabel: '正在加载歌单歌曲',
                    ),
                  ),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: AppEmptyState(
                  title: '歌单加载失败',
                  message: '$error',
                  icon: M3EIcons.error,
                  action: M3EButton(
                    style: M3EButtonStyle.tonal,
                    label: const Text('重试'),
                    onPressed: () => ref.invalidate(
                      neteasePlaylistTracksProvider(playlist.id),
                    ),
                  ),
                ),
              ),
              data: (items) => NeteaseTrackSliver(
                tracks: <rust.UiTrack>[...items, ..._additionalTracks],
                source: '网易云歌单',
              ),
            ),
            if (_isLoadingMoreTracks)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: NeteaseLoadingIndicator(
                      size: 36,
                      semanticLabel: '正在加载更多歌曲',
                    ),
                  ),
                ),
              ),
            if (_loadMoreTracksError case final error?)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: <Widget>[
                      Text('后续歌曲加载失败：$error'),
                      M3EButton(
                        style: M3EButtonStyle.tonal,
                        label: const Text('重试'),
                        onPressed: () {
                          setState(() => _loadMoreTracksError = null);
                          unawaited(_loadMoreTracks());
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }
}

class _NeteasePlaylistCover extends ConsumerWidget {
  const _NeteasePlaylistCover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final cacheSize = (48 * MediaQuery.devicePixelRatioOf(context)).round();
    final value = url;
    final bytes = value == null || value.isEmpty
        ? null
        : ref.watch(neteasePlaylistCoverProvider(value)).value;

    return ClipRRect(
      borderRadius: AppRadii.smAll,
      child: SizedBox.square(
        dimension: 48,
        child: bytes == null || bytes.isEmpty
            ? ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  M3EIcons.queue_music,
                  size: AppIconSize.md,
                  color: scheme.onSurfaceVariant,
                ),
              )
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: cacheSize,
                cacheHeight: cacheSize,
              ),
      ),
    );
  }
}

class _PlaylistError extends StatelessWidget {
  const _PlaylistError({
    required this.message,
    required this.onRetry,
    required this.onLogin,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final needsLogin = message.contains('请先登录');
    return AppEmptyState(
      title: needsLogin ? '需要登录网易云' : '歌单加载失败',
      message: message,
      icon: needsLogin ? M3EIcons.login : M3EIcons.error,
      action: needsLogin
          ? M3EButton(label: const Text('登录网易云'), onPressed: onLogin)
          : M3EButton(
              style: M3EButtonStyle.tonal,
              label: const Text('重试'),
              onPressed: onRetry,
            ),
    );
  }
}
