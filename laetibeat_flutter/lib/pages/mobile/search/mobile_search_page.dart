import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/lx.dart' as rust_lx;
import 'package:laetibeat/src/rust/api/online.dart' as rust_online;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:laetibeat/widgets/player/lx_search_provider.dart';
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/lx_track.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/playlist_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/cover_shape_settings.dart';
import 'package:laetibeat/widgets/settings/music_library_provider.dart';
import 'package:laetibeat/widgets/settings/online_provider.dart';
import 'package:laetibeat/widgets/settings/persistence.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_mode.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/layout/app_bottom_inset.dart';
import '../library/albums/album_detail_page.dart';
import '../library/artists/artist_detail_page.dart';
import '../library/playlists/local_playlist_detail_page.dart';
import '../library/playlists/lx_playlist_preview_page.dart';
import '../library/playlists/playlist_actions.dart';
import '../library/online/online_detail_pages.dart';
import '../library/online/online_widgets.dart';
import '../library/playlists/remote_playlist_detail_page.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
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
  static const int _recentSearchLimit = 30;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final String _recentSearchKey;
  List<String> _recentSearches = const <String>[];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery.trim());
    _focusNode = FocusNode();
    _recentSearchKey = searchHistoryKeyForMode(ref.read(appModeProvider));
    final preferences = ref.read(sharedPreferencesProvider);
    _recentSearches =
        preferences.getStringList(_recentSearchKey) ??
        preferences.getStringList(legacySearchHistoryKey) ??
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
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_recentSearchKey, const <String>[]);
  }

  Widget _buildQuerySuggestion(M3EThemeData theme, String query) {
    return M3EList(
      color: theme.colorScheme.surfaceContainerLow,
      variant: M3ECardVariant.filled,
      itemCount: 1,
      onTap: (_) => _openResults(query),
      itemBuilder: (BuildContext context, int index) => M3EListItem(
        leading: const Icon(M3EIcons.search),
        headline: query,
        supportingText: AppLocalizations.of(context).searchHint,
        trailing: const Icon(M3EIcons.arrow_forward),
      ),
    );
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
            color: theme.colorScheme.surfaceContainerLow,
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
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      appBar: M3EAppBar.top(
        backgroundColor: theme.colorScheme.surfaceContainerLow,
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
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
          child: _controller.text.trim().isEmpty
              ? _buildHistory(theme, l10n)
              : _buildQuerySuggestion(theme, _controller.text.trim()),
        ),
      ),
    );
  }
}

