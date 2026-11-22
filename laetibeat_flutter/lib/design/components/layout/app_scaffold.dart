import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../tokens/app_color_tokens.dart';
import '../../tokens/app_layout_tokens.dart';
import 'app_page_body.dart';

/// Tokenized page scaffold.
///
/// This exists so pages can stop choosing `surfaceContainer` ad hoc. The
/// background defaults to the semantic base surface; content regions can use
/// [AppSurface] when grouping is meaningful.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.background = AppSurfaceLevel.base,
    this.safeArea = true,
    this.resizeToAvoidBottomInset,
    this.applyPageGutter = true,
    this.maxContentWidth = AppLayout.maxContentWidth,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final AppSurfaceLevel background;
  final bool safeArea;
  final bool? resizeToAvoidBottomInset;

  /// Applies [AppPageBody]'s horizontal gutter. Disable for full-bleed pages
  /// that manage their own inset.
  final bool applyPageGutter;

  /// Maximum content width on wide windows. Use `double.infinity` to opt out.
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    final content = applyPageGutter
        ? AppPageBody(maxContentWidth: maxContentWidth, child: body)
        : body;

    return Scaffold(
      backgroundColor: background.resolve(scheme),
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: safeArea
          ? SafeArea(left: true, right: true, child: content)
          : content,
    );
  }
}
