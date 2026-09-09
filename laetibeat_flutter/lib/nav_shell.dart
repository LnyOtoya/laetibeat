import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/home_page.dart';

class NavShell extends StatefulWidget {
  const NavShell({super.key});

  @override
  State<NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<NavShell> {
  static const _animDuration = Duration(milliseconds: 280);
  static const _animCurve = Curves.easeOutCubic;
  static const _navDestCount = 4;

  int _selectedIndex = 0;
  int _pageIndex = 0;
  bool _navRailExpanded = false;
  _PlaylistItem? _selectedPlaylist;

  final List<Widget> _pages = const [
    HomePage(),
    Center(child: Text('Search')),
    Center(child: Text('Library')),
    Center(child: Text('Settings')),
  ];


  final List<_PlaylistItem> _playlists = const [
    _PlaylistItem(icon: M3EIcons.favorite, label: 'Favorite'),
    _PlaylistItem(icon: M3EIcons.history, label: 'History'),
    _PlaylistItem(icon: M3EIcons.auto_awesome, label: 'Daily Recommend'),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
      if (index < _navDestCount) {
        _pageIndex = index;
        _selectedPlaylist = null;
      } else {
        _selectedPlaylist = _playlists[index - _navDestCount];
      }
    });
  }

  List<M3ENavigationRailSection> _buildSections() {
    final navSection = M3ENavigationRailSection(
      destinations: const [
        M3ENavigationRailDestination(
          icon: Icon(M3EIcons.home),
          label: 'Home',
        ),
        M3ENavigationRailDestination(
          icon: Icon(M3EIcons.search),
          label: 'Search',
        ),
        M3ENavigationRailDestination(
          icon: Icon(M3EIcons.music_note),
          label: 'Library',
        ),
        M3ENavigationRailDestination(
          icon: Icon(M3EIcons.settings),
          label: 'Settings',
        ),
      ],
    );

    if (!_navRailExpanded) {
      return [navSection];
    }

    // 展开时额外显示歌单 Section
    return [
      navSection,
      M3ENavigationRailSection(
        header: Padding(
          padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
          child: Text(
            'Playlists',
            style: M3ETheme.of(context).typeScale.labelMedium?.copyWith(
              color: M3ETheme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        destinations: _playlists.map((p) => M3ENavigationRailDestination(
          icon: Icon(p.icon),
          label: p.label,
          short: true,
        )).toList(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Scaffold(
      body: AnimatedContainer(
        duration: _animDuration,
        curve: _animCurve,
        color: theme.colorScheme.surfaceContainer,
        child: Row(
        children: [
          M3ENavigationRail(
            background: theme.colorScheme.surfaceContainer,
            sections: _buildSections(),
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            type: M3ENavigationRailType.collapsed,
            modality: M3ENavigationRailModality.standard,
            labelBehavior: M3ENavigationRailLabelBehavior.alwaysShow,
            onTypeChanged: (type) {
              setState(() => _navRailExpanded = type == M3ENavigationRailType.expanded);
            },
          ),
          Expanded(
            child: Column(
              children: [
                _buildTitleBar(),
                Expanded(
                  child: AnimatedContainer(
                    duration: _animDuration,
                    curve: _animCurve,
                    margin: EdgeInsets.fromLTRB(
                      theme.spacing.md, 
                      0, 
                      theme.spacing.md, 
                      theme.spacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: M3ETheme.of(context).colorScheme.surface,
                      borderRadius: M3EDimensions.borderRadiusMedium,
                    ),
                    child: _selectedPlaylist != null
                        ? Center(child: Text('Playlist: ${_selectedPlaylist!.label}'))
                        : _pages[_pageIndex],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  // 自定义顶栏
  Widget _buildTitleBar() {
    final theme = M3ETheme.of(context);

    return DragToMoveArea(
      child: AnimatedContainer(
        duration: _animDuration,
        curve: _animCurve,
        color:  theme.colorScheme.surfaceContainer,
        // height: theme.spacing.xxl,
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.xs,
        ),
        child: Row(
          children: [
            Expanded(child: SizedBox()),      
            M3EIconButton(
              size: M3EIconButtonSize.xs,
              icon: const Icon(M3EIcons.minimize),
              tooltip: '最小化',
              onPressed: () => windowManager.minimize(),
            ),
            M3EIconButton(
              size: M3EIconButtonSize.xs,
              icon: const Icon(M3EIcons.crop_square),
              tooltip: '最大化',
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            M3EIconButton(
              size: M3EIconButtonSize.xs,
              icon: const Icon(M3EIcons.close),
              tooltip: '关闭',
              onPressed: () => windowManager.close(),
            ),      
          ],
        ),
      ),
    );
  }

}

// 歌单项结构辅助类
class _PlaylistItem {
  final IconData icon;
  final String label;
  const _PlaylistItem({required this.icon, required this.label});
}