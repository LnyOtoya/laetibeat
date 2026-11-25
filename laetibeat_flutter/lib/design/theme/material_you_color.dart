// `CorePalette` is still the type returned by the dynamic_color plugin even
// though material_color_utilities marks it as deprecated in favour of
// DynamicScheme. The conversion below immediately projects it into a
// DynamicScheme so the rest of the pipeline uses the current API.
// ignore_for_file: deprecated_member_use

import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_color_utilities/material_color_utilities.dart' as mcu;
import 'package:material_ui/material_ui.dart';

/// Material You scheme variants exposed by the official Google color
/// utilities. `tonalSpot` is the Android 12/13 default.
enum AppColorVariant {
  tonalSpot,
  fidelity,
  content,
  vibrant,
  expressive,
  neutral,
  monochrome,
  rainbow,
  fruitSalad,
}

/// Builds a complete [M3EColorScheme] from the official Material Color
/// Utilities (MCU) dynamic schemes.
///
/// This intentionally bypasses Flutter's `ColorScheme.fromSeed`-only path for
/// palette generation: every role, including the `surfaceContainer*` family,
/// is resolved from a single [mcu.DynamicScheme].
abstract final class MaterialYouColorScheme {
  static M3EColorScheme fromSeed(
    Color seed, {
    Brightness brightness = Brightness.light,
    AppColorVariant variant = AppColorVariant.tonalSpot,
    double contrastLevel = 0.0,
  }) {
    final scheme = _schemeFromSeed(
      seed: seed,
      brightness: brightness,
      variant: variant,
      contrastLevel: contrastLevel,
    );
    return _toExpressive(scheme);
  }

  /// Builds a scheme from the OS-provided core palette without re-seeding.
  ///
  /// This preserves the wallpaper's actual tonal palettes instead of
  /// discarding everything except `primary` and generating a new seed scheme.
  static M3EColorScheme fromCorePalette(
    mcu.CorePalette palette, {
    Brightness brightness = Brightness.light,
    AppColorVariant variant = AppColorVariant.tonalSpot,
    double contrastLevel = 0.0,
  }) {
    final scheme = mcu.DynamicScheme(
      sourceColorHct: palette.primary.keyColor,
      variant: _variantOf(variant),
      isDark: brightness == Brightness.dark,
      contrastLevel: contrastLevel.clamp(-1.0, 1.0),
      primaryPalette: palette.primary,
      secondaryPalette: palette.secondary,
      tertiaryPalette: palette.tertiary,
      neutralPalette: palette.neutral,
      neutralVariantPalette: palette.neutralVariant,
    );
    return _toExpressive(scheme);
  }

  /// Builds the expressive scheme from final Android system roles.
  ///
  /// Android/Compose reads finalized resource values such as
  /// `system_primary_light`; they are more accurate than re-deriving every
  /// accent from the CorePalette. Missing roles fall back to a seed scheme.
  static M3EColorScheme fromSystemRoles(
    Map<String, Color> roles, {
    required Brightness brightness,
  }) {
    final primary = roles['primary'] ?? const Color(0xFF6750A4);
    final base = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    );

    final resolved = base.copyWith(
      primary: roles['primary'],
      onPrimary: roles['onPrimary'],
      primaryContainer: roles['primaryContainer'],
      onPrimaryContainer: roles['onPrimaryContainer'],
      secondary: roles['secondary'],
      onSecondary: roles['onSecondary'],
      secondaryContainer: roles['secondaryContainer'],
      onSecondaryContainer: roles['onSecondaryContainer'],
      tertiary: roles['tertiary'],
      onTertiary: roles['onTertiary'],
      tertiaryContainer: roles['tertiaryContainer'],
      onTertiaryContainer: roles['onTertiaryContainer'],
      error: roles['error'],
      onError: roles['onError'],
      errorContainer: roles['errorContainer'],
      onErrorContainer: roles['onErrorContainer'],
      surface: roles['surface'],
      onSurface: roles['onSurface'],
      onSurfaceVariant: roles['onSurfaceVariant'],
      surfaceContainerLowest: roles['surfaceContainerLowest'],
      surfaceContainerLow: roles['surfaceContainerLow'],
      surfaceContainer: roles['surfaceContainer'],
      surfaceContainerHigh: roles['surfaceContainerHigh'],
      surfaceContainerHighest: roles['surfaceContainerHighest'],
      surfaceDim: roles['surfaceDim'],
      surfaceBright: roles['surfaceBright'],
      outline: roles['outline'],
      outlineVariant: roles['outlineVariant'],
      inverseSurface: roles['inverseSurface'],
      onInverseSurface: roles['onInverseSurface'],
      inversePrimary: roles['inversePrimary'],
      shadow: roles['shadow'],
      scrim: roles['scrim'],
      surfaceTint: roles['surfaceTint'],
    );

