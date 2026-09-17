import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'settings_pane.dart';

//音频输出设置
class AudioOutputSettings extends StatefulWidget {
  const AudioOutputSettings({super.key});

  @override
  State<AudioOutputSettings> createState() => _AudioOutputSettingsState();
}

class _AudioOutputSettingsState extends State<AudioOutputSettings> {
  //输出设备:0系统默认,1扬声器,2耳机
  int _selectedDevice = 0;
  bool _exclusiveMode = false;

  //设备假数据
  static const List<String> _devices = ['系统默认', '扬声器', '耳机'];

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return SettingsPane(
      title: '音频输出',
      children: [
        //输出设备
        Text('输出设备', style: theme.typeScale.titleMedium),
        SizedBox(height: theme.spacing.sm),
        M3ESegmentedButton<int>(
          segments: [
            for (int i = 0; i < _devices.length; i++)
              M3ESegment(value: i, label: _devices[i]),
          ],
          selected: {_selectedDevice},
          onSelectionChanged: (value) {
            setState(() => _selectedDevice = value.first);
          },
        ),
        SizedBox(height: theme.spacing.md),
        M3EDivider(),
        SizedBox(height: theme.spacing.sm),
        //独占模式
        M3EListItem(
          headline: '独占模式',
          supportingText: '绕过系统混音,直接控制音频设备',
          trailing: M3ESwitch(
            value: _exclusiveMode,
            onChanged: (value) => setState(() => _exclusiveMode = value),
          ),
        ),
      ],
    );
  }
}
