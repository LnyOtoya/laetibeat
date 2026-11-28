import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/design.dart';
import '../../widgets/player/cover_provider.dart';
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

/// Root Navigator 上的 Full Player 是否正在显示。
///
/// 嵌套 Tab 路由通过 [MobileNestedRoutePopGate] 监听它：Full Player 打开期间
/// 禁止嵌套 route 参与 predictive back，让根 Navigator 的 Full Player 接管
/// 返回手势。
final ValueNotifier<bool> mobileFullPlayerOpen = ValueNotifier<bool>(false);

/// 打开全局搜索页。
///
/// 二级页顶部栏的搜索动作统一走这里，页面不再各自判断路由。
void openMobileSearch(BuildContext context) {
  if (mobileCurrentRouteName.value == MobileRoutes.search) return;
  Navigator.of(context).pushNamed(MobileRoutes.search);
}

/// 一级页面折叠 AppBar 的取色：优先使用当前播放封面主色。
Color mobileTabBarBackground(WidgetRef ref, M3EColorScheme scheme) {
  final coverColor = ref.watch(playbackCoverProvider).value?.coverColor;
  if (coverColor == null) return scheme.surfaceContainer;
  return MaterialYouColorScheme.fromSeed(
    coverColor,
    brightness: scheme.brightness,
  ).surfaceContainer;
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
        Navigator.of(context).pushNamed(MobileRoutes.stats);
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
      onPressed: () => Navigator.of(context).pushNamed(MobileRoutes.settings),
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

/// 放在嵌套 Navigator 的 route 页面内容层，而不是 Navigator 外层。
///
/// PopScope 必须位于对应 [ModalRoute] 的子树中：它会把自身注册到最近的
/// MaterialPageRoute，更新该 route 的 popDisposition，从而让
/// ModalRoute.popGestureEnabled 返回 false。
class MobileNestedRoutePopGate extends StatelessWidget {
  const MobileNestedRoutePopGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: mobileFullPlayerOpen,
      builder: (BuildContext context, bool fullPlayerOpen, Widget? child) {
        return PopScope<Object?>(canPop: !fullPlayerOpen, child: child!);
      },
      child: child,
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
      builder: (_) => MobileNestedRoutePopGate(child: page),
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
Future<T?> pushMobileFullPlayer<T>(BuildContext context, Widget page) async {
  final NavigatorState? navigator = mobileRootNavigatorKey.currentState;
  if (navigator == null || mobileFullPlayerOpen.value) {
    return null;
  }

  mobileFullPlayerOpen.value = true;
  try {
    return await navigator.push<T>(mobileFullPlayerRoute<T>(page));
  } finally {
    mobileFullPlayerOpen.value = false;
  }
}
