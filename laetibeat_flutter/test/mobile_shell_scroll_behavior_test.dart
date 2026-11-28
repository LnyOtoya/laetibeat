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
import 'package:m3e_core/m3e_core.dart';

class _FakePlayerNotifier extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

class _FakeAppModeNotifier extends AppModeNotifier {
  @override
  AppMode build() => AppMode.qq;
}

class _ScrollablePage extends StatelessWidget {
  const _ScrollablePage({required this.axis});

  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: ValueKey<String>('scroll-${axis.name}'),
      scrollDirection: axis,
      itemCount: 80,
      itemExtent: 100,
      itemBuilder: (BuildContext context, int index) =>
          Center(child: Text('$index')),
    );
  }
}

Future<M3EFloatingToolbarState> _pumpShell(
  WidgetTester tester, {
  required Axis axis,
}) async {
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
        home: _ScrollablePage(axis: axis),
        appBuilder: (BuildContext context, Widget? child) =>
            MobileShell(child: child ?? const SizedBox.shrink()),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return tester
      .widget<AppFloatingNavBar>(find.byType(AppFloatingNavBar))
      .scrollBehavior!
      .state;
}

void main() {
  setUp(() {
    mobileCurrentRouteName.value = MobileRoutes.home;
  });

  testWidgets('small vertical scroll does not hide navigation bar', (
    WidgetTester tester,
  ) async {
    final scrollState = await _pumpShell(tester, axis: Axis.vertical);

    await tester.drag(
      find.byKey(const ValueKey<String>('scroll-vertical')),
      const Offset(0, -32),
    );
    await tester.pumpAndSettle();
    expect(scrollState.offset, 0);

    await tester.drag(
      find.byKey(const ValueKey<String>('scroll-vertical')),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    expect(scrollState.offset, lessThan(0));
  });

  testWidgets('horizontal scroll does not hide navigation bar', (
    WidgetTester tester,
  ) async {
    final scrollState = await _pumpShell(tester, axis: Axis.horizontal);

    await tester.drag(
      find.byKey(const ValueKey<String>('scroll-horizontal')),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();

    expect(scrollState.offset, 0);
  });
}
