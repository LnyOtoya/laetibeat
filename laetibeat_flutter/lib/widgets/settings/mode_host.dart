import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/online.dart' as rust_online;
import 'package:path_provider/path_provider.dart';

import '../../app/app_mode.dart';
import '../player/player_provider.dart';

const MethodChannel _modeHostChannel = MethodChannel(
  'com.otimeum.laetibeat/host',
);
const String _listenPrefix = 'LAETIBEAT_MUSICAPI_LISTEN=';

// 开发期可绕过打包路径：
// flutter run -d linux --dart-define=LAETIBEAT_QQ_HOST_PATH=/path/to/laetibeat_qq_host
const String _qqHostOverride = String.fromEnvironment('LAETIBEAT_QQ_HOST_PATH');
const String _neteaseHostOverride = String.fromEnvironment(
  'LAETIBEAT_NETEASE_HOST_PATH',
);

enum ModeHostStatus { stopped, starting, running, error }

class ModeHostState {
  const ModeHostState({
    this.mode = AppMode.local,
    this.status = ModeHostStatus.stopped,
    this.baseUrl,
    this.token,
    this.error,
    this.pid,
  });

  final AppMode mode;
  final ModeHostStatus status;
  final String? baseUrl;
  final String? token;
  final String? error;
  final int? pid;

  bool get isRunning => status == ModeHostStatus.running && baseUrl != null;
  bool get isStarting => status == ModeHostStatus.starting;
  bool get hasError => status == ModeHostStatus.error;
}

class ModeRuntime {
  const ModeRuntime({this.mode = AppMode.local, this.baseUrl, this.token});

  final AppMode mode;
  final String? baseUrl;
  final String? token;

  bool get hasBaseUrl => baseUrl != null && baseUrl!.isNotEmpty;
}

/// 管理 QQ / 网易云两个 Rust sidecar 的生命周期。
///
/// local / subsonic 不启动进程。切换模式时：
/// 1. 暂停播放
/// 2. 停止当前 sidecar
/// 3. 保留数据目录（Cookie / Credential）
/// 4. 启动目标 sidecar
class ModeHostController extends Notifier<ModeHostState> {
  Process? _process;
  StreamSubscription<String>? _stdout;
  StreamSubscription<String>? _stderr;
  Completer<String>? _listenCompleter;
  StringBuffer _stderrTail = StringBuffer();
  Future<void>? _startFuture;
  bool _stopping = false;
  bool _disposed = false;
  int _restartAttempts = 0;

  @override
  ModeHostState build() {
    ref.onDispose(() {
      _disposed = true;
      unawaited(_shutdown());
    });
    return ModeHostState(mode: ref.read(appModeProvider));
  }

