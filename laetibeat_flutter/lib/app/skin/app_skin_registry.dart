import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../skins/expressive/expressive_skin.dart';
import 'app_skin.dart';

/// AppSkinId 到具体皮肤实现的注册表。
///
/// 新皮肤实现后只需要在这里增加一个 case；页面和业务 provider 不需要改动。
class AppSkinRegistry {
  const AppSkinRegistry();

  AppSkin skinFor(AppSkinId id) {
    return switch (id) {
      AppSkinId.expressive => const ExpressiveSkin(),
    };
  }
}

final appSkinRegistryProvider = Provider<AppSkinRegistry>(
  (ref) => const AppSkinRegistry(),
);
