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
import 'routes.dart';
import 'search/mobile_search_browse_view.dart';
import 'search/mobile_search_inline_view.dart';
import 'search/mobile_search_page.dart';
import 'settings/content/mobile_content_settings_page.dart';
import 'settings/mobile_settings_page.dart';
import 'stats/mobile_stats_page.dart';

/// 移动端 Shell。
///
/// [child] 是 MaterialApp 的根 Navigator。所有页面都在这条 Navigator 上，
/// Shell 负责底部导航、inline search、MiniPlayer 和底部 inset。
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
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey<MobileSearchInlineViewState> _searchViewKey =
      GlobalKey<MobileSearchInlineViewState>();

  bool _isSearching = false;
  bool _searchFieldFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchFocusChanged() {
    if (!mounted) return;
    final focused = _searchFocusNode.hasFocus;
    if (focused == _searchFieldFocused) return;
    setState(() => _searchFieldFocused = focused);
  }

  List<AppMorphingTab> _destinations(AppLocalizations l10n) {
    return <AppMorphingTab>[
      AppMorphingTab(icon: M3EIcons.home, label: l10n.navHome),
      AppMorphingTab(icon: M3EIcons.music_note, label: l10n.navLibrary),
      AppMorphingTab(icon: M3EIcons.bar_chart, label: l10n.statisticsTitle),
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
    };
    return visible.contains(route);
  }

  void _selectTab(AppDestination destination) {
    if (_isSearching) _closeSearch();
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
      case AppDestination.search:
        if (current == MobileRoutes.search) return;
        navigator.pushNamed(MobileRoutes.search);
        return;
      default:
        return;
    }
  }

  void _handleSearchToggle(bool value) {
    if (value) {
      if (_isSearching) return;
      _searchFocusNode.unfocus();
      setState(() {
        _isSearching = true;
        _searchFieldFocused = false;
      });
    } else {
      _closeSearch();
    }
  }

  void _closeSearch() {
    if (!_isSearching) return;
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchFieldFocused = false;
    });
  }

  void _clearSearchText() {
    if (_searchController.text.isEmpty) {
      _closeSearch();
      return;
    }
    _searchController.clear();
  }

  void _selectGenre(String genre) {
    _searchController.value = TextEditingValue(
      text: genre,
      selection: TextSelection.collapsed(offset: genre.length),
    );
    _searchFocusNode.requestFocus();
  }

  void _submitSearch(String query) {
    _searchViewKey.currentState?.submit(query);
  }

  double _bottomOverlayInset(
    BuildContext context, {
    required bool showNavigationBar,
    required bool showMiniPlayer,
  }) {
    if (!showNavigationBar) return 0;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return AppSpacing.sm +
        AppComponentSize.morphingBar +
        safeBottom +
        (showMiniPlayer ? AppComponentSize.miniPlayerAccessory : 0);
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
        final bool isHome = routeName == null || routeName == MobileRoutes.home;
        final bool showMiniPlayer =
            hasTrack && showNavigationBar && !isHome && !_searchFieldFocused;
        final double bottomInset = _bottomOverlayInset(
          context,
          showNavigationBar: showNavigationBar,
          showMiniPlayer: showMiniPlayer,
        );

        final bottomBar = showNavigationBar
            ? AppMorphingTabBar(
                key: const ValueKey('mobile_morphing_tab_bar'),
                tabs: _destinations(l10n),
                selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                onTabSelected: (int index) {
                  if (index < 0 || index >= _tabs.length) return;
                  _selectTab(_tabs[index]);
                },
                isSearching: _isSearching,
                searchEditing: _searchFieldFocused,
                onSearchToggle: _handleSearchToggle,
                onSearchClear: _clearSearchText,
                searchConfig: AppMorphingSearchConfig(
                  hintText: l10n.searchHint,
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onSubmitted: _submitSearch,
                  showClearButton: false,
                ),
                bottomAccessory: showMiniPlayer ? const MiniPlayer() : null,
                hideBottomAccessoryWhenSearching: false,
                floatAboveKeyboard: false,
              )
            : null;

        final body = Stack(
          children: <Widget>[
            Positioned.fill(
              child: Offstage(offstage: _isSearching, child: widget.child),
            ),
            if (_isSearching)
              Positioned.fill(
                child: _searchFieldFocused
                    ? MobileSearchInlineView(
                        key: _searchViewKey,
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onClose: _closeSearch,
                      )
                    : MobileSearchBrowseView(onGenreSelected: _selectGenre),
              ),
            if (bottomBar != null)
              Positioned(left: 0, right: 0, bottom: 0, child: bottomBar),
          ],
        );

        return TapHapticDetector(
          child: PopScope(
            canPop: !_isSearching,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (!didPop && _isSearching) _closeSearch();
            },
            child: Scaffold(
              backgroundColor: theme.colorScheme.surfaceContainer,
              body: AppBottomInsetScope(bottomInset: bottomInset, child: body),
            ),
          ),
        );
      },
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
    MobileRoutes.search => const MobileSearchPage(),
    MobileRoutes.stats => const MobileStatsPage(showBackButton: false),
    MobileRoutes.settings => const MobileSettingsPage(),
    MobileRoutes.contentSettings => const MobileContentSettingsPage(),
    _ => const MobileHomePage(),
  };

  return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
}
