import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../src/rust/api/simple.dart' as rust;
import '../../../../widgets/player/cover_provider.dart';
import '../../../../widgets/player/player_provider.dart';
import '../../../../widgets/settings/netease_provider.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';

/// 网易云每日推荐。
class NeteaseDailyPage extends ConsumerWidget {
  const NeteaseDailyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final daily = ref.watch(neteaseDailyProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: '每日推荐 · 网易云'),
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
                top: AppSpacing.lg,
                bottom: AppSpacing.xxl,
              ),
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppLayout.pageGutter,
                  ),
                  child: AppSectionHeader(
                    title: '今日推荐',
                    padding: AppInsets.sectionHeader,
                  ),
                ),
                m3e_core.M3ESegmentedList.builder(
                  itemCount: tracks.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  listPadding: EdgeInsets.zero,
                  onTap: (int index) {
                    ref
                        .read(playerProvider.notifier)
                        .load(tracks, index, source: '网易云每日推荐');
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
                    final track = tracks[index];
                    return m3e_core.M3EListItem(
                      headline: Text(track.title),
                      supportingText: Text(track.artist),
                      leading: _NeteaseTrackCover(track: track),
                    );
                  },
                ),
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
