import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/playback/audio_effects.dart';
import '../../core/providers/playback_backend_provider.dart';
import 'persistence.dart' show sharedPreferencesProvider;

const String kEqualizerEnabledKey = 'audio.equalizer.enabled';
const String kEqualizerGainsKey = 'audio.equalizer.gains';
const double kEqualizerMinGain = -12;
const double kEqualizerMaxGain = 12;

/// 系统均衡器常见的 5 个频段。实际设备频段以 Android AudioEffect 为准。
const List<double> kEqualizerFrequencies = <double>[60, 230, 910, 3600, 14000];

class EqualizerSettings {
  const EqualizerSettings({required this.enabled, required this.gains});

  final bool enabled;
  final List<double> gains;

  EqualizerSettings copyWith({bool? enabled, List<double>? gains}) {
    return EqualizerSettings(
      enabled: enabled ?? this.enabled,
      gains: gains ?? this.gains,
    );
  }
}

class EqualizerSettingsNotifier extends Notifier<EqualizerSettings> {
  @override
  EqualizerSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final enabled = prefs.getBool(kEqualizerEnabledKey) ?? false;
    final raw = prefs.getString(kEqualizerGainsKey);
    final gains = _parseGains(raw);
    final settings = EqualizerSettings(enabled: enabled, gains: gains);
    unawaited(_applyAll(settings));
    return settings;
  }

  void setEnabled(bool enabled) {
    final next = state.copyWith(enabled: enabled);
    state = next;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setBool(kEqualizerEnabledKey, enabled),
    );
    final effects = _effects;
    if (effects != null) {
      unawaited(effects.setEqualizerEnabled(enabled));
    }
  }

  void setBandGain(int index, double gain) {
    if (index < 0 || index >= kEqualizerFrequencies.length) return;
    final gains = List<double>.of(state.gains);
    gains[index] = gain.clamp(kEqualizerMinGain, kEqualizerMaxGain);
    final next = state.copyWith(gains: List<double>.unmodifiable(gains));
    state = next;
    unawaited(_persistGains(next.gains));
    final effects = _effects;
    if (effects != null) {
      unawaited(effects.setEqualizerBandGain(index, next.gains[index]));
    }
  }

  void reset() {
    final next = EqualizerSettings(
      enabled: state.enabled,
      gains: List<double>.filled(kEqualizerFrequencies.length, 0),
    );
    state = next;
    unawaited(_persistGains(next.gains));
    final effects = _effects;
    if (effects == null) return;
    for (var i = 0; i < next.gains.length; i++) {
      unawaited(effects.setEqualizerBandGain(i, next.gains[i]));
    }
  }

  AudioEffectsController? get _effects {
    final backend = ref.read(playbackBackendProvider);
    return backend is AudioEffectsController
        ? backend as AudioEffectsController
        : null;
  }

  Future<void> _applyAll(EqualizerSettings settings) async {
    final effects = _effects;
    if (effects == null) return;
    await effects.setEqualizerEnabled(settings.enabled);
    for (var i = 0; i < settings.gains.length; i++) {
      await effects.setEqualizerBandGain(i, settings.gains[i]);
    }
  }

  Future<void> _persistGains(List<double> gains) {
    return ref
        .read(sharedPreferencesProvider)
        .setString(kEqualizerGainsKey, gains.map(_formatGain).join(','));
  }

  static List<double> _parseGains(String? raw) {
    final defaults = List<double>.filled(kEqualizerFrequencies.length, 0);
    if (raw == null || raw.isEmpty) return defaults;
    final values = raw.split(',');
    for (var i = 0; i < defaults.length && i < values.length; i++) {
      final parsed = double.tryParse(values[i]);
      if (parsed != null) {
        defaults[i] = parsed.clamp(kEqualizerMinGain, kEqualizerMaxGain);
      }
    }
    return List<double>.unmodifiable(defaults);
  }

  static String _formatGain(double value) {
    return value.toStringAsFixed(1);
  }
}

final equalizerSettingsProvider =
    NotifierProvider<EqualizerSettingsNotifier, EqualizerSettings>(
      EqualizerSettingsNotifier.new,
    );
