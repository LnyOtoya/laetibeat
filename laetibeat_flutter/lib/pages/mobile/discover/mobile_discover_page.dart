import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/layout/app_bottom_inset.dart';
import '../../../src/rust/api/netease.dart' as rust_netease;
import '../../../src/rust/api/simple.dart' as rust;
import '../../../widgets/player/player_provider.dart';
import '../../../widgets/settings/netease_provider.dart';
import '../../../widgets/settings/netease_session.dart';
import '../../../widgets/settings/netease_settings.dart';
import '../library/netease/netease_daily_page.dart';
import '../library/netease/netease_detail_widgets.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import '../settings/sources/netease/mobile_netease_login_page.dart';
import '../settings/sources/netease/mobile_netease_settings_page.dart';
import 'netease_discover_playlists_page.dart';

/// 移动端发现页面。
///
/// 顶部是横向推荐卡片。每张卡片只用真实接口数据；必须登录的卡片在未登录时
/// 显示登录提示，不用占位数据伪装成推荐内容。
class MobileDiscoverPage extends ConsumerWidget {
  const MobileDiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = M3ETheme.of(context).colorScheme;
    final settings = ref.watch(neteaseSettingsProvider);
    final cookie = ref.watch(neteaseCookieProvider).value;
    final loggedIn = cookie != null && cookie.isNotEmpty;
    final configured = settings.apiBaseUrl.isNotEmpty;
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return AppScaffold(
      background: AppSurfaceLevel.base,
      applyPageGutter: false,
      safeArea: false,
      appBar: AppPageBar.tab(
        title: l10n.navDiscover,
        subtitle: l10n.discoverSubtitle,
        backgroundColor: AppSurfaceLevel.base.resolve(scheme),
      ),
      body: configured
          ? _DiscoverContent(loggedIn: loggedIn, bottomInset: bottomInset)
          : _DiscoverUnconfigured(bottomInset: bottomInset),
    );
  }
}

class _DiscoverUnconfigured extends StatelessWidget {
  const _DiscoverUnconfigured({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: AppEmptyState(
          title: '还没有配置网易云音乐',
          message: '填写网易云 API 地址后，这里会显示推荐歌单、雷达和漫游内容。',
          icon: M3EIcons.cloud_off,
          action: M3EButton(
            style: M3EButtonStyle.filled,
            label: const Text('去配置'),
            onPressed: () => pushMobileRootPage(
              context,
              const MobileNeteaseSettingsPage(),
              name: MobileRoutes.neteaseConfig,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverContent extends ConsumerWidget {
  const _DiscoverContent({required this.loggedIn, required this.bottomInset});

  final bool loggedIn;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageGutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    final cardWidth = (MediaQuery.sizeOf(context).width * 0.78).clamp(
      240.0,
      360.0,
    );
    final cardHeight = cardWidth * 9 / 16 + 76;

    final daily = ref.watch(neteaseDailyProvider);
    final playlists = ref.watch(neteasePersonalizedPlaylistsProvider);
    final fm = ref.watch(neteasePersonalFmProvider);
    final radar = ref.watch(neteaseRadarPlaylistsProvider);
    final liked = loggedIn ? ref.watch(neteaseLikedPlaylistProvider) : null;

    final cards = <_DiscoverCardData>[
      _dailyCard(context, ref, daily),
      _seedCard(
        context: context,
        ref: ref,
        title: '心动模式',
        subtitle: '红心歌曲和相似推荐',
        loggedIn: loggedIn,
        liked: liked,
        source: '网易云心动模式',
        load: () => ref.read(neteaseHeartModeProvider.future),
      ),
      _playlistCard(context, ref, playlists),
      _roamCard(context, ref, fm),
      _radarCard(context, ref, radar),
      _seedCard(
        context: context,
        ref: ref,
        title: '相似歌曲',
        subtitle: '从你喜欢的歌听起',
        loggedIn: loggedIn,
        liked: liked,
        source: '网易云相似歌曲',
        load: () => ref.read(neteaseSimilarSongsProvider.future),
      ),
    ];

    return ListView(
      padding: EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.xxl + bottomInset,
      ),
      children: <Widget>[
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: pageGutter),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.lg),
            itemBuilder: (BuildContext context, int index) {
              return _DiscoverCard(data: cards[index], width: cardWidth);
            },
          ),
        ),
      ],
    );
  }

