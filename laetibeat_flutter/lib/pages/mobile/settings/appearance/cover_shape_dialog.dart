import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../widgets/settings/cover_shape_settings.dart';

Future<M3EShapeKind?> showCoverShapeDialog(
  BuildContext context, {
  required M3EShapeKind initial,
}) {
  return M3EDialog.show<M3EShapeKind>(
    context,
    dialog: _CoverShapeDialog(initial: initial),
  );
}

class _CoverShapeDialog extends StatefulWidget {
  const _CoverShapeDialog({required this.initial});

  final M3EShapeKind initial;

  @override
  State<_CoverShapeDialog> createState() => _CoverShapeDialogState();
}

class _CoverShapeDialogState extends State<_CoverShapeDialog> {
  late M3EShapeKind _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;

    return M3EDialog(
      title: l10n.coverShapeDialogTitle,
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: ListView.separated(
                itemCount: M3EShapeKind.values.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final kind = M3EShapeKind.values[index];
                  final selected = kind == _selected;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selected = kind),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? scheme.secondaryContainer : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        coverShapeLabel(kind),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typeScale.bodyMedium.copyWith(
                          color: selected
                              ? scheme.onSecondaryContainer
                              : scheme.onSurface,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  M3EShapeContainer(
                    kind: _selected,
                    width: 140,
                    height: 140,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        scheme.primaryContainer,
                        scheme.tertiaryContainer,
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        M3EIcons.music_note,
                        size: 54,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    coverShapeLabel(_selected),
                    textAlign: TextAlign.center,
                    style: theme.typeScale.labelLarge.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        M3EButton(
          label: Text(l10n.lyricsSearchCancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        M3EButton(
          label: Text(l10n.lyricsSearchConfirm),
          onPressed: () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }
}
