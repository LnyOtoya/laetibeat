import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/app/app_destination.dart';
import 'package:laetibeat/app/app_mode.dart';
import 'package:laetibeat/widgets/settings/mode_host.dart';
import 'package:laetibeat/widgets/settings/online_settings.dart';
import 'package:laetibeat/widgets/settings/persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app mode persists and maps host ids', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{kAppModeKey: 'qq'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(appModeProvider), AppMode.qq);
    expect(AppMode.qq.usesOnlineHost, isTrue);
    expect(AppMode.qq.hostId, 'qq');
    expect(AppMode.netease.hostId, 'netease');
    expect(AppMode.local.usesOnlineHost, isFalse);
    expect(AppMode.subsonic.usesOnlineHost, isFalse);
    expect(AppMode.local.mobileDestinations, <AppDestination>[
      AppDestination.library,
    ]);
    expect(AppMode.subsonic.mobileDestinations, <AppDestination>[
      AppDestination.home,
      AppDestination.library,
    ]);
    expect(AppMode.qq.mobileDestinations, <AppDestination>[
      AppDestination.home,
      AppDestination.library,
    ]);
    expect(AppMode.netease.mobileDestinations, AppMode.qq.mobileDestinations);
    expect(AppMode.local.mobileInitialDestination, AppDestination.library);
    expect(AppMode.subsonic.mobileInitialDestination, AppDestination.home);
    expect(AppMode.qq.mobileInitialDestination, AppDestination.home);

    await container.read(appModeProvider.notifier).setMode(AppMode.netease);
    expect(container.read(appModeProvider), AppMode.netease);
    expect(prefs.getString(kAppModeKey), 'netease');

    await container.read(appModeProvider.notifier).setMode(AppMode.local);
    expect(container.read(appModeProvider), AppMode.local);
    expect(prefs.getString(kAppModeKey), 'local');
  });

  test('mode runtime exposes and clears sidecar endpoint', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(modeRuntimeProvider).hasBaseUrl, isFalse);
    container
        .read(modeRuntimeProvider.notifier)
        .set(
          mode: AppMode.netease,
          baseUrl: 'http://127.0.0.1:1234',
          token: 'secret',
        );
    final runtime = container.read(modeRuntimeProvider);
    expect(runtime.mode, AppMode.netease);
    expect(runtime.baseUrl, 'http://127.0.0.1:1234');
    expect(runtime.token, 'secret');
    expect(runtime.hasBaseUrl, isTrue);

    container.read(modeRuntimeProvider.notifier).clear();
    expect(container.read(modeRuntimeProvider).hasBaseUrl, isFalse);
  });

  test('online base URL follows active native sidecar runtime', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kAppModeKey: 'netease',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(onlineBaseUrlProvider), isEmpty);
    container
        .read(modeRuntimeProvider.notifier)
        .set(
          mode: AppMode.netease,
          baseUrl: 'http://127.0.0.1:18102',
          token: 'secret',
        );
    expect(container.read(onlineBaseUrlProvider), 'http://127.0.0.1:18102');
    expect(await container.read(onlineTokenProvider.future), 'secret');
  });

  test('unknown persisted mode falls back to local', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kAppModeKey: 'spotify',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(AppMode.fromName(prefs.getString(kAppModeKey)), AppMode.local);
  });
}