/// Search results are restricted to the active app mode.
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
  late final String _recentSearchKey;
  List<String> _recentSearches = const <String>[];
  String _submittedQuery = '';
  MobileSearchCategory _category = MobileSearchCategory.songs;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _submittedQuery = widget.initialQuery.trim();
    _recentSearchKey = searchHistoryKeyForMode(ref.read(appModeProvider));
    final preferences = ref.read(sharedPreferencesProvider);
    _recentSearches =
        preferences.getStringList(_recentSearchKey) ??
        preferences.getStringList(legacySearchHistoryKey) ??
        const <String>[];
  }

  Future<void> _rememberSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final next = <String>[
      query,
      ..._recentSearches.where((item) => item != query),
    ];
    if (next.length > 30) {
      next.removeRange(30, next.length);
    }
    if (mounted) setState(() => _recentSearches = next);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_recentSearchKey, next);
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches = const <String>[]);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_recentSearchKey, const <String>[]);
  }

  Future<void> _submitQuery(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    await _rememberSearch(query);
    if (!mounted) return;
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    FocusScope.of(context).unfocus();
    setState(() => _submittedQuery = query);
  }

  void _onQueryChanged(String value) {
    if (_submittedQuery.isNotEmpty && value.trim() != _submittedQuery) {
      setState(() => _submittedQuery = '');
    }
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
            color: theme.colorScheme.surfaceContainerLow,
            variant: M3ECardVariant.filled,
            itemCount: _recentSearches.length,
            onTap: (index) => unawaited(_submitQuery(_recentSearches[index])),
            itemBuilder: (BuildContext context, int index) => M3EListItem(
              leading: const Icon(M3EIcons.history),
              headline: _recentSearches[index],
            ),
          ),
      ],
    );
  }

  Widget _buildQuerySuggestion(M3EThemeData theme, String query) {
    return M3EList(
      color: theme.colorScheme.surfaceContainerLow,
      variant: M3ECardVariant.filled,
      itemCount: 1,
      onTap: (_) => unawaited(_submitQuery(query)),
      itemBuilder: (BuildContext context, int index) => M3EListItem(
        leading: const Icon(M3EIcons.search),
        headline: query,
        supportingText: AppLocalizations.of(context).searchHint,
        trailing: const Icon(M3EIcons.arrow_forward),
      ),
    );
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
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final mode = ref.watch(appModeProvider);
    final categories = searchCategoriesForMode(mode);
    final selectedCategory = categories.contains(_category)
        ? _category
        : categories.first;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      appBar: M3EAppBar.top(
        backgroundColor: theme.colorScheme.surfaceContainerLow,
        density: M3EAppBarDensity.compact,
        shapeFamily: M3EAppBarShapeFamily.square,
        title: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            IconButton(
              tooltip: l10n.searchBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(M3EIcons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: M3ESearchBar(
                controller: _controller,
                hintText: l10n.searchHint,
                leading: const Icon(M3EIcons.search),
                showClearButton: true,
                expandOnFocus: false,
                constraints: const BoxConstraints.tightFor(height: 48),
                backgroundColor: WidgetStatePropertyAll<Color?>(
                  theme.colorScheme.surfaceContainerHigh,
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (value) => unawaited(_submitQuery(value)),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _submittedQuery.isEmpty
            ? SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
                child: _controller.text.trim().isEmpty
                    ? _buildHistory(theme, l10n)
                    : _buildQuerySuggestion(theme, _controller.text.trim()),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _CategoryTabs(
                      categories: categories,
                      selected: selectedCategory,
                      onSelected: (category) =>
                          setState(() => _category = category),
                    ),
                  ),
                  Expanded(
                    child: _SearchResults(
                      query: _submittedQuery,
                      category: selectedCategory,
                      filter: searchSourceForMode(mode),
                      lxPlatform: null,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<MobileSearchCategory> categories;
  final MobileSearchCategory selected;
  final ValueChanged<MobileSearchCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(MobileSearchCategory category) => switch (category) {
      MobileSearchCategory.songs => l10n.librarySongs,
      MobileSearchCategory.playlists => l10n.libraryPlaylists,
      MobileSearchCategory.albums => l10n.libraryAlbums,
      MobileSearchCategory.artists => l10n.libraryArtists,
    };
    IconData icon(MobileSearchCategory category) => switch (category) {
      MobileSearchCategory.songs => M3EIcons.music_note,
      MobileSearchCategory.playlists => M3EIcons.queue_music,
      MobileSearchCategory.albums => M3EIcons.album,
      MobileSearchCategory.artists => M3EIcons.person,
    };

    return M3ESegmentedButton<MobileSearchCategory>(
      segments: <M3ESegment<MobileSearchCategory>>[
        for (final category in categories)
          M3ESegment<MobileSearchCategory>(
            value: category,
            label: label(category),
            icon: Icon(icon(category)),
          ),
      ],
      selected: <MobileSearchCategory>{selected},
      showSelectedIcon: false,
      semanticLabel: l10n.navSearch,
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) onSelected(selection.first);
      },
    );
  }
}

class _LxAlbumGroup {
  _LxAlbumGroup({
    required this.title,
    required this.artist,
    required this.tracks,
  });

  final String title;
  final String artist;
  final List<rust.UiTrack> tracks;
}

class _LxArtistGroup {
  _LxArtistGroup({required this.name, required this.tracks});

  final String name;
  final List<rust.UiTrack> tracks;
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.category,
    required this.filter,
    required this.lxPlatform,
  });

  final String query;
  final MobileSearchCategory category;
  final MobileSearchSourceFilter filter;
  final String? lxPlatform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final appMode = ref.watch(appModeProvider);
    final filterSource = switch (filter) {
      MobileSearchSourceFilter.qq => 'qq',
      MobileSearchSourceFilter.netease => 'netease',
      _ => null,
    };
    final onlineSource = filterSource == appMode.hostId ? filterSource : null;
    if (filterSource != null && onlineSource == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '当前模式不提供 ${onlineSourceLabel(filterSource)} 搜索，请先切换音源模式。',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (onlineSource != null) {
      return switch (category) {
        MobileSearchCategory.songs => _OnlineSongsResults(
          query: query,
          source: onlineSource,
        ),
        MobileSearchCategory.playlists => _OnlinePlaylistResults(
          query: query,
          source: onlineSource,
        ),
        MobileSearchCategory.albums => _OnlineAlbumResults(
          query: query,
          source: onlineSource,
        ),
        MobileSearchCategory.artists => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '${onlineSourceLabel(onlineSource)}暂不支持艺人搜索',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      };
    }
    if (category == MobileSearchCategory.songs &&
        (filter == MobileSearchSourceFilter.all ||
            filter == MobileSearchSourceFilter.local ||
            filter == MobileSearchSourceFilter.subsonic)) {
      return _PagedSongsResults(
        key: ValueKey<String>('$query\u0000${filter.name}'),
        query: query,
        filter: filter,
      );
    }
    if (category == MobileSearchCategory.songs &&
        filter == MobileSearchSourceFilter.lx &&
        lxPlatform != null) {
      return _LxPlatformResults(
        key: ValueKey<String>('$query\u0000$lxPlatform'),
        query: query,
        platform: lxPlatform!,
      );
    }
    final isPlaylistCategory = category == MobileSearchCategory.playlists;
    final isLxFilter = filter == MobileSearchSourceFilter.lx;
    if (isLxFilter && lxPlatform == null) {
      // 只会发生在内置平台表尚未返回（或宿主初始化失败）时。
      final platformsAsync = ref.watch(lxPlatformsProvider);
      if (platformsAsync.isLoading) return _loading();
      if (platformsAsync.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              platformsAsync.error.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return Center(child: Text(l10n.searchNoResults));
    }
    final local = !_includesLocal || isPlaylistCategory || isLxFilter
        ? null
        : ref.watch(musicLibraryProvider).value;
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final server = servers.isEmpty ? null : servers.first;
    final remoteAsync =
        server == null || !_includesSubsonic || isPlaylistCategory || isLxFilter
        ? null
        : ref.watch(remoteSearchProvider((sourceId: server.id, query: query)));
    final lxPage =
        isLxFilter &&
            !isPlaylistCategory &&
            category != MobileSearchCategory.songs &&
            lxPlatform != null
        ? ref.watch(lxSearchProvider((platform: lxPlatform!, query: query)))
        : null;
    final children = <Widget>[];
    if ((remoteAsync?.isLoading ?? false) || (lxPage?.isLoading ?? false)) {
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
      // 歌曲由上面的分页列表提前返回，这里不会真正渲染。
      MobileSearchCategory.songs => const <Widget>[],
      MobileSearchCategory.playlists => _buildPlaylists(
        context,
        ref,
        server,
        l10n,
        lxPlatform,
      ),
      MobileSearchCategory.albums => _buildAlbums(
        context,
        ref,
        local,
        remote,
        server,
        l10n,
        lxPage?.value,
        lxPlatform,
      ),
      MobileSearchCategory.artists => _buildArtists(
        context,
        ref,
        local,
        remote,
        server,
        l10n,
        lxPage?.value,
        lxPlatform,
      ),
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: children,
    );
  }

  List<Widget> _buildPlaylists(
    BuildContext context,
    WidgetRef ref,
    SubsonicServerConfig? server,
    AppLocalizations l10n,
    String? lxPlatform,
  ) {
    final widgets = <Widget>[];
    if (_includesLocal) {
      // 本地（含订阅）歌单：与歌曲/专辑一样属于媒体库内容，必须能搜到。
      final localPlaylists = ref.watch(localPlaylistsProvider).value;
      if (localPlaylists != null) {
        final lower = query.toLowerCase();
        final matches = localPlaylists
            .where((playlist) => playlist.name.toLowerCase().contains(lower))
            .toList(growable: false);
        if (matches.isNotEmpty) {
          widgets.add(
            M3EList(
              color: M3ETheme.of(context).colorScheme.surface,
              variant: M3ECardVariant.filled,
              itemCount: matches.length,
              onTap: (int index) => pushMobileRootPage(
                context,
                LocalPlaylistDetailPage(playlistId: matches[index].id),
                name: MobileRoutes.libraryPlaylists,
              ),
              itemBuilder: (BuildContext context, int index) {
                final playlist = matches[index];
                final platform = playlist.source;
                final isLx = platform != null && platform.isNotEmpty;
                return M3EListItem(
                  headline: playlist.name,
                  supportingText: l10n.librarySongsCount(
                    playlist.itemCount.toInt(),
                  ),
                  trailing: filter == MobileSearchSourceFilter.all
                      ? _sourceChip(
                          isLx
                              ? 'LX · ${lxPlatformLabel(l10n, platform)}'
                              : l10n.searchSourceLocal,
                          platform ?? 'local',
                        )
                      : null,
                );
              },
            ),
          );
        }
      }
    }
    if (server != null && _includesSubsonic) {
      final playlists = ref.watch(remotePlaylistsProvider(server.id)).value;
      if (playlists != null) {
        final lower = query.toLowerCase();
        final matches = playlists
            .where((playlist) => playlist.name.toLowerCase().contains(lower))
            .toList(growable: false);
        if (matches.isNotEmpty) {
          widgets.add(
            M3EList(
              color: M3ETheme.of(context).colorScheme.surface,
              variant: M3ECardVariant.filled,
              itemCount: matches.length,
              onTap: (int index) {
                final playlist = matches[index];
                pushMobileRootPage(
                  context,
                  RemotePlaylistDetailPage(
                    sourceId: server.id,
                    playlist: playlist,
                  ),
                  name: MobileRoutes.libraryPlaylists,
                );
              },
              itemBuilder: (BuildContext context, int index) {
                final playlist = matches[index];
                return M3EListItem(
                  headline: playlist.name,
                  supportingText: playlist.owner ?? '',
                );
              },
            ),
          );
        }
      } else {
        widgets.add(_loading());
      }
    }
    if (_includesLx && lxPlatform != null) {
      final platform = lxPlatform;
      final lxAsync = ref.watch(
        lxPlaylistSearchProvider((platform: platform, query: query)),
      );
      final lx = lxAsync.value;
      if (lx == null) {
        if (lxAsync.isLoading) {
          widgets.add(_loading());
        } else if (lxAsync.hasError) {
          // 当前 kg / wy / mg 尚未实现歌单搜索，后端返回 "not implemented"。
          // 换成可读文案，而不是把英文错误直接丢给用户。
          final message = lxAsync.error.toString();
          final unsupported = message.contains('not implemented');
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: <Widget>[
                  Icon(
                    M3EIcons.info,
                    color: M3ETheme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    unsupported ? l10n.lxPlaylistSearchUnsupported : message,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
      } else if (lx.isNotEmpty) {
        widgets.add(
          M3EList(
            color: M3ETheme.of(context).colorScheme.surface,
            variant: M3ECardVariant.filled,
            itemCount: lx.length,
            onTap: (int index) {
              final playlist = lx[index];
              pushMobileRootPage(
                context,
                LxPlaylistPreviewPage(platform: platform, playlist: playlist),
                name: MobileRoutes.libraryPlaylists,
              );
            },
            itemBuilder: (BuildContext context, int index) {
              final playlist = lx[index];
              return M3EListItem(
                headline: playlist.name,
                supportingText: playlist.author,
                trailing: _sourceChip(
                  'LX · ${lxPlatformLabel(l10n, platform)}',
                  platform,
                ),
              );
            },
          ),
        );
      }
    }
    if (widgets.isEmpty) {
      return <Widget>[_empty(l10n, message: l10n.searchNoPlaylistResults)];
    }
    return widgets;
  }

  List<Widget> _buildAlbums(
    BuildContext context,
    WidgetRef ref,
    MusicLibraryState? local,
    rust_subsonic.UiRemoteSearchResult? remote,
    SubsonicServerConfig? server,
    AppLocalizations l10n,
    rust_lx.UiLxSearchPage? lxPage,
    String? lxPlatform,
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
    final lxAlbums = filter == MobileSearchSourceFilter.lx
        ? _lxAlbumGroups(lxPage)
        : const <_LxAlbumGroup>[];
    if (localAlbums.isEmpty && remoteAlbums.isEmpty && lxAlbums.isEmpty) {
      return <Widget>[_empty(l10n, message: l10n.searchNoAlbumResults)];
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
    if (lxAlbums.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        M3EList(
          color: M3ETheme.of(context).colorScheme.surface,
          variant: M3ECardVariant.filled,
          itemCount: lxAlbums.length,
          onTap: (int index) {
            final album = lxAlbums[index];
            unawaited(
              _playLxTracks(
                context,
                ref,
                l10n,
                lxPlatform,
                album.tracks,
                '洛雪 · ${lxPlatformLabel(l10n, lxPlatform ?? '')} · ${album.title}',
              ),
            );
          },
          itemBuilder: (BuildContext context, int index) {
            final album = lxAlbums[index];
            return M3EListItem(
              leading: _SearchResultCover(track: album.tracks.first),
              headline: album.title,
              supportingText: album.artist,
              trailing: _sourceChip(
                'LX · ${lxPlatformLabel(l10n, lxPlatform ?? '')}',
                lxPlatform ?? '',
              ),
            );
          },
        ),
      );
    }
    return children;
  }

  List<_LxAlbumGroup> _lxAlbumGroups(rust_lx.UiLxSearchPage? page) {
    if (page == null) return const <_LxAlbumGroup>[];
    final groups = <String, _LxAlbumGroup>{};
    for (final raw in page.tracks) {
      final track = lxSearchTrackToUiTrack(raw);
      final key = track.albumId.isNotEmpty ? track.albumId : track.album;
      if (key.isEmpty) continue;
      final existing = groups[key];
      if (existing == null) {
        groups[key] = _LxAlbumGroup(
          title: track.album.isEmpty ? track.title : track.album,
          artist: track.artist,
          tracks: <rust.UiTrack>[track],
        );
      } else {
        existing.tracks.add(track);
      }
    }
    return groups.values.toList(growable: false);
  }

  List<Widget> _buildArtists(
    BuildContext context,
    WidgetRef ref,
    MusicLibraryState? local,
    rust_subsonic.UiRemoteSearchResult? remote,
    SubsonicServerConfig? server,
    AppLocalizations l10n,
    rust_lx.UiLxSearchPage? lxPage,
    String? lxPlatform,
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
    final lxArtists = filter == MobileSearchSourceFilter.lx
        ? _lxArtistGroups(lxPage)
        : const <_LxArtistGroup>[];
    if (localArtists.isEmpty && remoteArtists.isEmpty && lxArtists.isEmpty) {
      return <Widget>[_empty(l10n, message: l10n.searchNoArtistResults)];
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
    if (lxArtists.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        M3EList(
          color: M3ETheme.of(context).colorScheme.surface,
          variant: M3ECardVariant.filled,
          itemCount: lxArtists.length,
          onTap: (int index) {
            final artist = lxArtists[index];
            unawaited(
              _playLxTracks(
                context,
                ref,
                l10n,
                lxPlatform,
                artist.tracks,
                '洛雪 · ${lxPlatformLabel(l10n, lxPlatform ?? '')} · ${artist.name}',
              ),
            );
          },
          itemBuilder: (BuildContext context, int index) {
            final artist = lxArtists[index];
            return M3EListItem(
              headline: artist.name,
              supportingText: l10n.librarySongsCount(artist.tracks.length),
              trailing: _sourceChip(
                'LX · ${lxPlatformLabel(l10n, lxPlatform ?? '')}',
                lxPlatform ?? '',
              ),
            );
          },
        ),
      );
    }
    return children;
  }

  List<_LxArtistGroup> _lxArtistGroups(rust_lx.UiLxSearchPage? page) {
    if (page == null) return const <_LxArtistGroup>[];
    final groups = <String, _LxArtistGroup>{};
    for (final raw in page.tracks) {
      final track = lxSearchTrackToUiTrack(raw);
      if (track.artist.isEmpty) continue;
      final existing = groups[track.artist];
      if (existing == null) {
        groups[track.artist] = _LxArtistGroup(
          name: track.artist,
          tracks: <rust.UiTrack>[track],
        );
      } else {
        existing.tracks.add(track);
      }
    }
    return groups.values.toList(growable: false);
  }

  bool get _includesLocal =>
      filter == MobileSearchSourceFilter.all ||
      filter == MobileSearchSourceFilter.local;

  bool get _includesSubsonic =>
      filter == MobileSearchSourceFilter.all ||
      filter == MobileSearchSourceFilter.subsonic;

  bool get _includesLx => filter == MobileSearchSourceFilter.lx;

  /// LX 平台只有在有启用源能解析 `musicUrl` 时才允许起播。
  ///
  /// 搜索、浏览、加入歌单都不受此限制；源还在初始化时这里会等待而不是
  /// 直接判失败（见 [ensureLxPlayable]）。
  Future<void> _playLxTracks(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String? lxPlatform,
    List<rust.UiTrack> tracks,
    String source,
  ) async {
    if (tracks.isEmpty) return;
    if (!await ensureLxPlayable(context, ref, lxPlatform, l10n)) return;
    if (!context.mounted) return;
    ref.read(playerProvider.notifier).load(tracks, 0, source: source);
  }

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

class _PagedSongsResults extends ConsumerStatefulWidget {
  const _PagedSongsResults({
    super.key,
    required this.query,
    required this.filter,
  });

  final String query;
  final MobileSearchSourceFilter filter;

  @override
  ConsumerState<_PagedSongsResults> createState() => _PagedSongsResultsState();
}

class _PagedSongsResultsState extends ConsumerState<_PagedSongsResults> {
  static const int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  int _visible = _pageSize;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
    if (_scrollController.position.extentAfter < 240 && _hasMore) {
      setState(() => _visible += _pageSize);
    }
  }

  void _ensureViewportFilled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasMore) return;
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= 0) {
        setState(() => _visible += _pageSize);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final query = widget.query.trim().toLowerCase();
    final entries = <_PagedSongEntry>[];
    var loading = false;

    if (widget.filter != MobileSearchSourceFilter.subsonic) {
      final localAsync = ref.watch(musicLibraryProvider);
      if (localAsync.isLoading) loading = true;
      final local = localAsync.value;
      if (local != null) {
        for (final track in local.tracks) {
          if (!track.title.toLowerCase().contains(query) &&
              !track.artist.toLowerCase().contains(query) &&
              !track.album.toLowerCase().contains(query)) {
            continue;
          }
          entries.add(
            _PagedSongEntry(
              track: track,
              source: l10n.searchSourceLocal,
              sourceKey: 'local',
            ),
          );
        }
      }
    }

    if (widget.filter != MobileSearchSourceFilter.local) {
      final servers =
          ref.watch(subsonicServersProvider).value ??
          const <SubsonicServerConfig>[];
      if (servers.isNotEmpty) {
        final server = servers.first;
        final remoteAsync = ref.watch(
          remoteSearchProvider((sourceId: server.id, query: widget.query)),
        );
        if (remoteAsync.isLoading) loading = true;
        final remote = remoteAsync.value;
        if (remote != null) {
          final sourceKey = server.name.toLowerCase().contains('navidrome')
              ? 'navidrome'
              : 'subsonic';
          for (final track in remote.tracks) {
            entries.add(
              _PagedSongEntry(
                track: remoteTrackToUiTrack(track, server.id),
                source: server.name,
                sourceKey: sourceKey,
              ),
            );
          }
        }
      }
    }

    if (entries.isEmpty) {
      if (loading) {
        return Center(
          child: M3ELoadingIndicator(
            color: theme.colorScheme.primary,
            containerColor: theme.colorScheme.surfaceContainerHighest,
          ),
        );
      }
      return Center(child: Text(l10n.searchNoResults));
    }

    _hasMore = entries.length > _visible;
    final visibleEntries = entries.take(_visible).toList(growable: false);
    _ensureViewportFilled();

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        M3EList(
          color: theme.colorScheme.surface,
          variant: M3ECardVariant.filled,
          itemCount: visibleEntries.length,
          onTap: (index) => ref
              .read(playerProvider.notifier)
              .load(
                visibleEntries
                    .map((entry) => entry.track)
                    .toList(growable: false),
                index,
                source: '搜索',
              ),
          itemBuilder: (BuildContext context, int index) {
            final entry = visibleEntries[index];
            return M3EListItem(
              leading: _SearchResultCover(track: entry.track),
              headline: entry.track.title,
              supportingText: entry.track.artist,
              trailing: widget.filter == MobileSearchSourceFilter.all
                  ? _sourceChip(entry.source, entry.sourceKey)
                  : null,
            );
          },
        ),
      ],
    );
  }
}

class _PagedSongEntry {
  const _PagedSongEntry({
    required this.track,
    required this.source,
    required this.sourceKey,
  });

  final rust.UiTrack track;
  final String source;
  final String sourceKey;
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
  /// 单页数量。平台接口按页返回，20 条接近官方 30 条的体验，
  /// 又不会一次拉太多。
  static const int _pageSize = 20;

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

  /// 播放才需要音源；没有源时给明确提示，初始化中则等待。
  Future<void> _playTrack(
    List<rust.UiTrack> tracks,
    int index,
    AppLocalizations l10n,
  ) async {
    if (!await ensureLxPlayable(context, ref, widget.platform, l10n)) return;
    if (!mounted) return;
    ref.read(playerProvider.notifier).load(tracks, index, source: '洛雪');
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    // 节流由统一的 LxSearchGate 负责（同平台串行 + 最小间隔），
    // 这里只需要防止滚动事件重复触发。
    setState(() => _loadingMore = true);
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
      final result = await searchLxSongs(
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
          onTap: (index) => unawaited(_playTrack(tracks, index, l10n)),
          itemBuilder: (BuildContext context, int index) {
            final track = _tracks[index];
            final quality = lxQualityLabel(l10n, tracks[index]);
            final singer = track.singer.join('、');
            return M3EListItem(
              leading: _SearchResultCover(track: tracks[index]),
              headline: track.name,
              supportingText: quality == null
                  ? singer
                  : (singer.isEmpty ? quality : '$singer · $quality'),
              trailing: M3EIconButton(
                size: M3EIconButtonSize.xs,
                icon: const Icon(M3EIcons.playlist_add),
                tooltip: l10n.addToPlaylist,
                onPressed: () => showAddToPlaylistSheet(
                  context,
                  ref,
                  <rust.UiTrack>[tracks[index]],
                ),
              ),
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
    final cacheSize = (44 * MediaQuery.devicePixelRatioOf(context)).round();
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
            ? Image.memory(
                bytes,
                fit: BoxFit.cover,
                cacheWidth: cacheSize,
                cacheHeight: cacheSize,
              )
            : Icon(
                M3EIcons.music_note,
                size: 20,
                color: theme.colorScheme.onSecondaryContainer,
              ),
      ),
    );
  }
}

Widget _sourceChip(String label, String sourceKey) {
  return SearchSourceChip(label: label, sourceKey: sourceKey);
}

Widget _empty(AppLocalizations l10n, {String? message}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(child: Text(message ?? l10n.searchNoResults)),
  );
}

Widget _loading() {
  return const Padding(
    padding: EdgeInsets.symmetric(vertical: 32),
    child: Center(child: CircularProgressIndicator()),
  );
}

typedef _OnlineSearchPageProvider<T> =
    FutureProvider<List<T>> Function(int offset);

class _PagedOnlineSearchResults<T> extends ConsumerStatefulWidget {
  const _PagedOnlineSearchResults({
    super.key,
    required this.pageProvider,
    required this.retryPage,
    required this.itemBuilder,
    required this.onItemTap,
    required this.emptyMessage,
  });

  final _OnlineSearchPageProvider<T> pageProvider;
  final ValueChanged<int> retryPage;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final void Function(List<T> items, int index) onItemTap;
  final String emptyMessage;

  @override
  ConsumerState<_PagedOnlineSearchResults<T>> createState() =>
      _PagedOnlineSearchResultsState<T>();
}

class _PagedOnlineSearchResultsState<T>
    extends ConsumerState<_PagedOnlineSearchResults<T>> {
  final ScrollController _scrollController = ScrollController();
  int _requestedPages = 1;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _loadingMore ||
        _scrollController.position.extentAfter > 240) {
      return;
    }

    final offset = (_requestedPages - 1) * onlineSearchPageSize;
    final currentPage = ref.read(widget.pageProvider(offset)).asData?.value;
    if (currentPage?.length != onlineSearchPageSize) return;

    _loadingMore = true;
    setState(() => _requestedPages++);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = <AsyncValue<List<T>>>[
      for (var index = 0; index < _requestedPages; index++)
        ref.watch(widget.pageProvider(index * onlineSearchPageSize)),
    ];
    final items = <T>[
      for (final page in pages)
        if (page.asData != null) ...page.asData!.value,
    ];
    final lastPage = pages.last;

    if (_loadingMore && !lastPage.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadingMore = false;
        _handleScroll();
      });
    } else if (!_loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleScroll();
      });
    }

    if (pages.first.isLoading && items.isEmpty) return _loading();
    if (pages.first.hasError && items.isEmpty) {
      return _searchError(
        context,
        pages.first.error!,
        onRetry: () => widget.retryPage(0),
      );
    }
    if (items.isEmpty) {
      return _empty(l10n, message: widget.emptyMessage);
    }

    final lastOffset = (_requestedPages - 1) * onlineSearchPageSize;
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        24 + AppBottomInsetScope.bottomInsetOf(context),
      ),
      children: <Widget>[
        M3EList(
          color: M3ETheme.of(context).colorScheme.surfaceContainerLow,
          variant: M3ECardVariant.filled,
          itemCount: items.length,
          onTap: (int index) => widget.onItemTap(items, index),
          itemBuilder: (BuildContext context, int index) =>
              widget.itemBuilder(context, items[index]),
        ),
        if (lastPage.isLoading) _loading(),
        if (lastPage.hasError)
          _searchError(
            context,
            lastPage.error!,
            onRetry: () => widget.retryPage(lastOffset),
          ),
      ],
    );
  }
}

