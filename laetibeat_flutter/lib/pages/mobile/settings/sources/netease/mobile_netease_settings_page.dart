import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/netease.dart' as rust_netease;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../design/design.dart';
import '../../../../../widgets/settings/netease_provider.dart';
import '../../../../../widgets/settings/netease_session.dart';
import '../../../../../widgets/settings/netease_settings.dart';
import '../../../mobile_navigation.dart';
import '../../../routes.dart';
import '../../../widgets/mobile_large_subpage_app_bar.dart';
import 'mobile_netease_login_page.dart';

/// 网易云在线音源配置页。
///
/// 当前只保存 API 服务地址和洛雪后备开关，真实 API 尚未接入。
class MobileNeteaseSettingsPage extends ConsumerStatefulWidget {
  const MobileNeteaseSettingsPage({super.key});

  @override
  ConsumerState<MobileNeteaseSettingsPage> createState() =>
      _MobileNeteaseSettingsPageState();
}

class _MobileNeteaseSettingsPageState
    extends ConsumerState<MobileNeteaseSettingsPage> {
  late final TextEditingController _urlController;
  late bool _allowLxFallback;
  bool _saving = false;
  bool _testing = false;
  String? _statusText;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(neteaseSettingsProvider);
    _urlController = TextEditingController(text: settings.apiBaseUrl);
    _allowLxFallback = settings.allowLxFallback;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _urlController.text.trim();
    if (raw.isNotEmpty) {
      final uri = Uri.tryParse(raw);
      if (uri == null ||
          uri.host.isEmpty ||
          !(uri.scheme == 'http' || uri.scheme == 'https')) {
        M3ESnackbar.show(context, message: '请输入有效的 API 地址（http/https）');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(neteaseSettingsProvider.notifier)
          .save(apiBaseUrl: raw, allowLxFallback: _allowLxFallback);
      ref.invalidate(neteaseStatusProvider);
      ref.invalidate(neteaseDailyProvider);
      if (!mounted) return;
      M3ESnackbar.show(context, message: '已保存');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _testConnection() async {
    final raw = normalizeNeteaseBaseUrl(_urlController.text);
    final uri = Uri.tryParse(raw);
    if (raw.isEmpty ||
        uri == null ||
        uri.host.isEmpty ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      M3ESnackbar.show(context, message: '请先填写有效的 API 地址');
      return;
    }

    setState(() {
      _testing = true;
      _statusText = '正在连接…';
      _statusIsError = false;
    });
    try {
      final cookie = await ref.read(neteaseCookieProvider.future);
      final status = await rust_netease.neteaseStatus(
        baseUrl: raw,
        cookie: cookie,
      );
      if (!mounted) return;
      setState(() {
        _statusText = status.loggedIn
            ? '连接成功，已登录：${status.nickname ?? status.userId ?? ''}'
            : '连接成功，当前未登录';
        _statusIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusText = '连接失败：$error';
        _statusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _openLogin() async {
    await pushMobileRootPage<bool>(
      context,
      const MobileNeteaseLoginPage(),
      name: MobileRoutes.neteaseLogin,
    );
    ref.invalidate(neteaseStatusProvider);
    ref.invalidate(neteaseDailyProvider);
  }

  Future<void> _logout() async {
    await ref.read(neteaseCookieProvider.notifier).clear();
    ref.invalidate(neteaseStatusProvider);
    ref.invalidate(neteaseDailyProvider);
    if (!mounted) return;
    M3ESnackbar.show(context, message: '已退出网易云');
  }

  Widget _buildAccountCard(M3EThemeData theme) {
    final scheme = theme.colorScheme;
    final cookie = ref.watch(neteaseCookieProvider);
    final status = ref.watch(neteaseStatusProvider);
    final loggedIn = cookie.value != null;
    final nickname = status.value?.nickname;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadii.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                loggedIn ? M3EIcons.account_circle : M3EIcons.login,
                size: AppIconSize.lg,
                color: loggedIn ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      loggedIn ? (nickname ?? '网易云账号') : '未登录网易云',
                      style: theme.typeScale.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loggedIn
                          ? (status.isLoading
                                ? '正在获取账号信息…'
                                : '已登录，可使用个人歌单和会员音质')
                          : '登录后可获取个人歌单、个性化日推和会员完整音质',
                      style: theme.typeScale.bodySmall.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: M3EButton(
              style: M3EButtonStyle.tonal,
              label: Text(loggedIn ? '退出登录' : '登录'),
              onPressed: loggedIn ? _logout : _openLogin,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: '网易云音乐'),
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
                      '支持二维码与手机验证码登录。登录后每日推荐、播放 URL 会自动携带 Cookie。',
                      style: theme.typeScale.bodyMedium.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildAccountCard(theme),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'API 服务地址',
                hintText: 'https://xxx.vercel.app 或 https://ncm.example.com',
                helperText: '支持 Vercel / VPS / NAS 部署的 API 地址',
                prefixIcon: Icon(M3EIcons.link),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('允许洛雪作为后备解析'),
              subtitle: const Text('网易云直连失败时，尝试已启用的洛雪 wy 音源'),
              value: _allowLxFallback,
              onChanged: (bool value) async {
                setState(() => _allowLxFallback = value);
                await ref
                    .read(neteaseSettingsProvider.notifier)
                    .setAllowLxFallback(value);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: M3EButton(
                    style: M3EButtonStyle.tonal,
                    label: Text(_testing ? '测试中…' : '测试连接'),
                    enabled: !_testing,
                    onPressed: _testConnection,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: M3EButton(
                    label: Text(_saving ? '保存中…' : '保存'),
                    enabled: !_saving,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
            if (_statusText != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: _statusIsError
                      ? scheme.errorContainer
                      : scheme.secondaryContainer,
                  borderRadius: AppRadii.lgAll,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      _statusIsError ? M3EIcons.error : M3EIcons.check_circle,
                      size: AppIconSize.md,
                      color: _statusIsError
                          ? scheme.onErrorContainer
                          : scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _statusText!,
                        style: theme.typeScale.bodyMedium.copyWith(
                          color: _statusIsError
                              ? scheme.onErrorContainer
                              : scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
