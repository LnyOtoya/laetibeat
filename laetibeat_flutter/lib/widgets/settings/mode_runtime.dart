import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_mode.dart';

class ModeRuntime {
  const ModeRuntime({this.mode = AppMode.local, this.baseUrl, this.token});

  final AppMode mode;
  final String? baseUrl;
  final String? token;

  bool get hasBaseUrl => baseUrl != null && baseUrl!.isNotEmpty;
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

final modeRuntimeProvider = NotifierProvider<ModeRuntimeNotifier, ModeRuntime>(
  ModeRuntimeNotifier.new,
);
