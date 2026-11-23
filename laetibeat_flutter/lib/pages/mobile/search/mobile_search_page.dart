import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/lx.dart' as rust_lx;
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
import 'package:laetibeat/widgets/settings/search_settings.dart';
import 'package:laetibeat/widgets/settings/persistence.dart';
import 'package:laetibeat/widgets/settings/subsonic_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../library/albums/album_detail_page.dart';
import '../library/artists/artist_detail_page.dart';
import '../library/playlists/local_playlist_detail_page.dart';
import '../library/playlists/lx_playlist_preview_page.dart';
import '../library/playlists/playlist_actions.dart';
import '../library/playlists/remote_playlist_detail_page.dart';
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
  late MobileSearchSourceFilter _filter;
  String? _lxPlatform;

  /// 自动解析出的默认平台。用户没有手动选择时，一旦播放能力加载完成，
  /// 允许用它纠正"当前平台没有任何音源"的情况。
  String? _resolvedLxPlatform;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _filter = ref.read(defaultSearchSourceProvider);
    // 源可能在设置页被增删；进页面后刷新一次播放能力。
    //
    // 必须放到首帧之后：initState 仍处于 build 阶段，此时 invalidate 会让
    // Riverpod 对 UncontrolledProviderScope 调用 setState，触发
    // "setState() called during build" 断言（上一页的 suggestions 仍在 watch
    // 这个 provider，所以它一定有存活 element）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 源的能力声明可能变化，重新读取运行时状态。
      ref.invalidate(lxRuntimeProvider);
    });
  }

  /// 解析当前平台。
  ///
  /// 平台来自内置列表，与是否导入音源无关；这里只决定"默认选中哪一个"：
  /// 用户手动选择优先，其次是内置顺序中第一个可播放平台，最后回退到第一个
  /// 内置平台（保证没导入任何音源时依然能搜索）。
  String? _resolveLxPlatform(List<String> platforms, List<String> playable) {
    final selected = _lxPlatform;
    if (selected != null && platforms.contains(selected)) return selected;

    final current = _resolvedLxPlatform;
    if (current != null && platforms.contains(current)) {
      // playable 为空可能只是运行时还没就绪：保持当前选择，
      // 避免初始化完成后平台从 kw 突然跳到 tx。
      if (playable.isEmpty || playable.contains(current)) return current;
    }
    // 纯内部记忆值，不触发重建：输入不变时结果稳定。
    _resolvedLxPlatform = lxDefaultPlatform(
      platforms: platforms,
      playable: playable,
    );
    return _resolvedLxPlatform;
  }

  void _playLxResults() {
    final query = widget.initialQuery.trim();
    if (query.isEmpty) return;
    unawaited(_playLxResultsFor(query));
  }

  Future<void> _playLxResultsFor(String query) async {
    final l10n = AppLocalizations.of(context);
    final platforms = ref.read(lxPlatformsProvider).value ?? kLxPlatformOrder;
    final playable =
        ref.read(lxRuntimeProvider).value?.playablePlatforms ??
        const <String>[];
    final platform = _resolveLxPlatform(platforms, playable);
    if (platform == null) return;
    // 源还在初始化时等待，而不是把用户挡回去。
    if (!await ensureLxPlayable(context, ref, platform, l10n)) return;
    if (!mounted) return;
    await _loadLxFirstPage(platform, query);
  }

  Future<void> _loadLxFirstPage(String platform, String query) async {
    final l10n = AppLocalizations.of(context);
    try {
      // 走统一的 gated 入口：与歌曲/歌单搜索共享同平台节流。
      final page = await searchLxSongs(
        platform: platform,
        keyword: query,
        page: 1,
        limit: 10,
      );
      if (!mounted || page.tracks.isEmpty) return;
      final tracks = page.tracks
          .map(lxSearchTrackToUiTrack)
          .toList(growable: false);
      ref
          .read(playerProvider.notifier)
          .load(tracks, 0, source: '洛雪 · ${lxPlatformLabel(l10n, platform)}');
    } catch (error) {
      if (!mounted) return;
      M3ESnackbar.show(context, message: error.toString());
    }
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
    final lxPlatformsAsync = ref.watch(lxPlatformsProvider);
    final runtimeAsync = ref.watch(lxRuntimeProvider);
    final lxPlatforms = lxPlatformsAsync.value ?? kLxPlatformOrder;
    final playablePlatforms =
        runtimeAsync.value?.playablePlatforms ?? const <String>[];
    // 源还在初始化时"可播列表为空"只代表未知，不能当成"没有源"。
    final lxPreparing =
        (runtimeAsync.isLoading && !runtimeAsync.hasValue) ||
        (runtimeAsync.value?.warming ?? false);
    final activeLxPlatform = _resolveLxPlatform(lxPlatforms, playablePlatforms);

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
                      // 平台列表来自内置能力，永远不会为空；这里只是防御。
                      platform: activeLxPlatform ?? kLxPlatformOrder.first,
                      platforms: lxPlatforms,
                      playablePlatforms: playablePlatforms,
                      preparing: lxPreparing,
                      showPlay: _category == MobileSearchCategory.songs,
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
                    ? activeLxPlatform
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

class _LxPlatformBar extends StatelessWidget {
  const _LxPlatformBar({
    super.key,
    required this.platform,
    required this.platforms,
    required this.playablePlatforms,
    required this.preparing,
    required this.onChanged,
    required this.onPlay,
    required this.showPlay,
  });

  final String platform;
  final List<String> platforms;

  /// 有启用源可以解析播放地址的平台。为空表示只能浏览，不能播放。
  final List<String> playablePlatforms;

  /// 源运行时还在初始化：此时 [playablePlatforms] 还没算出来，
  /// 不能据此显示"暂无可播放音源"。
  final bool preparing;
  final ValueChanged<String> onChanged;
  final VoidCallback onPlay;
  final bool showPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = M3ETheme.of(context);
    final canPlay = playablePlatforms.contains(platform);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: <Widget>[
          if (showPlay)
            M3EButton.icon(
              icon: const Icon(M3EIcons.play_arrow),
              label: Text(l10n.play),
              style: M3EButtonStyle.filled,
              size: M3EButtonSize.sm,
              shape: M3EButtonShape.round,
              onPressed: onPlay,
            ),
          if (showPlay && (preparing || !canPlay)) ...<Widget>[
            const SizedBox(width: 8),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    M3EIcons.info,
                    size: 14,
                    color: preparing
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      preparing
                          ? l10n.lxSourcePreparing
                          : l10n.lxPlatformNoSource,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typeScale.labelSmall.copyWith(
                        color: preparing
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          M3ESplitButton<String>(
            size: M3EButtonSize.sm,
            shape: M3EButtonShape.round,
            style: M3EButtonStyle.tonal,
            label: lxPlatformLabel(l10n, platform),
            leadingIcon: M3EIcons.music_note,
            selectedValue: platform,
            trailingTooltip: l10n.searchFilter,
            // 切歌在播放链路里是"解析播放地址"，只标注是否可用；
            // 平台本身始终可切换，搜索永远不受音源影响。
            onPressed: () {},
            onSelected: onChanged,
            items: <M3ESplitButtonItem<String>>[
              for (final item in platforms)
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
    final local = isPlaylistCategory || isLxFilter
        ? null
        : ref.watch(musicLibraryProvider).value;
    final servers =
        ref.watch(subsonicServersProvider).value ??
        const <SubsonicServerConfig>[];
    final server = servers.isEmpty ? null : servers.first;
    final remoteAsync = server == null || isPlaylistCategory || isLxFilter
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
                              ? 'LX · ${lxPlatformLabel(l10n, platform ?? '')}'
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
                  trailing: _sourceChip(
                    server.name,
                    server.name.toLowerCase().contains('navidrome')
                        ? 'navidrome'
                        : 'subsonic',
                  ),
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
