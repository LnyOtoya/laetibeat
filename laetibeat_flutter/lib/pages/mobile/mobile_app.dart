import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_destination.dart';
import '../../app/app_mode.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/feedback/app_haptics.dart';
import '../../shared/layout/app_bottom_inset.dart';
import '../../widgets/player/player_provider.dart';
import 'discover/mobile_discover_page.dart';
import 'home/mobile_home_page.dart';
import 'library/mobile_library_page.dart';
import 'library/mobile_library_subpages.dart';
import 'mobile_navigation.dart';
import 'player/mini_player.dart';
import 'routes.dart';
import 'search/mobile_search_page.dart';
import 'settings/about/mobile_about_settings_page.dart';
import 'settings/appearance/mobile_color_mapping_page.dart';
import 'settings/content/mobile_content_settings_page.dart';
import 'settings/mobile_settings_page.dart';
import 'stats/mobile_stats_page.dart';

/// 移动端 Shell。
///
/// [child] 是 MaterialApp 的根 Navigator。所有页面都在这条 Navigator 上，
/// Shell 负责底部导航、MiniPlayer 和底部 inset。
class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell> {
  final M3EFloatingToolbarScrollBehavior _navBarScrollBehavior =
      M3EFloatingToolbarScrollBehavior.exitAlways(
        exitDirection: M3EFloatingToolbarExitDirection.bottom,
      );

  @override
  void dispose() {
    _navBarScrollBehavior.state.dispose();
    super.dispose();
  }

  List<AppFloatingNavTab> _destinations(
    AppLocalizations l10n,
    List<AppDestination> tabs,
  ) {
    return tabs
        .map((tab) {
          final icon = switch (tab) {
            AppDestination.home => M3EIcons.home,
            AppDestination.discover => M3EIcons.explore,
            AppDestination.library => M3EIcons.music_note,
            AppDestination.stats => M3EIcons.bar_chart,
            _ => M3EIcons.more_horiz,
          };
          final label = switch (tab) {
            AppDestination.home => l10n.navHome,
            AppDestination.discover => l10n.navDiscover,
            AppDestination.library => l10n.navLibrary,
            AppDestination.stats => l10n.statisticsTitle,
            _ => tab.name,
          };
          return AppFloatingNavTab(
            icon: icon,
            selectedIcon: icon,
            label: label,
          );
        })
        .toList(growable: false);
  }

  String _routeForDestination(AppDestination destination) {
    return switch (destination) {
      AppDestination.home => MobileRoutes.home,
      AppDestination.discover => MobileRoutes.discover,
      AppDestination.library => MobileRoutes.library,
      AppDestination.stats => MobileRoutes.stats,
      _ => MobileRoutes.home,
    };
  }

  AppDestination? _tabForRoute(String? route, List<AppDestination> tabs) {
    if (route == null || route == MobileRoutes.home) {
      return tabs.contains(AppDestination.home)
          ? AppDestination.home
          : tabs.first;
    }
    if (route == MobileRoutes.library || route.startsWith('/library/')) {
      return AppDestination.library;
    }
    if (route == MobileRoutes.stats) {
      return AppDestination.stats;
    }
    if (route == MobileRoutes.discover) {
      return AppDestination.discover;
    }
    return null;
  }

  bool _showNavigationBar(String? route, List<AppDestination> tabs) {
    final tab = _tabForRoute(route, tabs);
    if (tab == null || !tabs.contains(tab)) return false;
    if (route == null) return true;
    return route == MobileRoutes.home ||
        route == MobileRoutes.discover ||
        route == MobileRoutes.library ||
        route.startsWith('/library/') ||
        route == MobileRoutes.stats;
  }

  void _selectTab(AppDestination destination) {
    final NavigatorState? navigator = mobileNavigatorKey.currentState;
    if (navigator == null) return;
    final String? current = mobileCurrentRouteName.value;

    switch (destination) {
      case AppDestination.home:
        if (current == MobileRoutes.home) return;
        navigator.popUntil((Route<dynamic> route) => route.isFirst);
        return;
      case AppDestination.library:
        if (current == MobileRoutes.library ||
            (current?.startsWith('/library/') ?? false)) {
          navigator.popUntil(
            (Route<dynamic> route) =>
                route.isFirst || route.settings.name == MobileRoutes.library,
          );
          return;
        }
        navigator.pushNamed(MobileRoutes.library);
        return;
      case AppDestination.stats:
        if (current == MobileRoutes.stats) return;
        navigator.pushNamed(MobileRoutes.stats);
        return;
      case AppDestination.discover:
        if (current == MobileRoutes.discover) return;
        navigator.pushNamed(MobileRoutes.discover);
        return;
      case AppDestination.search:
        _openSearch();
        return;
      default:
        return;
    }
  }

