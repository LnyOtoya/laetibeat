import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../src/rust/api/netease.dart' as rust_netease;
import '../../../../widgets/settings/netease_provider.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../../settings/sources/netease/mobile_netease_login_page.dart';
import 'netease_album_artist_pages.dart';

class NeteaseArtistsPage extends ConsumerStatefulWidget {
  const NeteaseArtistsPage({super.key});

  @override
  ConsumerState<NeteaseArtistsPage> createState() => _NeteaseArtistsPageState();
}

class _NeteaseArtistsPageState extends ConsumerState<NeteaseArtistsPage> {
  final List<rust_netease.UiNeteaseArtist> _additionalItems = [];
  bool _isLoadingMore = false;
  bool _isNearEnd = false;
  bool _hasMore = true;
  Object? _loadMoreError;
  int _requestGeneration = 0;

  Future<void> _refresh() async {
    _resetPagination();
    await ref
        .refresh(neteaseSubscribedArtistsProvider.future)
        .then<void>((_) {});
  }

  void _retryInitialLoad() {
    _resetPagination();
    ref.invalidate(neteaseSubscribedArtistsProvider);
  }

  void _resetPagination() {
    _requestGeneration++;
    setState(() {
      _additionalItems.clear();
      _isLoadingMore = false;
      _isNearEnd = false;
      _hasMore = true;
      _loadMoreError = null;
    });
  }

  void _handleScroll(ScrollNotification notification, int firstPageCount) {
    if (notification.metrics.axis != Axis.vertical) return;
    final extentAfter = notification.metrics.extentAfter;
    if (extentAfter < 400) {
      if (!_isNearEnd) {
        _isNearEnd = true;
        debugPrint(
          '[NeteaseSubscriptionsPagination] artists near end: '
          'loaded=${firstPageCount + _additionalItems.length}, '
          'extentAfter=${extentAfter.toStringAsFixed(0)}',
        );
      }
      unawaited(_loadMore(firstPageCount));
    } else {
      _isNearEnd = false;
    }
  }

