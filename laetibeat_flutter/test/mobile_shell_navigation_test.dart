import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/app/app_destination.dart';
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
  testWidgets('mobile shell uses the floating nav bar for top-level tabs', (
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
      find.byKey(const ValueKey('mobile_floating_nav_bar')),
      findsOneWidget,
    );
    expect(find.byType(M3ENavigationBar), findsNothing);
    expect(find.text(AppDestination.home.name), findsOneWidget);

    await tester.tap(find.byIcon(M3EIcons.music_note));
    await tester.pumpAndSettle();

    expect(find.text(AppDestination.library.name), findsOneWidget);
    expect(find.byType(AppFloatingNavBar), findsOneWidget);
  });
}
