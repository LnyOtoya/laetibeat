import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/app/app_mode.dart';
import 'package:laetibeat/design/components/navigation/app_bottom_overlay.dart';
import 'package:laetibeat/design/theme/app_theme.dart';
import 'package:laetibeat/l10n/generated/app_localizations.dart';
import 'package:laetibeat/pages/mobile/mobile_app.dart';
import 'package:laetibeat/pages/mobile/mobile_navigation.dart';
import 'package:laetibeat/pages/mobile/routes.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

class _FakePlayerNotifier extends PlayerNotifier {
  @override
  PlayerState build() => PlayerState(
    queue: <rust.UiTrack>[
      rust.UiTrack(
        id: 'test-track',
        title: 'Test track',
        artist: 'Test artist',
        album: 'Test album',
        albumArtist: 'Test artist',
        albumId: 'test-album',
        artistId: 'test-artist',
        duration: '1:00',
        durationSeconds: BigInt.from(60),
        path: '',
        source: 'local',
        sourceId: 'local',
      ),
    ],
  );
}

class _FakeAppModeNotifier extends AppModeNotifier {
  @override
  AppMode build() => AppMode.local;
}

void main() {
  testWidgets('mini player remains on non-settings routes only', (
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
          home: const SizedBox.shrink(),
          appBuilder: (BuildContext context, Widget? child) =>
              MobileShell(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    mobileCurrentRouteName.value = MobileRoutes.recent;
    await tester.pumpAndSettle();

    final overlayFinder = find.byType(AppBottomOverlay);
    expect(overlayFinder, findsOneWidget);
    expect(tester.widget<AppBottomOverlay>(overlayFinder).miniVisible, isTrue);

    mobileCurrentRouteName.value = MobileRoutes.opensubsonicConfig;
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomOverlay), findsNothing);
  });
}
