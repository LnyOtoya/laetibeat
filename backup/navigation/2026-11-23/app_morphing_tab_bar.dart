import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/physics.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../tokens/app_color_tokens.dart';
import '../../tokens/app_layout_tokens.dart';
import '../../tokens/app_motion_tokens.dart';
import '../../tokens/app_shape_tokens.dart';
import '../../tokens/app_size_tokens.dart';
import '../../tokens/app_spacing_tokens.dart';
import '../text/app_text.dart';
import '../text/app_text_role.dart';

/// One destination in [AppMorphingTabBar].
class AppMorphingTab {
  const AppMorphingTab({
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

/// A trailing action rendered next to the search pill.
class AppMorphingTabAction {
  const AppMorphingTabAction({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;
}

/// Search-field configuration for [AppMorphingTabBar].
class AppMorphingSearchConfig {
  const AppMorphingSearchConfig({
    this.hintText = '搜索',
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.autoFocus = false,
    this.showClearButton = true,
    this.onClear,
  });

  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autoFocus;

  /// Whether the trailing clear/cancel affordance is shown while the field
  /// is expanded. Use this to hide it in browse mode and reveal it on focus.
  final bool showClearButton;

  /// Runs when the trailing affordance is tapped. Defaults to closing search.
  final VoidCallback? onClear;
}

/// M3E-styled bottom bar that morphs between tabs and search.
///
/// Default: an expanded tab pill + a search pill + optional trailing action.
/// Searching: a collapsed leading pill + an expanded search pill.
///
/// The two pills share one width spring: the left pill collapses while the
/// right pill grows, so the search field is revealed spatially instead of
/// being swapped in. The spring is retargeted from the current value and
/// velocity, so tapping search again mid-flight reverses cleanly.
class AppMorphingTabBar extends StatefulWidget {
  const AppMorphingTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.isSearching = false,
    this.searchEditing = false,
    this.onSearchToggle,
    this.onSearchPressed,
    this.searchConfig = const AppMorphingSearchConfig(),
    this.onSearchClear,
    this.searchClearIcon = M3EIcons.close,
    this.searchClearLabel = '清除',
    this.extraAction,
    this.searchModeLeadingIcon = M3EIcons.home,
    this.searchModeLeadingLabel = '返回',
    this.horizontalPadding,
    this.bottomPadding = AppSpacing.sm,
    this.barHeight = AppComponentSize.morphingBar,
    this.searchPillWidth = AppComponentSize.morphingPill,
    this.spacing = AppSpacing.sm,
    this.safeArea = true,
    this.hideExtraActionWhenSearching = true,
    this.bottomAccessory,
    this.bottomAccessorySpacing = 0,
    this.hideBottomAccessoryWhenSearching = true,
    this.floatAboveKeyboard = true,
    this.spring = M3EMotion.expressiveSpatialDefault,
  }) : assert(tabs.length > 0);

  final List<AppMorphingTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final bool isSearching;

  /// Whether the search field currently owns the whole left side.
  ///
  /// Browse: leading pill + expanded search field.
  /// Editing: search field on the left + a separate clear pill on the right.
  final bool searchEditing;
  final ValueChanged<bool>? onSearchToggle;
  final VoidCallback? onSearchClear;
  final IconData searchClearIcon;
  final String searchClearLabel;

  /// When provided, the search pill runs this action instead of entering the
  /// inline search state. Use this to open a dedicated search page while the
  /// morph remains available for hosts that own an inline search view.
  final VoidCallback? onSearchPressed;
  final AppMorphingSearchConfig searchConfig;
  final AppMorphingTabAction? extraAction;

  final IconData searchModeLeadingIcon;
  final String searchModeLeadingLabel;

  /// Horizontal gutter. When null, uses [AppLayout.gutterFor].
  final double? horizontalPadding;
  final double bottomPadding;
  final double barHeight;
  final double searchPillWidth;
  final double spacing;
  final bool safeArea;
  final bool hideExtraActionWhenSearching;

  /// Optional widget above the bar, e.g. a Mini Player.
  ///
  /// The accessory is rendered full-width; it is responsible for its own
  /// horizontal inset. The bar's [horizontalPadding] applies only to the pills.
  final Widget? bottomAccessory;
  final double bottomAccessorySpacing;
  final bool hideBottomAccessoryWhenSearching;

  /// Lifts the bar above the software keyboard.
  ///
  /// Set false when the host already handles the keyboard inset, e.g. a
  /// Scaffold with `resizeToAvoidBottomInset`.
  final bool floatAboveKeyboard;

  /// Spring used for the tab-pill/search-pill width morph.
  final M3ESpring spring;

  @override
  State<AppMorphingTabBar> createState() => _AppMorphingTabBarState();
}

class _AppMorphingTabBarState extends State<AppMorphingTabBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _morphController;
  late bool _searching;
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _searching = widget.isSearching;
    _morphController = AnimationController.unbounded(
      vsync: this,
      value: _searching ? 1 : 0,
    );
    _bindSearchNodes();
  }

  @override
  void didUpdateWidget(covariant AppMorphingTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isSearching != widget.isSearching &&
        widget.isSearching != _searching) {
      _searching = widget.isSearching;
      if (!_searching) _focusNode.unfocus();
      _animateTo(_searching);
    }

    if (oldWidget.searchConfig.controller != widget.searchConfig.controller ||
        oldWidget.searchConfig.focusNode != widget.searchConfig.focusNode) {
      _releaseSearchNodes();
      _bindSearchNodes();
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    _releaseSearchNodes();
    super.dispose();
  }

  void _bindSearchNodes() {
    _controller = widget.searchConfig.controller ?? TextEditingController();
    _ownsController = widget.searchConfig.controller == null;
    _focusNode = widget.searchConfig.focusNode ?? FocusNode();
    _ownsFocusNode = widget.searchConfig.focusNode == null;
  }

  void _releaseSearchNodes() {
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
  }

  void _setSearching(bool value) {
    if (_searching == value) return;
    setState(() => _searching = value);
    _animateTo(value);
    if (!value) _focusNode.unfocus();
    widget.onSearchToggle?.call(value);
  }

  void _animateTo(bool searching) {
    final target = searching ? 1.0 : 0.0;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _morphController.value = target;
      return;
    }

    final current = _morphController.value;
    final velocity = _morphController.velocity;
    if ((current - target).abs() < 0.001 && velocity.abs() < 0.001) {
      _morphController.value = target;
      return;
    }

    _morphController.animateWith(
      SpringSimulation(
        widget.spring.toDescription(),
        current,
        target,
        velocity,
      ),
    );
  }

