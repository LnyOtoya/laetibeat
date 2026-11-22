import 'package:flutter/widgets.dart';

/// Spacing tokens for the Laetibeat design system.
///
/// Values follow a 4dp rhythm. Screens and components should consume these
/// tokens instead of hard-coded numbers so density can change in one place.
abstract final class AppSpacing {
  static const double none = 0;
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;
}

/// Common internal padding compositions built from [AppSpacing].
///
/// Page-level horizontal padding lives in `AppLayout` / `AppPageBody`, not
/// here. These insets are for content that is already inside the page gutter
/// or for deliberately inset surfaces such as sheets and cards.
abstract final class AppInsets {
  /// Vertical padding for a page-level list row. Horizontal gutter is provided
  /// once by `AppPageBody`.
  static const EdgeInsets listRow = EdgeInsets.symmetric(
    vertical: AppSpacing.sm,
  );

  /// Row padding for surfaces that are not already inside `AppPageBody`.
  static const EdgeInsets listRowInset = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );
}
