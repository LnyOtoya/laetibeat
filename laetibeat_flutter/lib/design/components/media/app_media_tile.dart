import 'package:material_ui/material_ui.dart';

import '../../tokens/app_color_tokens.dart';
import '../../tokens/app_shape_tokens.dart';
import '../../tokens/app_spacing_tokens.dart';
import '../text/app_text.dart';
import '../text/app_text_role.dart';

/// Artwork-first media tile for carousels and grids.
class AppMediaTile extends StatelessWidget {
  const AppMediaTile({
    super.key,
    required this.artwork,
    required this.title,
    this.subtitle,
    this.onTap,
    this.width = 160,
  });

  final Widget artwork;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.mdAll,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                artwork,
                const SizedBox(height: AppSpacing.sm),
                AppText(
                  title,
                  role: AppTextRole.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  AppText(
                    subtitle!,
                    role: AppTextRole.bodySmall,
                    colorRole: AppColorRole.onSurfaceVariant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
