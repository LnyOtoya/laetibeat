import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/lx.dart' as rust_lx;
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../l10n/generated/app_localizations.dart';

typedef LxSearchKey = ({String platform, String query});

/// Official platform order (kw → kg → tx → wy → mg).
///
/// Used as a fallback while the host list is loading, so the platform selector
/// never disappears.
const List<String> kLxPlatformOrder = <String>['kw', 'kg', 'tx', 'wy', 'mg'];

/// Built-in search platforms, ordered.
///
/// Platform search is implemented by the host's built-in clients, so this list
/// never depends on which source scripts the user imported: searching,
/// browsing and subscribing work with no source at all. Only resolving a play
/// URL needs an enabled source (see [lxPlayablePlatformsProvider]).
final lxPlatformsProvider = FutureProvider<List<String>>((ref) async {
  try {
    final platforms = await rust_lx.supportedLxSearchPlatforms();
    final ordered = platforms
        .where(isSupportedLxSearchPlatform)
        .toList(growable: false);
    if (ordered.isNotEmpty) return ordered;
  } catch (_) {
    // Host not ready yet: keep the built-in order so the UI stays usable.
  }
  return kLxPlatformOrder;
});

/// 洛雪运行时的就绪状态（值 = 可解析 `musicUrl` 的平台列表）。
///
/// 首次读取时开始加载，结果常驻（非 autoDispose），所有入口共享同一个
/// Future —— 搜索页、建议、播放、设置页不会各自触发一次初始化。
/// 启动后由 `bootstrap` 预热，把源脚本初始化（可能十几秒）挪到后台。
final lxRuntimeProvider = AsyncNotifierProvider<LxRuntimeNotifier, List<String>>(
  LxRuntimeNotifier.new,
);

class LxRuntimeNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    // `list_lx_sources` 会在 Rust 侧初始化尚未加载的启用源（懒加载入口）。
    final sources = await rust_lx.listLxSources();
    final platforms = <String>{};
    for (final source in sources) {
      if (!source.enabled) continue;
      for (final capability in source.capabilities) {
        if (capability.sourceType != 'music') continue;
        if (!capability.actions.contains('musicUrl')) continue;
        platforms.add(capability.source);
      }
    }
    return platforms.toList(growable: false);
  }

  /// 等待就绪并判断 [platform] 是否可播。
  ///
  /// 初始化失败或超时都返回 false（不抛异常），由调用方决定提示文案。
  Future<bool> ensurePlayable(String platform) async {
    if (platform.isEmpty) return false;
    final current = state;
    if (current.hasValue) {
      return (current.value ?? const <String>[]).contains(platform);
    }
    if (current.hasError) return false;
    try {
      final platforms = await future.timeout(const Duration(seconds: 60));
      return platforms.contains(platform);
    } catch (_) {
      return false;
    }
  }
}

/// 兼容旧的 AsyncValue 形态调用点；数据来自 [lxRuntimeProvider]。
final lxPlayablePlatformsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(lxRuntimeProvider.future),
);

/// Default platform: the first playable platform in built-in order, falling
/// back to the first built-in platform so search works without any source.
String? lxDefaultPlatform({
  required List<String> platforms,
  required List<String> playable,
}) {
  if (platforms.isEmpty) return null;
  for (final platform in platforms) {
    if (playable.contains(platform)) return platform;
  }
  return platforms.first;
}

/// 播放能力三态。
enum LxPlaybackStatus {
  /// 已就绪且该平台有可用源。
  ready,

  /// 运行时还在初始化（源脚本可能十几秒），可以等待。
  preparing,

  /// 没有启用源 / 初始化失败：需要用户去设置页处理。
  unavailable,
}

/// 当前平台的可播状态。
///
/// 关键点：**"还在初始化"不等于"不可用"**。以前把二者混在一起，导致首次
/// 启动时点播放会误报"请先导入音源"。
LxPlaybackStatus lxPlaybackStatus(WidgetRef ref, String? platform) {
  if (platform == null || platform.isEmpty) return LxPlaybackStatus.unavailable;
  final runtime = ref.read(lxRuntimeProvider);
  if (runtime.isLoading && !runtime.hasValue) return LxPlaybackStatus.preparing;
  if (runtime.hasError) return LxPlaybackStatus.unavailable;
  final platforms = runtime.value ?? const <String>[];
  return platforms.contains(platform)
      ? LxPlaybackStatus.ready
      : LxPlaybackStatus.unavailable;
}

