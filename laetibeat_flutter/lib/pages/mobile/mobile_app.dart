import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_destination.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/feedback/app_haptics.dart';
import '../../shared/layout/app_bottom_inset.dart';
import '../../widgets/player/player_provider.dart';
import 'home/mobile_home_page.dart';
import 'library/mobile_library_page.dart';
import 'library/mobile_library_subpages.dart';
import 'mobile_navigation.dart';
import 'player/mini_player.dart';
import 'radio/mobile_radio_page.dart';
import 'routes.dart';
import 'search/mobile_search_page.dart';
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
  static const List<AppDestination> _tabs = <AppDestination>[
    AppDestination.home,
    AppDestination.library,
    AppDestination.stats,
    AppDestination.radio,
  ];

  List<AppFloatingNavTab> _destinations(AppLocalizations l10n) {
    return <AppFloatingNavTab>[
      AppFloatingNavTab(
        icon: M3EIcons.home,
        selectedIcon: M3EIcons.home,
        label: l10n.navHome,
      ),
      AppFloatingNavTab(
        icon: M3EIcons.music_note,
        selectedIcon: M3EIcons.music_note,
        label: l10n.navLibrary,
      ),
      AppFloatingNavTab(
        icon: M3EIcons.bar_chart,
        selectedIcon: M3EIcons.bar_chart,
        label: l10n.statisticsTitle,
      ),
      AppFloatingNavTab(
        icon: M3EIcons.radio,
        selectedIcon: M3EIcons.radio,
        label: l10n.navRadio,
      ),
    ];
  }

  AppDestination? _tabForRoute(String? route) {
    if (route == null || route == MobileRoutes.home) {
      return AppDestination.home;
    }
    if (route == MobileRoutes.library || route.startsWith('/library/')) {
      return AppDestination.library;
    }
    if (route == MobileRoutes.stats) {
      return AppDestination.stats;
    }
    if (route == MobileRoutes.radio) {
      return AppDestination.radio;
    }
    return null;
  }

  bool _showNavigationBar(String? route) {
    const visible = <String>{
      MobileRoutes.home,
      MobileRoutes.library,
      MobileRoutes.librarySongs,
      MobileRoutes.libraryPlaylists,
      MobileRoutes.libraryArtists,
      MobileRoutes.libraryAlbums,
      MobileRoutes.stats,
      MobileRoutes.radio,
    };
    return visible.contains(route);
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
      case AppDestination.radio:
        if (current == MobileRoutes.radio) return;
        navigator.pushNamed(MobileRoutes.radio);
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
    final bool hasTrack = ref.watch(
      playerProvider.select((state) => state.current != null),
    );

    return ValueListenableBuilder<String?>(
      valueListenable: mobileCurrentRouteName,
      builder: (BuildContext context, String? routeName, Widget? _) {
        final AppDestination tab =
            _tabForRoute(routeName) ?? AppDestination.home;
        final int selectedIndex = _tabs.indexOf(tab);
        final bool showNavigationBar = _showNavigationBar(routeName);
        final bool showMiniPlayer = hasTrack && showNavigationBar;
        final AppFloatingNavBar? navBar = showNavigationBar
            ? AppFloatingNavBar(
                key: const ValueKey<String>('mobile_floating_nav_bar'),
                tabs: _destinations(l10n),
                selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                onTabSelected: (int index) {
                  if (index < 0 || index >= _tabs.length) return;
                  _selectTab(_tabs[index]);
                },
                onSearchPressed: _openSearch,
                searchLabel: l10n.searchHint,
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
              );

        // This is a metric for page-owned scroll/content padding. The Shell
        // never wraps the page in this padding, so page layout stays full-bleed.
        final double floatingChromeInset = showNavigationBar
            ? navigationBarHeight +
                  (showMiniPlayer ? AppComponentSize.miniPlayerAccessory : 0)
            : 0;

        final body = Stack(
          children: <Widget>[
            Positioned.fill(child: widget.child),
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
class MobileShellPage extends StatelessWidget {
  const MobileShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MobileShell(
      child: Navigator(
        key: mobileNavigatorKey,
        observers: <NavigatorObserver>[mobileNavigatorObserver],
        initialRoute: MobileRoutes.home,
        onGenerateRoute: mobileOnGenerateRoute,
      ),
    );
  }
}

/// 移动端根 Navigator 的路由表。
///
/// 所有页面都在同一条 Navigator 上，预测性返回由 Flutter 原生处理，
/// 不再使用根 Navigator / 嵌套 Navigator 交错的导航方式。
Route<dynamic>? mobileOnGenerateRoute(RouteSettings settings) {
  final Widget page = switch (settings.name) {
    MobileRoutes.home => const MobileHomePage(),
    MobileRoutes.library => const MobileLibraryPage(),
    MobileRoutes.librarySongs => const MobileLibrarySongsPage(),
    MobileRoutes.libraryPlaylists => const MobileLibraryPlaylistsPage(),
    MobileRoutes.libraryArtists => const MobileLibraryArtistsPage(),
    MobileRoutes.libraryAlbums => const MobileLibraryAlbumsPage(),
    MobileRoutes.libraryPodcasts => const MobileLibraryPage(),
    MobileRoutes.radio => const MobileRadioPage(),
    MobileRoutes.search => const MobileSearchPage(),
    MobileRoutes.stats => const MobileStatsPage(showBackButton: false),
    MobileRoutes.settings => const MobileSettingsPage(),
    MobileRoutes.colorMapping => const MobileColorMappingPage(),
    MobileRoutes.contentSettings => const MobileContentSettingsPage(),
    _ => const MobileHomePage(),
  };

  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => MobileNestedRoutePopGate(child: page),
  );
}
