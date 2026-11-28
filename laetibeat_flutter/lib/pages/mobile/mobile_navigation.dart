import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_destination.dart';
import '../../app/app_mode.dart';
import '../../design/design.dart';
import 'routes.dart';

final mobileSelectedDestinationProvider =
    NotifierProvider<MobileSelectedDestinationNotifier, AppDestination>(
      MobileSelectedDestinationNotifier.new,
    );

class MobileSelectedDestinationNotifier extends Notifier<AppDestination> {
  @override
  AppDestination build() => ref.read(appModeProvider).mobileInitialDestination;

  void select(AppDestination destination) {
    if (state == destination) return;
    state = destination;
  }
}

/// 移动端唯一的页面 Navigator。
///
/// Shell 是它外层的持久 UI；Tab 选择由 [mobileSelectedDestinationProvider]
/// 管理，所有详情页、设置页和播放器页面都进入这条路由栈。
final GlobalKey<NavigatorState> mobileRootNavigatorKey =
    GlobalKey<NavigatorState>();

/// 当前最上层的移动端路由名，供外层 Shell 决定底部导航是否显示。
final ValueNotifier<String?> mobileCurrentRouteName = ValueNotifier<String?>(
  MobileRoutes.home,
);

/// 打开全局搜索页。
///
/// 二级页顶部栏的搜索动作统一走这里，页面不再各自判断路由。
void openMobileSearch(BuildContext context) {
  if (mobileCurrentRouteName.value == MobileRoutes.search) return;
  _mobileRootNavigator(context).pushNamed(MobileRoutes.search);
}

/// 一级页面折叠 AppBar 的公共动作：最近 / 统计 / 一起听 / 设置。
List<Widget> mobileTabBarActions(BuildContext context) {
  return <Widget>[
    M3EIconButton(
      key: const ValueKey<String>('tab-recent'),
      variant: M3EIconButtonVariant.standard,
      icon: const Icon(M3EIcons.history),
      tooltip: '最近播放',
      onPressed: () => pushMobileRootPage(
        context,
        const MobileRecentPage(),
        name: MobileRoutes.recent,
      ),
    ),
    M3EIconButton(
      key: const ValueKey<String>('tab-stats'),
      variant: M3EIconButtonVariant.standard,
      icon: const Icon(M3EIcons.bar_chart),
      tooltip: '统计',
      onPressed: () {
        if (mobileCurrentRouteName.value == MobileRoutes.stats) return;
        _mobileRootNavigator(context).pushNamed(MobileRoutes.stats);
      },
    ),
    M3EIconButton(
      key: const ValueKey<String>('tab-listen-together'),
      variant: M3EIconButtonVariant.standard,
      icon: const Icon(M3EIcons.group),
      tooltip: '一起听',
      onPressed: () => pushMobileRootPage(
        context,
        const MobileListenTogetherPage(),
        name: MobileRoutes.listenTogether,
      ),
    ),
    M3EIconButton(
      key: const ValueKey<String>('tab-settings'),
      variant: M3EIconButtonVariant.standard,
      icon: const Icon(M3EIcons.settings),
      tooltip: '设置',
      onPressed: () =>
          _mobileRootNavigator(context).pushNamed(MobileRoutes.settings),
    ),
  ];
}

class MobileRecentPage extends StatelessWidget {
  const MobileRecentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppPageBar.subpage(
        title: '最近播放',
        onSearch: () => openMobileSearch(context),
        showLayout: false,
        backgroundColor: scheme.surface,
        actions: <Widget>[
          M3EIconButton(
            variant: M3EIconButtonVariant.standard,
            size: M3EIconButtonSize.sm,
            icon: const Icon(M3EIcons.search),
            tooltip: '搜索',
            onPressed: () => openMobileSearch(context),
          ),
        ],
      ),
      body: const Center(child: Text('最近播放 将在后续接入')),
    );
  }
}

class MobileListenTogetherPage extends StatelessWidget {
  const MobileListenTogetherPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppPageBar.subpage(
        title: '一起听',
        onSearch: () => openMobileSearch(context),
        showLayout: false,
        backgroundColor: scheme.surface,
        actions: const <Widget>[],
      ),
      body: const Center(child: Text('一起听 将在后续接入')),
    );
  }
}

class MobileNavigatorObserver extends NavigatorObserver {
  void _setRoute(Route<dynamic>? route) {
    final String? name = route?.settings.name;
    // M3ECard 的 container transform 会 push 一个无 route name 的页面；
    // 此时保留上一个命名路由，避免底部导航误切回首页。
    if (name == null) return;
    mobileCurrentRouteName.value = name;
  }

  // Dialog / ModalBottomSheet / PopupMenu 等覆盖层不应改变当前页面。
  bool _isPopup(Route<dynamic>? route) => route is PopupRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isPopup(route)) return;
    _setRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isPopup(route)) return;
    _setRoute(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isPopup(route)) return;
    _setRoute(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_isPopup(newRoute)) return;
    _setRoute(newRoute ?? oldRoute);
  }
}

final MobileNavigatorObserver mobileNavigatorObserver =
    MobileNavigatorObserver();

/// 将移动端业务页面推入唯一的页面路由栈。
Future<T?> pushMobileRootPage<T>(
  BuildContext context,
  Widget page, {
  String? name,
}) {
  final NavigatorState navigator = _mobileRootNavigator(context);
  return navigator.push<T>(
    MaterialPageRoute<T>(
      settings: name == null ? null : RouteSettings(name: name),
      builder: (_) => page,
    ),
  );
}

/// Full Player route on the shared page stack.
///
/// Uses its own transition so the mini player remains underneath while the
/// full player fades/slides in. The artwork itself is animated by a Hero.
Route<T> mobileFullPlayerRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    settings: const RouteSettings(name: MobileRoutes.playback),
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) => page,
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
  );
}

/// Push the full player on the same stack as the page that opened it.
Future<T?> pushMobileFullPlayer<T>(BuildContext context, Widget page) async {
  if (mobileCurrentRouteName.value == MobileRoutes.playback) return null;
  return _mobileRootNavigator(context).push<T>(mobileFullPlayerRoute<T>(page));
}

NavigatorState _mobileRootNavigator(BuildContext context) {
  final NavigatorState? navigator =
      mobileRootNavigatorKey.currentState ??
      Navigator.maybeOf(context, rootNavigator: true);
  if (navigator == null) {
    throw FlutterError(
      'Mobile navigation was requested without a mounted root Navigator.',
    );
  }
  return navigator;
}
