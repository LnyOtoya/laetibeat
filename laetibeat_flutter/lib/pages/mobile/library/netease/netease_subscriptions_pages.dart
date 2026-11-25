import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../widgets/settings/netease_provider.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../../settings/sources/netease/mobile_netease_login_page.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';
import 'netease_album_artist_pages.dart';

class NeteaseArtistsPage extends ConsumerWidget {
  const NeteaseArtistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final artists = ref.watch(neteaseSubscribedArtistsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: '收藏的艺人'),
      body: artists.when(
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(
              title: '收藏的艺人',
              message: '网易云没有返回收藏艺人',
              icon: M3EIcons.person,
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.refresh(neteaseSubscribedArtistsProvider.future),
            child: m3e_core.M3ESegmentedList.builder(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              listPadding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xxl,
              ),
              onTap: (int index) => pushMobileRootPage(
                context,
                NeteaseArtistDetailPage(artist: items[index]),
                name: MobileRoutes.libraryArtists,
              ),
              decoration: _decoration,
              itemBuilder: (BuildContext context, int index) {
                final artist = items[index];
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _SubscriptionError(
          message: '$error',
          onRetry: () => ref.invalidate(neteaseSubscribedArtistsProvider),
          onLogin: () => _openLogin(context, ref),
        ),
      ),
    );
  }
}

class NeteaseAlbumsPage extends ConsumerWidget {
  const NeteaseAlbumsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final albums = ref.watch(neteaseSubscribedAlbumsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: '收藏的专辑'),
      body: albums.when(
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(
              title: '收藏的专辑',
              message: '网易云没有返回收藏专辑',
              icon: M3EIcons.album,
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.refresh(neteaseSubscribedAlbumsProvider.future),
            child: m3e_core.M3ESegmentedList.builder(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              listPadding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xxl,
              ),
              onTap: (int index) => pushMobileRootPage(
                context,
                NeteaseAlbumDetailPage(album: items[index]),
                name: MobileRoutes.libraryAlbums,
              ),
              decoration: _decoration,
              itemBuilder: (BuildContext context, int index) {
                final album = items[index];
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _SubscriptionError(
          message: '$error',
          onRetry: () => ref.invalidate(neteaseSubscribedAlbumsProvider),
          onLogin: () => _openLogin(context, ref),
        ),
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
