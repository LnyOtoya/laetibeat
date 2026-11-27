import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/source_links.dart';
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
        //AGPL 源码入口
        M3EListItem(
          headline: '在线音源源码',
          supportingText: 'QQMusicApi-rs · GPL-3.0 / ncm-api-rs · WTFPL',
          onTap: () => _showSourceDialog(context),
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

  Future<void> _showSourceDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('在线音源源码'),
          content: const SingleChildScrollView(
            child: SelectableText(
              'Laetibeat\n'
              '$laetibeatSourceUrl\n\n'
              'QQMusicApi-rs\n$qqMusicApiSourceUrl\n\n'
              'ncm-api-rs\n$ncmApiSourceUrl\n\n'
              'laetibeat_qq_host 为 GPL-3.0-only；laetibeat_netease_host 为 MIT，'
              '依赖 ncm-api-rs（WTFPL）。完整许可文本见「开源许可」。',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
            FilledButton(
              onPressed: () async {
                await Clipboard.setData(
                  const ClipboardData(text: laetibeatSourceUrl),
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('复制项目链接'),
            ),
          ],
        );
      },
    );
  }
}
