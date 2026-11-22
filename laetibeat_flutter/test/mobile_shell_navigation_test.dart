import 'package:flutter_localizations/flutter_localizations.dart'
    as flutter_l10n;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/design/design.dart';
import 'package:laetibeat/l10n/generated/app_localizations.dart';
import 'package:laetibeat/pages/mobile/mobile_app.dart';
import 'package:laetibeat/pages/mobile/mobile_navigation.dart';
import 'package:laetibeat/pages/mobile/routes.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

class _FakePlayerNotifier extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

void main() {
  testWidgets('mobile shell uses the morphing bar for top-level tabs', (
    WidgetTester tester,
  ) async {
    addTearDown(() {
      mobileCurrentRouteName.value = MobileRoutes.home;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [playerProvider.overrideWith(_FakePlayerNotifier.new)],
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

    expect(find.byType(AppMorphingTabBar), findsOneWidget);
    expect(find.byType(M3ENavigationBar), findsNothing);
    expect(find.text(MobileRoutes.home), findsOneWidget);

    await tester.tap(find.byIcon(M3EIcons.bar_chart));
    await tester.pumpAndSettle();

    expect(find.text(MobileRoutes.stats), findsOneWidget);
    expect(find.byType(AppMorphingTabBar), findsOneWidget);
  });
}
