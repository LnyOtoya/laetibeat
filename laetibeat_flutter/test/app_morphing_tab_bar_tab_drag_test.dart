import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/design/design.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('tab indicator animates on tap and follows a horizontal drag', (
    WidgetTester tester,
  ) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      M3EMaterialApp(
        data: AppTheme.light(),
        home: MaterialYouThemeHost(
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return AppMorphingTabBar(
                    tabs: const <AppMorphingTab>[
                      AppMorphingTab(icon: M3EIcons.home, label: 'Home'),
                      AppMorphingTab(
                        icon: M3EIcons.music_note,
                        label: 'Library',
                      ),
                      AppMorphingTab(icon: M3EIcons.bar_chart, label: 'Stats'),
                    ],
                    selectedIndex: selectedIndex,
                    onTabSelected: (int index) {
                      setState(() => selectedIndex = index);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final double startX = tester
        .getTopLeft(find.byKey(const ValueKey('app_morphing_tab_indicator')))
        .dx;

    await tester.tap(find.text('Library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final double midX = tester
        .getTopLeft(find.byKey(const ValueKey('app_morphing_tab_indicator')))
        .dx;
    expect(midX, greaterThan(startX));

    await tester.pumpAndSettle();
    final double endX = tester
        .getTopLeft(find.byKey(const ValueKey('app_morphing_tab_indicator')))
        .dx;
    expect(endX, greaterThan(midX));

    await tester.drag(
      find.byKey(const ValueKey('app_morphing_left_pill')),
      const Offset(160, 0),
    );
    await tester.pumpAndSettle();

    expect(selectedIndex, greaterThan(1));
  });
}
