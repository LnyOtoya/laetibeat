import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../shared/layout/app_bottom_inset.dart';
import '../../../src/rust/api/netease.dart' as rust_netease;
import '../library/netease/netease_detail_widgets.dart';
import '../library/netease/netease_playlists_page.dart';
import '../mobile_navigation.dart';
import '../routes.dart';

/// 发现页的推荐歌单/雷达歌单集合页。
class NeteaseDiscoverPlaylistsPage extends StatelessWidget {
  const NeteaseDiscoverPlaylistsPage({
    super.key,
    required this.title,
    required this.playlists,
  });

  final String title;
  final List<rust_netease.UiNeteasePlaylist> playlists;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppPageBar.subpage(
        title: title,
        onSearch: () => openMobileSearch(context),
      ),
      body: playlists.isEmpty
          ? const AppEmptyState(
              title: '暂无歌单',
              message: '网易云暂时没有返回歌单',
              icon: M3EIcons.queue_music,
            )
          : m3e_core.M3ESegmentedList.builder(
              itemCount: playlists.length,
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              listPadding: EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xxl + bottomInset,
              ),
              onTap: (int index) {
                final playlist = playlists[index];
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
                final playlist = playlists[index];
                return m3e_core.M3EListItem(
                  minHeight: 64,
                  headline: Text(playlist.name),
                  supportingText: playlist.trackCount > 0
                      ? Text('${playlist.trackCount} 首')
                      : null,
                  headlineStyle: theme.typeScale.bodyLarge.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                  supportingTextStyle: theme.typeScale.bodyMedium.copyWith(
                    color: scheme.onSecondaryContainer.withValues(alpha: 0.75),
                  ),
                  leading: NeteaseCover(
                    url: playlist.coverUrl,
                    size: 48,
                    fallbackIcon: M3EIcons.queue_music,
                  ),
                  trailing: Icon(
                    M3EIcons.chevron_right,
                    size: 20,
                    color: scheme.onSecondaryContainer,
                  ),
                );
              },
            ),
    );
  }
}
