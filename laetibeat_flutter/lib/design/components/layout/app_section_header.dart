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
    this.leading,
    this.trailing,
    this.titleRole = AppTextRole.titleLarge,
    this.titleColorRole = AppColorRole.onSurface,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.sm),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// 标题字号；默认 `titleLarge`，紧凑页面可传 `titleMedium`。
  final AppTextRole titleRole;
  final AppColorRole titleColorRole;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppText(
          title,
          role: titleRole,
          colorRole: titleColorRole,
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
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: AppSpacing.sm),
            ],
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
