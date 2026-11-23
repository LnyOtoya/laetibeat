import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// 移动端页面统一的顶部 AppBar。
M3EAppBar mobileTopAppBar(
  BuildContext context, {
  Widget? title,
  List<Widget> actions = const <Widget>[],
}) {
  final theme = M3ETheme.of(context);

  return M3EAppBar.top(
    backgroundColor: theme.colorScheme.surfaceContainer,
    variant: M3EAppBarVariant.small,
    hideMode: M3EAppBarHideMode.entire,
    density: M3EAppBarDensity.compact,
    shapeFamily: M3EAppBarShapeFamily.square,
    safeArea: true,
    title: title,
    actions: actions,
  );
}

/// 移动端顶部 AppBar 的左侧标题。
Widget mobileTopAppBarTitle(BuildContext context, String text) {
  final theme = M3ETheme.of(context);
  return Padding(
    padding: const EdgeInsetsDirectional.only(start: 8),
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.typeScale.titleLarge.copyWith(
        color: theme.colorScheme.onSurface,
      ),
    ),
  );
}