  int get _selectedIndex =>
      widget.selectedIndex.clamp(0, widget.tabs.length - 1);

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final gutter =
        widget.horizontalPadding ??
        AppLayout.gutterFor(MediaQuery.sizeOf(context).width);

    final bar = Padding(
      padding: EdgeInsets.only(
        left: gutter,
        right: gutter,
        bottom: widget.bottomPadding,
      ),
      child: SizedBox(
        height: widget.barHeight,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return AnimatedBuilder(
              animation: _morphController,
              builder: (BuildContext context, Widget? child) {
                return _buildMorphRow(theme, constraints.maxWidth);
              },
            );
          },
        ),
      ),
    );

    final showAccessory =
        widget.bottomAccessory != null &&
        !(widget.hideBottomAccessoryWhenSearching && _searching);

    final content = AnimatedSize(
      duration: AppMotion.standard,
      curve: AppMotion.standardCurve,
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showAccessory) ...<Widget>[
            widget.bottomAccessory!,
            if (widget.bottomAccessorySpacing > 0)
              SizedBox(height: widget.bottomAccessorySpacing),
          ],
          bar,
        ],
      ),
    );

    final keyboardInset = widget.floatAboveKeyboard
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    final floatingContent = AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      duration: AppMotion.fast,
      curve: AppMotion.standardCurve,
      child: content,
    );

    return widget.safeArea
        ? SafeArea(top: false, child: floatingContent)
        : floatingContent;
  }

  Widget _buildMorphRow(M3EThemeData theme, double availableWidth) {
    final scheme = theme.colorScheme;
    final t = _morphController.value.clamp(0.0, 1.0);
    final editing = _searching && widget.searchEditing;

    final extraFullWidth = widget.extraAction == null
        ? 0.0
        : widget.searchPillWidth;
    final hidesExtra =
        widget.extraAction != null && widget.hideExtraActionWhenSearching;
    final extraWidth = editing
        ? 0.0
        : (hidesExtra ? extraFullWidth * (1 - t) : extraFullWidth);
    final clearWidth = editing ? widget.searchPillWidth : 0.0;

    final expandedLeftWidth = math.max(
      0.0,
      availableWidth - widget.searchPillWidth - widget.spacing - extraFullWidth,
    );
    final leftWidth = editing
        ? 0.0
        : _lerpDouble(expandedLeftWidth, widget.searchPillWidth, t);

    final showTabs = t < 0.999 || !_searching;
    final showLeading = !editing && (t > 0.001 || _searching);
    final showSearchButton = t < 0.999 || !_searching;
    final showSearchField = t > 0.001 || _searching;
    final hasLeftPill = leftWidth > 0.01;
    final hasClearPill = clearWidth > 0.01;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          key: const ValueKey('app_morphing_left_pill'),
          width: leftWidth,
          child: hasLeftPill
              ? _Pill(
                  color: scheme.surfaceContainerHigh,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (showTabs)
                        _FadeLayer(
                          opacity: 1 - t,
                          ignorePointer: t >= 0.5,
                          excludeSemantics: t >= 0.5,
                          child: _buildTabs(theme),
                        ),
                      if (showLeading)
                        _FadeLayer(
                          opacity: t,
                          ignorePointer: t < 0.5,
                          excludeSemantics: t < 0.5,
                          child: _buildCollapsedLeadingContent(theme),
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        SizedBox(width: hasLeftPill ? widget.spacing : 0),
        Expanded(
          child: SizedBox(
            key: const ValueKey('app_morphing_right_pill'),
            child: _Pill(
              color: scheme.surfaceContainerHigh,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (showSearchButton)
                    _FadeLayer(
                      opacity: 1 - t,
                      ignorePointer: t >= 0.5,
                      excludeSemantics: t >= 0.5,
                      child: _buildSearchButtonContent(theme),
                    ),
                  if (showSearchField)
                    _FadeLayer(
                      opacity: t,
                      ignorePointer: t < 0.5,
                      excludeSemantics: t < 0.5,
                      child: _buildSearchFieldContent(theme),
                    ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: hasClearPill ? widget.spacing : 0),
        SizedBox(
          width: clearWidth,
          child: hasClearPill
              ? _Pill(
                  color: scheme.surfaceContainerHigh,
                  child: _buildSearchClearContent(theme),
                )
              : const SizedBox.shrink(),
        ),
        if (extraWidth > 0.01) ...<Widget>[
          SizedBox(width: widget.spacing),
          SizedBox(
            width: extraWidth,
            child: _Pill(
              color: scheme.surfaceContainerHigh,
              child: _FadeLayer(
                opacity: extraFullWidth == 0
                    ? 1
                    : (extraWidth / extraFullWidth).clamp(0.0, 1.0),
                ignorePointer: extraWidth < 1,
                excludeSemantics: extraWidth < 1,
                child: _buildExtraActionContent(theme, widget.extraAction!),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabs(M3EThemeData theme) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final slotWidth = constraints.maxWidth / widget.tabs.length;
        final inset = AppSpacing.xs;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (DragUpdateDetails details) {
            if (slotWidth <= 0) return;
            final index =
                ((details.localPosition.dx - slotWidth / 2) / slotWidth)
                    .round()
                    .clamp(0, widget.tabs.length - 1);
            if (index != _selectedIndex) {
              widget.onTabSelected(index);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              AnimatedPositioned(
                key: const ValueKey('app_morphing_tab_indicator'),
                duration: AppMotion.standard,
                curve: AppMotion.standardCurve,
                left: _selectedIndex * slotWidth + inset,
                top: inset,
                bottom: inset,
                width: math.max(0, slotWidth - inset * 2),
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: AppRadii.fullAll,
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var index = 0; index < widget.tabs.length; index++)
                    Expanded(
                      child: _TabItem(
                        tab: widget.tabs[index],
                        selected: index == _selectedIndex,
                        onTap: () => widget.onTabSelected(index),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchButtonContent(M3EThemeData theme) {
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: widget.searchConfig.hintText,
      child: InkWell(
        key: const ValueKey('app_morphing_search_button'),
        onTap: widget.onSearchPressed ?? () => _setSearching(true),
        excludeFromSemantics: true,
        customBorder: const StadiumBorder(),
        child: Center(
          child: Icon(
            M3EIcons.search,
            size: AppIconSize.md,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedLeadingContent(M3EThemeData theme) {
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: widget.searchModeLeadingLabel,
      child: InkWell(
        key: const ValueKey('app_morphing_collapsed_leading'),
        onTap: () => _setSearching(false),
        excludeFromSemantics: true,
        customBorder: const StadiumBorder(),
        child: Center(
          child: Icon(
            widget.searchModeLeadingIcon,
            size: AppIconSize.md,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchFieldContent(M3EThemeData theme) {
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final compact = constraints.maxWidth < 180;
        return Padding(
          padding: EdgeInsetsDirectional.only(
            start: compact ? AppSpacing.sm : AppSpacing.md,
            end: AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                M3EIcons.search,
                size: compact ? AppIconSize.xs : AppIconSize.sm,
                color: scheme.onSurfaceVariant,
              ),
              if (!compact) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: widget.searchConfig.autoFocus,
                  // The bar lives outside the root Navigator's Overlay. Disable
                  // selection handles/context menu so EditableText does not
                  // require an Overlay ancestor; typing, caret and IME still work.
                  enableInteractiveSelection: false,
                  contextMenuBuilder: null,
                  textInputAction: TextInputAction.search,
                  onChanged: widget.searchConfig.onChanged,
                  onSubmitted: widget.searchConfig.onSubmitted,
                  cursorColor: scheme.primary,
                  style: theme.typeScale.bodyMedium.copyWith(
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: widget.searchConfig.hintText,
                    hintStyle: theme.typeScale.bodyMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              if (!compact &&
                  widget.searchConfig.showClearButton &&
                  !widget.searchEditing)
                SizedBox.square(
                  dimension: AppTouchTarget.min,
                  child: Semantics(
                    button: true,
                    label: widget.searchConfig.onClear == null
                        ? '关闭搜索'
                        : '清空搜索',
                    child: InkWell(
                      key: const ValueKey('app_morphing_search_close'),
                      onTap:
                          widget.searchConfig.onClear ??
                          () => _setSearching(false),
                      excludeFromSemantics: true,
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: Icon(
                          M3EIcons.close,
                          size: AppIconSize.sm,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchClearContent(M3EThemeData theme) {
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: widget.searchClearLabel,
      child: InkWell(
        key: const ValueKey('app_morphing_search_clear_pill'),
        onTap: widget.onSearchClear ?? () => _setSearching(false),
        excludeFromSemantics: true,
        customBorder: const StadiumBorder(),
        child: Center(
          child: Icon(
            widget.searchClearIcon,
            size: AppIconSize.md,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildExtraActionContent(
    M3EThemeData theme,
    AppMorphingTabAction action,
  ) {
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: action.semanticLabel,
      child: InkWell(
        key: const ValueKey('app_morphing_extra_action'),
        onTap: action.onPressed,
        excludeFromSemantics: true,
        customBorder: const StadiumBorder(),
        child: Center(
          child: Icon(
            action.icon,
            size: AppIconSize.md,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  static double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppMorphingTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final icon = selected ? (tab.selectedIcon ?? tab.icon) : tab.icon;

    return Semantics(
      role: SemanticsRole.tab,
      selected: selected,
      label: tab.semanticLabel ?? tab.label,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        customBorder: const StadiumBorder(),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 22,
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: AppText(
                  tab.label,
                  role: AppTextRole.labelSmall,
                  colorRole: selected
                      ? AppColorRole.onSecondaryContainer
                      : AppColorRole.onSurfaceVariant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FadeLayer extends StatelessWidget {
  const _FadeLayer({
    required this.child,
    required this.opacity,
    required this.ignorePointer,
    required this.excludeSemantics,
  });

  final Widget child;
  final double opacity;
  final bool ignorePointer;
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: ignorePointer,
      child: ExcludeSemantics(
        excluding: excludeSemantics,
        child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox.expand(child: child),
    );
  }
}
