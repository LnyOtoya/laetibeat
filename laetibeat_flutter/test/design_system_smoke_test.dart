import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/design/design.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('Material You scheme resolves all surface roles', () {
    final scheme = MaterialYouColorScheme.fromSeed(
      const Color(0xFF4C5C78),
      brightness: Brightness.light,
    );

    expect(scheme.brightness, Brightness.light);
    expect(scheme.primary, isNot(scheme.surface));
    expect(scheme.surfaceContainerLow, isNot(scheme.surfaceContainerHigh));
    expect(scheme.onSurface, isNot(scheme.surface));

    final dark = MaterialYouColorScheme.fromSeed(
      const Color(0xFF4C5C78),
      brightness: Brightness.dark,
    );
    expect(dark.brightness, Brightness.dark);
    expect(dark.surface, isNot(scheme.surface));
  });

  test('detail list text uses emphasized theme roles', () {
    final theme = AppTheme.withDetailTextEmphasis(AppTheme.light());
    final scheme = theme.colorScheme;

    expect(theme.listTheme.item.labelColor, scheme.primary);
    expect(theme.listTheme.item.supportingColor, scheme.onSurface);
  });

  testWidgets('Material text themes use the app CJK font fallback', (
    WidgetTester tester,
  ) async {
    late ThemeData materialTheme;

    await tester.pumpWidget(
      M3EMaterialApp(
        data: AppTheme.light(),
        home: MaterialYouThemeHost(
          child: Builder(
            builder: (context) {
              materialTheme = Theme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final bodyStyle = materialTheme.textTheme.bodyMedium!;
    final primaryStyle = materialTheme.primaryTextTheme.titleLarge!;

    expect(bodyStyle.fontFamily, AppTypography.fontFamily);
    expect(bodyStyle.fontFamilyFallback, AppTypography.fontFamilyFallback);
    expect(primaryStyle.fontFamily, AppTypography.fontFamily);
    expect(primaryStyle.fontFamilyFallback, AppTypography.fontFamilyFallback);
  });

  testWidgets('section and media row share the page gutter', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      M3EMaterialApp(
        data: AppTheme.light(),
        home: MaterialYouThemeHost(
          child: AppScaffold(
            body: ListView(
              children: <Widget>[
                const AppSectionHeader(title: 'Section'),
                const AppMediaRow(
                  leading: AppArtwork(size: AppArtworkSize.md),
                  title: 'Track',
                  subtitle: 'Artist',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final sectionLeft = tester.getTopLeft(find.byType(AppSectionHeader)).dx;
    final rowLeft = tester.getTopLeft(find.byType(AppMediaRow)).dx;

    expect(sectionLeft, AppLayout.pageGutter);
    expect(rowLeft, AppLayout.pageGutter);
  });

  testWidgets('design system primitives render inside the theme host', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      M3EMaterialApp(
        data: AppTheme.light(),
        home: MaterialYouThemeHost(
          child: AppScaffold(
            body: ListView(
              children: <Widget>[
                const AppSectionHeader(title: 'Section'),
                const AppMediaRow(
                  leading: AppArtwork(size: AppArtworkSize.md),
                  title: 'Track',
                  subtitle: 'Artist',
                ),
                const AppSurface(
                  padding: EdgeInsets.all(16),
                  child: AppText('Surface'),
                ),
                const AppEmptyState(title: 'Nothing here'),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Section'), findsOneWidget);
    expect(find.text('Track'), findsOneWidget);
    expect(find.text('Surface'), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);
  });
}