Widget _searchError(
  BuildContext context,
  Object error, {
  required VoidCallback onRetry,
}) {
  final l10n = AppLocalizations.of(context);
  return Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('${l10n.searchFailed}: $error', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        M3EButton(
          style: M3EButtonStyle.text,
          label: Text(l10n.playbackRetry),
          onPressed: onRetry,
        ),
      ],
    ),
  );
}

class _OnlineSongsResults extends ConsumerWidget {
  const _OnlineSongsResults({required this.query, required this.source});

  final String query;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (source: source, query: query);
    return _PagedOnlineSearchResults<rust.UiTrack>(
      key: ValueKey<String>('songs:$source:$query'),
      pageProvider: (offset) => onlineSongSearchProvider((
        source: key.source,
        query: key.query,
        limit: onlineSearchPageSize,
        offset: offset,
      )),
      retryPage: (offset) => ref.invalidate(
        onlineSongSearchProvider((
          source: key.source,
          query: key.query,
          limit: onlineSearchPageSize,
          offset: offset,
        )),
      ),
      emptyMessage: AppLocalizations.of(context).searchNoResults,
      onItemTap: (tracks, index) => ref
          .read(playerProvider.notifier)
          .load(tracks, index, source: onlineSourceLabel(source)),
      itemBuilder: (BuildContext context, rust.UiTrack track) => M3EListItem(
        headline: track.title,
        supportingText: track.artist,
        leading: OnlineCover(url: track.coverId),
      ),
    );
  }
}

