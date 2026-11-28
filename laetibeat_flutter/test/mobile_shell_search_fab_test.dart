import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/app/app_destination.dart';
import 'package:laetibeat/app/app_mode.dart';
import 'package:laetibeat/design/design.dart';
import 'package:laetibeat/l10n/generated/app_localizations.dart';
import 'package:laetibeat/pages/mobile/mobile_app.dart';
import 'package:laetibeat/pages/mobile/mobile_navigation.dart';
import 'package:laetibeat/pages/mobile/search/mobile_search_page.dart';
import 'package:laetibeat/pages/mobile/routes.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/settings/persistence.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePlayerNotifier extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

class _FakeAppModeNotifier extends AppModeNotifier {
  @override
  AppMode build() => AppMode.qq;
}

class _ShellDestinationPage extends ConsumerWidget {
  const _ShellDestinationPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Text(ref.watch(mobileSelectedDestinationProvider).name),
      ),
    );
  }
}

void main() {
  testWidgets('mobile shell search FAB opens the search route', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    addTearDown(() {
      mobileCurrentRouteName.value = MobileRoutes.home;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(_FakePlayerNotifier.new),
          appModeProvider.overrideWith(_FakeAppModeNotifier.new),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: M3EMaterialApp(
          data: AppTheme.light(),
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorKey: mobileRootNavigatorKey,
          navigatorObservers: [mobileNavigatorObserver],
          home: const _ShellDestinationPage(),
          appBuilder: (BuildContext context, Widget? child) =>
              MobileShell(child: child ?? const SizedBox.shrink()),
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

    expect(find.byType(MobileSearchPage), findsOneWidget);
    expect(mobileCurrentRouteName.value, MobileRoutes.search);
    expect(find.byType(AppFloatingNavBar), findsNothing);

    mobileRootNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text(AppDestination.home.name), findsOneWidget);
    expect(find.byType(AppFloatingNavBar), findsOneWidget);
  });
}
