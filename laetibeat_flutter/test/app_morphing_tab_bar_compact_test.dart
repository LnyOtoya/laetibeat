import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/design/design.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('morphing tab bar fits a 320dp phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
    expect(tester.takeException(), isNull);

    expect(
      tester
          .getSize(find.byKey(const ValueKey('app_morphing_left_pill')))
          .width,
      greaterThan(0),
    );

    await tester.tap(find.byKey(const ValueKey('app_morphing_search_button')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('app_morphing_right_pill')))
          .width,
      greaterThan(
        tester
            .getSize(find.byKey(const ValueKey('app_morphing_left_pill')))
            .width,
      ),
    );
  });
}
