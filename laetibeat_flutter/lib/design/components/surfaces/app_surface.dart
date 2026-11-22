import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../tokens/app_color_tokens.dart';
import '../../tokens/app_shape_tokens.dart';

/// A tokenized surface container.
///
/// Use this for meaningful grouping, not for every list row. Prefer spacing
/// and dividers when containment is not semantically required.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.level = AppSurfaceLevel.container,
    this.borderRadius = AppRadii.mdAll,
    this.padding,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final AppSurfaceLevel level;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: level.resolve(scheme),
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        clipBehavior: clipBehavior,
        child: content,
      ),
    );
  }
}