/// 播放前确保平台可播。
///
/// - 已就绪：直接返回 true；
/// - 初始化中：提示"正在准备音源"并等待（最长 60s），就绪后返回 true；
/// - 仍不可用：提示需要导入/启用源，返回 false。
Future<bool> ensureLxPlayable(
  BuildContext context,
  WidgetRef ref,
  String? platform,
  AppLocalizations l10n,
) async {
  final status = lxPlaybackStatus(ref, platform);
  if (status == LxPlaybackStatus.ready) return true;

  if (status == LxPlaybackStatus.preparing) {
    M3ESnackbar.show(context, message: l10n.lxSourcePreparing);
    final ready = await ref
        .read(lxRuntimeProvider.notifier)
        .ensurePlayable(platform ?? '');
    if (ready) return true;
    if (!context.mounted) return false;
    M3ESnackbar.show(context, message: l10n.lxSearchSourceRequired);
    return false;
  }

  // 之前初始化失败过：先给一次重试机会，避免一次失败就一直判定不可用。
  if (ref.read(lxRuntimeProvider).hasError) {
    ref.invalidate(lxRuntimeProvider);
    final ready = await ref
        .read(lxRuntimeProvider.notifier)
        .ensurePlayable(platform ?? '');
    if (ready) return true;
    if (!context.mounted) return false;
  }

  M3ESnackbar.show(context, message: l10n.lxSearchSourceRequired);
  return false;
}

/// Serializes LX search requests per platform and keeps a minimum gap between
/// them.
///
/// The platform endpoints are unofficial; bursting them risks rate limiting or
/// a temporary block, but a fixed multi-second delay makes paging feel broken.
/// Serializing per platform plus a small gap keeps normal browsing responsive
/// while bounding request frequency.
class LxSearchGate {
  LxSearchGate({this.minInterval = const Duration(milliseconds: 300)});

  final Duration minInterval;

  final Map<String, DateTime> _lastAt = <String, DateTime>{};
  final Map<String, Future<void>> _tails = <String, Future<void>>{};

  Future<T> run<T>(String platform, Future<T> Function() action) {
    final previous = _tails[platform] ?? Future<void>.value();
    final result = previous.then((_) async {
      final last = _lastAt[platform];
      if (last != null) {
        final wait = minInterval - DateTime.now().difference(last);
        if (wait > Duration.zero) {
          await Future<void>.delayed(wait);
        }
      }
      try {
        return await action();
      } finally {
        _lastAt[platform] = DateTime.now();
      }
    });
    // Keep the chain alive even when a request fails, otherwise one error
    // would stall every later request for the same platform.
    _tails[platform] = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }
}

/// Process-wide gate shared by song search, playlist search and suggestions.
final LxSearchGate lxSearchGate = LxSearchGate();

/// Single entry point for LX song search so every caller shares the gate.
Future<rust_lx.UiLxSearchPage> searchLxSongs({
  required String platform,
  required String keyword,
  required int page,
  required int limit,
}) {
  return lxSearchGate.run(
    platform,
    () => rust_lx.searchLxMusic(
      platform: platform,
      keyword: keyword,
      page: page,
      limit: limit,
    ),
  );
}

/// Independent platform search. It does not require local music, Subsonic or
/// an imported LX source.
final lxSearchProvider =
    FutureProvider.family<rust_lx.UiLxSearchPage?, LxSearchKey>((
      ref,
      key,
    ) async {
      final query = key.query.trim();
      if (query.isEmpty) return null;
      return searchLxSongs(
        platform: key.platform,
        keyword: query,
        page: 1,
        limit: 50,
      );
    });

const Map<String, String> _platformLabels = <String, String>{
  'kw': 'kw',
  'kg': 'kg',
  'tx': 'tx',
  'wy': 'wy',
  'mg': 'mg',
};

bool isSupportedLxSearchPlatform(String platform) =>
    _platformLabels.containsKey(platform);

String lxPlatformLabel(AppLocalizations l10n, String platform) =>
    switch (platform) {
      'kw' => l10n.lxPlatformKw,
      'kg' => l10n.lxPlatformKg,
      'tx' => l10n.lxPlatformTx,
      'wy' => l10n.lxPlatformWy,
      'mg' => l10n.lxPlatformMg,
      _ => platform,
    };
