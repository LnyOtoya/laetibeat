import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/settings/persistence.dart';

const String kDiscoverPlatformKey = 'discover.platform';

/// 发现页当前展示的平台。当前只支持网易云和 QQ。
enum DiscoverPlatform {
  netease(id: 'netease', label: '网易云音乐'),
  qq(id: 'qq', label: 'QQ 音乐');

  const DiscoverPlatform({required this.id, required this.label});

  final String id;
  final String label;

  /// 在线音源的 source 名称。
  String get source => id;

  static DiscoverPlatform fromId(String? id) {
    for (final platform in values) {
      if (platform.id == id) return platform;
    }
    return netease;
  }
}

class DiscoverPlatformNotifier extends Notifier<DiscoverPlatform> {
  @override
  DiscoverPlatform build() {
    final saved = ref
        .read(sharedPreferencesProvider)
        .getString(kDiscoverPlatformKey);
    return DiscoverPlatform.fromId(saved);
  }

  Future<void> select(DiscoverPlatform platform) async {
    if (state == platform) return;
    state = platform;
    await ref
        .read(sharedPreferencesProvider)
        .setString(kDiscoverPlatformKey, platform.id);
  }
}

final discoverPlatformProvider =
    NotifierProvider<DiscoverPlatformNotifier, DiscoverPlatform>(
      DiscoverPlatformNotifier.new,
    );
