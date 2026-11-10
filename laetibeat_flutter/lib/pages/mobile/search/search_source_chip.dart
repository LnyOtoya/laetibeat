import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// Fixed brand colors for search-source chips.
///
/// The local source uses the current M3E primary color; music services use
/// their recognizable brand colors.
Color searchSourceColor(BuildContext context, String sourceKey) {
  final scheme = M3ETheme.of(context).colorScheme;
  return switch (sourceKey) {
    'local' => scheme.primary,
    'tx' => const Color(0xFF31C27C), // QQ Music
    'wy' => const Color(0xFFC20C0C), // NetEase Cloud Music
    'kg' => const Color(0xFF00A1FF), // Kugou Music
    'navidrome' => const Color(0xFF2563EB), // Navidrome blue
    'subsonic' => const Color(0xFF3B82F6), // Subsonic blue
    'kw' => const Color(0xFFFF6A00), // Kuwo Music
    'mg' => const Color(0xFFFF3C6E), // Migu Music
    _ => scheme.secondary,
  };
}

class SearchSourceChip extends StatelessWidget {
  const SearchSourceChip({
    super.key,
    required this.label,
    required this.sourceKey,
  });

  final String label;
  final String sourceKey;

  @override
  Widget build(BuildContext context) {
    final color = searchSourceColor(context, sourceKey);
    final theme = M3ETheme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.typeScale.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
