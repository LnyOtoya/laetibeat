import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'settings_pane.dart';

//播放设置
class PlaybackSettings extends StatefulWidget {
  const PlaybackSettings({super.key});

  @override
  State<PlaybackSettings> createState() => _PlaybackSettingsState();
}

class _PlaybackSettingsState extends State<PlaybackSettings> {
  //均衡器开关
  bool _equalizer = false;
  bool _fadeInOut = true;
  bool _skipSilence = false;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return SettingsPane(
      title: '播放',
      children: [
        //均衡器
        M3EListItem(
          headline: '均衡器',
          supportingText: '调节各频段音量',
          trailing: M3ESwitch(
            value: _equalizer,
            onChanged: (value) => setState(() => _equalizer = value),
          ),
        ),
        //淡入淡出
        M3EListItem(
          headline: '淡入淡出',
          supportingText: '歌曲切换时平滑过渡',
          trailing: M3ESwitch(
            value: _fadeInOut,
            onChanged: (value) => setState(() => _fadeInOut = value),
          ),
        ),
        //跳过静音
        M3EListItem(
          headline: '跳过静音',
          supportingText: '自动跳过歌曲开头静音段落',
          trailing: M3ESwitch(
            value: _skipSilence,
            onChanged: (value) => setState(() => _skipSilence = value),
          ),
        ),
        SizedBox(height: theme.spacing.md),
        M3EDivider(),
        SizedBox(height: theme.spacing.sm),
        //倍速
        M3EListItem(
          headline: '播放速度',
          supportingText: '1.0x',
          onTap: () {},
        ),
      ],
    );
  }
}
