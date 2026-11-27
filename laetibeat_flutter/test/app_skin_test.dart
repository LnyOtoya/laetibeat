import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/app/skin/app_skin.dart';
import 'package:laetibeat/app/skin/app_skin_provider.dart';
import 'package:laetibeat/app/skin/app_skin_registry.dart';
import 'package:laetibeat/widgets/settings/persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to expressive skin', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(appSkinProvider), AppSkinId.expressive);
    expect(
      container.read(appSkinRegistryProvider).skinFor(AppSkinId.expressive).id,
      AppSkinId.expressive,
    );
  });

  test('unknown persisted skin falls back to expressive', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kAppSkinKey: 'spotify',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(
      AppSkinId.fromName(prefs.getString(kAppSkinKey)),
      AppSkinId.expressive,
    );
  });
}
