import 'package:flutter/widgets.dart';

/// 由 Shell 提供：悬浮底部 chrome 的度量值。
///
/// 这是页面可选的 scroll/content padding 输入，Shell 不会用它包裹或压缩
/// 页面布局。页面只依赖这个抽象，不依赖“移动端”“mini player”等具体概念。
/// 桌面端没有该作用域时返回 0。
class AppBottomInsetScope extends InheritedWidget {
  const AppBottomInsetScope({
    super.key,
    required this.bottomInset,
    required super.child,
  });

  final double bottomInset;

  static double bottomInsetOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppBottomInsetScope>()
          ?.bottomInset ??
      0;

  @override
  bool updateShouldNotify(AppBottomInsetScope oldWidget) =>
      oldWidget.bottomInset != bottomInset;
}
