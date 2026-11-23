import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/design/design.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('morphing tab bar animates both pill widths', (
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

    final double leftBefore = tester
        .getSize(find.byKey(const ValueKey('app_morphing_left_pill')))
        .width;
    final double rightBefore = tester
        .getSize(find.byKey(const ValueKey('app_morphing_right_pill')))
        .width;

    await tester.tap(find.byKey(const ValueKey('app_morphing_search_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final double leftMid = tester
        .getSize(find.byKey(const ValueKey('app_morphing_left_pill')))
        .width;
    final double rightMid = tester
        .getSize(find.byKey(const ValueKey('app_morphing_right_pill')))
        .width;

    expect(leftMid, lessThan(leftBefore));
    expect(rightMid, greaterThan(rightBefore));

    await tester.pumpAndSettle();

    final double leftAfter = tester
        .getSize(find.byKey(const ValueKey('app_morphing_left_pill')))
        .width;
    final double rightAfter = tester
        .getSize(find.byKey(const ValueKey('app_morphing_right_pill')))
        .width;

    expect(leftAfter, lessThan(leftBefore));
    expect(rightAfter, greaterThan(rightBefore));
    expect(leftAfter, moreOrLessEquals(64, epsilon: 0.5));

    await tester.tap(find.byKey(const ValueKey('app_morphing_search_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final double leftReverseMid = tester
        .getSize(find.byKey(const ValueKey('app_morphing_left_pill')))
        .width;
    expect(leftReverseMid, greaterThan(leftAfter));

    await tester.pumpAndSettle();

    final double leftRestored = tester
        .getSize(find.byKey(const ValueKey('app_morphing_left_pill')))
        .width;
    expect(leftRestored, moreOrLessEquals(leftBefore, epsilon: 0.5));
  });
}
