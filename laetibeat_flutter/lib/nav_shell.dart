import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:window_manager/window_manager.dart';

class NavShell extends StatefulWidget {
  const NavShell({super.key});

  @override
  State<NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<NavShell> {
  static const _animDuration = Duration(milliseconds: 280);
  static const _animCurve = Curves.easeOutCubic;

  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const Center(child: Text('Home')),
    const Center(child: Text('Search')),
    const Center(child: Text('Library')),
    const Center(child: Text('Settings')),
  ];

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
            sections: const <M3ENavigationRailSection>[
              M3ENavigationRailSection(
                destinations: <M3ENavigationRailDestination>[
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
              ),
            ],
            selectedIndex: _selectedIndex, 
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            type: M3ENavigationRailType.alwaysCollapse,
            modality: M3ENavigationRailModality.standard,
            labelBehavior: M3ENavigationRailLabelBehavior.alwaysShow,
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
                    child: _pages[_selectedIndex],
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