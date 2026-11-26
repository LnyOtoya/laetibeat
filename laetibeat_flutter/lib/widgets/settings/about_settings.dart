import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import 'app_info_provider.dart';
import 'settings_pane.dart';

//关于
class AboutSettings extends ConsumerWidget {
  const AboutSettings({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final version = ref.watch(appVersionLabelProvider);
    final versionText = version.when(
      data: (String value) => 'Laetibeat $value',
      loading: () => 'Laetibeat ...',
      error: (Object error, StackTrace stackTrace) => 'Laetibeat',
    );

    return SettingsPane(
      title: '关于',
      showTitle: showTitle,
      children: [
        //版本信息
        M3EListItem(headline: '版本', supportingText: versionText, onTap: () {}),
        //开源许可
        M3EListItem(
          headline: '开源许可',
          supportingText: '查看本项目使用的开源组件与许可',
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Laetibeat',
            applicationVersion: version.value ?? '',
          ),
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
