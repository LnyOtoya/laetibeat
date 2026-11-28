import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 应用级设计语言 / 皮肤。
///
/// 皮肤不只是颜色，而是一整套根 App、导航壳、页面和组件。
/// 皮肤可以改变这些界面的呈现，但移动端路由栈和返回规则由共享导航层管理。
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

/// 一个皮肤构建自己的视觉根 App，同时复用应用级路由和导航状态。
///
/// 皮肤可以复用 Riverpod 中的数据 / controller，并实现自己的页面和导航
/// 呈现；不能为移动端另建页面返回栈或改变共享路由的返回语义。
abstract interface class AppSkin {
  AppSkinId get id;

  Widget buildRoot(BuildContext context, WidgetRef ref);
}
