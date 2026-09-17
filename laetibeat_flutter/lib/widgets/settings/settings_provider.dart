import 'package:flutter_riverpod/flutter_riverpod.dart';

//设置页分类
enum SettingsCategory {
  appearance, //外观
  playerAudio, //播放器与音频
  content, //内容
  storage, //储存
  backup, //备份与还原
  changelog, //更新日志
  about, //关于
}

//选中分类的控制器
class SettingsCategoryNotifier extends Notifier<SettingsCategory> {
  @override
  SettingsCategory build() => SettingsCategory.appearance;

  void select(SettingsCategory category) {
    state = category;
  }
}

//当前选中的设置分类
final settingsCategoryProvider = NotifierProvider<SettingsCategoryNotifier, SettingsCategory>(
  SettingsCategoryNotifier.new,
);
