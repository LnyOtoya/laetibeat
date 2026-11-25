import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../tokens/app_color_tokens.dart';
import '../../tokens/app_spacing_tokens.dart';
import '../text/app_text.dart';
import '../text/app_text_role.dart';

/// 移动端唯一的顶部栏入口。
///
/// 只提供三种语义变体：
/// - [tab]：一级 tab 页。与首页一致的大标题，可随滚动折叠，无返回键。
/// - [subpage]：二级列表页。返回键 + 页面名 + 排序/搜索/布局三个动作。
/// - [detail]：详情页。返回键 + 页面名 + 三点菜单，两个按钮都用 tonal 圆形背景。
///
/// 页面不再直接构造 `M3EAppBar`，避免返回键尺寸、标题位置、动作间距各写一套。
abstract final class AppPageBar {
  /// 一级 tab 页顶部栏。
  ///
  /// [title] 是折叠后的页面名；[expandedTitle] 是展开态的大标题，缺省等于
  /// [title]；[subtitle] 只在折叠态显示。首页用 `expandedTitle` 保留内容
  /// 区块名，其余 tab 页直接使用页面名。
  static PreferredSizeWidget tab({
    required String title,
    String? expandedTitle,
    String? subtitle,
    List<Widget> Function(bool collapsed)? actionsBuilder,
    Color? backgroundColor,
  }) {
    return _AppTabPageBar(
      title: title,
      expandedTitle: expandedTitle,
      subtitle: subtitle,
      actionsBuilder: actionsBuilder,
      backgroundColor: backgroundColor,
    );
  }

  /// 二级页顶部栏。
  ///
  /// [onSort] 为 null 时排序按钮显示但禁用；[showLayout] 控制是否显示布局
  /// 切换按钮，[onToggleLayout] 为 null 时该按钮显示但禁用。
  static PreferredSizeWidget subpage({
    required String title,
    required VoidCallback onSearch,
    VoidCallback? onSort,
    bool showLayout = true,
    bool isGrid = true,
    VoidCallback? onToggleLayout,
    Color? backgroundColor,
  }) {
    return _AppSubpageBar(
      title: title,
      onSearch: onSearch,
      onSort: onSort,
      showLayout: showLayout,
      isGrid: isGrid,
      onToggleLayout: onToggleLayout,
      backgroundColor: backgroundColor,
    );
  }

  /// 详情页顶部栏。
  ///
  /// 只有返回键和三点菜单，不显示标题。两个按钮都是 40dp 圆形 tonal 背景、
  /// 48dp 点击目标；[onMenu] 为空时菜单按钮仍保持 tonal 外观但暂时没有动作。
  static PreferredSizeWidget detail({
    VoidCallback? onMenu,
    Color? backgroundColor,
  }) {
    return _AppDetailBar(onMenu: onMenu, backgroundColor: backgroundColor);
  }
}

class _AppTabPageBar extends StatefulWidget implements PreferredSizeWidget {
  const _AppTabPageBar({
    required this.title,
    this.expandedTitle,
    this.subtitle,
    this.actionsBuilder,
    this.backgroundColor,
  });

  final String title;
  final String? expandedTitle;
  final String? subtitle;
  final List<Widget> Function(bool collapsed)? actionsBuilder;
  final Color? backgroundColor;

  // 尺寸只取决于 variant / density，与文案和动作无关，测量一次即可。
  static final Size _preferredSize = M3EAppBar.top(
    variant: M3EAppBarVariant.largeFlexible,
    density: M3EAppBarDensity.regular,
    shapeFamily: M3EAppBarShapeFamily.square,
    safeArea: true,
    titleText: '',
  ).preferredSize;

  @override
  Size get preferredSize => _preferredSize;

  @override
  State<_AppTabPageBar> createState() => _AppTabPageBarState();
}

class _AppTabPageBarState extends State<_AppTabPageBar> {
  final M3EAppBarController _controller = M3EAppBarController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final bool collapsed = _controller.isCollapsed;

