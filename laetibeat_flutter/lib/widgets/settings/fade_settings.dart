import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persistence.dart' show sharedPreferencesProvider;

const String kFadeEnabledKey = 'audio.fade.enabled';
const String kFadeInSecondsKey = 'audio.fade.in_seconds';
const String kFadeOutSecondsKey = 'audio.fade.out_seconds';
const double kFadeMaxSeconds = 10;
const double kDefaultFadeInSeconds = 2;
const double kDefaultFadeOutSeconds = 2;

class FadeSettings {
  const FadeSettings({
    required this.enabled,
    required this.fadeInSeconds,
    required this.fadeOutSeconds,
  });

  final bool enabled;
  final double fadeInSeconds;
  final double fadeOutSeconds;

  FadeSettings copyWith({
    bool? enabled,
    double? fadeInSeconds,
    double? fadeOutSeconds,
  }) {
    return FadeSettings(
      enabled: enabled ?? this.enabled,
      fadeInSeconds: fadeInSeconds ?? this.fadeInSeconds,
      fadeOutSeconds: fadeOutSeconds ?? this.fadeOutSeconds,
    );
  }
}

class FadeSettingsNotifier extends Notifier<FadeSettings> {
  @override
  FadeSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return FadeSettings(
      enabled: prefs.getBool(kFadeEnabledKey) ?? false,
      fadeInSeconds: _readSeconds(
        prefs.getDouble(kFadeInSecondsKey),
        kDefaultFadeInSeconds,
      ),
      fadeOutSeconds: _readSeconds(
        prefs.getDouble(kFadeOutSecondsKey),
        kDefaultFadeOutSeconds,
      ),
    );
  }

  void setEnabled(bool enabled) {
    final next = state.copyWith(enabled: enabled);
    state = next;
    unawaited(
      ref.read(sharedPreferencesProvider).setBool(kFadeEnabledKey, enabled),
    );
  }

  void setFadeInSeconds(double seconds) {
    final value = seconds.clamp(0, kFadeMaxSeconds).toDouble();
    final next = state.copyWith(fadeInSeconds: value);
    state = next;
    unawaited(
      ref.read(sharedPreferencesProvider).setDouble(
        kFadeInSecondsKey,
        value,
      ),
    );
  }

  void setFadeOutSeconds(double seconds) {
    final value = seconds.clamp(0, kFadeMaxSeconds).toDouble();
    final next = state.copyWith(fadeOutSeconds: value);
    state = next;
    unawaited(
      ref.read(sharedPreferencesProvider).setDouble(
        kFadeOutSecondsKey,
        value,
      ),
    );
  }

  static double _readSeconds(double? value, double fallback) {
    return (value ?? fallback).clamp(0, kFadeMaxSeconds).toDouble();
  }
}

final fadeSettingsProvider = NotifierProvider<FadeSettingsNotifier, FadeSettings>(
  FadeSettingsNotifier.new,
);