  void _openSearch() {
    final NavigatorState? navigator = mobileNavigatorKey.currentState;
    if (navigator == null) return;
    if (mobileCurrentRouteName.value == MobileRoutes.search) return;
    navigator.pushNamed(MobileRoutes.search);
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(appModeProvider);
    final tabs = mode.mobileDestinations;
    final bool hasTrack = ref.watch(
      playerProvider.select((state) => state.current != null),
    );

    ref.listen<AppMode>(appModeProvider, (AppMode? previous, AppMode next) {
      if (previous == next) return;
      final currentRoute = mobileCurrentRouteName.value;
      final nextTabs = next.mobileDestinations;
      final currentTab = _tabForRoute(currentRoute, nextTabs);
      final homeIsHidden = !nextTabs.contains(AppDestination.home);
      final currentRouteAvailable =
          currentTab != null &&
          nextTabs.contains(currentTab) &&
          !(currentRoute == MobileRoutes.home && homeIsHidden);
      if (currentRouteAvailable) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = mobileNavigatorKey.currentState;
        if (navigator == null) return;
        navigator.pushNamedAndRemoveUntil(
          _routeForDestination(next.mobileInitialDestination),
          (route) => false,
        );
      });
    });

    return ValueListenableBuilder<String?>(
      valueListenable: mobileCurrentRouteName,
      builder: (BuildContext context, String? routeName, Widget? _) {
        final AppDestination tab = _tabForRoute(routeName, tabs) ?? tabs.first;
        final int selectedIndex = tabs.indexOf(tab);
        final bool showNavigationBar = _showNavigationBar(routeName, tabs);
        final bool showMiniPlayer = hasTrack && showNavigationBar;
        final AppFloatingNavBar? navBar = showNavigationBar
            ? AppFloatingNavBar(
                key: const ValueKey<String>('mobile_floating_nav_bar'),
                tabs: _destinations(l10n, tabs),
                selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                onTabSelected: (int index) {
                  if (index < 0 || index >= tabs.length) return;
                  _selectTab(tabs[index]);
                },
                onSearchPressed: _openSearch,
                searchLabel: l10n.searchHint,
                scrollBehavior: _navBarScrollBehavior,
              )
            : null;

        final double navigationBarHeight = navBar?.resolvedHeight(context) ?? 0;
        final Widget? bottomBar = navBar == null
            ? null
            : AppBottomOverlay(
                navigationBar: navBar,
                navigationBarHeight: navigationBarHeight,
                miniPlayer: const MiniPlayer(),
                miniVisible: showMiniPlayer,
                miniPlayerHeight: AppComponentSize.miniPlayerAccessory,
                navBarScrollState: _navBarScrollBehavior.state,
              );

        // This is a metric for page-owned scroll/content padding. The Shell
        // never wraps the page in this padding, so page layout stays full-bleed.
        final double floatingChromeInset = showNavigationBar
            ? navigationBarHeight +
                  (showMiniPlayer ? AppComponentSize.miniPlayerAccessory : 0)
            : 0;

        final body = Stack(
          children: <Widget>[
            Positioned.fill(
              child: M3EFloatingToolbarScrollWrapper(
                behavior: _navBarScrollBehavior,
                child: widget.child,
              ),
            ),
            if (bottomBar != null)
              Positioned(left: 0, right: 0, bottom: 0, child: bottomBar),
          ],
        );

        return TapHapticDetector(
          child: Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: AppBottomInsetScope(
              bottomInset: floatingChromeInset,
              child: body,
            ),
          ),
        );
      },
    );
  }
}

/// Root Navigator 中的 App Shell Route。
///
/// Shell 自身和 Tab Navigator 都在这条 Root Route 里。Full Player 等页面
/// 可以 push 到 Root Navigator，从而真正覆盖 Shell 和 BottomOverlay。
class MobileShellPage extends ConsumerWidget {
  const MobileShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appModeProvider);
    final initialRoute = _routeForDestination(mode.mobileInitialDestination);
    return MobileShell(
      child: Navigator(
        key: mobileNavigatorKey,
        observers: <NavigatorObserver>[mobileNavigatorObserver],
        initialRoute: initialRoute,
        onGenerateRoute: mobileOnGenerateRoute,
      ),
    );
  }
}

String _routeForDestination(AppDestination destination) {
  return switch (destination) {
    AppDestination.home => MobileRoutes.home,
    AppDestination.discover => MobileRoutes.discover,
    AppDestination.library => MobileRoutes.library,
    AppDestination.stats => MobileRoutes.stats,
    _ => MobileRoutes.home,
  };
}

/// 移动端根 Navigator 的路由表。
///
/// 所有页面都在同一条 Navigator 上，预测性返回由 Flutter 原生处理，
/// 不再使用根 Navigator / 嵌套 Navigator 交错的导航方式。
Route<dynamic>? mobileOnGenerateRoute(RouteSettings settings) {
  final Widget page = switch (settings.name) {
    MobileRoutes.home => const MobileHomePage(),
    MobileRoutes.discover => const MobileDiscoverPage(),
    MobileRoutes.library => const MobileLibraryPage(),
    MobileRoutes.librarySongs => const MobileLibrarySongsPage(),
    MobileRoutes.libraryPlaylists => const MobileLibraryPlaylistsPage(),
    MobileRoutes.libraryArtists => const MobileLibraryArtistsPage(),
    MobileRoutes.libraryAlbums => const MobileLibraryAlbumsPage(),
    MobileRoutes.libraryPodcasts => const MobileLibraryPage(),
    MobileRoutes.search => const MobileSearchPage(),
    MobileRoutes.stats => const MobileStatsPage(),
    MobileRoutes.recent => const MobileRecentPage(),
    MobileRoutes.listenTogether => const MobileListenTogetherPage(),
    MobileRoutes.settings => const MobileSettingsPage(),
    MobileRoutes.aboutSettings => const MobileAboutSettingsPage(),
    MobileRoutes.colorMapping => const MobileColorMappingPage(),
    MobileRoutes.contentSettings => const MobileContentSettingsPage(),
    _ => const MobileHomePage(),
  };

  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => MobileNestedRoutePopGate(child: page),
  );
}
