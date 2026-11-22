import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// Tonal placeholder shown while artwork is missing or loading.
class AppArtworkPlaceholder extends StatelessWidget {
  const AppArtworkPlaceholder({
    super.key,
    required this.size,
    this.icon = M3EIcons.music_note,
    this.backgroundColor,
    this.iconColor,
  });

  final double size;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    return ColoredBox(
      color: backgroundColor ?? scheme.secondaryContainer,
      child: Center(
        child: Icon(
          icon,
          size: size * 0.4,
          color: iconColor ?? scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
