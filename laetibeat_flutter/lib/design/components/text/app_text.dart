import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../tokens/app_color_tokens.dart';
import 'app_text_role.dart';

/// Tokenized text primitive.
///
/// Screens pick a semantic [AppTextRole] and [AppColorRole]; they should not
/// hard-code font sizes or color literals.
class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    super.key,
    this.role = AppTextRole.bodyMedium,
    this.colorRole = AppColorRole.onSurface,
    this.emphasized = false,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  final String text;
  final AppTextRole role;
  final AppColorRole colorRole;

  /// Uses the emphasized type scale instead of the baseline scale.
  final bool emphasized;

  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scale = emphasized ? theme.typography.emphasized : theme.typeScale;
    final base = role.styleOf(scale);
    final resolved = base.copyWith(color: colorRole.resolve(theme.colorScheme));

    return Text(
      text,
      style: style == null ? resolved : resolved.merge(style),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}
