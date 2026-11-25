import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/netease.dart' as rust_netease;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;

import 'netease_settings.dart';

/// 当前配置的网易云 Node API 地址。
final neteaseBaseUrlProvider = Provider<String>((ref) {
  return ref.watch(
    neteaseSettingsProvider.select((settings) => settings.apiBaseUrl),
  );
});

/// 网易云 Node API 的连接/登录状态。
final neteaseStatusProvider =
    FutureProvider.autoDispose<rust_netease.UiNeteaseStatus>((ref) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      return rust_netease.neteaseStatus(baseUrl: baseUrl);
    });

/// 网易云每日推荐。未登录时使用网易云返回的匿名推荐。
final neteaseDailyProvider = FutureProvider.autoDispose<List<rust.UiTrack>>((
  ref,
) async {
  final baseUrl = ref.watch(neteaseBaseUrlProvider);
  if (baseUrl.isEmpty) {
    throw StateError('请先配置网易云 API 地址');
  }
  return rust_netease.neteaseDailyRecommendations(baseUrl: baseUrl);
});

typedef NeteaseSearchKey = ({String keywords, int limit, int offset});

/// 网易云单曲搜索。当前 UI 尚未接入，先保留给搜索页使用。
final neteaseSearchProvider = FutureProvider.autoDispose
    .family<List<rust.UiTrack>, NeteaseSearchKey>((ref, key) async {
      final baseUrl = ref.watch(neteaseBaseUrlProvider);
      if (baseUrl.isEmpty) {
        throw StateError('请先配置网易云 API 地址');
      }
      return rust_netease.neteaseSearch(
        baseUrl: baseUrl,
        keywords: key.keywords,
        limit: key.limit,
        offset: key.offset,
      );
    });

/// 从 UiTrack 中取出网易云 songId，兼容旧数据与 sourceExtraJson。
String neteaseSongIdFromTrack(rust.UiTrack track) {
  final extra = track.sourceExtraJson;
  if (extra != null && extra.isNotEmpty) {
    try {
      final decoded = jsonDecode(extra);
      if (decoded is Map) {
        final songId = decoded['songId'];
        if (songId is num) return songId.toInt().toString();
        if (songId is String && songId.isNotEmpty) return songId;
      }
    } catch (_) {
      // 快照损坏或旧格式，回退到 id。
    }
  }
  const prefix = 'netease:';
  if (track.id.startsWith(prefix)) {
    return track.id.substring(prefix.length);
  }
  return track.id;
}