  Future<void> _loadMore(int firstPageCount) async {
    if (_isLoadingMore || !_hasMore || _loadMoreError != null) return;

    final offset = firstPageCount + _additionalItems.length;
    final generation = _requestGeneration;
    debugPrint(
      '[NeteaseSubscriptionsPagination] requesting artists: '
      'limit=$neteaseSubscriptionPageSize, offset=$offset',
    );
    setState(() => _isLoadingMore = true);
    try {
      final page = await ref.read(
        neteaseSubscribedArtistsPageProvider((
          limit: neteaseSubscriptionPageSize,
          offset: offset,
        )).future,
      );
      if (!mounted || generation != _requestGeneration) return;
      final hasMore = page.length == neteaseSubscriptionPageSize;
      debugPrint(
        '[NeteaseSubscriptionsPagination] artists received: '
        'offset=$offset, returned=${page.length}, hasMore=$hasMore',
      );
      setState(() {
        _additionalItems.addAll(page);
        _hasMore = hasMore;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      debugPrint(
        '[NeteaseSubscriptionsPagination] artists failed: '
        'offset=$offset, error=$error',
      );
      setState(() => _loadMoreError = error);
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final artists = ref.watch(neteaseSubscribedArtistsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageBar.subpage(
        title: '收藏的艺人',
        onSearch: () => openMobileSearch(context),
      ),
      body: artists.when(
        data: (items) {
          final visibleItems = <rust_netease.UiNeteaseArtist>[
            ...items,
            ..._additionalItems,
          ];
          if (visibleItems.isEmpty) {
            return const AppEmptyState(
              title: '收藏的艺人',
              message: '网易云没有返回收藏艺人',
              icon: M3EIcons.person,
            );
          }
          return Column(
            children: <Widget>[
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      _handleScroll(notification, items.length);
                      return false;
                    },
                    child: m3e_core.M3ESegmentedList.builder(
                      itemCount: visibleItems.length,
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      listPadding: const EdgeInsets.only(
                        top: AppSpacing.md,
                        bottom: AppSpacing.xxl,
                      ),
                      onTap: (int index) => pushMobileRootPage(
                        context,
                        NeteaseArtistDetailPage(artist: visibleItems[index]),
                        name: MobileRoutes.libraryArtists,
                      ),
                      decoration: _decoration,
                      itemBuilder: (BuildContext context, int index) {
                        final artist = visibleItems[index];
                        return m3e_core.M3EListItem(
                          headline: Text(artist.name),
                          supportingText: Text(
                            artist.alias.isEmpty
                                ? '${artist.albumSize} 张专辑'
                                : '${artist.alias.join(' / ')} · ${artist.albumSize} 张专辑',
                          ),
                          leading: _SubscriptionImage(
                            url: artist.coverUrl,
                            circular: true,
                            fallbackIcon: M3EIcons.person,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              _SubscriptionPageStatus(
                isLoading: _isLoadingMore,
                error: _loadMoreError,
                onRetry: () {
                  setState(() => _loadMoreError = null);
                  unawaited(_loadMore(items.length));
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _SubscriptionError(
          message: '$error',
          onRetry: _retryInitialLoad,
          onLogin: () => _openLogin(context, ref),
        ),
      ),
    );
  }
}

class NeteaseAlbumsPage extends ConsumerStatefulWidget {
  const NeteaseAlbumsPage({super.key});

  @override
  ConsumerState<NeteaseAlbumsPage> createState() => _NeteaseAlbumsPageState();
}

class _NeteaseAlbumsPageState extends ConsumerState<NeteaseAlbumsPage> {
  final List<rust_netease.UiNeteaseAlbum> _additionalItems = [];
  bool _isLoadingMore = false;
  bool _isNearEnd = false;
  bool _hasMore = true;
  Object? _loadMoreError;
  int _requestGeneration = 0;

  Future<void> _refresh() async {
    _resetPagination();
    await ref
        .refresh(neteaseSubscribedAlbumsProvider.future)
        .then<void>((_) {});
  }

  void _retryInitialLoad() {
    _resetPagination();
    ref.invalidate(neteaseSubscribedAlbumsProvider);
  }

  void _resetPagination() {
    _requestGeneration++;
    setState(() {
      _additionalItems.clear();
      _isLoadingMore = false;
      _isNearEnd = false;
      _hasMore = true;
      _loadMoreError = null;
    });
  }

  void _handleScroll(ScrollNotification notification, int firstPageCount) {
    if (notification.metrics.axis != Axis.vertical) return;
    final extentAfter = notification.metrics.extentAfter;
    if (extentAfter < 400) {
      if (!_isNearEnd) {
        _isNearEnd = true;
        debugPrint(
          '[NeteaseSubscriptionsPagination] albums near end: '
          'loaded=${firstPageCount + _additionalItems.length}, '
          'extentAfter=${extentAfter.toStringAsFixed(0)}',
        );
      }
      unawaited(_loadMore(firstPageCount));
    } else {
      _isNearEnd = false;
    }
  }

  Future<void> _loadMore(int firstPageCount) async {
    if (_isLoadingMore || !_hasMore || _loadMoreError != null) return;

    final offset = firstPageCount + _additionalItems.length;
    final generation = _requestGeneration;
    debugPrint(
      '[NeteaseSubscriptionsPagination] requesting albums: '
      'limit=$neteaseSubscriptionPageSize, offset=$offset',
    );
    setState(() => _isLoadingMore = true);
    try {
      final page = await ref.read(
        neteaseSubscribedAlbumsPageProvider((
          limit: neteaseSubscriptionPageSize,
          offset: offset,
        )).future,
      );
      if (!mounted || generation != _requestGeneration) return;
      final hasMore = page.length == neteaseSubscriptionPageSize;
      debugPrint(
        '[NeteaseSubscriptionsPagination] albums received: '
        'offset=$offset, returned=${page.length}, hasMore=$hasMore',
      );
      setState(() {
        _additionalItems.addAll(page);
        _hasMore = hasMore;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      debugPrint(
        '[NeteaseSubscriptionsPagination] albums failed: '
        'offset=$offset, error=$error',
      );
      setState(() => _loadMoreError = error);
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final albums = ref.watch(neteaseSubscribedAlbumsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageBar.subpage(
        title: '收藏的专辑',
        onSearch: () => openMobileSearch(context),
      ),
      body: albums.when(
        data: (items) {
          final visibleItems = <rust_netease.UiNeteaseAlbum>[
            ...items,
            ..._additionalItems,
          ];
          if (visibleItems.isEmpty) {
            return const AppEmptyState(
              title: '收藏的专辑',
              message: '网易云没有返回收藏专辑',
              icon: M3EIcons.album,
            );
          }
          return Column(
            children: <Widget>[
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      _handleScroll(notification, items.length);
                      return false;
                    },
                    child: m3e_core.M3ESegmentedList.builder(
                      itemCount: visibleItems.length,
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      listPadding: const EdgeInsets.only(
                        top: AppSpacing.md,
                        bottom: AppSpacing.xxl,
                      ),
                      onTap: (int index) => pushMobileRootPage(
                        context,
                        NeteaseAlbumDetailPage(album: visibleItems[index]),
                        name: MobileRoutes.libraryAlbums,
                      ),
                      decoration: _decoration,
                      itemBuilder: (BuildContext context, int index) {
                        final album = visibleItems[index];
                        return m3e_core.M3EListItem(
                          headline: Text(album.name),
                          supportingText: Text(
                            '${album.artist} · ${album.trackCount} 首',
                          ),
                          leading: _SubscriptionImage(
                            url: album.coverUrl,
                            fallbackIcon: M3EIcons.album,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              _SubscriptionPageStatus(
                isLoading: _isLoadingMore,
                error: _loadMoreError,
                onRetry: () {
                  setState(() => _loadMoreError = null);
                  unawaited(_loadMore(items.length));
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _SubscriptionError(
          message: '$error',
          onRetry: _retryInitialLoad,
          onLogin: () => _openLogin(context, ref),
        ),
      ),
    );
  }
}

class _SubscriptionPageStatus extends StatelessWidget {
  const _SubscriptionPageStatus({
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final bool isLoading;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: <Widget>[
          Text('加载更多失败：$error'),
          M3EButton(
            style: M3EButtonStyle.tonal,
            label: const Text('重试'),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

const m3e_core.M3ESegmentedListDecoration _decoration =
    m3e_core.M3ESegmentedListDecoration(
      outerRadius: 24,
      innerRadius: 16,
      pressedRadius: 8,
      pressedScale: 0.98,
      hoveredRadius: 16,
      selectedRadius: 28,
      gap: 6,
      padding: EdgeInsets.all(4),
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    );

Future<void> _openLogin(BuildContext context, WidgetRef ref) async {
  await pushMobileRootPage<bool>(
    context,
    const MobileNeteaseLoginPage(),
    name: MobileRoutes.neteaseLogin,
  );
  ref.invalidate(neteaseSubscribedArtistsProvider);
  ref.invalidate(neteaseSubscribedAlbumsProvider);
}

class _SubscriptionImage extends ConsumerWidget {
  const _SubscriptionImage({
    required this.url,
    required this.fallbackIcon,
    this.circular = false,
  });

  final String? url;
  final IconData fallbackIcon;
  final bool circular;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final value = url;
    final bytes = value == null || value.isEmpty
        ? null
        : ref.watch(neteaseImageProvider(value)).value;
    return ClipRRect(
      borderRadius: circular
          ? const BorderRadius.all(Radius.circular(24))
          : AppRadii.smAll,
      child: SizedBox.square(
        dimension: 48,
        child: bytes == null || bytes.isEmpty
            ? ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  fallbackIcon,
                  size: AppIconSize.md,
                  color: scheme.onSecondaryContainer,
                ),
              )
            : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }
}

class _SubscriptionError extends StatelessWidget {
  const _SubscriptionError({
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
      title: needsLogin ? '需要登录网易云' : '加载失败',
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
