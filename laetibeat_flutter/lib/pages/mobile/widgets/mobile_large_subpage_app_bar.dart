import 'dart:async';

import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// 移动端二级页面共用的 large baseline AppBar。
///
/// M3EAppBar 默认会随滚动连续折叠。这里额外在滚动停止时做一次阈值吸附：
/// 下滑超过 16dp 直接折叠；在顶部 120dp 内上滑则直接展开，不需要用户精确
/// 拖到最顶部。大 AppBar 的标题间距仍由 [_AutoCollapseSubpageAppBar] 处理。
PreferredSizeWidget mobileLargeSubpageAppBar(
  BuildContext context, {
  String? title,
  bool centerTitle = false,
  Color? backgroundColor,
  List<Widget> actions = const <Widget>[],
  M3EAppBarVariant variant = M3EAppBarVariant.large,
}) {
  final theme = M3ETheme.of(context);
  final resolvedBackground =
      backgroundColor ?? theme.colorScheme.surfaceContainer;
  // Used only for Scaffold's preferred extent; the real bar is built by the
  // stateful wrapper so it can own an M3EAppBarController.
  final measure = M3EAppBar.top(
    backgroundColor: resolvedBackground,
    variant: variant,
    shapeFamily: M3EAppBarShapeFamily.square,
    safeArea: true,
    titleText: title,
  );

  return _AutoCollapseSubpageAppBar(
    preferredSize: measure.preferredSize,
    title: title,
    centerTitle: centerTitle,
    backgroundColor: resolvedBackground,
    actions: actions,
    variant: variant,
  );
}

class _AutoCollapseSubpageAppBar extends StatefulWidget
    implements PreferredSizeWidget {
  const _AutoCollapseSubpageAppBar({
    required this.preferredSize,
    required this.title,
    required this.centerTitle,
    required this.backgroundColor,
    required this.actions,
    required this.variant,
  });

  @override
  final Size preferredSize;
  final String? title;
  final bool centerTitle;
  final Color backgroundColor;
  final List<Widget> actions;
  final M3EAppBarVariant variant;

  @override
  State<_AutoCollapseSubpageAppBar> createState() =>
      _AutoCollapseSubpageAppBarState();
}

class _AutoCollapseSubpageAppBarState
    extends State<_AutoCollapseSubpageAppBar> {
  static const double _collapseThreshold = 16;
  static const double _expandThreshold = 120;

  final M3EAppBarController _controller = M3EAppBarController();
  ScrollNotificationObserverState? _observer;
  double _lastOffset = 0;
  bool _lastMovedUp = false;
  bool _snapping = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindObserver();
  }

  void _bindObserver() {
    final next = ScrollNotificationObserver.maybeOf(context);
    if (identical(next, _observer)) return;
    _observer?.removeListener(_onNotification);
    _observer = next;
    _observer?.addListener(_onNotification);
  }

  @override
  void dispose() {
    _observer?.removeListener(_onNotification);
    _controller.dispose();
    super.dispose();
  }

  void _onNotification(ScrollNotification notification) {
    if (!mounted || _snapping) return;
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return;
    }

    if (notification is ScrollUpdateNotification) {
      final offset = notification.metrics.extentBefore;
      if (offset < _lastOffset) {
        _lastMovedUp = true;
      } else if (offset > _lastOffset) {
        _lastMovedUp = false;
      }
      _lastOffset = offset;
      return;
    }
    if (notification is! ScrollEndNotification) return;

    final offset = notification.metrics.extentBefore;
    if (_lastMovedUp && offset > 0 && offset < _expandThreshold) {
      _snap(_controller.expand);
    } else if (!_lastMovedUp && offset > _collapseThreshold) {
      _snap(_controller.collapse);
    }
  }

  Future<void> _snap(Future<void> Function() action) async {
    if (_snapping) return;
    _snapping = true;
    try {
      await action();
    } finally {
      if (mounted) _snapping = false;
    }
  }

  Widget? _buildTitle(BuildContext context, M3EThemeData theme) {
    final title = widget.title;
    if (title == null) return null;

    // Keep the designed leading position (24dp inset + 40dp circle) and only
    // adjust the title inset. M3EAppBar wraps a custom title in a lerped
    // DefaultTextStyle, so the font still animates displaySmall -> titleLarge;
    // use that inherited font size to make the extra inset collapse too.
    return Builder(
      builder: (titleContext) {
        final inheritedFontSize =
            DefaultTextStyle.of(titleContext).style.fontSize;
        final collapsedFontSize = theme.typeScale.titleLarge.fontSize ?? 22;
        final expandedFontSize = theme.typeScale.displaySmall.fontSize ?? 36;
        var expand = 1.0;
        if (inheritedFontSize != null &&
            expandedFontSize > collapsedFontSize) {
          expand =
              ((inheritedFontSize - collapsedFontSize) /
                      (expandedFontSize - collapsedFontSize))
                  .clamp(0.0, 1.0);
        }
        // Collapsed: 28dp clears the 40dp circle and adds ~12dp gap.
        // Expanded: back to the normal 12dp content inset.
        final startPadding = widget.centerTitle
            ? 0.0
            : 28.0 + (12.0 - 28.0) * expand;
        return Padding(
          padding: EdgeInsetsDirectional.only(start: startPadding),
          child: Text(
            title,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.centerTitle
                ? TextAlign.center
                : TextAlign.start,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return M3EAppBar.top(
      controller: _controller,
      backgroundColor: widget.backgroundColor,
      variant: widget.variant,
      hideMode: M3EAppBarHideMode.none,
      shapeFamily: M3EAppBarShapeFamily.square,
      safeArea: true,
      centerTitle: widget.centerTitle,
      title: _buildTitle(context, theme),
      // Restore the original designed leading position.
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(start: 24),
        child: _SubpageBackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      actions: widget.actions.isEmpty
          ? const <Widget>[]
          : [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.actions,
                ),
              ),
            ],
    );
  }
}

class _SubpageBackButton extends StatelessWidget {
  const _SubpageBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Semantics(
      button: true,
      label: '返回',
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                M3EIcons.arrow_back,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
