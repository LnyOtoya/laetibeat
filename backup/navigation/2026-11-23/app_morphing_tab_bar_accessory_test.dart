import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/design/design.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('bottom accessory hides when search mode opens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      M3EMaterialApp(
        data: AppTheme.light(),
        home: MaterialYouThemeHost(
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: AppMorphingTabBar(
                tabs: const <AppMorphingTab>[
                  AppMorphingTab(icon: M3EIcons.home, label: 'Home'),
                  AppMorphingTab(icon: M3EIcons.music_note, label: 'Library'),
                  AppMorphingTab(icon: M3EIcons.bar_chart, label: 'Stats'),
                ],
                selectedIndex: 0,
                onTabSelected: (_) {},
                bottomAccessory: const SizedBox(
                  height: 40,
                  child: Center(child: Text('Mini Accessory')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mini Accessory'), findsOneWidget);
    final double before = tester.getSize(find.byType(AppMorphingTabBar)).height;

    await tester.tap(find.byKey(const ValueKey('app_morphing_search_button')));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Mini Accessory'), findsNothing);
    final double after = tester.getSize(find.byType(AppMorphingTabBar)).height;
    expect(after, lessThan(before));
  });
}
