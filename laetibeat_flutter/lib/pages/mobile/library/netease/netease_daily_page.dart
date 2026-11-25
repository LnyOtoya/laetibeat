import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../widgets/settings/netease_provider.dart';
import '../../mobile_navigation.dart';
import 'netease_detail_widgets.dart';

/// 网易云每日推荐。
class NeteaseDailyPage extends ConsumerWidget {
  const NeteaseDailyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseTheme = M3ETheme.of(context);
    final contentColor = detailContentColor(baseTheme.colorScheme);
    final daily = ref.watch(neteaseDailyProvider);

    return Scaffold(
      backgroundColor: contentColor,
      appBar: AppPageBar.subpage(
        title: '每日推荐',
        onSearch: () => openMobileSearch(context),
        backgroundColor: contentColor,
      ),
      body: daily.when(
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
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.xxl,
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
        loading: () => const Center(child: CircularProgressIndicator()),
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
      ),
    );
  }
}
