import 'package:flutter/widgets.dart';

/// Canonical Material 3 window size classes.
enum AppWindowSize { compact, medium, expanded, large, extraLarge }

/// Width breakpoints from the Material 3 adaptive guidance.
abstract final class AppBreakpoints {
  static const double compactMax = 600;
  static const double mediumMax = 840;
  static const double expandedMax = 1200;
  static const double largeMax = 1600;

  static AppWindowSize fromWidth(double width) {
    if (width < compactMax) return AppWindowSize.compact;
    if (width < mediumMax) return AppWindowSize.medium;
    if (width < expandedMax) return AppWindowSize.expanded;
    if (width < largeMax) return AppWindowSize.large;
    return AppWindowSize.extraLarge;
  }

  static AppWindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);
}
