import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/netease.dart' as rust_netease;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../design/design.dart';
import '../../../../../widgets/settings/netease_provider.dart';
import '../../../../../widgets/settings/netease_session.dart';
import '../../../widgets/mobile_large_subpage_app_bar.dart';

enum _NeteaseLoginMode { qr, phone }

class MobileNeteaseLoginPage extends ConsumerStatefulWidget {
  const MobileNeteaseLoginPage({super.key});

  @override
  ConsumerState<MobileNeteaseLoginPage> createState() =>
      _MobileNeteaseLoginPageState();
}

class _MobileNeteaseLoginPageState
    extends ConsumerState<MobileNeteaseLoginPage> {
  _NeteaseLoginMode _mode = _NeteaseLoginMode.qr;

  rust_netease.UiNeteaseQrCode? _qr;
  bool _qrLoading = false;
  String? _qrError;
  String? _qrMessage;
  Timer? _qrPollTimer;
  bool _qrLoggedIn = false;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _captchaController = TextEditingController();
  bool _sendingCaptcha = false;
  bool _loggingIn = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshQr());
    });
  }

  @override
  void dispose() {
    _qrPollTimer?.cancel();
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  String? get _baseUrl {
    final value = ref.read(neteaseBaseUrlProvider);
    return value.isEmpty ? null : value;
  }

  Future<void> _refreshQr() async {
    final baseUrl = _baseUrl;
    if (baseUrl == null) {
      setState(() => _qrError = '请先在上一页保存网易云 API 地址');
      return;
    }
    _qrPollTimer?.cancel();
    setState(() {
      _qrLoading = true;
      _qrError = null;
      _qrMessage = null;
      _qrLoggedIn = false;
    });
    try {
      final qr = await rust_netease.neteaseQrCreate(baseUrl: baseUrl);
      if (!mounted) return;
      setState(() {
        _qr = qr;
        _qrLoading = false;
        _qrMessage = '请使用网易云音乐 App 扫码';
      });
      _startQrPolling(qr.key);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _qrLoading = false;
        _qrError = '$error';
      });
    }
  }

  void _startQrPolling(String key) {
    _qrPollTimer?.cancel();
    _qrPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollQr(key));
    });
  }

  Future<void> _pollQr(String key) async {
    if (!mounted || _qrLoggedIn) return;
    final baseUrl = _baseUrl;
    if (baseUrl == null) return;
    try {
      final check = await rust_netease.neteaseQrCheck(
        baseUrl: baseUrl,
        key: key,
      );
      if (!mounted || _qrLoggedIn) return;
      setState(() => _qrMessage = check.message);
      if (check.code == 803 && check.cookie != null) {
        _qrLoggedIn = true;
        _qrPollTimer?.cancel();
        await _completeLogin(check.cookie!);
      } else if (check.code == 800) {
        _qrPollTimer?.cancel();
        setState(() => _qrError = '二维码已过期，请刷新后重试');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _qrMessage = '查询登录状态失败：$error');
    }
  }

  Future<void> _sendCaptcha() async {
    final baseUrl = _baseUrl;
    final phone = _phoneController.text.trim();
    if (baseUrl == null) {
      M3ESnackbar.show(context, message: '请先保存网易云 API 地址');
      return;
    }
    if (phone.isEmpty) {
      M3ESnackbar.show(context, message: '请输入手机号');
      return;
    }

    setState(() => _sendingCaptcha = true);
    try {
      final result = await rust_netease.neteaseSendCaptcha(
        baseUrl: baseUrl,
        phone: phone,
      );
      if (!mounted) return;
      M3ESnackbar.show(
        context,
        message: result.message.isEmpty ? '验证码已发送' : result.message,
      );
      if (result.code == 200) {
        _startCountdown();
      }
    } catch (error) {
      if (!mounted) return;
      M3ESnackbar.show(context, message: '发送失败：$error');
    } finally {
      if (mounted) setState(() => _sendingCaptcha = false);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdown -= 1;
        if (_countdown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _loginWithCaptcha() async {
    final baseUrl = _baseUrl;
    final phone = _phoneController.text.trim();
    final captcha = _captchaController.text.trim();
    if (baseUrl == null) {
      M3ESnackbar.show(context, message: '请先保存网易云 API 地址');
      return;
    }
    if (phone.isEmpty || captcha.isEmpty) {
      M3ESnackbar.show(context, message: '请输入手机号和验证码');
      return;
    }

    setState(() => _loggingIn = true);
    try {
      final result = await rust_netease.neteaseLoginCellphone(
        baseUrl: baseUrl,
        phone: phone,
        captcha: captcha,
      );
      await _completeLogin(result.cookie);
    } catch (error) {
      if (!mounted) return;
      M3ESnackbar.show(context, message: '登录失败：$error');
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  Future<void> _completeLogin(String cookie) async {
    await ref.read(neteaseCookieProvider.notifier).save(cookie);
    ref.invalidate(neteaseStatusProvider);
    ref.invalidate(neteaseDailyProvider);
    if (!mounted) return;
    M3ESnackbar.show(context, message: '网易云登录成功');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: '登录网易云'),
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
              child: Text(
                '登录后可使用个人歌单、个性化每日推荐和会员音质。验证码登录请勿频繁请求。',
                style: theme.typeScale.bodyMedium.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            M3ESegmentedButton<_NeteaseLoginMode>(
              segments: const <M3ESegment<_NeteaseLoginMode>>[
                M3ESegment(value: _NeteaseLoginMode.qr, label: '二维码'),
                M3ESegment(value: _NeteaseLoginMode.phone, label: '手机验证码'),
              ],
              selected: <_NeteaseLoginMode>{_mode},
              onSelectionChanged: (value) {
                final mode = value.first;
                if (mode == _mode) return;
                setState(() => _mode = mode);
                if (mode == _NeteaseLoginMode.qr) {
                  unawaited(_refreshQr());
                } else {
                  _qrPollTimer?.cancel();
                }
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_mode == _NeteaseLoginMode.qr)
              _buildQr(theme)
            else
              _buildPhone(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildQr(M3EThemeData theme) {
    if (_qrLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_qrError != null) {
      return Column(
        children: <Widget>[
          _StatusCard(message: _qrError!, isError: true),
          const SizedBox(height: AppSpacing.md),
          M3EButton(
            style: M3EButtonStyle.tonal,
            label: const Text('刷新二维码'),
            onPressed: _refreshQr,
          ),
        ],
      );
    }
    final qr = _qr;
    if (qr == null) return const SizedBox.shrink();

    final bytes = _decodeQrImage(qr.qrImageBase64);
    return Column(
      children: <Widget>[
        if (bytes != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadii.lgAll,
            ),
            child: Image.memory(
              bytes,
              width: 220,
              height: 220,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _qrMessage ?? '请使用网易云音乐 App 扫码',
          textAlign: TextAlign.center,
          style: theme.typeScale.bodyMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SelectableText(
          qr.qrUrl,
          textAlign: TextAlign.center,
          style: theme.typeScale.bodySmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        M3EButton(
          style: M3EButtonStyle.tonal,
          label: const Text('刷新二维码'),
          onPressed: _refreshQr,
        ),
      ],
    );
  }

  Widget _buildPhone(M3EThemeData theme) {
    final canSend = !_sendingCaptcha && _countdown == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        M3ETextField(
          controller: _phoneController,
          label: '手机号',
          placeholder: '请输入网易云绑定手机号',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: M3ETextField(
                controller: _captchaController,
                label: '验证码',
                placeholder: '请输入短信验证码',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            M3EButton(
              style: M3EButtonStyle.tonal,
              label: Text(
                _sendingCaptcha
                    ? '发送中…'
                    : _countdown > 0
                    ? '${_countdown}s'
                    : '发送验证码',
              ),
              enabled: canSend,
              onPressed: _sendCaptcha,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        M3EButton(
          label: Text(_loggingIn ? '登录中…' : '登录'),
          enabled: !_loggingIn,
          onPressed: _loginWithCaptcha,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '验证码登录可能触发网易云风控，请不要连续重复请求。',
          style: theme.typeScale.bodySmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Uint8List? _decodeQrImage(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final comma = raw.indexOf(',');
    final payload = comma >= 0 ? raw.substring(comma + 1) : raw;
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isError ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: AppRadii.lgAll,
      ),
      child: Text(
        message,
        style: theme.typeScale.bodyMedium.copyWith(
          color: isError
              ? scheme.onErrorContainer
              : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
