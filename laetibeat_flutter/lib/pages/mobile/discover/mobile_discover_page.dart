import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/layout/app_bottom_inset.dart';

/// 移动端发现页面。
///
/// 在线音源正在重新接入：这里暂时保留页面结构与视觉骨架，不展示任何远端
/// 数据，也不包含旧的网易云 Node API 依赖。
class MobileDiscoverPage extends ConsumerWidget {
  const MobileDiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final gutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    final cardWidth = (MediaQuery.sizeOf(context).width * 0.78).clamp(
      240.0,
      360.0,
    );
    final cardHeight = cardWidth * 9 / 16 + 76;

    return AppScaffold(
      background: AppSurfaceLevel.base,
      applyPageGutter: false,
      safeArea: false,
      appBar: AppPageBar.tab(
        title: l10n.navDiscover,
        subtitle: l10n.discoverSubtitle,
        backgroundColor: AppSurfaceLevel.base.resolve(scheme),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          gutter,
          AppSpacing.lg,
          gutter,
          AppSpacing.xl + bottomInset,
        ),
        children: <Widget>[
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (BuildContext context, int index) =>
                  _DiscoverPlaceholderCard(width: cardWidth),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(
            title: '推荐内容',
            titleRole: AppTextRole.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (int index = 0; index < 4; index++) const _DiscoverPlaceholderRow(),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              '在线音源正在接入中',
              style: theme.typeScale.bodyMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverPlaceholderCard extends StatelessWidget {
  const _DiscoverPlaceholderCard({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadii.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Icon(
            M3EIcons.auto_awesome,
            size: AppIconSize.xl,
            color: scheme.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('为你推荐', style: theme.typeScale.titleMedium),
          const SizedBox(height: 2),
          Text(
            '即将接入',
            style: theme.typeScale.bodySmall.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverPlaceholderRow extends StatelessWidget {
  const _DiscoverPlaceholderRow();

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: AppRadii.smAll,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  height: 12,
                  width: 160,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 100,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
