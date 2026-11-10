import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:laetibeat/widgets/player/lx_search_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'search_models.dart';
import 'search_source_chip.dart';

/// Suggestions shown below the library search bar.
///
/// Sources are intentionally mixed here: the chip tells the user whether a
/// prediction comes from the local library, OpenSubsonic, or LX.
class LibrarySearchSuggestions extends ConsumerWidget {
  const LibrarySearchSuggestions({
    super.key,
    required this.query,
    required this.onSelected,
  });

  final String query;
  final ValueChanged<MobileSearchSuggestion> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Text(
          l10n.searchHint,
          style: theme.typeScale.bodyMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final suggestions = <MobileSearchSuggestion>[];
    final seen = <String>{};
    final perSource = <String, int>{};
    void add(MobileSearchSuggestion suggestion) {
      // Each source/platform contributes at most two predictions.
      final used = perSource[suggestion.sourceLabel] ?? 0;
      if (used >= 2) return;
      final key = '${suggestion.text}\u0000${suggestion.sourceLabel}';
      if (!seen.add(key)) return;
      perSource[suggestion.sourceLabel] = used + 1;
      suggestions.add(suggestion);
    }

    final local = ref.watch(musicLibraryProvider).value;
    if (local != null) {
      _addLocalSuggestions(local, trimmed, l10n, add);
    }

    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    if (servers.isNotEmpty) {
      final server = servers.first;
      final remote = ref
          .watch(remoteSearchProvider((sourceId: server.id, query: trimmed)))
          .value;
      if (remote != null) {
        _addRemoteSuggestions(remote, trimmed, server.name, l10n, add);
      }
    }

    final platforms =
        ref.watch(lxEnabledPlatformsProvider).value ?? const <String>[];
    // Predictions intentionally use QQ Music only.
    if (platforms.contains('tx')) {
      final lx = ref
          .watch(lxSearchProvider((platform: 'tx', query: trimmed)))
          .value;
      if (lx != null) {
        for (final track in lx.tracks.take(2)) {
          add(
            MobileSearchSuggestion(
              text: '${track.name} ${track.singer.join('、')}',
              query: '${track.name} ${track.singer.join(' ')}'.trim(),
              sourceLabel: '洛雪',
              sourceKey: 'tx',
              kindLabel: l10n.librarySongs,
            ),
          );
        }
      }
    }

    if (suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Text(
          l10n.searchNoResults,
          style: theme.typeScale.bodyMedium.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: M3EList(
        color: theme.colorScheme.surface,
        variant: M3ECardVariant.filled,
        itemCount: suggestions.length,
        onTap: (index) => onSelected(suggestions[index]),
        itemBuilder: (BuildContext context, int index) {
          final suggestion = suggestions[index];
          return M3EListItem(
            headline: suggestion.text,
            trailing: SearchSourceChip(
              label: suggestion.sourceLabel,
              sourceKey: suggestion.sourceKey,
            ),
          );
        },
      ),
    );
  }

  void _addLocalSuggestions(
    MusicLibraryState library,
    String query,
    AppLocalizations l10n,
    void Function(MobileSearchSuggestion) add,
  ) {
    final lower = query.toLowerCase();
    bool matches(String value) => value.toLowerCase().contains(lower);

    // Artist-like queries should lead with tracks by that artist, so a query
    // such as "周杰伦" becomes "周杰伦 晴天".
    final artistTracks = library.artists
        .where((artist) => matches(artist.name))
        .expand(
          (artist) => library.tracks.where(
            (track) =>
                track.artist.toLowerCase().contains(artist.name.toLowerCase()),
          ),
        )
        .take(3);
    for (final track in artistTracks) {
      add(
        MobileSearchSuggestion(
          text: '$query ${track.title}',
          query: '$query ${track.title}',
          sourceLabel: l10n.searchSourceLocal,
          kindLabel: l10n.librarySongs,
        ),
      );
    }

    for (final track in library.tracks.where(
      (track) =>
          matches(track.title) || matches(track.artist) || matches(track.album),
    )) {
      add(
        MobileSearchSuggestion(
          text: '$query ${track.title} ${track.artist}',
          query: '${track.title} ${track.artist}',
          sourceLabel: l10n.searchSourceLocal,
          kindLabel: l10n.librarySongs,
        ),
      );
    }
    for (final album in library.albums.where(
      (album) => matches(album.title) || matches(album.artist),
    )) {
      add(
        MobileSearchSuggestion(
          text: '$query ${album.title} ${album.artist}',
          query: '${album.title} ${album.artist}',
          sourceLabel: l10n.searchSourceLocal,
          kindLabel: l10n.libraryAlbums,
        ),
      );
    }
  }

  void _addRemoteSuggestions(
    rust_subsonic.UiRemoteSearchResult remote,
    String query,
    String source,
    AppLocalizations l10n,
    void Function(MobileSearchSuggestion) add,
  ) {
    final sourceKey = source.toLowerCase().contains('navidrome')
        ? 'navidrome'
        : 'subsonic';
    for (final track in remote.tracks.take(2)) {
      add(
        MobileSearchSuggestion(
          text: '$query ${track.title} ${track.artist}',
          query: '${track.title} ${track.artist}',
          sourceLabel: source,
          sourceKey: sourceKey,
          kindLabel: l10n.librarySongs,
        ),
      );
    }
    if (remote.tracks.isEmpty) {
      for (final album in remote.albums.take(2)) {
        add(
          MobileSearchSuggestion(
            text: '$query ${album.title} ${album.artist}',
            query: '${album.title} ${album.artist}',
            sourceLabel: source,
            sourceKey: sourceKey,
            kindLabel: l10n.libraryAlbums,
          ),
        );
      }
      for (final artist in remote.artists.take(2)) {
        add(
          MobileSearchSuggestion(
            text: '$query ${artist.name}',
            query: artist.name,
            sourceLabel: source,
            sourceKey: sourceKey,
            kindLabel: l10n.libraryArtists,
          ),
        );
      }
    }
  }
}

/// Keep the public type visible to callers without importing rust types.
typedef LocalSearchTrack = rust.UiTrack;
