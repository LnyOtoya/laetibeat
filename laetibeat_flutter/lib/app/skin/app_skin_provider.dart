import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/settings/persistence.dart';
import 'app_skin.dart';

const String kAppSkinKey = 'ui.skin';

class AppSkinNotifier extends Notifier<AppSkinId> {
  @override
  AppSkinId build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return AppSkinId.fromName(prefs.getString(kAppSkinKey));
  }

  Future<void> setSkin(AppSkinId skin) async {
    if (state == skin) return;
    state = skin;
    await ref.read(sharedPreferencesProvider).setString(kAppSkinKey, skin.name);
  }
}

final appSkinProvider = NotifierProvider<AppSkinNotifier, AppSkinId>(
  AppSkinNotifier.new,
);
