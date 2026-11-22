import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// Brand seed used when the OS does not provide a dynamic palette.
///
/// This is intentionally not the Material baseline purple. Change this one
/// token to re-brand the whole app; every other color comes from the official
/// Material You scheme.
abstract final class AppColorTokens {
  static const Color brandSeed = Color(0xFF4C5C78);
}

/// Semantic color roles available to screens and components.
enum AppColorRole {
  primary,
  onPrimary,
  primaryContainer,
  onPrimaryContainer,
  secondary,
  onSecondary,
  secondaryContainer,
  onSecondaryContainer,
  tertiary,
  onTertiary,
  tertiaryContainer,
  onTertiaryContainer,
  error,
  onError,
  errorContainer,
  onErrorContainer,
  surface,
  onSurface,
  onSurfaceVariant,
  outline,
  outlineVariant,
  inverseSurface,
  onInverseSurface,
  inversePrimary,
  emphasis,
  onEmphasis,
  success,
  warning,
  info,
  danger,
  surfaceStrong,
  onSurfaceStrong,
  outlineStrong,
}

/// Resolves an [AppColorRole] from the active expressive scheme.
extension AppColorRoleResolver on AppColorRole {
  Color resolve(M3EColorScheme scheme) {
    return switch (this) {
      AppColorRole.primary => scheme.primary,
      AppColorRole.onPrimary => scheme.onPrimary,
      AppColorRole.primaryContainer => scheme.primaryContainer,
      AppColorRole.onPrimaryContainer => scheme.onPrimaryContainer,
      AppColorRole.secondary => scheme.secondary,
      AppColorRole.onSecondary => scheme.onSecondary,
      AppColorRole.secondaryContainer => scheme.secondaryContainer,
      AppColorRole.onSecondaryContainer => scheme.onSecondaryContainer,
      AppColorRole.tertiary => scheme.tertiary,
      AppColorRole.onTertiary => scheme.onTertiary,
      AppColorRole.tertiaryContainer => scheme.tertiaryContainer,
      AppColorRole.onTertiaryContainer => scheme.onTertiaryContainer,
      AppColorRole.error => scheme.error,
      AppColorRole.onError => scheme.onError,
      AppColorRole.errorContainer => scheme.errorContainer,
      AppColorRole.onErrorContainer => scheme.onErrorContainer,
      AppColorRole.surface => scheme.surface,
      AppColorRole.onSurface => scheme.onSurface,
      AppColorRole.onSurfaceVariant => scheme.onSurfaceVariant,
      AppColorRole.outline => scheme.outline,
      AppColorRole.outlineVariant => scheme.outlineVariant,
      AppColorRole.inverseSurface => scheme.inverseSurface,
      AppColorRole.onInverseSurface => scheme.onInverseSurface,
      AppColorRole.inversePrimary => scheme.inversePrimary,
      AppColorRole.emphasis => scheme.emphasis,
      AppColorRole.onEmphasis => scheme.onEmphasis,
      AppColorRole.success => scheme.success,
      AppColorRole.warning => scheme.warning,
      AppColorRole.info => scheme.info,
      AppColorRole.danger => scheme.danger,
      AppColorRole.surfaceStrong => scheme.surfaceStrong,
      AppColorRole.onSurfaceStrong => scheme.onSurfaceStrong,
      AppColorRole.outlineStrong => scheme.outlineStrong,
    };
  }
}

/// Semantic surface levels. Prefer the lowest level that establishes the
/// required grouping; avoid stacking tonal layers without a reason.
enum AppSurfaceLevel {
  base,
  dim,
  bright,
  lowest,
  low,
  container,
  high,
  highest,
  strong,
}

extension AppSurfaceLevelResolver on AppSurfaceLevel {
  Color resolve(M3EColorScheme scheme) {
    return switch (this) {
      AppSurfaceLevel.base => scheme.surface,
      AppSurfaceLevel.dim => scheme.surfaceDim,
      AppSurfaceLevel.bright => scheme.surfaceBright,
      AppSurfaceLevel.lowest => scheme.surfaceContainerLowest,
      AppSurfaceLevel.low => scheme.surfaceContainerLow,
      AppSurfaceLevel.container => scheme.surfaceContainer,
      AppSurfaceLevel.high => scheme.surfaceContainerHigh,
      AppSurfaceLevel.highest => scheme.surfaceContainerHighest,
      AppSurfaceLevel.strong => scheme.surfaceStrong,
    };
  }
}
