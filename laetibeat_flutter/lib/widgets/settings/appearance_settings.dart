import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'settings_pane.dart';

//外观设置
class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    return SettingsPane(
      title: '外观',
      children: [
        //分组:全局主题
        Text(
          '全局主题',
          style: theme.typeScale.labelMedium.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        M3ECardList(
          itemCount: 1,
          itemBuilder: (context, i) {
            return M3EListItem(
              headline: '应用主题',
              leading: M3EShapeContainer.square(
                width: theme.spacing.xxl * 1.5,
                height: theme.spacing.xxl * 1.5,
                color: scheme.secondaryContainer,
                child: const Icon(M3EIcons.format_paint),
              ),
            );
          },
        ),
      ],
    );
  }
}
