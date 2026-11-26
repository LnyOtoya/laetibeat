import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../shared/layout/app_bottom_inset.dart';
import '../../../../widgets/settings/netease_provider.dart';
import '../../../../widgets/settings/netease_session.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../../settings/sources/netease/mobile_netease_login_page.dart';
import 'netease_detail_widgets.dart';

/// 网易云每日推荐。
///
/// 每日推荐属于登录后的个性化内容，未登录时只显示登录提示，不请求匿名日推。
class NeteaseDailyPage extends ConsumerWidget {
  const NeteaseDailyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseTheme = M3ETheme.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final contentColor = detailContentColor(baseTheme.colorScheme);
    final cookie = ref.watch(neteaseCookieProvider);

    return Scaffold(
      backgroundColor: contentColor,
      appBar: AppPageBar.subpage(
        title: '每日推荐',
        onSearch: () => openMobileSearch(context),
        backgroundColor: contentColor,
      ),
      body: cookie.when(
        data: (value) => value == null || value.isEmpty
            ? _DailyLoginRequired(bottomInset: bottomInset)
            : _DailyRecommendations(bottomInset: bottomInset),
        loading: () => const Center(child: NeteaseLoadingIndicator()),
        error: (_, _) => _DailyLoginRequired(bottomInset: bottomInset),
      ),
    );
  }
}

class _DailyLoginRequired extends ConsumerWidget {
  const _DailyLoginRequired({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: AppEmptyState(
          title: '登录后查看每日推荐',
          message: '网易云会根据当前账号的口味生成每日推荐。',
          icon: M3EIcons.lock,
          action: M3EButton(
            style: M3EButtonStyle.filled,
            label: const Text('登录网易云'),
            onPressed: () async {
              await pushMobileRootPage<bool>(
                context,
                const MobileNeteaseLoginPage(),
                name: MobileRoutes.neteaseLogin,
              );
              ref.invalidate(neteaseDailyProvider);
            },
          ),
        ),
      ),
    );
  }
}

class _DailyRecommendations extends ConsumerWidget {
  const _DailyRecommendations({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily = ref.watch(neteaseDailyProvider);

    return daily.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return const AppEmptyState(
            title: '每日推荐',
            message: '网易云暂时没有返回推荐歌曲',
            icon: M3EIcons.auto_awesome,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(neteaseDailyProvider.future),
          child: ListView(
            padding: EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xxl + bottomInset,
            ),
            children: <Widget>[
              const AppSectionHeader(
                title: '今日推荐',
                titleRole: AppTextRole.titleMedium,
                padding: EdgeInsets.fromLTRB(
                  AppLayout.pageGutter,
                  AppSpacing.sm,
                  AppLayout.pageGutter,
                  AppSpacing.xs,
                ),
              ),
              NeteaseTrackList(tracks: tracks, source: '网易云每日推荐'),
            ],
          ),
        );
      },
      loading: () => const Center(child: NeteaseLoadingIndicator()),
      error: (error, _) => AppEmptyState(
        title: '每日推荐加载失败',
        message: '$error',
        icon: M3EIcons.error,
        action: M3EButton(
          style: M3EButtonStyle.tonal,
          label: const Text('重试'),
          onPressed: () => ref.invalidate(neteaseDailyProvider),
        ),
      ),
    );
  }
}
