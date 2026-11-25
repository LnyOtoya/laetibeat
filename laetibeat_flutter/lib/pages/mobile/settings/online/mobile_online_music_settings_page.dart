import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../widgets/settings/online_music_settings.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';

/// 在线音乐来源选择页。
///
/// 这里始终是单选：媒体库「在线音乐」分组只跟随当前选中的一个来源。
class MobileOnlineMusicSettingsPage extends ConsumerWidget {
  const MobileOnlineMusicSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final selected = ref.watch(selectedOnlineMusicSourceProvider);
    final sources = allOnlineMusicSources;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: '在线音乐'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: AppRadii.lgAll,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    M3EIcons.info,
                    size: AppIconSize.md,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '只能选择一个在线音乐来源。媒体库的「在线音乐」分组会跟随这里的选择。',
                      style: theme.typeScale.bodyMedium.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            m3e_core.M3ESegmentedColumn(
              decoration: const m3e_core.M3ESegmentedListDecoration(
                outerRadius: 24.0,
                innerRadius: 4.0,
                pressedRadius: 8.0,
                pressedScale: 0.98,
                hoveredRadius: 16.0,
                gap: 2.0,
                padding: EdgeInsets.all(12.0),
                margin: EdgeInsets.zero,
              ),
              onTap: (int index) {
                final source = sources[index];
                unawaited(
                  ref
                      .read(selectedOnlineMusicSourceProvider.notifier)
                      .select(source),
                );
                M3ESnackbar.show(context, message: '已选择 ${source.label}');
              },
              children: [
                for (final source in sources)
                  m3e_core.M3EListItem(
                    headline: Text(source.label),
                    supportingText: Text(source.description),
                    leading: Icon(_iconFor(source), size: AppIconSize.md),
                    trailing: Icon(
                      source == selected
                          ? M3EIcons.radio_button_checked
                          : M3EIcons.radio_button_unchecked,
                      size: AppIconSize.md,
                      color: source == selected
                          ? scheme.primary
                          : scheme.outline,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(OnlineMusicSource source) {
    return switch (source) {
      OnlineMusicSource.netease => M3EIcons.cloud,
    };
  }
}
