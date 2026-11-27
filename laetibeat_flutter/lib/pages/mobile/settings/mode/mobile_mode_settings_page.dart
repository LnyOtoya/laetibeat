import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_mode.dart';
import '../../../../design/design.dart';
import '../../../../widgets/settings/mode_host.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';

/// 应用级音源模式与 Rust sidecar 生命周期。
///
/// N3 先提供模式切换、启停与状态；具体页面数据接入在 N4。
class MobileModeSettingsPage extends ConsumerStatefulWidget {
  const MobileModeSettingsPage({super.key});

  @override
  ConsumerState<MobileModeSettingsPage> createState() =>
      _MobileModeSettingsPageState();
}

class _MobileModeSettingsPageState
    extends ConsumerState<MobileModeSettingsPage> {
  bool _busy = false;

  Future<void> _switchMode(AppMode mode) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(modeHostProvider.notifier).switchTo(mode);
      if (!mounted) return;
      final host = ref.read(modeHostProvider);
      if (host.hasError) {
        M3ESnackbar.show(context, message: host.error ?? 'sidecar 启动失败');
      }
    } catch (error) {
      if (mounted) {
        M3ESnackbar.show(context, message: '切换失败：$error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(modeHostProvider.notifier).start();
      if (!mounted) return;
      final host = ref.read(modeHostProvider);
      if (host.hasError) {
        M3ESnackbar.show(context, message: host.error ?? 'sidecar 启动失败');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final mode = ref.watch(appModeProvider);
    final host = ref.watch(modeHostProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: '音源模式'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            Text('当前模式', style: theme.typeScale.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            M3ESegmentedButton<AppMode>(
              segments: const <M3ESegment<AppMode>>[
                M3ESegment(value: AppMode.local, label: '本地'),
                M3ESegment(value: AppMode.subsonic, label: 'Subsonic'),
                M3ESegment(value: AppMode.qq, label: 'QQ'),
                M3ESegment(value: AppMode.netease, label: '网易云'),
              ],
              selected: <AppMode>{mode},
              onSelectionChanged: (Set<AppMode> values) {
                unawaited(_switchMode(values.first));
              },
            ),
            const SizedBox(height: AppSpacing.md),
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
                      mode.usesOnlineHost
                          ? '切换模式会先暂停播放并停止当前 sidecar；Cookie / Credential '
                                '保存在各自数据目录，切回时自动恢复。'
                          : '本地与 Subsonic 模式不启动在线 sidecar。在线页面接入将在后续步骤完成。',
                      style: theme.typeScale.bodyMedium.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (mode.usesOnlineHost) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text('服务状态', style: theme.typeScale.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              _buildHostCard(theme, mode, host),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: M3EButton(
                      style: M3EButtonStyle.tonal,
                      label: Text(_busy ? '处理中…' : '启动'),
                      onPressed: _busy || host.isRunning ? null : _start,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: M3EButton(
                      style: M3EButtonStyle.outlined,
                      label: const Text('重启'),
                      onPressed: _busy || !host.isRunning
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await ref
                                    .read(modeHostProvider.notifier)
                                    .restart();
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: M3EButton(
                      style: M3EButtonStyle.outlined,
                      label: const Text('停止'),
                      onPressed: _busy || !host.isRunning
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await ref
                                    .read(modeHostProvider.notifier)
                                    .stop();
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            M3EList(
              color: scheme.surface,
              variant: M3ECardVariant.filled,
              itemCount: 4,
              itemBuilder: (BuildContext context, int index) {
                return switch (index) {
                  0 => const M3EListItem(
                    headline: '本地音乐',
                    supportingText: '扫描本地文件，不启动网络服务',
                    leading: Icon(M3EIcons.library_music),
                  ),
                  1 => const M3EListItem(
                    headline: 'Subsonic',
                    supportingText: '连接自建 Subsonic / Navidrome',
                    leading: Icon(M3EIcons.cloud),
                  ),
                  2 => const M3EListItem(
                    headline: 'QQ 音乐',
                    supportingText: 'laetibeat_qq_host · GPL-3.0 sidecar',
                    leading: Icon(M3EIcons.audiotrack),
                  ),
                  _ => const M3EListItem(
                    headline: '网易云音乐',
                    supportingText: 'laetibeat_netease_host · WTFPL sidecar',
                    leading: Icon(M3EIcons.album),
                  ),
                };
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostCard(M3EThemeData theme, AppMode mode, ModeHostState host) {
    final scheme = theme.colorScheme;
    final (
      IconData icon,
      Color background,
      Color foreground,
      String title,
    ) = switch (host.status) {
      ModeHostStatus.running => (
        M3EIcons.check_circle,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        '运行中',
      ),
      ModeHostStatus.starting => (
        M3EIcons.sync,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        '启动中',
      ),
      ModeHostStatus.error => (
        M3EIcons.error,
        scheme.errorContainer,
        scheme.onErrorContainer,
        '错误',
      ),
      ModeHostStatus.stopped => (
        M3EIcons.stop_circle,
        scheme.surfaceContainerHigh,
        scheme.onSurfaceVariant,
        '未启动',
      ),
    };
    final detail = host.error ?? host.baseUrl ?? '${mode.label} sidecar';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.lgAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: AppIconSize.md, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.typeScale.titleSmall.copyWith(color: foreground),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  detail,
                  style: theme.typeScale.bodyMedium.copyWith(color: foreground),
                ),
                if (host.pid != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'pid ${host.pid}',
                    style: theme.typeScale.bodySmall.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
