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
/// [child] 是唯一的 MaterialApp root Navigator。Shell 持久覆盖其上方，
/// 负责底部导航、MiniPlayer 和页面底部 inset。
class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _NavigationBarScrollThreshold extends StatefulWidget {
  const _NavigationBarScrollThreshold({required this.child});

  final Widget child;

  @override
  State<_NavigationBarScrollThreshold> createState() =>
      _NavigationBarScrollThresholdState();
}

class _NavigationBarScrollThresholdState
    extends State<_NavigationBarScrollThreshold> {
  double _accumulatedScroll = 0;
  bool _thresholdReached = false;

  bool _filterScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return true;

    if (notification is ScrollUpdateNotification && !_thresholdReached) {
      _accumulatedScroll += notification.scrollDelta ?? 0;
      if (_accumulatedScroll.abs() <
          M3EFloatingToolbarDefaults.scrollDistanceThreshold) {
        return true;
      }
      _thresholdReached = true;
      _accumulatedScroll = 0;
    } else if (notification is ScrollEndNotification) {
      _accumulatedScroll = 0;
      _thresholdReached = false;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _filterScrollNotification,
      child: widget.child,
    );
  }
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
            AppDestination.library => M3EIcons.music_note,
            AppDestination.stats => M3EIcons.bar_chart,
            _ => M3EIcons.more_horiz,
          };
          final label = switch (tab) {
            AppDestination.home => l10n.navHome,
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

  bool _showNavigationBar(String? route) {
    if (route == null || route == MobileRoutes.home) return true;
    return route == MobileRoutes.library || route.startsWith('/library/');
  }

  bool _showMiniPlayer(String? route) {
    if (route == MobileRoutes.playback ||
        route == MobileRoutes.settings ||
        (route?.startsWith('/settings/') ?? false)) {
      return false;
    }
    return true;
  }

  void _selectTab(AppDestination destination) {
    final mode = ref.read(appModeProvider);
    if (!mode.mobileDestinations.contains(destination)) return;

    final navigator = mobileRootNavigatorKey.currentState;
    if (navigator == null) return;

    if (mobileCurrentRouteName.value != MobileRoutes.home) {
      navigator.popUntil((Route<dynamic> route) => route.isFirst);
    }
    ref.read(mobileSelectedDestinationProvider.notifier).select(destination);
  }

  void _openSearch() {
    if (mobileCurrentRouteName.value?.startsWith('/search') ?? false) return;
    pushMobileRootPage(
      context,
      const MobileSearchPage(),
      name: MobileRoutes.search,
    );
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
      final selectedDestination = ref.read(mobileSelectedDestinationProvider);
      final isShellRoute =
          currentRoute == null || currentRoute == MobileRoutes.home;
      final isLibraryRoute =
          currentRoute == MobileRoutes.library ||
          (currentRoute?.startsWith('/library/') ?? false);
      final currentRouteAvailable =
          nextTabs.contains(selectedDestination) &&
          (isShellRoute ||
              (isLibraryRoute && nextTabs.contains(AppDestination.library)));
      if (currentRouteAvailable) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = mobileRootNavigatorKey.currentState;
        if (navigator == null) return;
        navigator.popUntil((Route<dynamic> route) => route.isFirst);
        ref
            .read(mobileSelectedDestinationProvider.notifier)
            .select(next.mobileInitialDestination);
      });
    });

    final selectedDestination = ref.watch(mobileSelectedDestinationProvider);
    return ValueListenableBuilder<String?>(
      valueListenable: mobileCurrentRouteName,
      builder: (BuildContext context, String? routeName, Widget? _) {
        final destination = tabs.contains(selectedDestination)
            ? selectedDestination
            : tabs.first;
        final int selectedIndex = tabs.indexOf(destination);
        final bool showNavigationBar = _showNavigationBar(routeName);
        final bool showMiniPlayer = hasTrack && _showMiniPlayer(routeName);
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

        final double navigationBarHeight =
            navBar?.resolvedHeight(context) ??
            (showMiniPlayer ? MediaQuery.paddingOf(context).bottom : 0);
        final Widget? bottomBar = navBar == null && !showMiniPlayer
            ? null
            : AppBottomOverlay(
                navigationBar: navBar ?? const SizedBox.shrink(),
                navigationBarHeight: navigationBarHeight,
                miniPlayer: const MiniPlayer(),
                miniVisible: showMiniPlayer,
                miniPlayerHeight: AppComponentSize.miniPlayerAccessory,
                navBarScrollState: showNavigationBar
                    ? _navBarScrollBehavior.state
                    : null,
              );

        // This is a metric for page-owned scroll/content padding. The Shell
        // never wraps the page in this padding, so page layout stays full-bleed.
        final double floatingChromeInset =
            (showNavigationBar ? navigationBarHeight : 0) +
            (showMiniPlayer ? AppComponentSize.miniPlayerAccessory : 0);

        final body = Stack(
          children: <Widget>[
            Positioned.fill(
              child: M3EFloatingToolbarScrollWrapper(
                behavior: _navBarScrollBehavior,
                child: _NavigationBarScrollThreshold(child: widget.child),
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

/// 一级目的地容器。Tab 切换只改变选中状态，不进入页面返回栈。
class MobileShellPage extends ConsumerStatefulWidget {
  const MobileShellPage({super.key});

  @override
  ConsumerState<MobileShellPage> createState() => _MobileShellPageState();
}

class _MobileShellPageState extends ConsumerState<MobileShellPage> {
  final Set<AppDestination> _visitedDestinations = <AppDestination>{};
  final Map<AppDestination, Widget> _pages = <AppDestination, Widget>{};

  @override
  void initState() {
    super.initState();
    _visitedDestinations.add(ref.read(mobileSelectedDestinationProvider));
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appModeProvider);
    final destinations = mode.mobileDestinations;
    final selectedDestination = ref.watch(mobileSelectedDestinationProvider);
    final destination = destinations.contains(selectedDestination)
        ? selectedDestination
        : mode.mobileInitialDestination;
    _visitedDestinations.add(destination);

    return IndexedStack(
      index: destinations.indexOf(destination),
      children: destinations
          .map((AppDestination tab) {
            if (!_visitedDestinations.contains(tab)) {
              return SizedBox.shrink(
                key: ValueKey<String>('unvisited-${tab.name}'),
              );
            }
            return KeyedSubtree(
              key: ValueKey<AppDestination>(tab),
              child: _pages.putIfAbsent(tab, () => _pageFor(tab)),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _pageFor(AppDestination destination) {
    return switch (destination) {
      AppDestination.home => const MobileHomePage(),
      AppDestination.library => const MobileLibraryPage(),
      AppDestination.stats => const MobileStatsPage(),
      _ => const MobileHomePage(),
    };
  }
}

/// 移动端 root Navigator 的路由表。
Route<dynamic>? mobileOnGenerateRoute(RouteSettings settings) {
  final Widget? page = switch (settings.name) {
    MobileRoutes.home => const MobileHomePage(),
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
    _ => null,
  };

  if (page == null) return null;
  return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
}
