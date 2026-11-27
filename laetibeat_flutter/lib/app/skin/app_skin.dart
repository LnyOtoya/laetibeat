import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 应用级设计语言 / 皮肤。
///
/// 皮肤不只是颜色，而是一整套根 App、导航壳、页面和组件。
/// 默认皮肤是当前的 Material 3 Expressive。
enum AppSkinId {
  expressive;

  String get label => switch (this) {
    AppSkinId.expressive => 'Material 3 Expressive',
  };

  String get description => switch (this) {
    AppSkinId.expressive => '当前默认主题',
  };

  static AppSkinId fromName(String? value) {
    for (final skin in values) {
      if (skin.name == value) return skin;
    }
    return AppSkinId.expressive;
  }
}

/// 一个皮肤必须自己构建完整的根 App。
///
/// 皮肤可以复用 Riverpod 中的数据 / controller，但不应直接复用另一套
/// 皮肤的页面或导航壳。
abstract interface class AppSkin {
  AppSkinId get id;

  Widget buildRoot(BuildContext context, WidgetRef ref);
}
