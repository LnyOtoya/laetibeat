import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/lx.dart' as rust_lx;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:laetibeat/widgets/player/lx_search_provider.dart';
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/lx_track.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/cover_shape_settings.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';
import 'package:laetibeat/widgets/settings/persistence.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../library/albums/album_detail_page.dart';
import '../library/artists/artist_detail_page.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import 'library_search_suggestions.dart';
import 'search_models.dart';
import 'search_source_chip.dart';

/// Full-screen query entry page. Its AppBar contains only the search field;
/// suggestions are shown in the body.
class MobileSearchPage extends ConsumerStatefulWidget {
  const MobileSearchPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<MobileSearchPage> createState() => _MobileSearchPageState();
}

class _MobileSearchPageState extends ConsumerState<MobileSearchPage> {
  static const String _recentSearchKey = 'search.recent_queries';
  static const int _recentSearchLimit = 30;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  List<String> _recentSearches = const <String>[];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery.trim());
    _focusNode = FocusNode();
    _recentSearches =
        ref.read(sharedPreferencesProvider).getStringList(_recentSearchKey) ??
        const <String>[];
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _rememberSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final next = <String>[
      query,
      ..._recentSearches.where((item) => item != query),
    ];
    if (next.length > _recentSearchLimit) {
      next.removeRange(_recentSearchLimit, next.length);
    }
    if (mounted) setState(() => _recentSearches = next);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_recentSearchKey, next);
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches = const <String>[]);
    await ref.read(sharedPreferencesProvider).remove(_recentSearchKey);
  }

  Future<void> _openResults(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    // Persist history before navigating so both submit (keyboard) and
    // suggestion taps share the same guaranteed write path.
    await _rememberSearch(query);
    if (!mounted) return;
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _focusNode.unfocus();
    pushMobileRootPage(
      context,
      MobileSearchResultsPage(initialQuery: query),
      name: MobileRoutes.searchResults,
    );
  }

  Widget _buildHistory(M3EThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.searchRecentTitle,
                style: theme.typeScale.titleMedium,
              ),
            ),
            if (_recentSearches.isNotEmpty)
              M3EButton(
                style: M3EButtonStyle.text,
                size: M3EButtonSize.sm,
                label: Text(l10n.searchRecentClear),
                onPressed: _clearRecentSearches,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentSearches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l10n.searchRecentEmpty,
              style: theme.typeScale.bodyMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          M3EList(
            color: theme.colorScheme.surface,
            variant: M3ECardVariant.filled,
            itemCount: _recentSearches.length,
            onTap: (index) => _openResults(_recentSearches[index]),
            itemBuilder: (BuildContext context, int index) {
              return M3EListItem(
                leading: const Icon(M3EIcons.history),
                headline: _recentSearches[index],
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: M3EAppBar.top(
        backgroundColor: theme.colorScheme.surfaceContainer,
        density: M3EAppBarDensity.compact,
        shapeFamily: M3EAppBarShapeFamily.square,
        title: M3ESearchBar(
          controller: _controller,
          focusNode: _focusNode,
          hintText: l10n.searchHint,
          leading: const Icon(M3EIcons.search),
          showClearButton: true,
          textInputAction: TextInputAction.search,
          expandOnFocus: false,
          autoFocus: true,
          constraints: const BoxConstraints.tightFor(height: 48),
          backgroundColor: WidgetStatePropertyAll<Color?>(
            theme.colorScheme.surfaceContainerHigh,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: _openResults,
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: _controller.text.trim().isEmpty
              ? _buildHistory(theme, l10n)
              : LibrarySearchSuggestions(
                  query: _controller.text,
                  onSelected: (selection) => _openResults(selection.query),
                ),
        ),
      ),
    );
  }
}

/// Actual search results page. This is the page with back/filter split button,
/// category tabs, source chips and result lists.
class MobileSearchResultsPage extends ConsumerStatefulWidget {
  const MobileSearchResultsPage({super.key, required this.initialQuery});

  final String initialQuery;

  @override
  ConsumerState<MobileSearchResultsPage> createState() =>
      _MobileSearchResultsPageState();
}

class _MobileSearchResultsPageState
    extends ConsumerState<MobileSearchResultsPage> {
  late final TextEditingController _controller;
  MobileSearchCategory _category = MobileSearchCategory.songs;
  MobileSearchSourceFilter _filter = MobileSearchSourceFilter.all;
  String _lxPlatform = 'tx';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  void _playLxResults() {
    final l10n = AppLocalizations.of(context);
    final query = widget.initialQuery.trim();
    if (query.isEmpty) return;
    final lx = ref
        .read(lxSearchProvider((platform: _lxPlatform, query: query)))
        .value;
    if (lx == null || lx.tracks.isEmpty) return;
    final tracks = lx.tracks
        .take(10)
        .map(lxSearchTrackToUiTrack)
        .toList(growable: false);
    ref
        .read(playerProvider.notifier)
        .load(tracks, 0, source: '洛雪 · ${lxPlatformLabel(l10n, _lxPlatform)}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: M3EAppBar.top(
        backgroundColor: theme.colorScheme.surfaceContainer,
        density: M3EAppBarDensity.compact,
        shapeFamily: M3EAppBarShapeFamily.square,
        title: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _SearchFilterButton(
              filter: _filter,
              onChanged: (filter) => setState(() => _filter = filter),
              onBack: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: M3ESearchBar(
                controller: _controller,
                hintText: l10n.searchHint,
                leading: const Icon(M3EIcons.search),
                readOnly: true,
                expandOnFocus: false,
                constraints: const BoxConstraints.tightFor(height: 48),
                backgroundColor: WidgetStatePropertyAll<Color?>(
                  theme.colorScheme.surfaceContainerHigh,
                ),
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _CategoryTabs(
                selected: _category,
                onSelected: (category) => setState(() => _category = category),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return SizeTransition(
                  sizeFactor: curved,
                  alignment: Alignment.topCenter,
                  child: FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.22),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  ),
                );
              },
              child: _filter == MobileSearchSourceFilter.lx
                  ? _LxPlatformBar(
                      key: const ValueKey<String>('lx-platform-bar'),
                      platform: _lxPlatform,
                      onPlay: _playLxResults,
                      onChanged: (platform) =>
                          setState(() => _lxPlatform = platform),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey<String>('lx-platform-hidden'),
                    ),
            ),
            Expanded(
              child: _SearchResults(
                query: widget.initialQuery,
                category: _category,
                filter: _filter,
                lxPlatform: _filter == MobileSearchSourceFilter.lx
                    ? _lxPlatform
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.selected, required this.onSelected});

  final MobileSearchCategory selected;
  final ValueChanged<MobileSearchCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    M3EButtonGroupAction action(IconData icon, String label) {
      return M3EButtonGroupAction(icon: Icon(icon), label: Text(label));
    }

    return M3EButtonGroup(
      type: M3EButtonGroupType.standard,
      shape: M3EButtonShape.round,
      size: M3EButtonSize.sm,
      style: M3EButtonStyle.filled,
      multiSelect: false,
      selectionRequired: true,
      neighborSquish: true,
      overflow: M3EButtonGroupOverflow.scroll,
      selectedIndex: selected.index,
      onSelectedIndexChanged: (int? index) {
        if (index == null) return;
        onSelected(MobileSearchCategory.values[index]);
      },
      actions: <M3EButtonGroupAction>[
        action(M3EIcons.music_note, l10n.librarySongs),
        action(M3EIcons.queue_music, l10n.libraryPlaylists),
        action(M3EIcons.album, l10n.libraryAlbums),
        action(M3EIcons.person, l10n.libraryArtists),
      ],
    );
  }
}

class _LxPlatformBar extends StatelessWidget {
  const _LxPlatformBar({
    super.key,
    required this.platform,
    required this.onChanged,
    required this.onPlay,
  });

  static const List<String> _platforms = <String>['tx', 'wy', 'mg', 'kg', 'kw'];

  final String platform;
  final ValueChanged<String> onChanged;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: <Widget>[
          M3EButton.icon(
            icon: const Icon(M3EIcons.play_arrow),
            label: Text(l10n.play),
            style: M3EButtonStyle.filled,
            size: M3EButtonSize.sm,
            shape: M3EButtonShape.round,
            onPressed: onPlay,
          ),
          const Spacer(),
          M3ESplitButton<String>(
            size: M3EButtonSize.sm,
            shape: M3EButtonShape.round,
            style: M3EButtonStyle.tonal,
            label: lxPlatformLabel(l10n, platform),
            leadingIcon: M3EIcons.music_note,
            selectedValue: platform,
            trailingTooltip: l10n.searchFilter,
            onPressed: () {},
            onSelected: onChanged,
            items: <M3ESplitButtonItem<String>>[
              for (final item in _platforms)
                M3ESplitButtonItem(
                  value: item,
                  child: Text(lxPlatformLabel(l10n, item)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchFilterButton extends StatelessWidget {
  const _SearchFilterButton({
    required this.filter,
    required this.onChanged,
    required this.onBack,
  });

  final MobileSearchSourceFilter filter;
  final ValueChanged<MobileSearchSourceFilter> onChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return M3ESplitButton<MobileSearchSourceFilter>(
      size: M3EButtonSize.sm,
      shape: M3EButtonShape.round,
      style: M3EButtonStyle.tonal,
      leadingIcon: M3EIcons.arrow_back,
      leadingTooltip: l10n.searchBack,
      trailingTooltip: l10n.searchFilter,
      onPressed: onBack,
      selectedValue: filter,
      onSelected: onChanged,
      items: <M3ESplitButtonItem<MobileSearchSourceFilter>>[
        M3ESplitButtonItem(
          value: MobileSearchSourceFilter.all,
          child: Text(l10n.searchFilterAll),
        ),
        M3ESplitButtonItem(
          value: MobileSearchSourceFilter.local,
          child: Text(l10n.searchSourceLocal),
        ),
        M3ESplitButtonItem(
          value: MobileSearchSourceFilter.subsonic,
          child: Text(l10n.searchFilterSubsonic),
        ),
        M3ESplitButtonItem(
          value: MobileSearchSourceFilter.lx,
          child: Text(l10n.searchFilterLx),
        ),
      ],
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.category,
    required this.filter,
    this.lxPlatform,
  });

  final String query;
  final MobileSearchCategory category;
  final MobileSearchSourceFilter filter;
  final String? lxPlatform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    if (category == MobileSearchCategory.songs &&
        filter == MobileSearchSourceFilter.lx &&
        lxPlatform != null) {
      return _LxPlatformResults(
        key: ValueKey<String>('$query\u0000$lxPlatform'),
        query: query,
        platform: lxPlatform!,
      );
    }
    final local = ref.watch(musicLibraryProvider).value;
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final server = servers.isEmpty ? null : servers.first;
    final remoteAsync = server == null
        ? null
        : ref.watch(remoteSearchProvider((sourceId: server.id, query: query)));
    final platforms =
        ref.watch(lxEnabledPlatformsProvider).value ?? const <String>[];
    final lxPages = <String, rust_lx.UiLxSearchPage?>{};
    var lxLoading = false;
    for (final platform in platforms) {
      final async = ref.watch(
        lxSearchProvider((platform: platform, query: query)),
      );
      lxPages[platform] = async.value;
      lxLoading = lxLoading || async.isLoading;
    }

    final children = <Widget>[];
    if ((remoteAsync?.isLoading ?? false) || lxLoading) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: LinearProgressIndicator(
            minHeight: 2,
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    final remote = remoteAsync?.value;
    children.addAll(switch (category) {
      MobileSearchCategory.songs => _buildSongs(
        context,
        ref,
        local,
        remote,
        lxPages,
        server,
        l10n,
      ),
      MobileSearchCategory.playlists => _buildPlaylists(
        context,
        ref,
        server,
        l10n,
      ),
      MobileSearchCategory.albums => _buildAlbums(
        context,
        ref,
        local,
        remote,
        server,
        l10n,
      ),
      MobileSearchCategory.artists => _buildArtists(
        context,
        local,
        remote,
        server,
        l10n,
      ),
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: children,
    );
  }

  List<Widget> _buildSongs(
    BuildContext context,
    WidgetRef ref,
    MusicLibraryState? local,
    rust_subsonic.UiRemoteSearchResult? remote,
    Map<String, rust_lx.UiLxSearchPage?> lxPages,
    SubsonicServerConfig? server,
    AppLocalizations l10n,
  ) {
    final entries = <_SongEntry>[];
    final lower = query.toLowerCase();
    if (local != null && _includesLocal) {
      for (final track in local.tracks.where(
        (track) => _matchesTrack(track, lower),
      )) {
        entries.add(
          _SongEntry(
            track: track,
            source: l10n.searchSourceLocal,
            sourceKey: 'local',
          ),
        );
      }
    }
    if (remote != null && _includesSubsonic) {
      for (final track in remote.tracks) {
        entries.add(
          _SongEntry(
            track: remoteTrackToUiTrack(track, server!.id),
            source: server.name,
            sourceKey: server.name.toLowerCase().contains('navidrome')
                ? 'navidrome'
                : 'subsonic',
          ),
        );
      }
    }
    if (_includesLx) {
      for (final entry in lxPages.entries) {
        final lx = entry.value;
        if (lx == null) continue;
        for (final track in lx.tracks) {
          entries.add(
            _SongEntry(
              track: lxSearchTrackToUiTrack(track),
              source: '洛雪',
              sourceKey: entry.key,
            ),
          );
        }
      }
    }
    if (entries.isEmpty) return <Widget>[_empty(l10n)];
    final tracks = entries.map((entry) => entry.track).toList(growable: false);
    return <Widget>[
      M3EList(
        color: M3ETheme.of(context).colorScheme.surface,
        variant: M3ECardVariant.filled,
        itemCount: entries.length,
        onTap: (index) =>
            ref.read(playerProvider.notifier).load(tracks, index, source: '搜索'),
        itemBuilder: (BuildContext context, int index) {
          final entry = entries[index];
          return M3EListItem(
            leading: _SearchResultCover(track: entry.track),
            headline: entry.track.title,
            supportingText: entry.track.artist,
            trailing: filter == MobileSearchSourceFilter.all
                ? _sourceChip(entry.source, entry.sourceKey)
                : null,
          );
        },
      ),
    ];
  }

  List<Widget> _buildPlaylists(
    BuildContext context,
    WidgetRef ref,
    SubsonicServerConfig? server,
    AppLocalizations l10n,
  ) {
    if (server == null || !_includesSubsonic) return <Widget>[_empty(l10n)];
    final playlists = ref.watch(remotePlaylistsProvider(server.id)).value;
    if (playlists == null) return <Widget>[_loading()];
    final lower = query.toLowerCase();
    final matches = playlists
        .where((playlist) => playlist.name.toLowerCase().contains(lower))
        .toList(growable: false);
    if (matches.isEmpty) return <Widget>[_empty(l10n)];
    return <Widget>[
      M3EList(
        color: M3ETheme.of(context).colorScheme.surface,
        variant: M3ECardVariant.filled,
        itemCount: matches.length,
        itemBuilder: (BuildContext context, int index) {
          final playlist = matches[index];
          return M3EListItem(
            headline: playlist.name,
            supportingText: playlist.owner ?? '',
            trailing: filter == MobileSearchSourceFilter.all
                ? _sourceChip(
                    server.name,
                    server.name.toLowerCase().contains('navidrome')
                        ? 'navidrome'
                        : 'subsonic',
                  )
                : null,
          );
        },
      ),
    ];
  }

  List<Widget> _buildAlbums(
    BuildContext context,
    WidgetRef ref,
    MusicLibraryState? local,
    rust_subsonic.UiRemoteSearchResult? remote,
    SubsonicServerConfig? server,
    AppLocalizations l10n,
  ) {
    final lower = query.toLowerCase();
    final children = <Widget>[];
    final localAlbums = _includesLocal && local != null
        ? local.albums
              .where(
                (album) =>
                    album.title.toLowerCase().contains(lower) ||
                    album.artist.toLowerCase().contains(lower),
              )
              .toList(growable: false)
        : const <rust.UiAlbum>[];
    final remoteAlbums = _includesSubsonic && remote != null
        ? remote.albums
              .where(
                (album) =>
                    album.title.toLowerCase().contains(lower) ||
                    album.artist.toLowerCase().contains(lower),
              )
              .toList(growable: false)
        : const <rust_subsonic.UiRemoteAlbum>[];
    if (localAlbums.isEmpty && remoteAlbums.isEmpty) {
      return <Widget>[_empty(l10n)];
    }
    if (localAlbums.isNotEmpty) {
      children.add(
        M3EList(
          color: M3ETheme.of(context).colorScheme.surface,
          variant: M3ECardVariant.filled,
          itemCount: localAlbums.length,
          onTap: (index) => _playLocalAlbum(ref, local!, localAlbums[index]),
          itemBuilder: (BuildContext context, int index) {
            final album = localAlbums[index];
            return M3EListItem(
              headline: album.title,
              supportingText: album.artist,
              trailing: filter == MobileSearchSourceFilter.all
                  ? _sourceChip(l10n.searchSourceLocal, 'local')
                  : null,
            );
          },
        ),
      );
    }
    if (remoteAlbums.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        M3EList(
          color: M3ETheme.of(context).colorScheme.surface,
          variant: M3ECardVariant.filled,
          itemCount: remoteAlbums.length,
          onTap: (index) => pushMobileRootPage(
            context,
            AlbumDetailPage(sourceId: server!.id, album: remoteAlbums[index]),
            name: MobileRoutes.albumDetail,
          ),
          itemBuilder: (BuildContext context, int index) {
            final album = remoteAlbums[index];
            return M3EListItem(
              headline: album.title,
              supportingText: album.artist,
              trailing: filter == MobileSearchSourceFilter.all
                  ? _sourceChip(
                      server?.name ?? 'Subsonic',
                      (server?.name.toLowerCase().contains('navidrome') ??
                              false)
                          ? 'navidrome'
                          : 'subsonic',
                    )
                  : null,
            );
          },
        ),
      );
    }
    return children;
  }

  List<Widget> _buildArtists(
    BuildContext context,
    MusicLibraryState? local,
    rust_subsonic.UiRemoteSearchResult? remote,
    SubsonicServerConfig? server,
    AppLocalizations l10n,
  ) {
    final lower = query.toLowerCase();
    final children = <Widget>[];
    final localArtists = _includesLocal && local != null
        ? local.artists
              .where((artist) => artist.name.toLowerCase().contains(lower))
              .toList(growable: false)
        : const <rust.UiArtist>[];
    final remoteArtists = _includesSubsonic && remote != null
        ? remote.artists
              .where((artist) => artist.name.toLowerCase().contains(lower))
              .toList(growable: false)
        : const <rust_subsonic.UiRemoteArtist>[];
    if (localArtists.isEmpty && remoteArtists.isEmpty) {
      return <Widget>[_empty(l10n)];
    }
    if (localArtists.isNotEmpty) {
      children.add(
        M3EList(
          color: M3ETheme.of(context).colorScheme.surface,
          variant: M3ECardVariant.filled,
          itemCount: localArtists.length,
          itemBuilder: (BuildContext context, int index) {
            final artist = localArtists[index];
            return M3EListItem(
              headline: artist.name,
              trailing: filter == MobileSearchSourceFilter.all
                  ? _sourceChip(l10n.searchSourceLocal, 'local')
                  : null,
            );
          },
        ),
      );
    }
    if (remoteArtists.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        M3EList(
          color: M3ETheme.of(context).colorScheme.surface,
          variant: M3ECardVariant.filled,
          itemCount: remoteArtists.length,
          onTap: (index) => pushMobileRootPage(
            context,
            ArtistDetailPage(
              sourceId: server!.id,
              artist: remoteArtists[index],
            ),
            name: MobileRoutes.artistDetail,
          ),
          itemBuilder: (BuildContext context, int index) {
            final artist = remoteArtists[index];
            return M3EListItem(
              headline: artist.name,
              trailing: filter == MobileSearchSourceFilter.all
                  ? _sourceChip(
                      server?.name ?? 'Subsonic',
                      (server?.name.toLowerCase().contains('navidrome') ??
                              false)
                          ? 'navidrome'
                          : 'subsonic',
                    )
                  : null,
            );
          },
        ),
      );
    }
    return children;
  }

  bool get _includesLocal =>
      filter == MobileSearchSourceFilter.all ||
      filter == MobileSearchSourceFilter.local;

  bool get _includesSubsonic =>
      filter == MobileSearchSourceFilter.all ||
      filter == MobileSearchSourceFilter.subsonic;

  bool get _includesLx =>
      filter == MobileSearchSourceFilter.all ||
      filter == MobileSearchSourceFilter.lx;

  bool _matchesTrack(rust.UiTrack track, String lower) =>
      track.title.toLowerCase().contains(lower) ||
      track.artist.toLowerCase().contains(lower) ||
      track.album.toLowerCase().contains(lower);

  void _playLocalAlbum(
    WidgetRef ref,
    MusicLibraryState library,
    rust.UiAlbum album,
  ) {
    final byId = {for (final track in library.tracks) track.id: track};
    final tracks = <rust.UiTrack>[
      for (final id in album.trackIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (tracks.isEmpty) return;
    ref.read(playerProvider.notifier).load(tracks, 0, source: album.title);
  }
}

class _LxPlatformResults extends ConsumerStatefulWidget {
  const _LxPlatformResults({
    super.key,
    required this.query,
    required this.platform,
  });

  final String query;
  final String platform;

  @override
  ConsumerState<_LxPlatformResults> createState() => _LxPlatformResultsState();
}

class _LxPlatformResultsState extends ConsumerState<_LxPlatformResults> {
  static const Duration _loadMoreDelay = Duration(seconds: 3);
  static const int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  List<rust_lx.UiLxSearchTrack> _tracks = const [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_fetch(reset: true));
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 240) {
      unawaited(_loadMore());
    }
  }

  void _ensureViewportFilled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loading || _loadingMore || !_hasMore) return;
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= 0) {
        unawaited(_loadMore());
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    await Future<void>.delayed(_loadMoreDelay);
    if (!mounted) return;
    await _fetch(reset: false);
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _fetch({required bool reset}) async {
    final generation = ++_generation;
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _error = null;
        _tracks = const [];
        _page = 0;
        _hasMore = true;
      });
    }
    try {
      final result = await rust_lx.searchLxMusic(
        platform: widget.platform,
        keyword: widget.query,
        page: reset ? 1 : _page + 1,
        limit: _pageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) {
          _tracks = result.tracks;
          _hasMore = result.hasMore;
        } else {
          final knownIds = _tracks.map((track) => track.id).toSet();
          final fresh = result.tracks
              .where((track) => knownIds.add(track.id))
              .toList(growable: false);
          _tracks = <rust_lx.UiLxSearchTrack>[..._tracks, ...fresh];
          _hasMore = result.hasMore && fresh.isNotEmpty;
        }
        _page = result.page;
        _loading = false;
      });
      _ensureViewportFilled();
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    if (_loading && _tracks.isEmpty) {
      return Center(
        child: M3ELoadingIndicator(
          color: theme.colorScheme.primary,
          containerColor: theme.colorScheme.surfaceContainerHighest,
        ),
      );
    }
    if (_error != null && _tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.typeScale.bodySmall.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
              M3EButton(
                label: Text(l10n.lxSourceRetry),
                onPressed: () => unawaited(_fetch(reset: true)),
              ),
            ],
          ),
        ),
      );
    }
    if (_tracks.isEmpty) {
      return Center(child: Text(l10n.searchNoResults));
    }

    final tracks = _tracks.map(lxSearchTrackToUiTrack).toList(growable: false);
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        M3EList(
          color: theme.colorScheme.surface,
          variant: M3ECardVariant.filled,
          itemCount: _tracks.length,
          onTap: (index) => ref
              .read(playerProvider.notifier)
              .load(tracks, index, source: '洛雪'),
          itemBuilder: (BuildContext context, int index) {
            final track = _tracks[index];
            return M3EListItem(
              leading: _SearchResultCover(track: tracks[index]),
              headline: track.name,
              supportingText: track.singer.join('、'),
            );
          },
        ),
        if (_loadingMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: M3ELoadingIndicator(
                variant: M3ELoadingIndicatorVariant.contained,
                size: 48,
                color: theme.colorScheme.primary,
                containerColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchResultCover extends ConsumerWidget {
  const _SearchResultCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final shape = ref.watch(searchCoverShapeProvider);
    final hasArt = bytes != null && bytes.isNotEmpty;
    return M3EShapeContainer(
      kind: shape,
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: theme.colorScheme.secondaryContainer,
        child: hasArt
            ? Image.memory(bytes, fit: BoxFit.cover)
            : Icon(
                M3EIcons.music_note,
                size: 20,
                color: theme.colorScheme.onSecondaryContainer,
              ),
      ),
    );
  }
}

class _SongEntry {
  const _SongEntry({
    required this.track,
    required this.source,
    required this.sourceKey,
  });

  final rust.UiTrack track;
  final String source;
  final String sourceKey;
}

Widget _sourceChip(String label, String sourceKey) {
  return SearchSourceChip(label: label, sourceKey: sourceKey);
}

Widget _empty(AppLocalizations l10n) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(child: Text(l10n.searchNoResults)),
  );
}

Widget _loading() {
  return const Padding(
    padding: EdgeInsets.symmetric(vertical: 32),
    child: Center(child: CircularProgressIndicator()),
  );
}
