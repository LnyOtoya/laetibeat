import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../tokens/app_color_tokens.dart';
import '../tokens/app_size_tokens.dart';
import '../tokens/app_spacing_tokens.dart';
import '../tokens/app_typography_tokens.dart';
import 'material_you_color.dart';

/// App density. Mobile uses compact spacing; desktop can use the regular
/// Material density with a slightly tighter visual density.
enum AppThemeDensity { compact, regular }

/// Single source of truth for the app's [M3EThemeData].
///
/// Pages should read semantic roles from `M3ETheme.of(context)`; they should
/// not build their own color schemes or typography.
abstract final class AppTheme {
  static M3EThemeData light({
    M3EColorScheme? colorScheme,
    AppThemeDensity density = AppThemeDensity.compact,
  }) {
    return build(
      brightness: Brightness.light,
      colorScheme:
          colorScheme ??
          MaterialYouColorScheme.fromSeed(
            AppColorTokens.brandSeed,
            brightness: Brightness.light,
          ),
      density: density,
    );
  }

  static M3EThemeData dark({
    M3EColorScheme? colorScheme,
    AppThemeDensity density = AppThemeDensity.compact,
  }) {
    return build(
      brightness: Brightness.dark,
      colorScheme:
          colorScheme ??
          MaterialYouColorScheme.fromSeed(
            AppColorTokens.brandSeed,
            brightness: Brightness.dark,
          ),
      density: density,
    );
  }

  static M3EThemeData build({
    required Brightness brightness,
    required M3EColorScheme colorScheme,
    AppThemeDensity density = AppThemeDensity.compact,
  }) {
    assert(
      colorScheme.brightness == brightness,
      'colorScheme.brightness must match the requested brightness',
    );
    return M3EThemeData(
      colorScheme: colorScheme,
      typography: _typography(),
      spacing: const M3ESpacing(
        xs: AppSpacing.xs,
        sm: AppSpacing.sm,
        md: AppSpacing.md,
        lg: AppSpacing.lg,
        xl: AppSpacing.xl,
        xxl: AppSpacing.xxl,
      ),
      iconTheme: const IconThemeData(size: AppIconSize.md),
      visualDensity: density == AppThemeDensity.compact ? 0 : -1,
    );
  }

  static M3ETypography _typography() {
    return M3ETypography.material3(mode: M3ETypeScaleMode.variable).apply(
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
    );
  }
}
