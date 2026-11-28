import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/online.dart' as rust_online;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../app/app_mode.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/layout/app_bottom_inset.dart';
import '../../../widgets/player/player_provider.dart';
import '../../../widgets/settings/mode_host.dart';
import '../../../widgets/settings/online_provider.dart';
import '../../../widgets/settings/online_settings.dart';
import '../library/online/online_detail_pages.dart';
import '../library/online/online_widgets.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import '../settings/mode/mobile_mode_settings_page.dart';
import '../settings/online/mobile_online_login_page.dart';
import 'discover_platform.dart';

/// 移动端发现页。
///
/// 当前只展示网易云 / QQ 两个平台的通用内容：推荐歌单、排行榜、热门歌曲。
/// 平台由 AppBar 图标切换并持久化；我的歌单等待登录能力接入。
class MobileDiscoverPage extends ConsumerWidget {
  const MobileDiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final appMode = ref.watch(appModeProvider);
    final platform = switch (appMode) {
      AppMode.qq => DiscoverPlatform.qq,
      AppMode.netease => DiscoverPlatform.netease,
      _ => ref.watch(discoverPlatformProvider),
    };
    final baseUrl = ref.watch(onlineBaseUrlProvider);
    final modeHost = ref.watch(modeHostProvider);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return AppScaffold(
      background: AppSurfaceLevel.base,
      applyPageGutter: false,
      safeArea: false,
      appBar: AppPageBar.tab(
        title: l10n.navDiscover,
        subtitle: '${l10n.discoverSubtitle} · ${platform.label}',
        backgroundColor: mobileTabBarBackground(ref, scheme),
        actionsBuilder: (bool _) => mobileTabBarActions(context),
      ),
      body: baseUrl.isEmpty
          ? _buildOnlinePlaceholder(
              context,
              ref,
              appMode: appMode,
              modeHost: modeHost,
              bottomInset: bottomInset,
            )
          : M3ERefreshIndicator(
              onRefresh: () => _refresh(ref, platform),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: AppSpacing.lg,
                  bottom: AppSpacing.xl + bottomInset,
                ),
                children: <Widget>[
                  _RecommendPlaylistsSection(source: platform.source),
                  const SizedBox(height: AppSpacing.xl),
                  _TopListsSection(source: platform.source),
                  const SizedBox(height: AppSpacing.xl),
                  _HotSongsSection(source: platform.source),
                  const SizedBox(height: AppSpacing.xl),
                  _MyPlaylistsSection(platform: platform),
                ],
              ),
            ),
    );
  }

  Widget _buildOnlinePlaceholder(
    BuildContext context,
    WidgetRef ref, {
    required AppMode appMode,
    required ModeHostState modeHost,
    required double bottomInset,
  }) {
    if (!appMode.usesOnlineHost) {
      return _OnlineModeUnavailable(bottomInset: bottomInset);
    }
    if (modeHost.isStarting) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text('正在启动 ${appMode.label} sidecar…'),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: AppEmptyState(
          title: modeHost.hasError
              ? '${appMode.label} sidecar 启动失败'
              : '${appMode.label} sidecar 未启动',
          message: modeHost.error ?? '点击启动本地 sidecar；无需额外部署。',
          icon: modeHost.hasError ? M3EIcons.error_outline : M3EIcons.cloud_off,
          action: M3EButton(
            style: M3EButtonStyle.filled,
            label: Text(modeHost.hasError ? '重试' : '启动'),
            onPressed: () => ref.read(modeHostProvider.notifier).start(),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref, DiscoverPlatform platform) async {
    await onlineClearCache(ref);
    final source = platform.source;
    ref.invalidate(onlineRecommendPlaylistsProvider(source));
    ref.invalidate(onlineTopListsProvider(source));
    ref.invalidate(onlineHotSongsProvider((source: source, limit: 20)));
    final refreshes = <Future<Object?>>[
      ref.read(onlineRecommendPlaylistsProvider(source).future),
      ref.read(onlineTopListsProvider(source).future),
      ref.read(onlineHotSongsProvider((source: source, limit: 20)).future),
    ];
    for (final future in refreshes) {
      try {
        await future;
      } catch (_) {
        // 错误由对应 provider 状态展示。
      }
    }
  }
}

class _OnlineModeUnavailable extends StatelessWidget {
  const _OnlineModeUnavailable({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: AppEmptyState(
          title: '当前模式不使用在线音源',
          message: '本地 / Subsonic 模式不启动在线 sidecar。切换到 QQ 或网易云后，这里会显示推荐、榜单和热门。',
          icon: M3EIcons.cloud_off,
          action: M3EButton(
            style: M3EButtonStyle.filled,
            label: const Text('切换模式'),
            onPressed: () => pushMobileRootPage(
              context,
              const MobileModeSettingsPage(),
              name: MobileRoutes.modeSettings,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  const _SectionContainer({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSectionHeader(title: title, titleRole: AppTextRole.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading({this.height = 180});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadii.mdAll,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: theme.typeScale.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onRetry != null)
            M3EButton(
              style: M3EButtonStyle.tonal,
              size: M3EButtonSize.sm,
              label: const Text('重试'),
              onPressed: onRetry,
            ),
        ],
      ),
    );
  }
}

class _RecommendPlaylistsSection extends ConsumerWidget {
  const _RecommendPlaylistsSection({required this.source});

  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(onlineRecommendPlaylistsProvider(source));
    return _SectionContainer(
      title: '推荐歌单',
      child: async.when(
        loading: () => const _SectionLoading(),
        error: (Object error, StackTrace? stack) => _SectionMessage(
          message: '加载失败：$error',
          onRetry: () =>
              ref.invalidate(onlineRecommendPlaylistsProvider(source)),
        ),
        data: (List<rust_online.UiOnlinePlaylist> playlists) {
          if (playlists.isEmpty) {
            return const _SectionMessage(message: '暂无推荐歌单');
          }
          return SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: playlists.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (BuildContext context, int index) {
                final playlist = playlists[index];
                return _PlaylistCard(playlist: playlist);
              },
            ),
          );
        },
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist});

  final rust_online.UiOnlinePlaylist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushMobileRootPage(
        context,
        OnlinePlaylistDetailPage(playlist: playlist),
        name: 'online-playlist',
      ),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            OnlineCover(url: playlist.coverUrl, size: 140),
            const SizedBox(height: AppSpacing.xs),
            Text(
              playlist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.typeScale.bodyMedium,
            ),
            if (playlist.creator != null && playlist.creator!.isNotEmpty)
              Text(
                playlist.creator!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typeScale.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopListsSection extends ConsumerWidget {
  const _TopListsSection({required this.source});

  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(onlineTopListsProvider(source));
    return _SectionContainer(
      title: '排行榜',
      child: async.when(
        loading: () => const _SectionLoading(),
        error: (Object error, StackTrace? stack) => _SectionMessage(
          message: '加载失败：$error',
          onRetry: () => ref.invalidate(onlineTopListsProvider(source)),
        ),
        data: (List<rust_online.UiOnlineTopList> topLists) {
          if (topLists.isEmpty) {
            return const _SectionMessage(message: '暂无排行榜');
          }
          return SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: topLists.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (BuildContext context, int index) {
                final topList = topLists[index];
                return _TopListCard(topList: topList);
              },
            ),
          );
        },
      ),
    );
  }
}

class _TopListCard extends StatelessWidget {
  const _TopListCard({required this.topList});

  final rust_online.UiOnlineTopList topList;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushMobileRootPage(
        context,
        OnlineTopListDetailPage(topList: topList),
        name: 'online-toplist',
      ),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            OnlineCover(url: topList.coverUrl, size: 140),
            const SizedBox(height: AppSpacing.xs),
            Text(
              topList.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typeScale.bodyMedium,
            ),
            if (topList.updateFrequency != null &&
                topList.updateFrequency!.isNotEmpty)
              Text(
                topList.updateFrequency!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typeScale.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HotSongsSection extends ConsumerWidget {
  const _HotSongsSection({required this.source});

  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (source: source, limit: 20);
    final async = ref.watch(onlineHotSongsProvider(key));
    return _SectionContainer(
      title: '热门歌曲',
      child: async.when(
        loading: () => const _SectionLoading(height: 240),
        error: (Object error, StackTrace? stack) => _SectionMessage(
          message: '加载失败：$error',
          onRetry: () => ref.invalidate(onlineHotSongsProvider(key)),
        ),
        data: (List<rust.UiTrack> tracks) {
          if (tracks.isEmpty) {
            return const _SectionMessage(message: '暂无热门歌曲');
          }
          return M3EList(
            color: M3ETheme.of(context).colorScheme.surface,
            variant: M3ECardVariant.filled,
            itemCount: tracks.length,
            onTap: (int index) => ref
                .read(playerProvider.notifier)
                .load(tracks, index, source: onlineSourceLabel(source)),
            itemBuilder: (BuildContext context, int index) {
              final track = tracks[index];
              return M3EListItem(
                headline: track.title,
                supportingText: track.artist,
                leading: OnlineCover(url: track.coverId),
              );
            },
          );
        },
      ),
    );
  }
}

class _MyPlaylistsSection extends ConsumerWidget {
  const _MyPlaylistsSection({required this.platform});

  final DiscoverPlatform platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(onlinePlatformStatusesProvider);
    return statuses.when(
      loading: () => const _SectionContainer(
        title: '我的歌单',
        child: _SectionLoading(height: 120),
      ),
      error: (Object error, StackTrace? stack) => _SectionContainer(
        title: '我的歌单',
        child: _LoginNotice(platform: platform, message: '无法获取登录状态：$error'),
      ),
      data: (List<rust_online.UiOnlinePlatformStatus> list) {
        if (!onlineHasCookie(list, platform.source)) {
          return _SectionContainer(
            title: '我的歌单',
            child: _LoginNotice(
              platform: platform,
              message: '登录 ${platform.label} 后可查看「我的歌单」。',
            ),
          );
        }
        final key = (source: platform.source, page: 1, limit: 30);
        final async = ref.watch(onlineUserPlaylistsProvider(key));
        return _SectionContainer(
          title: '我的歌单',
          child: async.when(
            loading: () => const _SectionLoading(height: 210),
            error: (Object error, StackTrace? stack) => _SectionMessage(
              message: '加载失败：$error',
              onRetry: () => ref.invalidate(onlineUserPlaylistsProvider(key)),
            ),
            data: (List<rust_online.UiOnlinePlaylist> playlists) {
              if (playlists.isEmpty) {
                return const _SectionMessage(message: '暂无歌单');
              }
              return SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: playlists.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    return _PlaylistCard(playlist: playlists[index]);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LoginNotice extends ConsumerWidget {
  const _LoginNotice({required this.platform, required this.message});

  final DiscoverPlatform platform;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadii.lgAll,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            M3EIcons.lock,
            size: AppIconSize.md,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.typeScale.bodyMedium.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
          M3EButton(
            style: M3EButtonStyle.tonal,
            size: M3EButtonSize.sm,
            label: const Text('去登录'),
            onPressed: () async {
              final ok = await pushMobileRootPage<bool>(
                context,
                MobileOnlineLoginPage(source: platform.source),
                name: 'online-login',
              );
              if (!context.mounted) return;
              ref.invalidate(onlinePlatformStatusesProvider);
              if (ok == true) {
                ref.invalidate(onlineUserPlaylistsProvider);
              }
            },
          ),
        ],
      ),
    );
  }
}
