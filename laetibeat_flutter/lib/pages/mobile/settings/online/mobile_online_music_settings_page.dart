import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/online.dart' as rust_online;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_mode.dart';
import '../../../../design/design.dart';
import '../../../../widgets/settings/mode_host.dart';
import '../../../../widgets/settings/online_provider.dart';
import '../../../../widgets/settings/online_settings.dart';
import '../../mobile_navigation.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';
import '../mode/mobile_mode_settings_page.dart';
import 'mobile_online_login_page.dart';

/// 在线音源的账号、音质与 LX 后备设置。
///
/// 服务地址 / Token 由当前 `AppMode` 的本地 sidecar 自动管理，不再填写远程地址。
class MobileOnlineMusicSettingsPage extends ConsumerStatefulWidget {
  const MobileOnlineMusicSettingsPage({super.key});

  @override
  ConsumerState<MobileOnlineMusicSettingsPage> createState() =>
      _MobileOnlineMusicSettingsPageState();
}

class _MobileOnlineMusicSettingsPageState
    extends ConsumerState<MobileOnlineMusicSettingsPage> {
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
      name: 'online-login',
    );
    if (!mounted) return;
    ref.invalidate(onlinePlatformStatusesProvider);
    if (ok == true) {
      ref.invalidate(onlineUserPlaylistsProvider);
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
    final mode = ref.watch(appModeProvider);
    final host = ref.watch(modeHostProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: '在线音源'),
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
                      mode.usesOnlineHost
                          ? '当前模式：${mode.label}。服务地址与 Token 由本地 sidecar 自动管理，'
                                'Cookie 保存在模式数据目录。'
                          : '当前模式不启动在线 sidecar。切换到 QQ / 网易云后可登录账号。',
                      style: theme.typeScale.bodyMedium.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!mode.usesOnlineHost)
              M3EButton(
                style: M3EButtonStyle.filled,
                label: const Text('切换音源模式'),
                onPressed: () => pushMobileRootPage(
                  context,
                  const MobileModeSettingsPage(),
                  name: 'mode-settings',
                ),
              )
            else ...<Widget>[
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
                      onPressed: _busy || host.isRunning
                          ? null
                          : () => _run(
                              () => ref.read(modeHostProvider.notifier).start(),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: M3EButton(
                      style: M3EButtonStyle.outlined,
                      label: const Text('重启'),
                      onPressed: _busy || !host.isRunning
                          ? null
                          : () => _run(
                              () =>
                                  ref.read(modeHostProvider.notifier).restart(),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: M3EButton(
                      style: M3EButtonStyle.outlined,
                      label: const Text('停止'),
                      onPressed: _busy || !host.isRunning
                          ? null
                          : () => _run(
                              () => ref.read(modeHostProvider.notifier).stop(),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('账号', style: theme.typeScale.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              _buildAccountList(theme, mode, host),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('播放', style: theme.typeScale.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            M3EList(
              color: scheme.surface,
              variant: M3ECardVariant.filled,
              itemCount: 2,
              onTap: (int index) {
                if (index == 0) {
                  unawaited(_pickQuality());
                } else {
                  final value = !ref
                      .read(onlineSettingsProvider)
                      .allowLxFallback;
                  unawaited(
                    ref
                        .read(onlineSettingsProvider.notifier)
                        .setAllowLxFallback(value),
                  );
                }
              },
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return M3EListItem(
                    headline: '默认音质',
                    supportingText: _qualityLabel(
                      ref.watch(onlineSettingsProvider).defaultQuality,
                    ),
                    leading: const Icon(M3EIcons.graphic_eq),
                    trailing: const Icon(M3EIcons.chevron_right),
                  );
                }
                return M3EListItem(
                  headline: '洛雪后备',
                  supportingText: '无版权或试听时尝试用洛雪解析完整音源',
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
                );
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountList(
    M3EThemeData theme,
    AppMode mode,
    ModeHostState host,
  ) {
    final scheme = theme.colorScheme;
    final statuses = ref.watch(onlinePlatformStatusesProvider);
    final configured = host.isRunning;
    final sources = switch (mode) {
      AppMode.qq => const <(String, String)>[('qq', 'QQ 音乐')],
      AppMode.netease => const <(String, String)>[('netease', '网易云音乐')],
      _ => const <(String, String)>[],
    };
    if (!configured) {
      return Text(
        '启动 ${mode.label} sidecar 后可登录账号。',
        style: theme.typeScale.bodyMedium.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return M3EList(
      color: scheme.surface,
      variant: M3ECardVariant.filled,
      itemCount: sources.length,
      itemBuilder: (BuildContext context, int index) {
        final (source, label) = sources[index];
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
        return M3EListItem(
          headline: label,
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
                    source == 'netease'
                        ? _openLogin('netease')
                        : _openQqLogin(),
                  ),
          ),
        );
      },
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