class _OnlinePlaylistResults extends ConsumerWidget {
  const _OnlinePlaylistResults({required this.query, required this.source});

  final String query;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (source: source, query: query);
    return _PagedOnlineSearchResults<rust_online.UiOnlinePlaylist>(
      key: ValueKey<String>('playlists:$source:$query'),
      pageProvider: (offset) => onlinePlaylistSearchProvider((
        source: key.source,
        query: key.query,
        limit: onlineSearchPageSize,
        offset: offset,
      )),
      retryPage: (offset) => ref.invalidate(
        onlinePlaylistSearchProvider((
          source: key.source,
          query: key.query,
          limit: onlineSearchPageSize,
          offset: offset,
        )),
      ),
      emptyMessage: AppLocalizations.of(context).searchNoResults,
      onItemTap: (playlists, index) => pushMobileRootPage(
        context,
        OnlinePlaylistDetailPage(playlist: playlists[index]),
        name: 'online-playlist',
      ),
      itemBuilder:
          (BuildContext context, rust_online.UiOnlinePlaylist playlist) {
            final supporting = <String>[
              if (playlist.creator != null && playlist.creator!.isNotEmpty)
                playlist.creator!,
              if (playlist.trackCount > 0) '${playlist.trackCount} 首',
            ];
            return M3EListItem(
              headline: playlist.name,
              supportingText: supporting.isEmpty
                  ? '歌单'
                  : supporting.join(' · '),
              leading: OnlineCover(url: playlist.coverUrl),
            );
          },
    );
  }
}

