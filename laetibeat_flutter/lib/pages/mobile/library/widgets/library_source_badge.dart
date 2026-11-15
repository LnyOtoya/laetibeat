import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// 媒体库条目来源标记。
class LibrarySourceBadge extends StatelessWidget {
  const LibrarySourceBadge({
    super.key,
    required this.label,
    required this.remote,
  });

  final String label;
  final bool remote;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final background = remote
        ? scheme.tertiaryContainer
        : scheme.secondaryContainer;
    final foreground = remote
        ? scheme.onTertiaryContainer
        : scheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.typeScale.labelSmall.copyWith(color: foreground),
      ),
    );
  }
}
