import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

//播放状态:当前曲目/播放中/进度/队列
//三页右侧播放面板 + 全屏页都读同一份,保证"相互联系"
class PlayerState {
  final List<rust.UiTrack> queue;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  const PlayerState({
    this.queue = const <rust.UiTrack>[],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  rust.UiTrack? get current => queue.isEmpty ? null : queue[currentIndex];

  PlayerState copyWith({
    List<rust.UiTrack>? queue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    return PlayerState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

class PlayerNotifier extends Notifier<PlayerState> {
  @override
  PlayerState build() {
    //假数据占位,后期接真实解码/播放链路
    final queue = _fakeTracks();
    return PlayerState(
      queue: queue,
      currentIndex: 0,
      duration: const Duration(seconds: 204),
    );
  }

  //播放/暂停切换
  void toggle() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  //播放队列中指定曲目
  void play(int index) {
    final queue = state.queue;
    if (queue.isEmpty || index < 0 || index >= queue.length) return;
    final idx = (index + queue.length) % queue.length;
    state = state.copyWith(
      currentIndex: idx,
      isPlaying: true,
      position: Duration.zero,
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