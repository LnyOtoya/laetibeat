import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/design/design.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('search pill can dispatch an external search action', (
    WidgetTester tester,
  ) async {
    var presses = 0;

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
                onSearchPressed: () => presses++,
                searchConfig: const AppMorphingSearchConfig(hintText: '搜索歌曲'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('app_morphing_search_button')));
    await tester.pumpAndSettle();

    expect(presses, 1);
    expect(find.byType(TextField), findsNothing);
    expect(
      find.byKey(const ValueKey('app_morphing_search_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('app_morphing_collapsed_leading')),
      findsNothing,
    );
  });
}