        return M3EAppBar.top(
          backgroundColor: widget.backgroundColor ?? scheme.surface,
          controller: _controller,
          variant: M3EAppBarVariant.largeFlexible,
          density: M3EAppBarDensity.regular,
          shapeFamily: M3EAppBarShapeFamily.square,
          safeArea: true,
          hideOnScroll: false,
          hideMode: M3EAppBarHideMode.none,
          actions: widget.actionsBuilder?.call(collapsed) ?? const <Widget>[],
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder:
                (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: <Widget>[...previousChildren, ?currentChild],
                  );
                },
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _buildTitle(context, collapsed),
          ),
        );
      },
    );
  }

  Widget _buildTitle(BuildContext context, bool collapsed) {
    if (!collapsed) {
      return Text(
        widget.expandedTitle ?? widget.title,
        key: const ValueKey<String>('expanded'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      key: const ValueKey<String>('collapsed'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: M3ETheme.of(context).typeScale.titleLarge.copyWith(
            color: DefaultTextStyle.of(context).style.color,
          ),
        ),
        if (widget.subtitle != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          AppText(
            widget.subtitle!,
            role: AppTextRole.bodySmall,
            colorRole: AppColorRole.onSurfaceVariant,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _AppSubpageBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppSubpageBar({
    required this.title,
    required this.onSearch,
    this.onSort,
    this.showLayout = true,
    this.isGrid = true,
    this.onToggleLayout,
    this.backgroundColor,
  });

  final String title;
  final VoidCallback onSearch;
  final VoidCallback? onSort;
  final bool showLayout;
  final bool isGrid;
  final VoidCallback? onToggleLayout;
  final Color? backgroundColor;

  static final Size _preferredSize = M3EAppBar.top(
    variant: M3EAppBarVariant.small,
    density: M3EAppBarDensity.compact,
    shapeFamily: M3EAppBarShapeFamily.square,
    safeArea: true,
    titleText: '',
  ).preferredSize;

  @override
  Size get preferredSize => _preferredSize;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return M3EAppBar.top(
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      variant: M3EAppBarVariant.small,
      density: M3EAppBarDensity.compact,
      shapeFamily: M3EAppBarShapeFamily.square,
      safeArea: true,
      hideMode: M3EAppBarHideMode.none,
      leading: M3EIconButton(
        variant: M3EIconButtonVariant.standard,
        size: M3EIconButtonSize.sm,
        icon: const Icon(M3EIcons.arrow_back),
        tooltip: l10n.commonBack,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: <Widget>[
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          size: M3EIconButtonSize.sm,
          icon: const Icon(M3EIcons.sort),
          tooltip: l10n.sortLabel,
          onPressed: onSort,
        ),
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          size: M3EIconButtonSize.sm,
          icon: const Icon(M3EIcons.search),
          tooltip: l10n.searchHint,
          onPressed: onSearch,
        ),
        if (showLayout)
          M3EIconButton(
            variant: M3EIconButtonVariant.tonal,
            size: M3EIconButtonSize.sm,
            // 图标表示“切换后的目标布局”，与原来的控制条保持一致。
            icon: Icon(isGrid ? M3EIcons.view_list : M3EIcons.grid_view),
            tooltip: isGrid ? l10n.switchToList : l10n.switchToGrid,
            onPressed: onToggleLayout,
          ),
      ],
    );
  }
}

class _AppDetailBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppDetailBar({this.onMenu, this.backgroundColor});

  final VoidCallback? onMenu;
  final Color? backgroundColor;

  static final Size _preferredSize = M3EAppBar.top(
    variant: M3EAppBarVariant.small,
    density: M3EAppBarDensity.compact,
    shapeFamily: M3EAppBarShapeFamily.square,
    safeArea: true,
    titleText: '',
  ).preferredSize;

  @override
  Size get preferredSize => _preferredSize;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return M3EAppBar.top(
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      variant: M3EAppBarVariant.small,
      density: M3EAppBarDensity.compact,
      shapeFamily: M3EAppBarShapeFamily.square,
      safeArea: true,
      hideMode: M3EAppBarHideMode.none,
      leading: M3EIconButton(
        variant: M3EIconButtonVariant.tonal,
        size: M3EIconButtonSize.sm,
        icon: const Icon(M3EIcons.arrow_back),
        tooltip: l10n.commonBack,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: <Widget>[
        m3e_core.M3EButton(
          style: m3e_core.M3EButtonStyle.tonal,
          shape: m3e_core.M3EButtonShape.round,
          // 菜单内容后续接入；这里先保留可点击的 tonal 外观。
          onPressed: onMenu ?? () {},
          tooltip: l10n.more,
          semanticLabel: l10n.more,
          decoration: const m3e_core.M3EButtonDecoration(
            minimumSize: Size(40, 40),
            fixedSize: Size(40, 40),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          child: const Icon(M3EIcons.more_vert, size: 20),
        ),
      ],
    );
  }
}
