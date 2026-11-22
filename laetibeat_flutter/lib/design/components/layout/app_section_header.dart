import 'package:material_ui/material_ui.dart';

import '../../tokens/app_color_tokens.dart';
import '../../tokens/app_spacing_tokens.dart';
import '../text/app_text.dart';
import '../text/app_text_role.dart';

/// Section heading used by Home, Library and detail pages.
///
/// The header owns typography and spacing; the page only supplies content.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.sm),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppText(
          title,
          role: AppTextRole.titleLarge,
          colorRole: AppColorRole.onSurface,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          AppText(
            subtitle!,
            role: AppTextRole.bodySmall,
            colorRole: AppColorRole.onSurfaceVariant,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    return Semantics(
      header: true,
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: titleColumn),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
