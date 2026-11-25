import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/netease.dart' as rust_netease;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../design/design.dart';
import '../../../../../widgets/settings/netease_settings.dart';
import '../../../widgets/mobile_large_subpage_app_bar.dart';

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
      final status = await rust_netease.neteaseStatus(baseUrl: raw);
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
                      '当前支持搜索、每日推荐和免费歌曲播放。登录、个人歌单与 VIP 完整音质尚未接入。',
                      style: theme.typeScale.bodyMedium.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
              onChanged: (bool value) {
                setState(() => _allowLxFallback = value);
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
