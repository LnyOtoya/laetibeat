import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

//播放状态:当前曲目/播放中/进度/来源/队列
//三页右侧播放面板 + 全屏页都读同一份,保证"相互联系"
class PlayerState {
  final List<rust.UiTrack> queue;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final String source; //播放来源(如'曲目'/'recently add'),由启动播放处设置

  const PlayerState({
    this.queue = const <rust.UiTrack>[],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.source = '曲目',
  });

  rust.UiTrack? get current => queue.isEmpty ? null : queue[currentIndex];

  PlayerState copyWith({
    List<rust.UiTrack>? queue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    String? source,
  }) {
    return PlayerState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      source: source ?? this.source,
    );
  }
}

class PlayerNotifier extends Notifier<PlayerState> {
  //进度自动前进(假实现,周期触发;后期由真实解码回调驱动)
  Timer? _ticker;

  @override
  PlayerState build() {
    //假数据占位,后期接真实解码/播放链路
    final queue = _fakeTracks();
    final state = PlayerState(
      queue: queue,
      currentIndex: 0,
      duration: const Duration(seconds: 204),
    );
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    return state;
  }

  void _tick() {
    if (!state.isPlaying) return;
    final total = state.duration.inMilliseconds;
    final nextPos = state.position + const Duration(seconds: 1);
    if (total > 0 && nextPos.inMilliseconds >= total) {
      next(); //播完自动切下一首
    } else {
      state = state.copyWith(position: nextPos);
    }
  }

  //播放/暂停切换
  void toggle() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  //播放队列中指定曲目,同时记录来源
  void play(int index, {String? source}) {
    final queue = state.queue;
    if (queue.isEmpty) return;
    final idx = (index + queue.length) % queue.length;
    state = state.copyWith(
      currentIndex: idx,
      isPlaying: true,
      position: Duration.zero,
      source: source ?? state.source,
    );
  }

  //用真实扫描到的曲目整体替换队列并从 startIndex 开始播放
  void load(List<rust.UiTrack> tracks, int startIndex, {String? source}) {
    if (tracks.isEmpty) return;
    final idx = (startIndex + tracks.length) % tracks.length;
    state = state.copyWith(
      queue: List<rust.UiTrack>.of(tracks),
      currentIndex: idx,
      isPlaying: true,
      position: Duration.zero,
      duration: _durationOf(tracks[idx]),
      source: source ?? state.source,
    );
  }

  //从解析的'03:24'时长文本转成 Duration,失败则用整曲默认值
  static Duration _durationOf(rust.UiTrack t) {
    final parts = t.duration.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]);
      final s = int.tryParse(parts[1]);
      if (m != null && s != null) return Duration(minutes: m, seconds: s);
    }
    return const Duration(seconds: 204);
  }

  //拖拽进度条定位
  void seek(Duration position) {
    final total = state.duration.inMilliseconds;
    final ms = position.inMilliseconds.clamp(0, total > 0 ? total : 0);
    state = state.copyWith(
      position: Duration(milliseconds: ms),
      isPlaying: true,
    );
  }

  //下一首
  void next() => play(state.currentIndex + 1);

  //上一首
  void prev() => play(state.currentIndex - 1);

  //假数据
  static List<rust.UiTrack> _fakeTracks() => [
        rust.UiTrack(
          id: 'C:/fake/resonance.mp3',
          title: 'Resonance',
          artist: 'Home',
          album: 'Odyssey',
          duration: '03:24',
        ),
        rust.UiTrack(
          id: 'C:/fake/neon.mp3',
          title: 'Neon Lights',
          artist: 'Home',
          album: 'Odyssey',
          duration: '04:02',
        ),
        rust.UiTrack(
          id: 'C:/fake/echo.mp3',
          title: 'Echo',
          artist: 'Pixel',
          album: 'Skyline',
          duration: '02:51',
        ),
      ];
}

//全局播放状态
final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);