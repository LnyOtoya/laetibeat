import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../shared/layout/app_bottom_inset.dart';
import 'mobile_home_content.dart';

/// 移动端首页。
///
/// 独立页面：后续通过 Navigator 承载，才能正确支持 Android 预测性返回手势。
class MobileHomePage extends StatelessWidget {
  const MobileHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return AppScaffold(
      background: AppSurfaceLevel.container,
      applyPageGutter: true,
      safeArea: false,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: const MobileHomeContent(),
        ),
      ),
    );
  }
}
