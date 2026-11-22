import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../tokens/app_color_tokens.dart';
import '../../tokens/app_shape_tokens.dart';
import '../../tokens/app_size_tokens.dart';
import '../../tokens/app_spacing_tokens.dart';
import '../text/app_text.dart';
import '../text/app_text_role.dart';

/// Flat media row used by song/album/artist/playlist lists.
///
/// Prefer this over wrapping every list row in a card.
class AppMediaRow extends StatelessWidget {
  const AppMediaRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.padding = AppInsets.listRow,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    final background = selected
        ? scheme.secondaryContainer
        : Colors.transparent;

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: background,
        borderRadius: AppRadii.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.mdAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppComponentSize.listRowMin,
            ),
            child: Padding(
              padding: padding,
              child: Row(
                children: <Widget>[
                  leading,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        AppText(
                          title,
                          role: AppTextRole.titleMedium,
                          colorRole: selected
                              ? AppColorRole.onSecondaryContainer
                              : AppColorRole.onSurface,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.xxs),
                          AppText(
                            subtitle!,
                            role: AppTextRole.bodySmall,
                            colorRole: selected
                                ? AppColorRole.onSecondaryContainer
                                : AppColorRole.onSurfaceVariant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
