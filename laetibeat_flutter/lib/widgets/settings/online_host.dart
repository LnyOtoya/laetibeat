import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/online.dart' as rust_online;
import 'package:path_provider/path_provider.dart';

import 'online_settings.dart';

const MethodChannel _hostChannel = MethodChannel('com.otimeum.laetibeat/host');
const String _listenPrefix = 'LAETIBEAT_MUSICAPI_LISTEN=';

enum OnlineHostStatus { stopped, starting, running, error }

class OnlineHostState {
  const OnlineHostState({
    this.status = OnlineHostStatus.stopped,
    this.baseUrl,
    this.error,
    this.pid,
  });

  final OnlineHostStatus status;
  final String? baseUrl;
  final String? error;
  final int? pid;

  bool get isRunning => status == OnlineHostStatus.running && baseUrl != null;
  bool get isStarting => status == OnlineHostStatus.starting;
  bool get hasError => status == OnlineHostStatus.error;
}

/// 管理内置 go-music-api host 的进程生命周期。
///
/// 只在 Android / Linux 的「内置服务」模式下启动：
/// - 随机 loopback 端口
/// - 每次启动随机 Bearer token
/// - data dir 使用应用支持目录下的 musicapi
/// - stdout 读取 `LAETIBEAT_MUSICAPI_LISTEN=host:port`
/// - 启动后健康检查；异常退出最多自动重启 2 次
class OnlineHostController extends Notifier<OnlineHostState> {
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
  OnlineHostState build() {
    ref.onDispose(() {
      _disposed = true;
      unawaited(_shutdown());
    });
    return const OnlineHostState();
  }

  bool get supported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isLinux;
  }

  Future<void> startIfNeeded() async {
    final mode = ref.read(onlineSettingsProvider).mode;
    if (mode != OnlineMode.builtin) return;
    if (!supported) {
      _setState(
        const OnlineHostState(
          status: OnlineHostStatus.error,
          error: '当前平台不支持内置服务，请改用远程模式',
        ),
      );
      return;
    }
    if (_process != null ||
        state.status == OnlineHostStatus.running ||
        state.status == OnlineHostStatus.starting) {
      return;
    }
    await start();
  }

  Future<void> start() {
    return _startFuture ??= _start().whenComplete(() => _startFuture = null);
  }

  Future<void> _start() async {
    if (_disposed) return;
    _stopping = false;
    _setState(const OnlineHostState(status: OnlineHostStatus.starting));

    var process = _process;
    try {
      final token = _randomToken();
      final executable = await _hostExecutable();
      final dataDir = await _dataDir();
      final environment = Map<String, String>.from(Platform.environment)
        ..['LAETIBEAT_MUSICAPI_ADDR'] = '127.0.0.1:0'
        ..['LAETIBEAT_MUSICAPI_TOKEN'] = token
        ..['LAETIBEAT_MUSICAPI_DATA_DIR'] = dataDir.path
        ..['LAETIBEAT_MUSICAPI_PARENT_PID'] = pid.toString();
      if (Platform.isAndroid) {
        environment['LD_LIBRARY_PATH'] = File(executable).parent.path;
      }

      process = await Process.start(
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
        onTimeout: () => throw StateError('内置服务启动超时'),
      );
      final baseUrl = 'http://$addr';
      await _waitForHealth(baseUrl, token);
      if (_disposed || _stopping) {
        await _shutdownProcess();
        return;
      }

      ref
          .read(onlineRuntimeOverridesProvider.notifier)
          .set(baseUrl: baseUrl, token: token);
      _restartAttempts = 0;
      _setState(
        OnlineHostState(
          status: OnlineHostStatus.running,
          baseUrl: baseUrl,
          pid: process.pid,
        ),
      );
      debugPrint('内置在线音源已启动: $baseUrl (pid ${process.pid})');
    } catch (error) {
      await _shutdownProcess();
      if (_disposed || _stopping) return;
      _setState(
        OnlineHostState(
          status: OnlineHostStatus.error,
          error: '内置服务启动失败：$error${_stderrSuffix()}',
        ),
      );
    }
  }

  Future<void> stop() async {
    _stopping = true;
    await _shutdownProcess();
    if (!_disposed) {
      ref.read(onlineRuntimeOverridesProvider.notifier).clear();
      _setState(const OnlineHostState(status: OnlineHostStatus.stopped));
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
      completer.completeError(StateError('内置服务已停止'));
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
        // 进程已不可等待。
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
      debugPrint('musicapi: $line');
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
    debugPrint('musicapi(stderr): $line');
  }

  Future<void> _handleExit(int code) async {
    if (_stopping || _disposed) return;
    _process = null;
    ref.read(onlineRuntimeOverridesProvider.notifier).clear();
    _setState(
      OnlineHostState(
        status: OnlineHostStatus.error,
        error: '内置服务已退出（code=$code）${_stderrSuffix()}',
      ),
    );
    if (ref.read(onlineSettingsProvider).mode != OnlineMode.builtin) return;
    if (_restartAttempts >= 2) return;
    _restartAttempts++;
    await Future<void>.delayed(const Duration(seconds: 1));
    if (_disposed || _stopping || _process != null) return;
    if (ref.read(onlineSettingsProvider).mode != OnlineMode.builtin) return;
    await start();
  }

  Future<String> _hostExecutable() async {
    if (Platform.isAndroid) {
      final dir = await _hostChannel.invokeMethod<String>(
        'getNativeLibraryDir',
      );
      if (dir == null || dir.trim().isEmpty) {
        throw StateError('无法获取 Android nativeLibraryDir');
      }
      final path = '$dir/liblaetibeat_musicapi_host.so';
      if (!await File(path).exists()) {
        throw StateError('内置 host 未打包：$path');
      }
      return path;
    }

    if (Platform.isLinux) {
      final path =
          '${File(Platform.resolvedExecutable).parent.path}/lib/laetibeat_musicapi_host';
      if (!await File(path).exists()) {
        throw StateError('内置 host 未打包：$path');
      }
      return path;
    }

    throw UnsupportedError('当前平台不支持内置 host，请使用远程模式');
  }

  Future<Directory> _dataDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/musicapi');
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

  void _setState(OnlineHostState value) {
    if (_disposed) return;
    state = value;
  }

  String _randomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

final onlineHostProvider =
    NotifierProvider<OnlineHostController, OnlineHostState>(
      OnlineHostController.new,
    );
