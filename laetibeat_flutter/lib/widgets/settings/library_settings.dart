import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'settings_pane.dart';

//音乐库设置
class LibrarySettings extends StatefulWidget {
  const LibrarySettings({super.key});

  @override
  State<LibrarySettings> createState() => _LibrarySettingsState();
}

class _LibrarySettingsState extends State<LibrarySettings> {
  bool _autoScan = true;
  bool _onlyDownloaded = false;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return SettingsPane(
      title: '音乐库',
      children: [
        //扫描目录
        M3EListItem(
          headline: '扫描目录',
          supportingText: 'C:\\Users\\otoya\\Music',
          onTap: () {},
        ),
        //立即扫描
        M3EListItem(
          headline: '立即扫描',
          supportingText: '重新扫描音乐库并刷新标签',
          onTap: () {},
        ),
        SizedBox(height: theme.spacing.md),
        M3EDivider(),
        SizedBox(height: theme.spacing.sm),
        //自动扫描
        M3EListItem(
          headline: '自动扫描',
          supportingText: '启动时自动检测新增音乐',
          trailing: M3ESwitch(
            value: _autoScan,
            onChanged: (value) => setState(() => _autoScan = value),
          ),
        ),
        //仅显示已下载
        M3EListItem(
          headline: '仅显示已下载',
          supportingText: '隐藏云端歌曲,只显示本地文件',
          trailing: M3ESwitch(
            value: _onlyDownloaded,
            onChanged: (value) => setState(() => _onlyDownloaded = value),
          ),
        ),
      ],
    );
  }
}
