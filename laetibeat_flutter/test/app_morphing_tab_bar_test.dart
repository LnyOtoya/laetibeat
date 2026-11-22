import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/design/design.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('morphing tab bar switches between tabs and search', (
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
                  AppMorphingTab(
                    icon: M3EIcons.library_music,
                    label: 'Library',
                  ),
                  AppMorphingTab(icon: M3EIcons.search, label: 'Search'),
                ],
                selectedIndex: 0,
                onTabSelected: (_) {},
                extraAction: AppMorphingTabAction(
                  icon: M3EIcons.more_horiz,
                  onPressed: () {},
                  semanticLabel: '更多',
                ),
                searchConfig: const AppMorphingSearchConfig(hintText: '搜索歌曲'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app_morphing_search_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('app_morphing_extra_action')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('app_morphing_search_button')));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('搜索歌曲'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app_morphing_collapsed_leading')),
      findsOneWidget,
    );
    expect(find.text('Home'), findsNothing);
    expect(find.text('Library'), findsNothing);
  });
}
