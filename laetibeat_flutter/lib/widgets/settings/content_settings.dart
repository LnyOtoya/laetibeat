import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'settings_pane.dart';

//内容设置:音乐来源
class ContentSettings extends StatelessWidget {
  const ContentSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    //单个分组通用构建
    Widget group({
      required String title,
      required List<Widget> items,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //分组小标题
          Text(
            title,
            style: theme.typeScale.labelMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          ...items,
        ],
      );
    }

    //列表项通用构建
    Widget item({
      required String label,
      required IconData icon,
    }) {
      return M3ECardList(
        itemCount: 1,
        itemBuilder: (context, i) {
          return M3EListItem(
            headline: label,
            leading: M3EShapeContainer.square(
              width: theme.spacing.xxl * 1.5,
              height: theme.spacing.xxl * 1.5,
              color: scheme.secondaryContainer,
              child: Icon(icon),
            ),
          );
        },
      );
    }

    return SettingsPane(
      title: '内容',
      children: [
        //分组:本地目录结构
        group(
          title: '本地目录结构',
          items: [
            item(label: '选择目录', icon: M3EIcons.folder_open),
            SizedBox(height: theme.spacing.md),
            item(label: '重新扫描', icon: M3EIcons.refresh),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        //分组:navidrome音乐库
        group(
          title: 'navidrome音乐库',
          items: [
            item(label: '连接配置', icon: M3EIcons.link),
            SizedBox(height: theme.spacing.md),
            item(label: '同步音乐', icon: M3EIcons.sync),
          ],
        ),
      ],
    );
  }
}