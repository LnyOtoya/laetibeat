// `CorePalette` is the type returned by the dynamic_color plugin. See
// material_you_color.dart for why the deprecation is intentionally suppressed.
// ignore_for_file: deprecated_member_use

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_color_utilities/material_color_utilities.dart' as mcu;
import 'package:material_ui/material_ui.dart';

import '../tokens/app_color_tokens.dart';
import 'app_theme.dart';
import 'material_you_color.dart';
import 'system_color_source.dart';

/// Provides the app's [M3ETheme] from the OS Material You palette.
///
/// Unlike the built-in dynamic-color host, this keeps the full wallpaper
/// palette (all five tonal palettes) and resolves every M3 color role through
/// the official `material_color_utilities` dynamic scheme. The seed is only a
/// fallback for platforms without a dynamic palette.
class MaterialYouThemeHost extends StatefulWidget {
  const MaterialYouThemeHost({
    super.key,
    required this.child,
    this.density = AppThemeDensity.compact,
    this.variant = AppColorVariant.tonalSpot,
    this.contrastLevel = 0.0,
    this.fallbackSeed = AppColorTokens.brandSeed,
  });

  final Widget child;
  final AppThemeDensity density;
  final AppColorVariant variant;
  final double contrastLevel;
  final Color fallbackSeed;

  @override
  State<MaterialYouThemeHost> createState() => _MaterialYouThemeHostState();
}

class _MaterialYouThemeHostState extends State<MaterialYouThemeHost>
    with WidgetsBindingObserver {
  mcu.CorePalette? _corePalette;
  Color? _accentColor;
  SystemColorRoles? _systemRoles;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDynamicColors();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDynamicColors();
    }
  }

  Future<void> _loadDynamicColors() async {
    // Prefer the finalized Android role resources used by Compose. They avoid
    // re-deriving accent tones from the five CorePalette palettes.
    final systemRoles = await SystemColorSource.load();
    if (!mounted) return;
    if (systemRoles != null) {
      setState(() => _systemRoles = systemRoles);
      return;
    }

    try {
      final palette = await DynamicColorPlugin.getCorePalette();
      if (!mounted) return;
      if (palette != null) {
        setState(() => _corePalette = palette);
        return;
      }
    } catch (_) {
      // Platform without a core palette (e.g. desktop) falls through.
    }

    try {
      final accent = await DynamicColorPlugin.getAccentColor();
      if (!mounted) return;
      if (accent != null) {
        setState(() => _accentColor = accent);
      }
    } catch (_) {
      // No system accent either: keep the brand seed fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final systemRoles = _systemRoles?.forBrightness(brightness);
    if (kDebugMode) {
      final source = systemRoles != null && systemRoles.isNotEmpty
          ? 'system'
          : _corePalette != null
          ? 'corePalette'
          : 'seed';
      debugPrint(
        '[theme] dynamic source=$source brightness=${brightness.name}',
      );
    }
    final colorScheme = systemRoles != null && systemRoles.isNotEmpty
        ? MaterialYouColorScheme.fromSystemRoles(
            systemRoles,
            brightness: brightness,
          )
        : _corePalette != null
        ? MaterialYouColorScheme.fromCorePalette(
            _corePalette!,
            brightness: brightness,
            variant: widget.variant,
            contrastLevel: widget.contrastLevel,
          )
        : MaterialYouColorScheme.fromSeed(
            _accentColor ?? widget.fallbackSeed,
            brightness: brightness,
            variant: widget.variant,
            contrastLevel: widget.contrastLevel,
          );

    final data = AppTheme.build(
      brightness: brightness,
      colorScheme: colorScheme,
      density: widget.density,
    );

    // `m3e_core` widgets (FAB / floating toolbar / icon buttons) read
    // `Theme.of(context)`, while `material_3_expressive` widgets read
    // `M3ETheme.of(context)`. Project the same dynamic scheme onto both so the
    // shell and the page components do not fall back to the brand seed.
    final baseMaterialTheme = Theme.of(context);
    final materialTheme = baseMaterialTheme.copyWith(
      colorScheme: data.colorScheme.toColorScheme(),
      textTheme: AppTheme.applyMaterialTextTypography(
        baseMaterialTheme.textTheme,
      ),
      primaryTextTheme: AppTheme.applyMaterialTextTypography(
        baseMaterialTheme.primaryTextTheme,
      ),
      scaffoldBackgroundColor: data.colorScheme.surface,
      canvasColor: data.colorScheme.surface,
    );

    return Theme(
      data: materialTheme,
      child: M3ETheme(data: data, child: widget.child),
    );
  }
}
