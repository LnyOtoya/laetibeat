import 'package:material_ui/material_ui.dart';

import '../../tokens/app_layout_tokens.dart';

/// Applies the one and only horizontal page gutter.
///
/// Place this around a page body, list or scroll view. Sections, media rows,
/// cards and artwork inside must not add another horizontal page padding.
class AppPageBody extends StatelessWidget {
  const AppPageBody({
    super.key,
    required this.child,
    this.applyHorizontalGutter = true,
    this.maxContentWidth = AppLayout.maxContentWidth,
    this.padding,
  });

  final Widget child;

  /// Set to false for full-bleed content that manages its own gutter
  /// (for example a horizontal carousel).
  final bool applyHorizontalGutter;

  /// Maximum content width. Use `double.infinity` for a full-width layout.
  final double maxContentWidth;

  /// Optional override. When null, a symmetric horizontal gutter is used.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = AppLayout.gutterFor(width);
    final resolvedPadding =
        padding ??
        (applyHorizontalGutter
            ? EdgeInsets.symmetric(horizontal: gutter)
            : EdgeInsets.zero);

    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final horizontal = resolvedPadding.resolve(direction).horizontal;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth + horizontal),
        child: Padding(padding: resolvedPadding, child: child),
      ),
    );
  }
}