  bool get supported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isLinux;
  }

  Future<void> switchTo(AppMode mode) async {
    if (mode == ref.read(appModeProvider) && !state.hasError) {
      if (mode.usesOnlineHost && !state.isRunning && !state.isStarting) {
        await start();
      }
      return;
    }

    await ref.read(playerProvider.notifier).pause();
    await stop();
    await ref.read(appModeProvider.notifier).setMode(mode);
    _setState(ModeHostState(mode: mode));
    if (mode.usesOnlineHost) {
      await start();
    }
  }

  Future<void> startIfNeeded() async {
    final mode = ref.read(appModeProvider);
    if (!mode.usesOnlineHost) return;
    if (!supported) {
      _setState(
        ModeHostState(
          mode: mode,
          status: ModeHostStatus.error,
          error: '当前平台不支持内置 sidecar',
        ),
      );
      return;
    }
    if (_process != null ||
        state.status == ModeHostStatus.running ||
        state.status == ModeHostStatus.starting) {
      return;
    }
    await start();
  }

  Future<void> start() {
    return _startFuture ??= _start().whenComplete(() => _startFuture = null);
  }

  Future<void> _start() async {
    if (_disposed) return;
    final mode = ref.read(appModeProvider);
    if (!mode.usesOnlineHost) {
      _setState(ModeHostState(mode: mode));
      return;
    }
    _stopping = false;
    _setState(ModeHostState(mode: mode, status: ModeHostStatus.starting));

    try {
      final token = _randomToken();
      final executable = await _hostExecutable(mode);
      final dataDir = await _dataDir(mode);
      final environment = Map<String, String>.from(Platform.environment)
        ..['LAETIBEAT_MUSICAPI_ADDR'] = '127.0.0.1:0'
        ..['LAETIBEAT_MUSICAPI_TOKEN'] = token
        ..['LAETIBEAT_MUSICAPI_DATA_DIR'] = dataDir.path
        ..['LAETIBEAT_MUSICAPI_PARENT_PID'] = pid.toString();
      if (Platform.isAndroid) {
        environment['LD_LIBRARY_PATH'] = File(executable).parent.path;
      }

      final process = await Process.start(
        executable,
        const <String>[],
        environment: environment,
        workingDirectory: dataDir.path,
        includeParentEnvironment: false,
      );
      _process = process;
      _stderrTail = StringBuffer();
      _listenCompleter = Completer<String>();

      _stdout = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleStdout);
      _stderr = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleStderr);
      unawaited(process.exitCode.then(_handleExit));

      final addr = await _listenCompleter!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw StateError('${mode.label} sidecar 启动超时'),
      );
      final baseUrl = 'http://$addr';
      await _waitForHealth(baseUrl, token);
      if (_disposed || _stopping || ref.read(appModeProvider) != mode) {
        await _shutdownProcess();
        return;
      }

      ref
          .read(modeRuntimeProvider.notifier)
          .set(mode: mode, baseUrl: baseUrl, token: token);
      _restartAttempts = 0;
      _setState(
        ModeHostState(
          mode: mode,
          status: ModeHostStatus.running,
          baseUrl: baseUrl,
          token: token,
          pid: process.pid,
        ),
      );
      debugPrint('${mode.label} sidecar 已启动: $baseUrl (pid ${process.pid})');
    } catch (error) {
      await _shutdownProcess();
      if (_disposed || _stopping) return;
      _setState(
        ModeHostState(
          mode: mode,
          status: ModeHostStatus.error,
          error: '${mode.label} sidecar 启动失败：$error${_stderrSuffix()}',
        ),
      );
    }
  }

  Future<void> stop() async {
    _stopping = true;
    await _shutdownProcess();
    if (!_disposed) {
      ref.read(modeRuntimeProvider.notifier).clear();
      _setState(ModeHostState(mode: ref.read(appModeProvider)));
    }
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<void> _shutdown() async {
    _stopping = true;
    await _shutdownProcess();
  }

  Future<void> _shutdownProcess() async {
    final completer = _listenCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(StateError('sidecar 已停止'));
    }
    await _stdout?.cancel();
    await _stderr?.cancel();
    _stdout = null;
    _stderr = null;

    final process = _process;
    _process = null;
    if (process == null) return;
    try {
      process.kill(ProcessSignal.sigterm);
      await process.exitCode.timeout(const Duration(seconds: 3));
    } catch (_) {
      process.kill(ProcessSignal.sigkill);
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        // ignore
      }
    }
  }

  void _handleStdout(String line) {
    if (line.startsWith(_listenPrefix)) {
      final value = line.substring(_listenPrefix.length).trim();
      final completer = _listenCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete(value);
      }
      return;
    }
    if (line.trim().isNotEmpty) {
      debugPrint('mode-host: $line');
    }
  }

  void _handleStderr(String line) {
    if (line.trim().isEmpty) return;
    _stderrTail.write(line);
    _stderrTail.write('\n');
    final value = _stderrTail.toString();
    if (value.length > 4096) {
      _stderrTail = StringBuffer(value.substring(value.length - 4096));
    }
    debugPrint('mode-host(stderr): $line');
  }

  Future<void> _handleExit(int code) async {
    if (_stopping || _disposed) return;
    final mode = state.mode;
    _process = null;
    ref.read(modeRuntimeProvider.notifier).clear();
    _setState(
      ModeHostState(
        mode: mode,
        status: ModeHostStatus.error,
        error: '${mode.label} sidecar 已退出（code=$code）${_stderrSuffix()}',
      ),
    );
    if (ref.read(appModeProvider) != mode) return;
    if (_restartAttempts >= 2) return;
    _restartAttempts++;
    await Future<void>.delayed(const Duration(seconds: 1));
    if (_disposed || _stopping || _process != null) return;
    if (ref.read(appModeProvider) != mode) return;
    await start();
  }

  Future<String> _hostExecutable(AppMode mode) async {
    final hostId = mode.hostId;
    if (hostId == null) throw StateError('${mode.label} 不使用 sidecar');

    final override = switch (mode) {
      AppMode.qq => _qqHostOverride,
      AppMode.netease => _neteaseHostOverride,
      _ => '',
    };
    if (override.isNotEmpty) {
      if (!await File(override).exists()) {
        throw StateError('开发期 sidecar 路径不存在：$override');
      }
      return override;
    }

    if (Platform.isAndroid) {
      final dir = await _modeHostChannel.invokeMethod<String>(
        'getNativeLibraryDir',
      );
      if (dir == null || dir.trim().isEmpty) {
        throw StateError('无法获取 Android nativeLibraryDir');
      }
      final path = '$dir/liblaetibeat_${hostId}_host.so';
      if (!await File(path).exists()) {
        throw StateError('sidecar 未打包：$path');
      }
      return path;
    }

    if (Platform.isLinux) {
      final path =
          '${File(Platform.resolvedExecutable).parent.path}/lib/laetibeat_${hostId}_host';
      if (!await File(path).exists()) {
        throw StateError('sidecar 未打包：$path');
      }
      return path;
    }

    throw UnsupportedError('当前平台不支持内置 sidecar');
  }

  Future<Directory> _dataDir(AppMode mode) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/modes/${mode.id}');
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _waitForHealth(String baseUrl, String token) async {
    Object? lastError;
    for (var attempt = 0; attempt < 40; attempt++) {
      try {
        await rust_online.onlineHealth(baseUrl: baseUrl, token: token);
        return;
      } catch (error) {
        lastError = error;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    throw StateError('健康检查失败：$lastError');
  }

  String _stderrSuffix() {
    final value = _stderrTail.toString().trim();
    if (value.isEmpty) return '';
    return '\n$value';
  }

  void _setState(ModeHostState value) {
    if (_disposed) return;
    state = value;
  }

  String _randomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

class ModeRuntimeNotifier extends Notifier<ModeRuntime> {
  @override
  ModeRuntime build() => const ModeRuntime();

  void set({required AppMode mode, required String baseUrl, String? token}) {
    state = ModeRuntime(mode: mode, baseUrl: baseUrl, token: token);
  }

  void clear() {
    if (state.baseUrl == null && state.token == null) return;
    state = ModeRuntime(mode: state.mode);
  }
}

final modeHostProvider = NotifierProvider<ModeHostController, ModeHostState>(
  ModeHostController.new,
);

final modeRuntimeProvider = NotifierProvider<ModeRuntimeNotifier, ModeRuntime>(
  ModeRuntimeNotifier.new,
);
