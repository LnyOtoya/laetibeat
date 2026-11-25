import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../routes.dart';
import 'mobile_home_content.dart';

/// 移动端首页。
///
/// 独立页面：后续通过 Navigator 承载，才能正确支持 Android 预测性返回手势。
/// 顶部栏由 [AppPageBar.tab] 统一提供，样式与其余一级 tab 页一致。
class MobileHomePage extends StatelessWidget {
  const MobileHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;

    return AppScaffold(
      background: AppSurfaceLevel.base,
      applyPageGutter: false,
      safeArea: false,
      appBar: AppPageBar.tab(
        title: '首页',
        subtitle: '浏览音乐库近况',
        expandedTitle: '最新发行',
        backgroundColor: AppSurfaceLevel.base.resolve(scheme),
        actionsBuilder: (bool collapsed) => collapsed
            ? <Widget>[
                M3EIconButton(
                  key: const ValueKey<String>('home-settings'),
                  variant: M3EIconButtonVariant.standard,
                  icon: const Icon(M3EIcons.settings),
                  tooltip: '设置',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(MobileRoutes.settings),
                ),
              ]
            : const <Widget>[],
      ),
      body: const SafeArea(
        top: false,
        bottom: false,
        child: MobileHomeContent(),
      ),
    );
  }
}
