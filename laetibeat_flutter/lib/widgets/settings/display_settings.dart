import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:refresh_rate/refresh_rate.dart';

import 'persistence.dart';

/// 是否请求设备支持的最高刷新率。
///
/// 这是显示偏好，不是绕过系统策略的硬性锁定；省电、温控和 OEM 调度仍可能
/// 降低实际刷新率。
const String kHighRefreshRateEnabledKey = 'display.high_refresh_rate.enabled';

class HighRefreshRateNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(kHighRefreshRateEnabledKey) ?? true;
  }

  void setEnabled(bool enabled) {
    if (state == enabled) return;
    state = enabled;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setBool(kHighRefreshRateEnabledKey, enabled),
    );
    unawaited(applyHighRefreshRatePreference(enabled));
  }
}

final highRefreshRateProvider =
    NotifierProvider<HighRefreshRateNotifier, bool>(
      HighRefreshRateNotifier.new,
    );

/// 在 Android 上提交高刷新率偏好；其他平台保持系统默认。
Future<void> applyHighRefreshRatePreference(bool enabled) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  try {
    final RateRequestResult result = enabled
        ? await RefreshRate.enable()
        : await RefreshRate.preferDefault();
    debugPrint(
      '[refresh] ${enabled ? 'high' : 'default'}: '
      '${result.status.name} / ${result.backend}',
    );
  } catch (error) {
    debugPrint('[refresh] apply preference failed: $error');
  }
}