class _OnlineAlbumResults extends ConsumerWidget {
  const _OnlineAlbumResults({required this.query, required this.source});

  final String query;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (source: source, query: query);
    return _PagedOnlineSearchResults<rust_online.UiOnlineAlbum>(
      key: ValueKey<String>('albums:$source:$query'),
      pageProvider: (offset) => onlineAlbumSearchProvider((
        source: key.source,
        query: key.query,
        limit: onlineSearchPageSize,
        offset: offset,
      )),
      retryPage: (offset) => ref.invalidate(
        onlineAlbumSearchProvider((
          source: key.source,
          query: key.query,
          limit: onlineSearchPageSize,
          offset: offset,
        )),
      ),
      emptyMessage: AppLocalizations.of(context).searchNoResults,
      onItemTap: (albums, index) => pushMobileRootPage(
        context,
        OnlineAlbumDetailPage(album: albums[index]),
        name: 'online-album',
      ),
      itemBuilder: (BuildContext context, rust_online.UiOnlineAlbum album) {
        final supporting = <String>[
          if (album.artist != null && album.artist!.isNotEmpty) album.artist!,
          if (album.trackCount > 0) '${album.trackCount} 首',
        ];
        return M3EListItem(
          headline: album.name,
          supportingText: supporting.isEmpty ? '专辑' : supporting.join(' · '),
          leading: OnlineCover(url: album.coverUrl),
        );
      },
    );
  }
}
