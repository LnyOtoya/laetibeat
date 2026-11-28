import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/layout/app_bottom_inset.dart';
import '../../../widgets/player/playback_stats.dart';
import '../mobile_navigation.dart';
import 'widgets/mobile_history_section.dart';

/// 移动端统计页面。
///
/// 一级 tab 页，顶部栏与首页保持一致；作为二级入口时由调用方自行包裹。
class MobileStatsPage extends ConsumerWidget {
  const MobileStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageBar.subpage(
        title: l10n.statisticsTitle,
        onSearch: () => openMobileSearch(context),
        showLayout: false,
        backgroundColor: theme.colorScheme.surface,
        actions: <Widget>[
          M3EIconButton(
            variant: M3EIconButtonVariant.standard,
            size: M3EIconButtonSize.sm,
            icon: const Icon(M3EIcons.refresh),
            tooltip: '刷新',
            onPressed: () => ref.read(statsRevisionProvider.notifier).bump(),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
        children: const <Widget>[MobileHistorySection()],
      ),
    );
  }
}
