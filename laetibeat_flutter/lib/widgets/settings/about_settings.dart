import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'settings_pane.dart';

//关于
class AboutSettings extends StatelessWidget {
  const AboutSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return SettingsPane(
      title: '关于',
      children: [
        //版本信息
        M3EListItem(
          headline: '版本',
          supportingText: 'Laetibeat 0.1.0',
          onTap: () {},
        ),
        //开源许可
        M3EListItem(
          headline: '开源许可',
          supportingText: '查看本项目使用的开源组件与许可',
          onTap: () {},
        ),
        //检查更新
        M3EListItem(
          headline: '检查更新',
          supportingText: '检测是否有新版本可用',
          onTap: () {},
        ),
        SizedBox(height: theme.spacing.lg),
        Center(
          child: Text(
            'Made with ♥ and Rust + Flutter',
            style: theme.typeScale.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
