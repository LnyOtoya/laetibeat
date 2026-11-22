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
/// URL needs an enabled source (see [lxRuntimeProvider]).
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

/// 洛雪运行时快照。
class LxRuntimeSnapshot {
  const LxRuntimeSnapshot({
    required this.playablePlatforms,
    required this.warming,
  });

  /// 能解析 `musicUrl` 的平台。来自本次进程加载的 `inited` 声明，
  /// 或上次成功加载后持久化的缓存。
  final List<String> playablePlatforms;

  /// 还有已启用源没拿到能力声明：此时"不在列表里"只代表未知。
  final bool warming;
}

/// 洛雪运行时的就绪状态。
///
/// 首次读取只做一次廉价的 `list_lx_sources`（读持久化声明，毫秒级），
/// 真正的脚本加载由 [LxRuntimeNotifier.warmUp] 在后台完成；
/// 结果常驻（非 autoDispose），所有入口共享同一次初始化。
final lxRuntimeProvider =
    AsyncNotifierProvider<LxRuntimeNotifier, LxRuntimeSnapshot>(
      LxRuntimeNotifier.new,
    );

class LxRuntimeNotifier extends AsyncNotifier<LxRuntimeSnapshot> {
  Future<void>? _warmUp;

  @override
  Future<LxRuntimeSnapshot> build() async {
    final sources = await rust_lx.listLxSources();
    return _snapshot(sources);
  }

  static LxRuntimeSnapshot _snapshot(List<rust_lx.UiLxSourceEntry> sources) {
    final platforms = <String>{};
    var warming = false;
    for (final source in sources) {
      if (!source.enabled) continue;
      if (source.capabilities.isEmpty) warming = true;
      for (final capability in source.capabilities) {
        if (capability.sourceType != 'music') continue;
        if (!capability.actions.contains('musicUrl')) continue;
        platforms.add(capability.source);
      }
    }
    return LxRuntimeSnapshot(
      playablePlatforms: platforms.toList(growable: false),
      warming: warming,
    );
  }

  /// 后台加载所有已启用源（每个可能几秒），完成后刷新可播列表。
  ///
  /// 多条调用共享同一次预热；单个源失败只记录日志，不影响其它源。
  Future<void> warmUp() => _warmUp ??= _warmUpOnce();

  Future<void> _warmUpOnce() async {
    try {
      await future; // 等 build 完成（读缓存声明，毫秒级）
    } catch (_) {
      return; // build 失败：错误已经在 state 里
    }
    if (state.value == null) return;
    try {
      final sources = await rust_lx.listLxSources();
      // 即使声明已缓存也照样预热：这样本次进程里首次播放不用再等脚本初始化。
      for (final source in sources) {
        if (!source.enabled) continue;
        try {
          await rust_lx.loadLxSource(id: source.id);
        } catch (error) {
          debugPrint('洛雪音源加载失败 id=${source.id}: $error');
        }
      }
      final refreshed = await rust_lx.listLxSources();
      state = AsyncData(_snapshot(refreshed));
    } catch (error, stackTrace) {
      state = AsyncError<LxRuntimeSnapshot>(error, stackTrace);
    }
  }

  /// 等待就绪并判断 [platform] 是否可播。
  ///
  /// 初始化失败或超时都返回 false（不抛异常），由调用方决定提示文案。
  Future<bool> ensurePlayable(String platform) async {
    if (platform.isEmpty) return false;
    final current = state;
    if (current.hasValue) {
      final snapshot = current.value!;
      if (snapshot.playablePlatforms.contains(platform)) return true;
      if (!snapshot.warming) return false;
    } else if (current.hasError) {
      return false;
    }
    try {
      await warmUp().timeout(const Duration(seconds: 90));
    } catch (_) {
      return false;
    }
    return state.value?.playablePlatforms.contains(platform) ?? false;
  }
}

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
  final snapshot = runtime.value;
  if (snapshot == null) return LxPlaybackStatus.unavailable;
  if (snapshot.playablePlatforms.contains(platform)) {
    return LxPlaybackStatus.ready;
  }
  // 还有已启用源未加载：此时"不可播"只是未知，值得等一等。
  if (snapshot.warming) return LxPlaybackStatus.preparing;
  return LxPlaybackStatus.unavailable;
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
