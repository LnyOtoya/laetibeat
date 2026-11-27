import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/online.dart' as rust_online;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_mode.dart';
import '../../../../design/design.dart';
import '../../../../widgets/settings/online_host.dart';
import '../../../../widgets/settings/online_provider.dart';
import '../../../../widgets/settings/online_settings.dart';
import '../../mobile_navigation.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';
import 'mobile_online_login_page.dart';

/// 在线音源服务配置。
///
/// 当前版本先支持填写远程/本机 go-music-api 地址；内置进程启动在后续版本接入。
class MobileOnlineMusicSettingsPage extends ConsumerStatefulWidget {
  const MobileOnlineMusicSettingsPage({super.key});

  @override
  ConsumerState<MobileOnlineMusicSettingsPage> createState() =>
      _MobileOnlineMusicSettingsPageState();
}

class _MobileOnlineMusicSettingsPageState
    extends ConsumerState<MobileOnlineMusicSettingsPage> {
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  OnlineMode _mode = OnlineMode.remote;
  bool _allowLxFallback = false;
  String _quality = kOnlineDefaultQuality;
  bool _saving = false;
  bool _testing = false;
  String? _statusText;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(onlineSettingsProvider);
    final supported = ref.read(onlineHostProvider.notifier).supported;
    _mode = supported ? settings.mode : OnlineMode.remote;
    if (!supported && settings.mode == OnlineMode.builtin) {
      unawaited(
        ref.read(onlineSettingsProvider.notifier).setMode(OnlineMode.remote),
      );
    }
    _baseUrlController.text = settings.baseUrl;
    _allowLxFallback = settings.allowLxFallback;
    _quality = settings.defaultQuality;
    unawaited(_loadToken());
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    try {
      final token = await ref.read(onlineTokenProvider.future);
      if (!mounted) return;
      _tokenController.text = token ?? '';
    } catch (error) {
      debugPrint('读取在线音源 token 失败: $error');
    }
  }

  Future<void> _save() async {
    final raw = normalizeOnlineBaseUrl(_baseUrlController.text);
    if (raw.isNotEmpty && !isValidOnlineBaseUrl(raw)) {
      M3ESnackbar.show(
        context,
        message: '地址无效：远程必须使用 https，只有 127.0.0.1/localhost 允许 http',
      );
      return;
    }

    setState(() {
      _saving = true;
      _mode = OnlineMode.remote;
    });
    try {
      await ref
          .read(onlineSettingsProvider.notifier)
          .save(
            baseUrl: raw,
            allowLxFallback: _allowLxFallback,
            defaultQuality: _quality,
          );
      await ref.read(onlineTokenProvider.notifier).save(_tokenController.text);
      ref.invalidate(onlineStatusProvider);
      if (!mounted) return;
      M3ESnackbar.show(context, message: '已保存');
    } catch (error) {
      if (mounted) {
        M3ESnackbar.show(context, message: '保存失败：$error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    final raw = normalizeOnlineBaseUrl(_baseUrlController.text);
    if (raw.isEmpty || !isValidOnlineBaseUrl(raw)) {
      M3ESnackbar.show(context, message: '请先填写有效的服务地址');
      return;
    }

    setState(() {
      _testing = true;
      _statusText = '正在连接…';
      _statusIsError = false;
    });
    try {
      final token = _tokenController.text.trim();
      final status = await rust_online.onlineHealth(
        baseUrl: raw,
        token: token.isEmpty ? null : token,
      );
      if (!mounted) return;
      setState(() {
        _statusText = '连接成功：${status.baseUrl}';
        _statusIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusText = '连接失败：$error';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
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
    String? current;
    for (final entry in labels.entries) {
      if (entry.value == _quality) {
        current = entry.key;
        break;
      }
    }
    final picked = await M3EDialog.showSelectionScreen(
      context,
      title: '默认音质',
      options: labels.keys.toList(growable: false),
      initialSelection: <String>[if (current != null) current],
      icon: const Icon(M3EIcons.graphic_eq),
    );
    if (picked == null || picked.isEmpty) return;
    final value = labels[picked.first];
    if (value == null) return;
    setState(() => _quality = value);
    await ref.read(onlineSettingsProvider.notifier).setDefaultQuality(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: '在线音乐'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            _buildModeSelector(theme),
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
                      _mode == OnlineMode.builtin
                          ? '内置服务随 App 启动，无需额外部署。首次使用可能需要几秒启动时间；Cookie 保存在应用私有目录。'
                          : '远程地址必须使用 https；本机 127.0.0.1/localhost 允许 http。',
                      style: theme.typeScale.bodyMedium.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_mode == OnlineMode.builtin) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _buildBuiltinStatus(theme),
            ] else ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              M3ETextField(
                controller: _baseUrlController,
                variant: M3ETextFieldVariant.filled,
                label: '服务地址',
                supportingText:
                    '例如 https://music.example.com 或 http://127.0.0.1:33531',
                supportingTextOnFocusOnly: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                placeholder: 'https://music.example.com',
                onChanged: (_) {
                  if (_statusText != null) {
                    setState(() {
                      _statusText = null;
                      _statusIsError = false;
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              M3ETextField(
                controller: _tokenController,
                variant: M3ETextFieldVariant.filled,
                label: '访问 Token',
                supportingText: '对应 host 的 LAETIBEAT_MUSICAPI_TOKEN，可留空',
                supportingTextOnFocusOnly: false,
                obscureText: true,
                showPasswordToggle: true,
                textInputAction: TextInputAction.done,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            M3EList(
              color: scheme.surface,
              variant: M3ECardVariant.filled,
              itemCount: 2,
              onTap: (int index) {
                if (index == 0) {
                  unawaited(_pickQuality());
                } else {
                  setState(() => _allowLxFallback = !_allowLxFallback);
                  unawaited(
                    ref
                        .read(onlineSettingsProvider.notifier)
                        .setAllowLxFallback(_allowLxFallback),
                  );
                }
              },
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return M3EListItem(
                    headline: '默认音质',
                    supportingText: _qualityLabel(_quality),
                    leading: const Icon(M3EIcons.graphic_eq),
                    trailing: const Icon(M3EIcons.chevron_right),
                  );
                }
                return M3EListItem(
                  headline: '洛雪后备',
                  supportingText: '无版权或试听时尝试用洛雪解析完整音源',
                  leading: const Icon(M3EIcons.extension),
                  trailing: M3ESwitch(
                    value: _allowLxFallback,
                    onChanged: (bool value) {
                      setState(() => _allowLxFallback = value);
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
            const SizedBox(height: AppSpacing.lg),
            Text('账号', style: theme.typeScale.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            _buildAccountList(theme),
            if (_mode == OnlineMode.remote) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: M3EButton(
                      style: M3EButtonStyle.tonal,
                      label: Text(_testing ? '测试中…' : '测试连接'),
                      onPressed: _testing ? null : _testConnection,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: M3EButton(
                      style: M3EButtonStyle.filled,
                      label: Text(_saving ? '保存中…' : '保存'),
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ],
              ),
            ],
            if (_statusText != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: _statusIsError
                      ? scheme.errorContainer
                      : scheme.tertiaryContainer,
                  borderRadius: AppRadii.mdAll,
                ),
                child: Text(
                  _statusText!,
                  style: theme.typeScale.bodyMedium.copyWith(
                    color: _statusIsError
                        ? scheme.onErrorContainer
                        : scheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(M3EThemeData theme) {
    if (!ref.read(onlineHostProvider.notifier).supported) {
      return Text(
        '当前平台仅支持远程服务',
        style: theme.typeScale.bodyMedium.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('服务模式', style: theme.typeScale.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        M3ESegmentedButton<OnlineMode>(
          segments: const <M3ESegment<OnlineMode>>[
            M3ESegment(value: OnlineMode.builtin, label: '内置服务'),
            M3ESegment(value: OnlineMode.remote, label: '远程服务'),
          ],
          selected: <OnlineMode>{_mode},
          onSelectionChanged: (Set<OnlineMode> values) {
            unawaited(_changeMode(values.first));
          },
        ),
      ],
    );
  }

  Widget _buildBuiltinStatus(M3EThemeData theme) {
    final host = ref.watch(onlineHostProvider);
    final scheme = theme.colorScheme;
    final (
      IconData icon,
      String title,
      String? detail,
      Color background,
    ) = switch (host.status) {
      OnlineHostStatus.running => (
        M3EIcons.check_circle,
        '内置服务运行中',
        host.baseUrl,
        scheme.tertiaryContainer,
      ),
      OnlineHostStatus.starting => (
        M3EIcons.hourglass_top,
        '正在启动内置服务…',
        null,
        scheme.secondaryContainer,
      ),
      OnlineHostStatus.error => (
        M3EIcons.error_outline,
        '内置服务启动失败',
        host.error,
        scheme.errorContainer,
      ),
      OnlineHostStatus.stopped => (
        M3EIcons.cloud_off,
        '内置服务未启动',
        '点击启动，或回到发现页自动启动。',
        scheme.surfaceContainerHighest,
      ),
    };
    final foreground = host.status == OnlineHostStatus.error
        ? scheme.onErrorContainer
        : scheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: AppIconSize.md, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.typeScale.titleSmall.copyWith(color: foreground),
                ),
              ),
              M3EButton(
                style: M3EButtonStyle.tonal,
                size: M3EButtonSize.sm,
                label: Text(host.isRunning ? '重启' : '启动'),
                onPressed: host.isStarting
                    ? null
                    : () => unawaited(
                        host.isRunning ? _restartBuiltin() : _startBuiltin(),
                      ),
              ),
            ],
          ),
          if (detail != null && detail.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              detail,
              style: theme.typeScale.bodySmall.copyWith(
                color: foreground.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _changeMode(OnlineMode mode) async {
    if (_mode == mode) return;
    if (mode == OnlineMode.builtin &&
        !ref.read(onlineHostProvider.notifier).supported) {
      M3ESnackbar.show(context, message: '当前平台仅支持远程服务');
      return;
    }
    setState(() {
      _mode = mode;
      _statusText = null;
      _statusIsError = false;
    });
    await ref.read(onlineSettingsProvider.notifier).setMode(mode);
    if (mode == OnlineMode.builtin) {
      await ref.read(onlineHostProvider.notifier).startIfNeeded();
    } else {
      await ref.read(onlineHostProvider.notifier).stop();
    }
    ref.invalidate(onlineStatusProvider);
    ref.invalidate(onlinePlatformStatusesProvider);
  }

  Future<void> _startBuiltin() async {
    await ref.read(onlineHostProvider.notifier).start();
    ref.invalidate(onlineStatusProvider);
    ref.invalidate(onlinePlatformStatusesProvider);
  }

  Future<void> _restartBuiltin() async {
    await ref.read(onlineHostProvider.notifier).restart();
    ref.invalidate(onlineStatusProvider);
    ref.invalidate(onlinePlatformStatusesProvider);
  }

  Widget _buildAccountList(M3EThemeData theme) {
    final scheme = theme.colorScheme;
    final statuses = ref.watch(onlinePlatformStatusesProvider);
    final host = ref.watch(onlineHostProvider);
    final configured = _mode == OnlineMode.builtin
        ? host.isRunning
        : ref.watch(onlineBaseUrlProvider).isNotEmpty;
    final appMode = ref.watch(appModeProvider);
    final sources = switch (appMode) {
      AppMode.qq => const <(String, String)>[('qq', 'QQ 音乐')],
      AppMode.netease => const <(String, String)>[('netease', '网易云音乐')],
      _ => const <(String, String)>[('netease', '网易云音乐'), ('qq', 'QQ 音乐')],
    };

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
        final statusText = !configured
            ? '未配置服务'
            : statuses.isLoading
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
            onPressed: !configured
                ? null
                : hasCookie
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