  _DiscoverCardData _dailyCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<rust.UiTrack>> value,
  ) {
    final tracks = value.value;
    final hasData = tracks != null && tracks.isNotEmpty;
    final state = _stateFor(value, hasData: hasData);
    return _DiscoverCardData(
      title: '媒体推荐',
      subtitle: '今日限定好歌推荐',
      coverUrl: hasData ? tracks.first.coverId : null,
      state: state,
      message: state == _CardState.error ? '加载失败，点击重试' : null,
      onTap: () => pushMobileRootPage(
        context,
        const NeteaseDailyPage(),
        name: MobileRoutes.discovery,
      ),
      onRetry: () => ref.invalidate(neteaseDailyProvider),
      onLogin: () => _openLogin(context, ref),
    );
  }

  _DiscoverCardData _playlistCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<rust_netease.UiNeteasePlaylist>> value,
  ) {
    final items = value.value ?? const <rust_netease.UiNeteasePlaylist>[];
    final hasData = items.isNotEmpty;
    final state = _stateFor(value, hasData: hasData);
    return _DiscoverCardData(
      title: '歌单推荐',
      subtitle: '打工人续命歌单',
      coverUrl: hasData ? items.first.coverUrl : null,
      state: state,
      message: state == _CardState.error ? '加载失败，点击重试' : null,
      onTap: hasData
          ? () => pushMobileRootPage(
              context,
              NeteaseDiscoverPlaylistsPage(title: '推荐歌单', playlists: items),
              name: MobileRoutes.discovery,
            )
          : null,
      onRetry: () => ref.invalidate(neteasePersonalizedPlaylistsProvider),
      onLogin: () => _openLogin(context, ref),
    );
  }

  _DiscoverCardData _roamCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<rust.UiTrack>> value,
  ) {
    final tracks = value.value ?? const <rust.UiTrack>[];
    final hasData = tracks.isNotEmpty;
    final state = _stateFor(value, hasData: hasData);
    return _DiscoverCardData(
      title: '漫游',
      subtitle: '多样频道无限唱听',
      coverUrl: hasData ? tracks.first.coverId : null,
      state: state,
      message: state == _CardState.error ? '加载失败，点击重试' : null,
      onTap: hasData ? () => _playTracks(context, ref, tracks, '网易云漫游') : null,
      onRetry: () => ref.invalidate(neteasePersonalFmProvider),
      onLogin: () => _openLogin(context, ref),
    );
  }

  _DiscoverCardData _radarCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<rust_netease.UiNeteasePlaylist>> value,
  ) {
    final items = value.value ?? const <rust_netease.UiNeteasePlaylist>[];
    final hasData = items.isNotEmpty;
    final state = _stateFor(value, hasData: hasData);
    return _DiscoverCardData(
      title: '雷达歌单',
      subtitle: '反复聆听你爱的歌',
      coverUrl: hasData ? items.first.coverUrl : null,
      state: state,
      message: state == _CardState.error ? '加载失败，点击重试' : null,
      onTap: hasData
          ? () => pushMobileRootPage(
              context,
              NeteaseDiscoverPlaylistsPage(title: '雷达歌单', playlists: items),
              name: MobileRoutes.discovery,
            )
          : null,
      onRetry: () => ref.invalidate(neteaseRadarPlaylistsProvider),
      onLogin: () => _openLogin(context, ref),
    );
  }

  _DiscoverCardData _seedCard({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required bool loggedIn,
    required AsyncValue<rust_netease.UiNeteasePlaylist?>? liked,
    required String source,
    required Future<List<rust.UiTrack>> Function() load,
  }) {
    if (!loggedIn || liked == null) {
      return _DiscoverCardData(
        title: title,
        subtitle: subtitle,
        state: _CardState.login,
        onLogin: () => _openLogin(context, ref),
      );
    }

    final playlist = liked.value;
    final hasData = playlist != null && playlist.trackCount > 0;
    final state = _stateFor(liked, hasData: hasData);
    return _DiscoverCardData(
      title: title,
      subtitle: subtitle,
      coverUrl: hasData ? playlist.coverUrl : null,
      state: state,
      message: switch (state) {
        _CardState.error => '加载失败，点击重试',
        _CardState.empty => '还没有红心歌曲',
        _ => null,
      },
      onTap: hasData
          ? () => unawaited(_playFuture(context, ref, load(), source))
          : null,
      onRetry: () => ref.invalidate(neteaseLikedPlaylistProvider),
      onLogin: () => _openLogin(context, ref),
    );
  }

  Future<void> _playFuture(
    BuildContext context,
    WidgetRef ref,
    Future<List<rust.UiTrack>> future,
    String source,
  ) async {
    try {
      final tracks = await future;
      if (!context.mounted) return;
      _playTracks(context, ref, tracks, source);
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, '$error');
    }
  }

  void _playTracks(
    BuildContext context,
    WidgetRef ref,
    List<rust.UiTrack> tracks,
    String source,
  ) {
    if (tracks.isEmpty) {
      _showMessage(context, '网易云暂时没有返回可播放的歌曲');
      return;
    }
    ref.read(playerProvider.notifier).load(tracks, 0, source: source);
  }

  Future<void> _openLogin(BuildContext context, WidgetRef ref) async {
    await pushMobileRootPage<bool>(
      context,
      const MobileNeteaseLoginPage(),
      name: MobileRoutes.neteaseLogin,
    );
    ref.invalidate(neteaseLikedPlaylistProvider);
    ref.invalidate(neteaseDailyProvider);
    ref.invalidate(neteasePersonalizedPlaylistsProvider);
    ref.invalidate(neteaseRadarPlaylistsProvider);
    ref.invalidate(neteasePersonalFmProvider);
  }
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.data, required this.width});

  final _DiscoverCardData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final onTap = switch (data.state) {
      _CardState.login => data.onLogin,
      _CardState.error => data.onRetry,
      _CardState.data => data.onTap,
      _CardState.loading || _CardState.empty => null,
    };

    return Semantics(
      button: onTap != null,
      label: '${data.title}，${data.subtitle}',
      child: SizedBox(
        width: width,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadii.lgAll,
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typeScale.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typeScale.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: width,
                  height: width * 9 / 16,
                  child: ClipRRect(
                    borderRadius: AppRadii.lgAll,
                    child: _DiscoverCover(data: data),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverCover extends ConsumerWidget {
  const _DiscoverCover({required this.data});

  final _DiscoverCardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;

    switch (data.state) {
      case _CardState.login:
        return _CoverPlaceholder(
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
          icon: M3EIcons.lock,
          text: '登录后查看',
        );
      case _CardState.loading:
        return _CoverPlaceholder(
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurfaceVariant,
          child: const NeteaseLoadingIndicator(size: 32),
        );
      case _CardState.error:
        return _CoverPlaceholder(
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
          icon: M3EIcons.error,
          text: data.message ?? '加载失败',
        );
      case _CardState.empty:
        return _CoverPlaceholder(
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurfaceVariant,
          icon: M3EIcons.music_note,
          text: data.message ?? '暂无内容',
        );
      case _CardState.data:
        final url = data.coverUrl;
        if (url == null || url.isEmpty) {
          return _CoverPlaceholder(
            background: scheme.surfaceContainerHighest,
            foreground: scheme.onSurfaceVariant,
            icon: M3EIcons.music_note,
            text: '暂无封面',
          );
        }
        final image = ref.watch(neteaseImageProvider(url));
        return image.when(
          data: (bytes) {
            if (bytes == null || bytes.isEmpty) {
              return _CoverPlaceholder(
                background: scheme.surfaceContainerHighest,
                foreground: scheme.onSurfaceVariant,
                icon: M3EIcons.music_note,
                text: '暂无封面',
              );
            }
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            );
          },
          loading: () => _CoverPlaceholder(
            background: scheme.surfaceContainerHighest,
            foreground: scheme.onSurfaceVariant,
            child: const NeteaseLoadingIndicator(size: 32),
          ),
          error: (_, _) => _CoverPlaceholder(
            background: scheme.surfaceContainerHighest,
            foreground: scheme.onSurfaceVariant,
            icon: M3EIcons.error,
            text: '封面加载失败',
          ),
        );
    }
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({
    required this.background,
    required this.foreground,
    this.icon,
    this.text,
    this.child,
  });

  final Color background;
  final Color foreground;
  final IconData? icon;
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return ColoredBox(
      color: background,
      child: Center(
        child:
            child ??
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null)
                  Icon(icon, size: AppIconSize.lg, color: foreground),
                if (text != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    text!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typeScale.labelMedium.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
              ],
            ),
      ),
    );
  }
}

enum _CardState { data, loading, empty, error, login }

class _DiscoverCardData {
  const _DiscoverCardData({
    required this.title,
    required this.subtitle,
    required this.state,
    this.coverUrl,
    this.message,
    this.onTap,
    this.onRetry,
    this.onLogin,
  });

  final String title;
  final String subtitle;
  final String? coverUrl;
  final _CardState state;
  final String? message;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onLogin;
}

_CardState _stateFor<T>(AsyncValue<T> value, {required bool hasData}) {
  if (value.isLoading && !value.hasValue) return _CardState.loading;
  if (value.hasError) {
    return _needsLogin(value.error) ? _CardState.login : _CardState.error;
  }
  return hasData ? _CardState.data : _CardState.empty;
}

bool _needsLogin(Object? error) {
  final text = '$error';
  return text.contains('301') || text.contains('需要登录') || text.contains('请先登录');
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
