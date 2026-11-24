import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../shared/layout/app_bottom_inset.dart';
import '../routes.dart';
import 'mobile_home_content.dart';

/// 移动端首页。
///
/// 独立页面：后续通过 Navigator 承载，才能正确支持 Android 预测性返回手势。
class MobileHomePage extends StatefulWidget {
  const MobileHomePage({super.key});

  @override
  State<MobileHomePage> createState() => _MobileHomePageState();
}

class _MobileHomePageState extends State<MobileHomePage> {
  static final Size _appBarSize = M3EAppBar.top(
    variant: M3EAppBarVariant.largeFlexible,
    density: M3EAppBarDensity.regular,
    shapeFamily: M3EAppBarShapeFamily.square,
    safeArea: true,
  ).preferredSize;

  final M3EAppBarController _appBarController = M3EAppBarController();

  @override
  void dispose() {
    _appBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final scheme = M3ETheme.of(context).colorScheme;

    return AppScaffold(
      background: AppSurfaceLevel.base,
      applyPageGutter: false,
      safeArea: false,
      appBar: PreferredSize(
        preferredSize: _appBarSize,
        child: AnimatedBuilder(
          animation: _appBarController,
          builder: (BuildContext context, Widget? child) {
            return M3EAppBar.top(
              backgroundColor: AppSurfaceLevel.base.resolve(scheme),
              controller: _appBarController,
              variant: M3EAppBarVariant.largeFlexible,
              density: M3EAppBarDensity.regular,
              shapeFamily: M3EAppBarShapeFamily.square,
              safeArea: true,
              hideOnScroll: false,
              hideMode: M3EAppBarHideMode.none,
              actions: _appBarController.isCollapsed
                  ? <Widget>[
                      M3EIconButton(
                        key: const ValueKey<String>('home-settings'),
                        variant: M3EIconButtonVariant.standard,
                        icon: const Icon(M3EIcons.settings),
                        tooltip: '设置',
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pushNamed(MobileRoutes.settings);
                        },
                      ),
                    ]
                  : const <Widget>[],
              title: AnimatedBuilder(
                animation: _appBarController,
                builder: (BuildContext context, Widget? child) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder:
                        (Widget? currentChild, List<Widget> previousChildren) {
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: <Widget>[
                              ...previousChildren,
                              ?currentChild,
                            ],
                          );
                        },
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.08),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                    child: _appBarController.isCollapsed
                        ? Column(
                            key: const ValueKey<String>('collapsed'),
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '首页',
                                style: M3ETheme.of(context).typeScale.titleLarge
                                    .copyWith(
                                      color: DefaultTextStyle.of(
                                        context,
                                      ).style.color,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              AppText(
                                '浏览音乐库近况',
                                role: AppTextRole.bodySmall,
                                colorRole: AppColorRole.onSurfaceVariant,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          )
                        : const Text(
                            '最新发行',
                            key: ValueKey<String>('expanded'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  );
                },
              ),
            );
          },
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: const MobileHomeContent(),
        ),
      ),
    );
  }
}
