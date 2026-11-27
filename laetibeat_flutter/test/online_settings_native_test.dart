import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/app/app_mode.dart';
import 'package:laetibeat/widgets/settings/mode_host.dart';
import 'package:laetibeat/widgets/settings/online_settings.dart';
import 'package:laetibeat/widgets/settings/persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'quality and LX fallback persist without remote service config',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(onlineSettingsProvider).defaultQuality, 'high');
      expect(container.read(onlineSettingsProvider).allowLxFallback, isFalse);
      expect(container.read(onlineBaseUrlProvider), isEmpty);

      await container
          .read(onlineSettingsProvider.notifier)
          .setDefaultQuality('lossless');
      await container
          .read(onlineSettingsProvider.notifier)
          .setAllowLxFallback(true);
      expect(prefs.getString(kOnlineDefaultQualityKey), 'lossless');
      expect(prefs.getBool(kOnlineAllowLxFallbackKey), isTrue);

      await container.read(onlineSettingsProvider.notifier).clear();
      expect(container.read(onlineSettingsProvider).defaultQuality, 'high');
      expect(container.read(onlineSettingsProvider).allowLxFallback, isFalse);
    },
  );

  test('base URL follows the active native runtime only', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{kAppModeKey: 'qq'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(onlineBaseUrlProvider), isEmpty);
    container
        .read(modeRuntimeProvider.notifier)
        .set(
          mode: AppMode.qq,
          baseUrl: 'http://127.0.0.1:18103',
          token: 'secret',
        );
    expect(container.read(onlineBaseUrlProvider), 'http://127.0.0.1:18103');
    expect(await container.read(onlineTokenProvider.future), 'secret');
  });
}
