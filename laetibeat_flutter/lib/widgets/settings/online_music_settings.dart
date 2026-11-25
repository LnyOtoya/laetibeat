import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persistence.dart';

const String kOnlineMusicSourceKey = 'onlineMusic.source';

/// 在线音乐来源。
///
/// 媒体库的「在线音乐」分组只跟随这里选中的一个来源；后续增加 QQ 音乐等
/// 平台时继续在这里扩展，但状态始终只有一个值。
enum OnlineMusicSource {
  netease(id: 'netease', label: '网易云音乐', description: '通过自建 Node API 接入网易云音乐');

  const OnlineMusicSource({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  static OnlineMusicSource fromId(String? id) {
    for (final source in values) {
      if (source.id == id) return source;
    }
    return netease;
  }
}

class SelectedOnlineMusicSourceNotifier extends Notifier<OnlineMusicSource> {
  @override
  OnlineMusicSource build() {
    final saved = ref
        .read(sharedPreferencesProvider)
        .getString(kOnlineMusicSourceKey);
    return OnlineMusicSource.fromId(saved);
  }

  Future<void> select(OnlineMusicSource source) async {
    if (state == source) return;
    state = source;
    await ref
        .read(sharedPreferencesProvider)
        .setString(kOnlineMusicSourceKey, source.id);
  }
}

final selectedOnlineMusicSourceProvider =
    NotifierProvider<SelectedOnlineMusicSourceNotifier, OnlineMusicSource>(
      SelectedOnlineMusicSourceNotifier.new,
    );

/// 当前所有可选的在线音乐来源。
///
/// 目前只有网易云；后续增加平台后仍然只能在这里选中一个。
List<OnlineMusicSource> get allOnlineMusicSources => OnlineMusicSource.values;
