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
  AppMode build() => AppMode.local;
}

class _RootPage extends StatelessWidget {
  const _RootPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => pushMobileRootPage(
            context,
            const _AlbumPage(),
            name: MobileRoutes.albumDetail,
          ),
          child: const Text('open album'),
        ),
      ),
    );
  }
}

class _AlbumPage extends StatelessWidget {
  const _AlbumPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () =>
              pushMobileFullPlayer(context, const _FullPlayerPage()),
          child: const Text('open player'),
        ),
      ),
    );
  }
}

class _FullPlayerPage extends StatelessWidget {
  const _FullPlayerPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('full player')));
  }
}

void main() {
  testWidgets('system back pops full player, detail, then returns to shell', (
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
          navigatorObservers: <NavigatorObserver>[mobileNavigatorObserver],
          home: const _RootPage(),
          appBuilder: (BuildContext context, Widget? child) =>
              MobileShell(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open album'));
    await tester.pumpAndSettle();
    expect(find.text('open player'), findsOneWidget);

    await tester.tap(find.text('open player'));
    await tester.pumpAndSettle();
    expect(find.text('full player'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('open player'), findsOneWidget);
    expect(mobileCurrentRouteName.value, MobileRoutes.albumDetail);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('open album'), findsOneWidget);
    expect(mobileCurrentRouteName.value, MobileRoutes.home);
  });
}
