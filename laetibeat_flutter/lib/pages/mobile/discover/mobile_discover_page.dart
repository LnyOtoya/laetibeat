import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/layout/app_bottom_inset.dart';

/// 移动端发现页面。
///
/// 一级 tab 页，位于首页之后。当前先建立独立导航入口，发现内容后续接入。
class MobileDiscoverPage extends StatelessWidget {
  const MobileDiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return AppScaffold(
      background: AppSurfaceLevel.base,
      appBar: AppPageBar.tab(
        title: l10n.navDiscover,
        subtitle: l10n.discoverSubtitle,
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Center(
          child: AppEmptyState(
            title: l10n.discoverEmptyTitle,
            message: l10n.discoverEmptyMessage,
            icon: M3EIcons.explore,
          ),
        ),
      ),
    );
  }
}
