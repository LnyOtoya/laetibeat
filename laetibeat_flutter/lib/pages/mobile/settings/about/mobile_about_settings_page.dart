import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/layout/app_bottom_inset.dart';
import '../../../../widgets/settings/about_settings.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';

/// 移动端「关于」页：版本、开源许可、第三方声明入口。
class MobileAboutSettingsPage extends StatelessWidget {
  const MobileAboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: '关于'),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
          child: const AboutSettings(showTitle: false),
        ),
      ),
    );
  }
}
