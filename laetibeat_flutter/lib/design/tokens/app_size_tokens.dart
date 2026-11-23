/// Icon sizes in logical pixels.
abstract final class AppIconSize {
  static const double xs = 16;
  static const double sm = 20;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 40;
}

/// Minimum interaction sizes. M3 requires at least 48dp touch targets.
abstract final class AppTouchTarget {
  static const double min = 48;
}

/// Shared component dimensions.
abstract final class AppComponentSize {
  static const double appBar = 64;
  static const double listRowMin = 56;
  static const double miniPlayer = 64;
  static const double miniPlayerAccessory = 96;
  static const double navigationBar = 80;
  static const double sectionHeader = 44;
  static const double controlMaxWidth = 340;
  static const double morphingBar = 64;
  static const double morphingBarSmall = 52;
  static const double morphingPill = 64;
  static const double floatingNavTabCollapsed = 46;
  static const double floatingNavTabExpanded = 100;
  static const double floatingNavTabHeight = 48;
  static const double floatingNavFab = 56;
}

/// Content measures for readable layouts on wide windows.
abstract final class AppContentWidth {
  static const double compact = 600;
  static const double readable = 720;
  static const double wide = 1024;
}
