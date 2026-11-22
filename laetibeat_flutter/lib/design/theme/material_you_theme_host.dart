// `CorePalette` is the type returned by the dynamic_color plugin. See
// material_you_color.dart for why the deprecation is intentionally suppressed.
// ignore_for_file: deprecated_member_use

import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_color_utilities/material_color_utilities.dart' as mcu;
import 'package:material_ui/material_ui.dart';

import '../tokens/app_color_tokens.dart';
import 'app_theme.dart';
import 'material_you_color.dart';

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

    final colorScheme = _corePalette != null
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

    return M3ETheme(data: data, child: widget.child);
  }
}
