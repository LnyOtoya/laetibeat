import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/online.dart' as rust_online;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../design/design.dart';
import '../../../../widgets/settings/online_provider.dart';
import '../../../../widgets/settings/online_settings.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';

/// 通用扫码登录页，支持 netease / qq / qq_wx。
class MobileOnlineLoginPage extends ConsumerStatefulWidget {
  const MobileOnlineLoginPage({super.key, required this.source});

  final String source;

  @override
  ConsumerState<MobileOnlineLoginPage> createState() =>
      _MobileOnlineLoginPageState();
}

class _MobileOnlineLoginPageState extends ConsumerState<MobileOnlineLoginPage> {
  rust_online.UiOnlineQrSession? _session;
  Timer? _timer;
  bool _loading = true;
  bool _polling = false;
  bool _success = false;
  String? _error;
  String _statusMessage = '正在生成二维码…';

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _timer?.cancel();
    setState(() {
      _loading = true;
      _success = false;
      _error = null;
      _session = null;
      _statusMessage = '正在生成二维码…';
    });

    final baseUrl = ref.read(onlineBaseUrlProvider);
    if (baseUrl.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '请先在设置中配置在线音源服务';
      });
      return;
    }

    try {
      final token = await ref.read(onlineTokenProvider.future);
      final session = await rust_online.onlineQrCreate(
        baseUrl: baseUrl,
        token: token,
        source: widget.source,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
        _statusMessage = '等待扫码';
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (Timer timer) {
        unawaited(_poll());
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '生成二维码失败：$error';
      });
    }
  }

  Future<void> _poll() async {
    final session = _session;
    if (session == null || _polling || _success) return;
    _polling = true;
    try {
      final baseUrl = ref.read(onlineBaseUrlProvider);
      final token = await ref.read(onlineTokenProvider.future);
      final result = await rust_online.onlineQrCheck(
        baseUrl: baseUrl,
        token: token,
        source: widget.source,
        key: session.key,
      );
      if (!mounted) return;

      switch (result.status) {
        case 'waiting':
          setState(() => _statusMessage = '等待扫码');
        case 'scanned':
          setState(() => _statusMessage = '已扫码，请在手机上确认');
        case 'success':
          _timer?.cancel();
          setState(() {
            _success = true;
            _statusMessage = result.cookieSaved ? '登录成功' : '登录成功，但 Cookie 未保存';
          });
          ref.invalidate(onlinePlatformStatusesProvider);
          ref.invalidate(onlineUserPlaylistsProvider);
          if (mounted) {
            M3ESnackbar.show(context, message: '登录成功');
          }
        case 'expired':
          _timer?.cancel();
          setState(() => _statusMessage = '二维码已过期，请刷新');
        case 'failed':
          _timer?.cancel();
          setState(
            () => _statusMessage = result.message.isEmpty
                ? '登录失败'
                : '登录失败：${result.message}',
          );
        default:
          setState(() => _statusMessage = result.message);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = '查询登录状态失败：$error');
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: _title),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_loading)
                  const CircularProgressIndicator()
                else if (_error != null)
                  _buildError(theme)
                else if (_success)
                  _buildSuccess(theme)
                else
                  _buildQr(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(M3EThemeData theme) {
    return Column(
      children: <Widget>[
        Icon(M3EIcons.error_outline, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: AppSpacing.md),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        M3EButton(
          style: M3EButtonStyle.filled,
          label: const Text('重试'),
          onPressed: _start,
        ),
      ],
    );
  }

  Widget _buildSuccess(M3EThemeData theme) {
    return Column(
      children: <Widget>[
        Icon(M3EIcons.check_circle, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.md),
        Text(_statusMessage, style: theme.typeScale.titleMedium),
        const SizedBox(height: AppSpacing.lg),
        M3EButton(
          style: M3EButtonStyle.filled,
          label: const Text('完成'),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }

  Widget _buildQr(M3EThemeData theme) {
    final session = _session;
    if (session == null) return const SizedBox.shrink();
    final image = _buildQrImage(session);
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadii.lgAll,
          ),
          child: image,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(_statusMessage, style: theme.typeScale.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _hint,
          textAlign: TextAlign.center,
          style: theme.typeScale.bodySmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        M3EButton(
          style: M3EButtonStyle.tonal,
          label: const Text('刷新二维码'),
          onPressed: _start,
        ),
      ],
    );
  }

  Widget _buildQrImage(rust_online.UiOnlineQrSession session) {
    final data = _decodeDataUrl(session.imageUrl);
    if (data != null) {
      return Image.memory(data, width: 220, height: 220, gaplessPlayback: true);
    }
    if (session.imageUrl.startsWith('http://') ||
        session.imageUrl.startsWith('https://')) {
      return Image.network(
        session.imageUrl,
        width: 220,
        height: 220,
        fit: BoxFit.contain,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return _qrFromUrl(session.url);
        },
      );
    }
    return _qrFromUrl(session.url);
  }

  Widget _qrFromUrl(String url) {
    if (url.isEmpty) {
      return const SizedBox(
        width: 220,
        height: 220,
        child: Center(child: Text('二维码链接为空')),
      );
    }
    return QrImageView(data: url, size: 220, backgroundColor: Colors.white);
  }

  Uint8List? _decodeDataUrl(String value) {
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(value.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  String get _title {
    return switch (widget.source) {
      'netease' => '登录网易云音乐',
      'qq' => '登录 QQ 音乐',
      'qq_wx' => '微信扫码登录 QQ 音乐',
      _ => '扫码登录',
    };
  }

  String get _hint {
    return switch (widget.source) {
      'netease' => '请使用网易云音乐 App 扫码',
      'qq' => '请使用 QQ 音乐 App 扫码',
      'qq_wx' => '请使用微信扫码',
      _ => '请使用对应 App 扫码',
    };
  }
}
