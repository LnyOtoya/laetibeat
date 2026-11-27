import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../shared/layout/app_bottom_inset.dart';
import '../../../src/rust/api/simple.dart' as rust;
import '../../../widgets/player/player_provider.dart';
import '../../../widgets/settings/online_provider.dart';
import '../library/online/online_widgets.dart';
import '../widgets/mobile_large_subpage_app_bar.dart';

/// 网易云每日推荐。
class OnlineDailyPage extends ConsumerWidget {
  const OnlineDailyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final daily = ref.watch(onlineDailySongsProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: '每日推荐'),
      body: daily.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace? stack) => Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: AppEmptyState(
              title: '每日推荐加载失败',
              message: '$error',
              icon: M3EIcons.error,
              action: M3EButton(
                style: M3EButtonStyle.tonal,
                label: const Text('重试'),
                onPressed: () => ref.invalidate(onlineDailySongsProvider),
              ),
            ),
          ),
        ),
        data: (List<rust.UiTrack> tracks) {
          if (tracks.isEmpty) {
            return const AppEmptyState(
              title: '今日推荐',
              message: '网易云暂时没有返回推荐歌曲',
              icon: M3EIcons.auto_awesome,
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(onlineDailySongsProvider.future),
            child: ListView(
              padding: EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.xxl + bottomInset,
              ),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.pageGutter,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: AppSectionHeader(
                          title: '今日推荐',
                          padding: AppInsets.sectionHeader,
                        ),
                      ),
                      M3EButton.icon(
                        style: M3EButtonStyle.tonal,
                        size: M3EButtonSize.sm,
                        icon: const Icon(M3EIcons.play_arrow),
                        label: const Text('播放全部'),
                        onPressed: () => ref
                            .read(playerProvider.notifier)
                            .load(tracks, 0, source: '网易云每日推荐'),
                      ),
                    ],
                  ),
                ),
                M3EList(
                  color: scheme.surface,
                  variant: M3ECardVariant.filled,
                  itemCount: tracks.length,
                  onTap: (int index) => ref
                      .read(playerProvider.notifier)
                      .load(tracks, index, source: '网易云每日推荐'),
                  itemBuilder: (BuildContext context, int index) {
                    final track = tracks[index];
                    return M3EListItem(
                      headline: track.title,
                      supportingText: track.artist,
                      leading: OnlineCover(url: track.coverId),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
