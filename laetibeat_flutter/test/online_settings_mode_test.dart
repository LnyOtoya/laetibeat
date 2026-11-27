import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/widgets/settings/online_settings.dart';
import 'package:laetibeat/widgets/settings/persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mode and runtime overrides drive base URL and token', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kOnlineModeKey: 'remote',
      kOnlineBaseUrlKey: 'https://music.example.com',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(onlineSettingsProvider).mode, OnlineMode.remote);
    expect(container.read(onlineBaseUrlProvider), 'https://music.example.com');

    await container
        .read(onlineSettingsProvider.notifier)
        .setMode(OnlineMode.builtin);
    expect(container.read(onlineSettingsProvider).mode, OnlineMode.builtin);
    expect(prefs.getString(kOnlineModeKey), 'builtin');

    container
        .read(onlineRuntimeOverridesProvider.notifier)
        .set(baseUrl: 'http://127.0.0.1:1234', token: 'token');
    expect(container.read(onlineBaseUrlProvider), 'http://127.0.0.1:1234');
    expect(await container.read(onlineTokenProvider.future), 'token');

    container.read(onlineRuntimeOverridesProvider.notifier).clear();
    expect(container.read(onlineBaseUrlProvider), 'https://music.example.com');
  });
}
