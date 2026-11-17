import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/lx.dart' as rust_lx;

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

/// Platforms that at least one enabled source can resolve `musicUrl` for.
///
/// This is playback capability only. It must never gate search, browsing or
/// playlist subscription.
final lxPlayablePlatformsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
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
});

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

/// Whether [platform] can currently resolve a play URL.
///
/// Callers use this to show a "needs a source" prompt instead of letting the
/// play request fail deep inside the player.
bool lxPlatformCanPlay(WidgetRef ref, String? platform) {
  if (platform == null || platform.isEmpty) return false;
  final playable = ref.read(lxPlayablePlatformsProvider).value;
  if (playable == null) return false;
  return playable.contains(platform);
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
