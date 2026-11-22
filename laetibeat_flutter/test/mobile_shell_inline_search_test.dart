import 'package:flutter_localizations/flutter_localizations.dart'
    as flutter_l10n;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/design/design.dart';
import 'package:laetibeat/l10n/generated/app_localizations.dart';
import 'package:laetibeat/pages/mobile/mobile_app.dart';
import 'package:laetibeat/pages/mobile/mobile_navigation.dart';
import 'package:laetibeat/pages/mobile/routes.dart';
import 'package:laetibeat/pages/mobile/search/mobile_search_browse_view.dart';
import 'package:laetibeat/pages/mobile/search/mobile_search_inline_view.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/settings/persistence.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlayerNotifier extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

void main() {
  testWidgets('mobile shell opens and closes inline search', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    addTearDown(() {
      mobileCurrentRouteName.value = MobileRoutes.home;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(_FakePlayerNotifier.new),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: M3EMaterialApp(
          data: AppTheme.light(),
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
            flutter_l10n.GlobalMaterialLocalizations.delegate,
            flutter_l10n.GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MobileShell(
            child: Navigator(
              key: mobileNavigatorKey,
              observers: [mobileNavigatorObserver],
              initialRoute: MobileRoutes.home,
              onGenerateRoute: (RouteSettings settings) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => Scaffold(
                    body: Center(child: Text(settings.name ?? 'unknown')),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(MobileSearchInlineView), findsNothing);

    await tester.tap(find.byKey(const ValueKey('app_morphing_search_button')));
    await tester.pumpAndSettle();

    expect(find.byType(MobileSearchBrowseView), findsOneWidget);
    expect(find.byType(MobileSearchInlineView), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app_morphing_left_pill')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('app_morphing_search_clear_pill')),
      findsNothing,
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.byType(MobileSearchInlineView), findsOneWidget);
    expect(find.byType(MobileSearchBrowseView), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('app_morphing_left_pill')))
          .width,
      0,
    );
    expect(
      find.byKey(const ValueKey('app_morphing_collapsed_leading')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('app_morphing_search_close')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('app_morphing_search_clear_pill')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('app_morphing_search_clear_pill')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MobileSearchInlineView), findsNothing);
    expect(find.byType(MobileSearchBrowseView), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
