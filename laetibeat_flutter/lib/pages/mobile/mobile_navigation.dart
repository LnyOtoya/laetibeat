import 'package:material_ui/material_ui.dart';

import 'routes.dart';

/// 移动端 App Shell 的 Root Navigator。
///
/// 它承载 AppShellRoute（Shell + Tab Navigator）以及 Full Player 等
/// 需要覆盖整个 Shell 的页面。
final GlobalKey<NavigatorState> mobileRootNavigatorKey =
    GlobalKey<NavigatorState>();

/// Shell 内部的 Tab Navigator。
///
/// Home、Library、Search、设置、详情页都在这里 push；Shell 和
/// MiniPlayer 不随这些页面重建。
final GlobalKey<NavigatorState> mobileNavigatorKey =
    GlobalKey<NavigatorState>();

/// 当前最上层的移动端路由名，供外层 Shell 决定底部导航是否显示。
final ValueNotifier<String?> mobileCurrentRouteName = ValueNotifier<String?>(
  MobileRoutes.home,
);

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

/// 将移动端业务页面推到 Shell 内部的 Tab Navigator。
Future<T?> pushMobileRootPage<T>(
  BuildContext context,
  Widget page, {
  String? name,
}) {
  // Shell 组件在 Tab Navigator 外层，context 中没有 Navigator。
  // 优先使用全局 key，页面内调用时再回退到 context 查找。
  final NavigatorState? navigator =
      mobileNavigatorKey.currentState ??
      Navigator.maybeOf(context, rootNavigator: true);
  if (navigator == null) {
    return Future<T?>.value(null);
  }
  return navigator.push<T>(
    MaterialPageRoute<T>(
      settings: name == null ? null : RouteSettings(name: name),
      builder: (_) => page,
    ),
  );
}

/// 将页面推到 Root Navigator，覆盖整个 Shell。
///
/// 用于 Full Player 等需要盖住 BottomOverlay 的页面。
Future<T?> pushMobileRootRoute<T>(
  BuildContext context,
  Widget page, {
  String? name,
}) {
  final NavigatorState? navigator = mobileRootNavigatorKey.currentState;
  if (navigator == null) {
    return Future<T?>.value(null);
  }
  return navigator.push<T>(
    MaterialPageRoute<T>(
      settings: name == null ? null : RouteSettings(name: name),
      builder: (_) => page,
    ),
  );
}

/// Full Player route above the Shell.
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

/// Push the full player on the Root Navigator so it covers the Shell.
Future<T?> pushMobileFullPlayer<T>(BuildContext context, Widget page) {
  final NavigatorState? navigator = mobileRootNavigatorKey.currentState;
  if (navigator == null) {
    return Future<T?>.value(null);
  }
  return navigator.push<T>(mobileFullPlayerRoute<T>(page));
}
