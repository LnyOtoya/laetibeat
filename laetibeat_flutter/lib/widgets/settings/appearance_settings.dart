import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'settings_pane.dart';

//外观设置
class AppearanceSettings extends StatefulWidget {
  const AppearanceSettings({super.key});

  @override
  State<AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<AppearanceSettings> {
  //主题模式:浅色/深色/跟随系统
  Set<String> _themeMode = {'system'};
  bool _dynamicColor = true;
  bool _reduceMotion = false;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return SettingsPane(
      title: '外观',
      children: [
        //主题模式
        Text('主题模式', style: theme.typeScale.titleMedium),
        SizedBox(height: theme.spacing.sm),
        M3ESegmentedButton<String>(
          segments: const [
            M3ESegment(value: 'light', label: '浅色'),
            M3ESegment(value: 'dark', label: '深色'),
            M3ESegment(value: 'system', label: '跟随系统'),
          ],
          selected: _themeMode,
          onSelectionChanged: (value) {
            setState(() => _themeMode = value);
          },
        ),
        SizedBox(height: theme.spacing.md),
        M3EDivider(),
        SizedBox(height: theme.spacing.sm),
        //动态取色
        M3EListItem(
          headline: '动态取色',
          supportingText: '根据当前播放歌曲封面自动生成主题色',
          trailing: M3ESwitch(
            value: _dynamicColor,
            onChanged: (value) => setState(() => _dynamicColor = value),
          ),
        ),
        //减弱动画
        M3EListItem(
          headline: '减弱动画',
          supportingText: '减少界面过渡与动效',
          trailing: M3ESwitch(
            value: _reduceMotion,
            onChanged: (value) => setState(() => _reduceMotion = value),
          ),
        ),
      ],
    );
  }
}
