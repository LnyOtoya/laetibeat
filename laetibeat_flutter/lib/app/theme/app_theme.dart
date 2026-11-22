import 'package:material_3_expressive/material_3_expressive.dart';

import '../../design/design.dart';
import '../app_form_factor.dart';

/// App-wide theme factory.
///
/// The actual tokens, typography, Material You color scheme and component
/// primitives live under `lib/design/`. This class only maps the form factor
/// to a density and the desktop navigation rail geometry.
class AppThemeFactory {
  const AppThemeFactory._();

  static const double _desktopRailCollapsedWidth = 104;

  static M3EThemeData dataFor(AppFormFactor formFactor) {
    final base = AppTheme.light(
      density: formFactor == AppFormFactor.desktop
          ? AppThemeDensity.regular
          : AppThemeDensity.compact,
    );

    return switch (formFactor) {
      AppFormFactor.desktop => base.copyWith(
        navigationRailTheme: const M3ENavigationRailTheme(
          collapsedWidth: _desktopRailCollapsedWidth,
        ),
      ),
      AppFormFactor.mobile => base,
    };
  }

  static M3EThemeData darkFor(AppFormFactor formFactor) {
    final base = AppTheme.dark(
      density: formFactor == AppFormFactor.desktop
          ? AppThemeDensity.regular
          : AppThemeDensity.compact,
    );

    return switch (formFactor) {
      AppFormFactor.desktop => base.copyWith(
        navigationRailTheme: const M3ENavigationRailTheme(
          collapsedWidth: _desktopRailCollapsedWidth,
        ),
      ),
      AppFormFactor.mobile => base,
    };
  }
}
