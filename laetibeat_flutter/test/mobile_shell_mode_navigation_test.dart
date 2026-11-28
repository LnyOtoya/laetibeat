import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/app/app_mode.dart';
import 'package:laetibeat/design/design.dart';
import 'package:laetibeat/l10n/generated/app_localizations.dart';
import 'package:laetibeat/pages/mobile/mobile_app.dart';
import 'package:laetibeat/pages/mobile/mobile_navigation.dart';
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

void main() {
  testWidgets('mobile tabs and landing route follow AppMode', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{kAppModeKey: 'qq'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        playerProvider.overrideWith(_FakePlayerNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => mobileCurrentRouteName.value = MobileRoutes.home);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
              observers: <NavigatorObserver>[mobileNavigatorObserver],
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

    // QQ mode: 首页 / 发现 / 媒体库
    expect(find.byIcon(M3EIcons.home), findsOneWidget);
    expect(find.byIcon(M3EIcons.explore), findsOneWidget);
    expect(find.byIcon(M3EIcons.music_note), findsOneWidget);
    expect(find.byIcon(M3EIcons.bar_chart), findsNothing);

    await container.read(appModeProvider.notifier).setMode(AppMode.local);
    await tester.pumpAndSettle();

    // Local mode: 仅媒体库，并落到媒体库。
    expect(find.byIcon(M3EIcons.home), findsNothing);
    expect(find.byIcon(M3EIcons.explore), findsNothing);
    expect(find.byIcon(M3EIcons.music_note), findsOneWidget);
    expect(find.byIcon(M3EIcons.bar_chart), findsNothing);
    expect(find.text(MobileRoutes.library), findsOneWidget);
  });
}
