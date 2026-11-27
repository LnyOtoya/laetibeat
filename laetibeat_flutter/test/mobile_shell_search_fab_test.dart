import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/app/app_mode.dart';
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

class _FakeAppModeNotifier extends AppModeNotifier {
  @override
  AppMode build() => AppMode.qq;
}

void main() {
  testWidgets('mobile shell search FAB opens the search route', (
    WidgetTester tester,
  ) async {
    addTearDown(() {
      mobileCurrentRouteName.value = MobileRoutes.home;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(_FakePlayerNotifier.new),
          appModeProvider.overrideWith(_FakeAppModeNotifier.new),
        ],
        child: M3EMaterialApp(
          data: AppTheme.light(),
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
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

    expect(find.byType(AppFloatingNavBar), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('app_floating_nav_search')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('app_floating_nav_search')),
    );
    await tester.pumpAndSettle();

    expect(find.text(MobileRoutes.search), findsOneWidget);
    expect(find.byType(AppFloatingNavBar), findsNothing);

    mobileNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text(MobileRoutes.home), findsOneWidget);
    expect(find.byType(AppFloatingNavBar), findsOneWidget);
  });
}
