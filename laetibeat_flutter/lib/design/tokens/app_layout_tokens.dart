import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';
import 'app_spacing_tokens.dart';

/// Layout tokens for page-level alignment.
///
/// There is exactly one horizontal page gutter. Pages apply it once through
/// `AppPageBody`; sections, rows, cards and artwork must not add their own
/// horizontal page padding.
abstract final class AppLayout {
  /// Base page gutter for compact windows.
  static const double pageGutter = AppSpacing.lg;

  /// Standard page padding: horizontal gutter only.
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: pageGutter);

  /// Vertical page padding without touching the horizontal gutter.
  static const EdgeInsets pageVertical = EdgeInsets.symmetric(
    vertical: AppSpacing.md,
  );

  /// Maximum readable content width on wider windows.
  ///
  /// The gutter is added outside this width, so content is centred instead of
  /// stretched edge-to-edge on desktop.
  static const double maxContentWidth = 720;

  /// Responsive gutter. All components in the same window use the same value.
  static double gutterFor(double width) {
    if (width < AppBreakpoints.compactMax) return pageGutter;
    if (width < AppBreakpoints.expandedMax) return AppSpacing.xl;
    return AppSpacing.xxl;
  }
}
