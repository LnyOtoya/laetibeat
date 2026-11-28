import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:laetibeat/src/rust/api/online.dart' as rust_online;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_mode.dart';
import '../../../../design/design.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../widgets/settings/mode_host.dart';
import '../../../../widgets/settings/online_provider.dart';
import '../../../../widgets/settings/online_settings.dart';
import '../../routes.dart';
import '../../mobile_navigation.dart';
import '../mobile_settings_section.dart';
import 'mobile_music_sources_page.dart';
import '../online/mobile_online_login_page.dart';

/// 移动端音源模式、账号与在线播放设置。
///
/// 服务地址 / Token 由当前 `AppMode` 的本地 sidecar 自动管理，不再填写远程地址。
class MobileSourceSettingsPage extends ConsumerStatefulWidget {
  const MobileSourceSettingsPage({super.key});

  @override
  ConsumerState<MobileSourceSettingsPage> createState() =>
      _MobileSourceSettingsPageState();
}

class _MobileSourceSettingsPageState extends ConsumerState<MobileSourceSettingsPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchMode(AppMode nextMode) async {
    if (_busy || nextMode == ref.read(appModeProvider)) return;
    try {
      await _run(
        () => ref.read(modeHostProvider.notifier).switchTo(nextMode),
      );
      if (!mounted) return;
      final host = ref.read(modeHostProvider);
      if (host.hasError) {
        M3ESnackbar.show(context, message: host.error ?? '音源服务启动失败');
      }
      ref.invalidate(onlinePlatformStatusesProvider);
    } catch (error) {
      if (mounted) {
        M3ESnackbar.show(context, message: '切换音源失败：$error');
      }
    }
  }

  Future<void> _runHostAction(Future<void> Function() action) async {
    try {
      await _run(action);
      if (!mounted) return;
      final host = ref.read(modeHostProvider);
      if (host.hasError) {
        M3ESnackbar.show(context, message: host.error ?? '音源服务操作失败');
      }
    } catch (error) {
      if (mounted) {
        M3ESnackbar.show(context, message: '音源服务操作失败：$error');
      }
    }
  }

  Future<void> _pickQuality() async {
    const labels = <String, String>{
      '自动': 'auto',
      '标准 128k': 'standard',
      '高品质 320k': 'high',
      '无损': 'lossless',
      'Hi-Res': 'hires',
      '母带': 'master',
    };
    final current = ref.read(onlineSettingsProvider).defaultQuality;
    String? selected;
    for (final entry in labels.entries) {
      if (entry.value == current) {
        selected = entry.key;
        break;
      }
    }
    final picked = await M3EDialog.showSelectionScreen(
      context,
      title: '默认音质',
      options: labels.keys.toList(growable: false),
      initialSelection: <String>[if (selected != null) selected],
      icon: const Icon(M3EIcons.graphic_eq),
    );
    if (picked == null || picked.isEmpty) return;
    final value = labels[picked.first];
    if (value == null) return;
    await ref.read(onlineSettingsProvider.notifier).setDefaultQuality(value);
  }

  Future<void> _openLogin(String source) async {
    final ok = await pushMobileRootPage<bool>(
      context,
      MobileOnlineLoginPage(source: source),
      name: MobileRoutes.onlineLogin,
    );
    if (!mounted) return;
    ref.invalidate(onlinePlatformStatusesProvider);
    if (ok == true) {
      ref.invalidate(onlineUserPlaylistsProvider);
      ref.invalidate(onlineUserProfileProvider);
      M3ESnackbar.show(context, message: '登录成功');
    }
  }

  Future<void> _openQqLogin() async {
    final picked = await M3EDialog.showSelectionScreen(
      context,
      title: 'QQ 登录方式',
      options: const <String>['QQ 扫码', '微信扫码'],
      icon: const Icon(M3EIcons.login),
    );
    if (picked == null || picked.isEmpty) return;
    await _openLogin(picked.first == '微信扫码' ? 'qq_wx' : 'qq');
  }

  Future<void> _logout(String source) async {
    final baseUrl = ref.read(onlineBaseUrlProvider);
    if (baseUrl.isEmpty) return;
    try {
      final token = await ref.read(onlineTokenProvider.future);
      await rust_online.onlineLogout(
        baseUrl: baseUrl,
        token: token,
        source: source,
      );
      ref.invalidate(onlinePlatformStatusesProvider);
      ref.invalidate(onlineUserPlaylistsProvider);
      ref.invalidate(onlineUserProfileProvider);
      if (mounted) {
        M3ESnackbar.show(context, message: '已退出登录');
      }
    } catch (error) {
      if (mounted) {
        M3ESnackbar.show(context, message: '退出失败：$error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(appModeProvider);
    final host = ref.watch(modeHostProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppPageBar.settings(
        title: l10n.settingsSourcesAccounts,
        backgroundColor: scheme.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            MobileSettingsSection(
              title: '当前音源',
              selectionMode: m3e_core.M3ESelectionMode.single,
              selectedIndices: <int>{AppMode.values.indexOf(mode)},
              showSelectionCheckmark: true,
              isEnabled: (_) => !_busy,
              onSelectionChanged: (indices) {
                if (indices.isNotEmpty) {
                  unawaited(_switchMode(AppMode.values[indices.first]));
                }
              },
              children: [
                for (final option in AppMode.values)
                  MobileSettingsRow(
                    title: option.label,
                    supportingText: switch (option) {
                      AppMode.local => '播放设备上的本地音乐',
                      AppMode.subsonic => '连接 Subsonic 或 Navidrome 服务',
                      AppMode.qq => '使用 QQ 音乐账号与在线曲库',
                      AppMode.netease => '使用网易云音乐账号与在线曲库',
                    },
                    leading: Icon(switch (option) {
                      AppMode.local => M3EIcons.library_music,
                      AppMode.subsonic => M3EIcons.cloud,
                      AppMode.qq => M3EIcons.audiotrack,
                      AppMode.netease => M3EIcons.album,
                    }),
                    enabled: !_busy,
                  ),
              ],
            ),
            const SizedBox(height: 24),
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
                          ? '切换模式会先暂停播放并停止当前在线服务；各模式的登录信息分别保存。'
                          : mode == AppMode.subsonic
                          ? 'Subsonic 服务连接信息可在下方来源管理中配置。'
                          : '本地模式不会启动在线服务。',
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
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  M3EButton(
                    style: M3EButtonStyle.tonal,
                    label: Text(_busy ? '处理中…' : '启动'),
                    onPressed: _busy || host.isRunning
                        ? null
                        : () => _runHostAction(
                            () => ref.read(modeHostProvider.notifier).start(),
                          ),
                  ),
                  M3EButton(
                    style: M3EButtonStyle.outlined,
                    label: const Text('重启'),
                    onPressed: _busy || !host.isRunning
                        ? null
                        : () => _runHostAction(
                            () =>
                                ref.read(modeHostProvider.notifier).restart(),
                          ),
                  ),
                  M3EButton(
                    style: M3EButtonStyle.outlined,
                    label: const Text('停止'),
                    onPressed: _busy || !host.isRunning
                        ? null
                        : () => _runHostAction(
                            () => ref.read(modeHostProvider.notifier).stop(),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildAccountList(mode, host),
              const SizedBox(height: AppSpacing.lg),
              MobileSettingsSection(
                title: '在线播放',
                onTap: (index) {
                  if (index == 0) unawaited(_pickQuality());
                },
                children: [
                  MobileSettingsRow(
                    title: '默认音质',
                    supportingText: _qualityLabel(
                      ref.watch(onlineSettingsProvider).defaultQuality,
                    ),
                    leading: const Icon(M3EIcons.graphic_eq),
                    trailing: const Icon(M3EIcons.chevron_right),
                  ),
                  MobileSettingsRow(
                    title: '洛雪后备',
                    supportingText: '无版权或试听时尝试使用洛雪解析完整音源',
                    leading: const Icon(M3EIcons.extension),
                    trailing: M3ESwitch(
                      value: ref.watch(onlineAllowLxFallbackProvider),
                      onChanged: (bool value) {
                        unawaited(
                          ref
                              .read(onlineSettingsProvider.notifier)
                              .setAllowLxFallback(value),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            MobileSettingsSection(
              title: '更多来源',
              onTap: (_) => pushMobileRootPage(
                context,
                const MobileMusicSourcesPage(),
                name: MobileRoutes.musicSources,
              ),
              children: const [
                MobileSettingsRow(
                  title: '来源管理',
                  supportingText: '配置 Subsonic 服务器与洛雪解析源',
                  leading: Icon(M3EIcons.settings),
                  trailing: Icon(M3EIcons.chevron_right),
                ),
              ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountList(AppMode mode, ModeHostState host) {
    final statuses = ref.watch(onlinePlatformStatusesProvider);
    final configured = host.isRunning;
    final sources = switch (mode) {
      AppMode.qq => const <(String, String)>[('qq', 'QQ 音乐')],
      AppMode.netease => const <(String, String)>[('netease', '网易云音乐')],
      _ => const <(String, String)>[],
    };
    if (sources.isEmpty) return const SizedBox.shrink();
    if (!configured) {
      return MobileSettingsSection(
        title: '账号',
        children: [
          MobileSettingsRow(
            title: mode.label,
            supportingText: '启动在线服务后即可登录账号',
            leading: Icon(
              mode == AppMode.netease ? M3EIcons.music_note : M3EIcons.forum,
            ),
            enabled: false,
          ),
        ],
      );
    }
    return MobileSettingsSection(
      title: '账号',
      children: [
        for (final (source, label) in sources)
          _buildAccountRow(source, label, statuses),
      ],
    );
  }

  Widget _buildAccountRow(
    String source,
    String label,
    AsyncValue<List<rust_online.UiOnlinePlatformStatus>> statuses,
  ) {
    final hasCookie =
        statuses.value?.any(
          (status) => status.source == source && status.hasCookie,
        ) ??
        false;
    final statusText = statuses.isLoading
        ? '读取中…'
        : statuses.hasError
        ? '状态不可用'
        : hasCookie
        ? '已登录'
        : '未登录';
    return MobileSettingsRow(
      title: label,
      supportingText: statusText,
      leading: Icon(
        source == 'netease' ? M3EIcons.music_note : M3EIcons.forum,
      ),
      trailing: M3EButton(
        style: M3EButtonStyle.tonal,
        size: M3EButtonSize.sm,
        label: Text(hasCookie ? '退出' : '登录'),
        onPressed: hasCookie
            ? () => unawaited(_logout(source))
            : () => unawaited(
                source == 'netease' ? _openLogin('netease') : _openQqLogin(),
              ),
      ),
    );
  }

  String _qualityLabel(String value) {
    return switch (value) {
      'auto' => '自动',
      'standard' => '标准 128k',
      'high' => '高品质 320k',
      'lossless' => '无损',
      'hires' => 'Hi-Res',
      'master' => '母带',
      _ => value,
    };
  }
}