    return M3EColorScheme.fromColorScheme(resolved).harmonized();
  }

  static mcu.DynamicScheme _schemeFromSeed({
    required Color seed,
    required Brightness brightness,
    required AppColorVariant variant,
    required double contrastLevel,
  }) {
    final source = mcu.Hct.fromInt(seed.toARGB32());
    final isDark = brightness == Brightness.dark;
    final level = contrastLevel.clamp(-1.0, 1.0);

    return switch (variant) {
      AppColorVariant.tonalSpot => mcu.SchemeTonalSpot(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: level,
      ),
      AppColorVariant.fidelity => mcu.SchemeFidelity(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: level,
      ),
      AppColorVariant.content => mcu.SchemeContent(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: level,
      ),
      AppColorVariant.vibrant => mcu.SchemeVibrant(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: level,
      ),
      AppColorVariant.expressive => mcu.SchemeExpressive(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: level,
      ),
      AppColorVariant.neutral => mcu.SchemeNeutral(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: level,
      ),
      AppColorVariant.monochrome => mcu.SchemeMonochrome(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: level,
      ),
      AppColorVariant.rainbow => mcu.SchemeRainbow(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: level,
      ),
      AppColorVariant.fruitSalad => mcu.SchemeFruitSalad(
        sourceColorHct: source,
        isDark: isDark,
        contrastLevel: level,
      ),
    };
  }

  /// Resolves every Material role from [scheme] into a Material [ColorScheme],
  /// then adapts it to the expressive role set.
  static M3EColorScheme _toExpressive(mcu.DynamicScheme scheme) {
    final brightness = scheme.isDark ? Brightness.dark : Brightness.light;

    // The seed call only provides a fully populated base object; every role
    // below is immediately replaced by the official DynamicScheme value.
    final base = ColorScheme.fromSeed(
      seedColor: Color(scheme.primary),
      brightness: brightness,
      contrastLevel: scheme.contrastLevel,
    );

    final resolved = base.copyWith(
      primary: Color(scheme.primary),
      onPrimary: Color(scheme.onPrimary),
      primaryContainer: Color(scheme.primaryContainer),
      onPrimaryContainer: Color(scheme.onPrimaryContainer),
      secondary: Color(scheme.secondary),
      onSecondary: Color(scheme.onSecondary),
      secondaryContainer: Color(scheme.secondaryContainer),
      onSecondaryContainer: Color(scheme.onSecondaryContainer),
      tertiary: Color(scheme.tertiary),
      onTertiary: Color(scheme.onTertiary),
      tertiaryContainer: Color(scheme.tertiaryContainer),
      onTertiaryContainer: Color(scheme.onTertiaryContainer),
      error: Color(scheme.error),
      onError: Color(scheme.onError),
      errorContainer: Color(scheme.errorContainer),
      onErrorContainer: Color(scheme.onErrorContainer),
      surface: Color(scheme.surface),
      onSurface: Color(scheme.onSurface),
      surfaceDim: Color(scheme.surfaceDim),
      surfaceBright: Color(scheme.surfaceBright),
      surfaceContainerLowest: Color(scheme.surfaceContainerLowest),
      surfaceContainerLow: Color(scheme.surfaceContainerLow),
      surfaceContainer: Color(scheme.surfaceContainer),
      surfaceContainerHigh: Color(scheme.surfaceContainerHigh),
      surfaceContainerHighest: Color(scheme.surfaceContainerHighest),
      onSurfaceVariant: Color(scheme.onSurfaceVariant),
      outline: Color(scheme.outline),
      outlineVariant: Color(scheme.outlineVariant),
      inverseSurface: Color(scheme.inverseSurface),
      onInverseSurface: Color(scheme.inverseOnSurface),
      inversePrimary: Color(scheme.inversePrimary),
      shadow: Color(scheme.shadow),
      scrim: Color(scheme.scrim),
      surfaceTint: Color(scheme.surfaceTint),
    );

    return M3EColorScheme.fromColorScheme(resolved).harmonized();
  }

  static mcu.Variant _variantOf(AppColorVariant variant) {
    return switch (variant) {
      AppColorVariant.tonalSpot => mcu.Variant.tonalSpot,
      AppColorVariant.fidelity => mcu.Variant.fidelity,
      AppColorVariant.content => mcu.Variant.content,
      AppColorVariant.vibrant => mcu.Variant.vibrant,
      AppColorVariant.expressive => mcu.Variant.expressive,
      AppColorVariant.neutral => mcu.Variant.neutral,
      AppColorVariant.monochrome => mcu.Variant.monochrome,
      AppColorVariant.rainbow => mcu.Variant.rainbow,
      AppColorVariant.fruitSalad => mcu.Variant.fruitSalad,
    };
  }
}

/// 详情页内容底色。
///
/// 以封面派生的 `secondaryContainer` 为基准，保留色相与彩度、把 tone 压低，
/// 保证比 tonal 按钮和列表卡片更深，同时仍然带封面颜色。
Color detailContentColor(M3EColorScheme scheme, {double toneDelta = 14}) {
  final Color base = scheme.secondaryContainer;
  final mcu.Hct hct = mcu.Hct.fromInt(base.toARGB32());
  final double target = (hct.tone - toneDelta).clamp(0.0, 100.0).toDouble();
  if (target >= hct.tone) return base;
  hct.tone = target;
  return Color(hct.toInt());
}
