import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:laetibeat/widgets/player/playback_backend.dart';

import 'audio_effects.dart';

/// Android/iOS 播放后端。
///
/// 桌面端继续使用 media_kit；移动端使用 just_audio + audio_service。
class JustAudioBackend implements PlaybackBackend, AudioEffectsController {
  JustAudioBackend() {
    unawaited(_configureAudioSession());
    unawaited(_prepareEqualizer());
  }

  final ja.AndroidEqualizer _equalizer = ja.AndroidEqualizer();
  late final ja.AudioPlayer _player = ja.AudioPlayer(
    audioPipeline: ja.AudioPipeline(
      androidAudioEffects: <ja.AndroidAudioEffect>[_equalizer],
    ),
  );
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _noisySubscription;
  bool _resumeAfterInterruption = false;

  List<ja.AndroidEqualizerBand>? _equalizerBands;
  bool _equalizerEnabled = false;
  final List<double> _equalizerGains = List<double>.filled(5, 0);

  Future<void> _prepareEqualizer() async {
    try {
      final parameters = await _equalizer.parameters;
      _equalizerBands = parameters.bands;
      await _equalizer.setEnabled(_equalizerEnabled);
      for (
        var i = 0;
        i < _equalizerBands!.length && i < _equalizerGains.length;
        i++
      ) {
        await _equalizerBands![i].setGain(_equalizerGains[i]);
      }
    } catch (e) {
      // 部分设备或非 Android 平台没有系统均衡器。
      debugPrint('初始化均衡器失败: $e');
    }
  }

  @override
  Future<void> setEqualizerEnabled(bool enabled) async {
    _equalizerEnabled = enabled;
    try {
      await _equalizer.setEnabled(enabled);
    } catch (e) {
      debugPrint('切换均衡器失败: $e');
    }
  }

  @override
  Future<void> setEqualizerBandGain(int index, double gain) async {
    if (index < 0 || index >= _equalizerGains.length) return;
    _equalizerGains[index] = gain;
    final bands = _equalizerBands;
    if (bands == null || index >= bands.length) return;
    try {
      await bands[index].setGain(gain);
    } catch (e) {
      debugPrint('设置均衡器频段失败: $e');
    }
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _interruptionSubscription = session.interruptionEventStream.listen((
      AudioInterruptionEvent event,
    ) {
      if (event.begin) {
        if (event.type == AudioInterruptionType.duck) {
          unawaited(_player.setVolume(0.2));
          return;
        }
        _resumeAfterInterruption = _player.playing;
        unawaited(_player.pause());
        unawaited(_player.setVolume(1.0));
        return;
      }

      unawaited(_player.setVolume(1.0));
      if (_resumeAfterInterruption &&
          event.type == AudioInterruptionType.pause) {
        unawaited(_player.play());
      }
      _resumeAfterInterruption = false;
    });

    _noisySubscription = session.becomingNoisyEventStream.listen((_) {
      unawaited(_player.pause());
    });
  }

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration> get durationStream => _player.durationStream
      .where(
        (Duration? duration) => duration != null && duration > Duration.zero,
      )
      .map((Duration? duration) => duration!);

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<void> get completedStream => _player.processingStateStream
      .where(
        (ja.ProcessingState state) => state == ja.ProcessingState.completed,
      )
      .map((_) {});

  @override
  Stream<AudioDeviceInfo> get audioDeviceStream =>
      const Stream<AudioDeviceInfo>.empty();

  @override
  Stream<List<AudioDeviceInfo>> get audioDevicesStream =>
      const Stream<List<AudioDeviceInfo>>.empty();

  @override
  Stream<AudioParamsInfo> get audioParamsStream =>
      const Stream<AudioParamsInfo>.empty();

  @override
  Stream<double?> get audioBitrateStream => const Stream<double?>.empty();

  @override
  Future<void> setAudioDevice(String id) async {
    // just_audio 使用系统默认路由，移动端不提供设备切换面板。
  }

  @override
  Future<void> open(PlaybackTrack track, {bool play = true}) async {
    await _player.setAudioSource(ja.AudioSource.uri(Uri.parse(track.uri)));
    if (play) {
      await _player.play();
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _interruptionSubscription?.cancel();
    await _noisySubscription?.cancel();
    await _player.dispose();
  }
}
