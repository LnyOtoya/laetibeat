import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/lx.dart' as rust_lx;

import '../../l10n/generated/app_localizations.dart';

typedef LxSearchKey = ({String platform, String query});

/// Platforms declared by enabled LX sources that can resolve `musicUrl`.
final lxEnabledPlatformsProvider = FutureProvider<List<String>>((ref) async {
  final sources = await rust_lx.listLxSources();
  final platforms = <String>{};
  for (final source in sources) {
    if (!source.enabled) continue;
    for (final capability in source.capabilities) {
      if (!capability.actions.contains('musicUrl')) continue;
      if (capability.sourceType != 'music') continue;
      if (_platformLabels.containsKey(capability.source)) {
        platforms.add(capability.source);
      }
    }
  }
  return platforms.toList(growable: false);
});

/// Independent platform search. It does not require local music or Subsonic.
final lxSearchProvider =
    FutureProvider.family<rust_lx.UiLxSearchPage?, LxSearchKey>((
      ref,
      key,
    ) async {
      final query = key.query.trim();
      if (query.isEmpty) return null;
      return rust_lx.searchLxMusic(
        platform: key.platform,
        keyword: query,
        page: 1,
        limit: 30,
      );
    });

const Map<String, String> _platformLabels = <String, String>{
  'kw': 'kw',
  'kg': 'kg',
  'mg': 'mg',
};

bool isSupportedLxSearchPlatform(String platform) =>
    _platformLabels.containsKey(platform);

String lxPlatformLabel(AppLocalizations l10n, String platform) =>
    switch (platform) {
      'kw' => l10n.lxPlatformKw,
      'kg' => l10n.lxPlatformKg,
      'mg' => l10n.lxPlatformMg,
      _ => platform,
    };
