import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';

/// 移动端电台页面。
///
/// 当前先建立独立导航入口，电台内容后续接入。
class MobileRadioPage extends StatelessWidget {
  const MobileRadioPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: M3EAppBar.top(
        backgroundColor: theme.colorScheme.surface,
        titleText: l10n.navRadio,
        variant: M3EAppBarVariant.small,
        density: M3EAppBarDensity.compact,
        shapeFamily: M3EAppBarShapeFamily.square,
        safeArea: true,
      ),
      body: const Center(
        child: AppEmptyState(
          title: '暂无电台',
          message: '电台内容将在这里显示',
          icon: M3EIcons.radio,
        ),
      ),
    );
  }
}
