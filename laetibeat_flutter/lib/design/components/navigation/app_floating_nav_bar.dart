import 'dart:math' as math;
import 'dart:ui' show SemanticsRole, lerpDouble;

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:motor/motor.dart';

import '../../tokens/app_color_tokens.dart';
import '../../tokens/app_layout_tokens.dart';
import '../../tokens/app_shape_tokens.dart';
import '../../tokens/app_size_tokens.dart';
import '../../tokens/app_spacing_tokens.dart';
import '../text/app_text.dart';
import '../text/app_text_role.dart';

/// One destination in [AppFloatingNavBar].
class AppFloatingNavTab {
  const AppFloatingNavTab({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.semanticLabel,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final String? semanticLabel;
}

/// Floating Material 3 Expressive navigation bar.
///
/// The bar contains a row of expanding tabs plus a separate search FAB.
/// Search is intentionally not a tab: it is an action and does not change
/// [selectedIndex].
class AppFloatingNavBar extends StatelessWidget {
  const AppFloatingNavBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onSearchPressed,
    this.searchIcon = Icons.search,
    this.searchLabel = '搜索',
    this.horizontalPadding = AppLayout.pageGutter,
    this.bottomPadding = AppSpacing.sm,
    this.safeArea = true,
    this.expanded = true,
  }) : assert(tabs.length > 0);

  /// Total height of the floating toolbar variant, excluding safe-area padding.
  static const double height = AppComponentSize.navigationBar;

  /// Height including the bottom safe area and bottom padding used by this
  /// instance. Bottom overlays consume this to position the mini player above
  /// the floating bar without re-laying out page content.
  double resolvedHeight(BuildContext context) {
    final double safeBottom = safeArea
        ? MediaQuery.paddingOf(context).bottom
        : 0;
    return height + math.max(safeBottom, bottomPadding);
  }

  final List<AppFloatingNavTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onSearchPressed;

  final IconData searchIcon;
  final String searchLabel;

  final double horizontalPadding;
  final double bottomPadding;
  final bool safeArea;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final int safeIndex = selectedIndex.clamp(0, tabs.length - 1);

    final Row tabRow = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.xxs,
      children: <Widget>[
        for (var index = 0; index < tabs.length; index++)
          _AppFloatingNavItem(
            key: ValueKey<String>('app_floating_nav_tab_$index'),
            tab: tabs[index],
            selected: index == safeIndex,
            onTap: () => onTabSelected(index),
          ),
      ],
    );

    final Widget toolbar = M3EFabHorizontalFloatingToolbar(
      key: const ValueKey<String>('app_floating_nav_toolbar'),
      expanded: expanded,
      alignment: Alignment.bottomCenter,
      fabPosition: M3EFloatingToolbarHorizontalFabPosition.end,
      decoration: M3EFloatingToolbarDecoration(
        colors: M3EFloatingToolbarDefaults.standardColors(context),
        motion: M3EMotion.expressiveSpatialFast,
        contentPadding: const EdgeInsets.all(AppSpacing.sm),
      ),
      content: tabRow,
      floatingActionButton: Semantics(
        button: true,
        label: searchLabel,
        child: M3EFab(
          key: const ValueKey<String>('app_floating_nav_search'),
          icon: Icon(searchIcon),
          size: M3EFabSize.medium,
          color: M3EFabColor.primary,
          onPressed: onSearchPressed,
        ),
      ),
    );

    final EdgeInsets padding = EdgeInsets.only(
      left: horizontalPadding,
      right: horizontalPadding,
      bottom: bottomPadding,
    );

    if (safeArea) {
      return SafeArea(top: false, minimum: padding, child: toolbar);
    }
    return Padding(padding: padding, child: toolbar);
  }
}

class _AppFloatingNavItem extends StatefulWidget {
  const _AppFloatingNavItem({
    super.key,
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppFloatingNavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AppFloatingNavItem> createState() => _AppFloatingNavItemState();
}

class _AppFloatingNavItemState extends State<_AppFloatingNavItem>
    with SingleTickerProviderStateMixin {
  late final SingleMotionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SingleMotionController(
      motion: M3EMotion.expressiveSpatialFast.toMotion(),
      vsync: this,
      initialValue: widget.selected ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant _AppFloatingNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _controller.animateTo(widget.selected ? 1.0 : 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = widget.selected
        ? (widget.tab.selectedIcon ?? widget.tab.icon)
        : widget.tab.icon;

    return Semantics(
      role: SemanticsRole.tab,
      selected: widget.selected,
      label: widget.tab.semanticLabel ?? widget.tab.label,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) {
          final double progress = _controller.value.clamp(0.0, 1.0);
          final double width = lerpDouble(
            AppComponentSize.floatingNavTabCollapsed,
            AppComponentSize.floatingNavTabExpanded,
            progress,
          )!;
          final Color background = Color.lerp(
            Colors.transparent,
            scheme.secondaryContainer,
            progress,
          )!;
          final Color foreground = Color.lerp(
            scheme.onSurfaceVariant,
            scheme.onSecondaryContainer,
            progress,
          )!;

          return Container(
            width: width,
            height: AppComponentSize.floatingNavTabHeight,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: background,
              borderRadius: AppRadii.fullAll,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  M3EHapticFeedback.light.apply();
                  widget.onTap();
                },
                excludeFromSemantics: true,
                customBorder: const StadiumBorder(),
                overlayColor: WidgetStateProperty.resolveWith<Color?>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.pressed)) {
                    return foreground.withValues(alpha: 0.12);
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return foreground.withValues(alpha: 0.08);
                  }
                  return null;
                }),
                child: ClipRect(
                  child: Center(
                    child: OverflowBox(
                      minWidth: 0,
                      maxWidth: AppComponentSize.floatingNavTabExpanded,
                      minHeight: 0,
                      maxHeight: AppComponentSize.floatingNavTabHeight,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(icon, color: foreground, size: AppIconSize.md),
                          if (progress > 0.01)
                            ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress,
                                child: Opacity(
                                  opacity: progress,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: AppSpacing.xs + AppSpacing.xxs,
                                    ),
                                    child: AppText(
                                      widget.tab.label,
                                      role: AppTextRole.labelLarge,
                                      colorRole: AppColorRole.onSurfaceVariant,
                                      style: TextStyle(
                                        color: foreground,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
