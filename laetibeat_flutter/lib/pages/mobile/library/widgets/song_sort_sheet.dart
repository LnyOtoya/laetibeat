import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../widgets/settings/song_sort_settings.dart';

/// 歌曲排序面板。
///
/// 顶部栏的排序动作与页面内入口共用同一套选项，避免两处各写一份。
Future<void> showSongSortSheet(BuildContext context, WidgetRef ref) async {
  final current = ref.read(defaultSongSortProvider);
  final picked = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      final theme = M3ETheme.of(sheetContext);
      final scheme = theme.colorScheme;
      return SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.spacing.lg),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              theme.spacing.lg,
              theme.spacing.md,
              theme.spacing.md,
              theme.spacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        AppLocalizations.of(sheetContext).sortBy,
                        style: theme.typeScale.titleLarge,
                      ),
                    ),
                    M3EIconButton(
                      size: M3EIconButtonSize.xs,
                      icon: const Icon(M3EIcons.close),
                      tooltip: AppLocalizations.of(sheetContext).closeSort,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                SizedBox(height: theme.spacing.sm),
                M3EList.scrollable(
                  shrinkWrap: true,
                  itemCount: SongSortModes.all.length,
                  onTap: (int index) =>
                      Navigator.of(sheetContext).pop(SongSortModes.all[index]),
                  itemBuilder: (BuildContext context, int index) {
                    final mode = SongSortModes.all[index];
                    final selected = mode == current;
                    return M3EListItem(
                      selected: selected,
                      headline: mode,
                      trailing: selected
                          ? Icon(M3EIcons.check, color: scheme.primary)
                          : null,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (picked == null) return;
  ref.read(defaultSongSortProvider.notifier).setMode(picked);
}
