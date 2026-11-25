import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../src/rust/api/netease.dart' as rust_netease;
import '../../../../src/rust/api/simple.dart' as rust;
import '../../../../widgets/player/cover_provider.dart';
import '../../../../widgets/player/player_provider.dart';
import '../../../../widgets/settings/netease_provider.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../../settings/sources/netease/mobile_netease_login_page.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';

/// 当前登录用户的网易云歌单列表。
class NeteasePlaylistsPage extends ConsumerWidget {
  const NeteasePlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final playlists = ref.watch(neteaseUserPlaylistsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: '我的在线歌单'),
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
                final playlist = items[index];
                return m3e_core.M3EListItem(
                  headline: Text(playlist.name),
                  supportingText: Text(
                    [
                      if (playlist.creator != null) playlist.creator!,
                      '${playlist.trackCount} 首',
                    ].join(' · '),
                  ),
                  leading: _NeteasePlaylistCover(url: playlist.coverUrl),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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

/// 歌单详情：歌单歌曲列表，点击后直接播放。
class NeteasePlaylistDetailPage extends ConsumerWidget {
  const NeteasePlaylistDetailPage({super.key, required this.playlist});

  final rust_netease.UiNeteasePlaylist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final tracks = ref.watch(neteasePlaylistTracksProvider(playlist.id));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: playlist.name),
      body: tracks.when(
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(
              title: '歌单',
              message: '这个歌单还没有歌曲',
              icon: M3EIcons.music_note,
            );
          }
          return m3e_core.M3ESegmentedList.builder(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            listPadding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.xxl,
            ),
            onTap: (int index) {
              ref
                  .read(playerProvider.notifier)
                  .load(items, index, source: '网易云歌单');
            },
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
              final track = items[index];
              return m3e_core.M3EListItem(
                headline: Text(track.title),
                supportingText: Text(track.artist),
                leading: _NeteaseTrackCover(track: track),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppEmptyState(
          title: '歌单加载失败',
          message: '$error',
          icon: M3EIcons.error,
          action: M3EButton(
            style: M3EButtonStyle.tonal,
            label: const Text('重试'),
            onPressed: () =>
                ref.invalidate(neteasePlaylistTracksProvider(playlist.id)),
          ),
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
                color: scheme.secondaryContainer,
                child: Icon(
                  M3EIcons.queue_music,
                  size: AppIconSize.md,
                  color: scheme.onSecondaryContainer,
                ),
              )
            : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }
}

class _NeteaseTrackCover extends ConsumerWidget {
  const _NeteaseTrackCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final bytes = ref.watch(trackCoverProvider(track)).value;

    return ClipRRect(
      borderRadius: AppRadii.xsAll,
      child: SizedBox.square(
        dimension: 40,
        child: bytes == null || bytes.isEmpty
            ? ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  M3EIcons.music_note,
                  size: AppIconSize.sm,
                  color: scheme.onSecondaryContainer,
                ),
              )
            : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
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
