import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'settings_pane.dart';

//通知设置
class NotificationsSettings extends StatefulWidget {
  const NotificationsSettings({super.key});

  @override
  State<NotificationsSettings> createState() => _NotificationsSettingsState();
}

class _NotificationsSettingsState extends State<NotificationsSettings> {
  bool _playbackNotification = true;
  bool _showLyrics = false;
  bool _showProgress = true;

  @override
  Widget build(BuildContext context) {
    return SettingsPane(
      title: '通知',
      children: [
        //播放通知
        M3EListItem(
          headline: '播放通知',
          supportingText: '在通知栏显示当前播放控件',
          trailing: M3ESwitch(
            value: _playbackNotification,
            onChanged: (value) => setState(() => _playbackNotification = value),
          ),
        ),
        //显示歌词
        M3EListItem(
          headline: '显示歌词',
          supportingText: '在通知栏展示当前歌词',
          trailing: M3ESwitch(
            value: _showLyrics,
            onChanged: (value) => setState(() => _showLyrics = value),
          ),
        ),
        //显示进度
        M3EListItem(
          headline: '显示进度',
          supportingText: '在通知栏展示播放进度条',
          trailing: M3ESwitch(
            value: _showProgress,
            onChanged: (value) => setState(() => _showProgress = value),
          ),
        ),
      ],
    );
  }
}
