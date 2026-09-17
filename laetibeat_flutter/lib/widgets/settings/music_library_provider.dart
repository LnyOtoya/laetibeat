import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

//本地音乐库状态:记录选中的目录与扫描出的单曲列表
class MusicLibraryState {
  final String? directory;
  final List<rust.UiTrack> tracks;
  final bool isLoading;
  final String? error;
  final bool hasScanned; //标记是否执行过扫描,用于控制状态项显隐

  const MusicLibraryState({
    this.directory,
    this.tracks = const <rust.UiTrack>[],
    this.isLoading = false,
    this.error,
    this.hasScanned = false,
  });

  MusicLibraryState copyWith({
    String? directory,
    List<rust.UiTrack>? tracks,
    bool? isLoading,
    String? error,
    bool? hasScanned,
  }) {
    return MusicLibraryState(
      directory: directory ?? this.directory,
      tracks: tracks ?? this.tracks,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      hasScanned: hasScanned ?? this.hasScanned,
    );
  }
}

class MusicLibraryNotifier extends AsyncNotifier<MusicLibraryState> {
  @override
  Future<MusicLibraryState> build() async {
    return const MusicLibraryState();
  }

  //选择本地音乐目录
  Future<void> pickDirectory() async {
    final path = await rust.pickDirectory();
    if (path == null) return;
    //仅记录目录,不自动扫描
    state = AsyncValue.data(
      (state.value ?? const MusicLibraryState()).copyWith(
        directory: path,
        error: null,
      ),
    );
  }

  //重新扫描当前目录
  Future<void> rescan() async {
    final current = state.value;
    final dir = current?.directory;
    if (dir == null) return;

    state = AsyncValue.data(
      current!.copyWith(isLoading: true, error: null, hasScanned: true),
    );
    try {
      final tracks = await rust.scanLocalMusicFolder(dirPath: dir);
      state = AsyncValue.data(
        state.value!.copyWith(tracks: tracks, isLoading: false),
      );
    } catch (e) {
      state = AsyncValue.data(
        state.value!.copyWith(
          isLoading: false,
          error: e.toString(),
        ),
      );
    }
  }
}

//当前本地音乐库
final musicLibraryProvider =
    AsyncNotifierProvider<MusicLibraryNotifier, MusicLibraryState>(
  MusicLibraryNotifier.new,
);