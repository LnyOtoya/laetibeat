import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/layout/app_bottom_inset.dart';
import '../../../src/rust/api/netease.dart' as rust_netease;
import '../../../src/rust/api/simple.dart' as rust;
import '../../../widgets/cache/netease_cover_cache.dart';
import '../../../widgets/player/cover_provider.dart';
import '../../../widgets/player/player_provider.dart';
import '../../../widgets/settings/netease_provider.dart';
import '../../../widgets/settings/netease_session.dart';
import '../../../widgets/settings/netease_settings.dart';
import '../library/netease/netease_album_artist_pages.dart';
import '../library/netease/netease_daily_page.dart';
import '../library/netease/netease_detail_widgets.dart';
import '../library/netease/netease_playlists_page.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import '../settings/sources/netease/mobile_netease_login_page.dart';
import '../settings/sources/netease/mobile_netease_settings_page.dart';
import 'netease_discover_playlists_page.dart';

/// 移动端发现页面。
///
/// 顶部是横向推荐卡片。六张卡片都依赖登录后的个性化数据；未登录时整页显示
/// 登录提示，不再请求或展示匿名/游客推荐。
class MobileDiscoverPage extends ConsumerWidget {
  const MobileDiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = M3ETheme.of(context).colorScheme;
    final settings = ref.watch(neteaseSettingsProvider);
    final cookie = ref.watch(neteaseCookieProvider).value;
    final loggedIn = cookie != null && cookie.isNotEmpty;
    final configured = settings.apiBaseUrl.isNotEmpty;
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    return AppScaffold(
      background: AppSurfaceLevel.base,
      applyPageGutter: false,
      safeArea: false,
      appBar: AppPageBar.tab(
        title: l10n.navDiscover,
        subtitle: l10n.discoverSubtitle,
        backgroundColor: AppSurfaceLevel.base.resolve(scheme),
      ),
      body: !configured
          ? _DiscoverUnconfigured(bottomInset: bottomInset)
          : !loggedIn
          ? _DiscoverLoginRequired(bottomInset: bottomInset)
          : _DiscoverContent(bottomInset: bottomInset),
    );
  }
}

class _DiscoverUnconfigured extends StatelessWidget {
  const _DiscoverUnconfigured({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: AppEmptyState(
          title: '还没有配置网易云音乐',
          message: '填写网易云 API 地址后，这里会显示推荐歌单、雷达和漫游内容。',
          icon: M3EIcons.cloud_off,
          action: M3EButton(
            style: M3EButtonStyle.filled,
            label: const Text('去配置'),
            onPressed: () => pushMobileRootPage(
              context,
              const MobileNeteaseSettingsPage(),
              name: MobileRoutes.neteaseConfig,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverLoginRequired extends ConsumerWidget {
  const _DiscoverLoginRequired({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: AppEmptyState(
          title: '登录网易云后查看为你推荐',
          message: '每日推荐、心动模式、歌单、漫游、雷达和相似歌曲都会在登录后按你的口味生成。',
          icon: M3EIcons.lock,
          action: M3EButton(
            style: M3EButtonStyle.filled,
            label: const Text('登录网易云'),
            onPressed: () => _openLogin(context, ref),
          ),
        ),
      ),
    );
  }
}

class _DiscoverContent extends ConsumerWidget {
  const _DiscoverContent({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageGutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    final cardWidth = (MediaQuery.sizeOf(context).width * 0.78).clamp(
      240.0,
      360.0,
    );
    final cardHeight = cardWidth * 9 / 16 + 76;

    final daily = ref.watch(neteaseDailyProvider);
    final playlists = ref.watch(neteasePersonalizedPlaylistsProvider);
    final fm = ref.watch(neteasePersonalFmProvider);
    final radar = ref.watch(neteaseRadarPlaylistsProvider);
    final liked = ref.watch(neteaseLikedPlaylistProvider);

    final cards = <_DiscoverCardData>[
      _dailyCard(context, ref, daily),
      _seedCard(
        context: context,
        ref: ref,
        title: '心动模式',
        subtitle: '红心歌曲和相似推荐',
        liked: liked,
        source: '网易云心动模式',
        load: () => ref.read(neteaseHeartModeProvider.future),
      ),
      _playlistCard(context, ref, playlists),
      _roamCard(context, ref, fm),
      _radarCard(context, ref, radar),
      _seedCard(
        context: context,
        ref: ref,
        title: '相似歌曲',
        subtitle: '从你喜欢的歌听起',
        liked: liked,
        source: '网易云相似歌曲',
        load: () => ref.read(neteaseSimilarSongsProvider.future),
      ),
    ];

    return m3e_core.M3EPullToRefreshIndicator(
      onRefresh: () => _refreshDiscover(ref),
      onError: (_, _) {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: AppSpacing.lg,
          bottom: AppSpacing.xxl + bottomInset,
        ),
        children: <Widget>[
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pageGutter),
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.lg),
              itemBuilder: (BuildContext context, int index) {
                return _DiscoverCard(data: cards[index], width: cardWidth);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _LikedSongRecommendationsSection(),
          const SizedBox(height: AppSpacing.xl),
          const _HomeSectionsSection(),
        ],
      ),
    );
  }

  _DiscoverCardData _dailyCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<rust.UiTrack>> value,
  ) {
    final tracks = value.value;
    final hasData = tracks != null && tracks.isNotEmpty;
    final state = _stateFor(value, hasData: hasData);
    return _DiscoverCardData(
      title: '今日推荐',
      subtitle: '今日限定好歌推荐',
      coverUrl: hasData ? tracks.first.coverId : null,
      state: state,
      message: state == _CardState.error ? '加载失败，点击重试' : null,
      onTap: () => pushMobileRootPage(
        context,
        const NeteaseDailyPage(),
        name: MobileRoutes.discovery,
      ),
      onRetry: () => ref.invalidate(neteaseDailyProvider),
      onLogin: () => _openLogin(context, ref),
    );
  }

  _DiscoverCardData _playlistCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<rust_netease.UiNeteasePlaylist>> value,
  ) {
    final items = value.value ?? const <rust_netease.UiNeteasePlaylist>[];
    final hasData = items.isNotEmpty;
    final state = _stateFor(value, hasData: hasData);
    return _DiscoverCardData(
      title: '歌单推荐',
      subtitle: '打工人续命歌单',
      coverUrl: hasData ? items.first.coverUrl : null,
      state: state,
      message: state == _CardState.error ? '加载失败，点击重试' : null,
      onTap: hasData
          ? () => pushMobileRootPage(
              context,
              NeteaseDiscoverPlaylistsPage(title: '推荐歌单', playlists: items),
              name: MobileRoutes.discovery,
            )
          : null,
      onRetry: () => ref.invalidate(neteasePersonalizedPlaylistsProvider),
      onLogin: () => _openLogin(context, ref),
    );
  }

  _DiscoverCardData _roamCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<rust.UiTrack>> value,
  ) {
    final tracks = value.value ?? const <rust.UiTrack>[];
    final hasData = tracks.isNotEmpty;
    final state = _stateFor(value, hasData: hasData);
    return _DiscoverCardData(
      title: '漫游',
      subtitle: '多样频道无限唱听',
      coverUrl: hasData ? tracks.first.coverId : null,
      state: state,
      message: state == _CardState.error ? '加载失败，点击重试' : null,
      onTap: hasData ? () => _playTracks(context, ref, tracks, '网易云漫游') : null,
      onRetry: () => ref.invalidate(neteasePersonalFmProvider),
      onLogin: () => _openLogin(context, ref),
    );
  }

  _DiscoverCardData _radarCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<rust_netease.UiNeteasePlaylist>> value,
  ) {
    final items = value.value ?? const <rust_netease.UiNeteasePlaylist>[];
    final hasData = items.isNotEmpty;
    final state = _stateFor(value, hasData: hasData);
    return _DiscoverCardData(
      title: '雷达歌单',
      subtitle: '反复聆听你爱的歌',
      coverUrl: hasData ? items.first.coverUrl : null,
      state: state,
      message: state == _CardState.error ? '加载失败，点击重试' : null,
      onTap: hasData
          ? () => pushMobileRootPage(
              context,
              NeteaseDiscoverPlaylistsPage(title: '雷达歌单', playlists: items),
              name: MobileRoutes.discovery,
            )
          : null,
      onRetry: () => ref.invalidate(neteaseRadarPlaylistsProvider),
      onLogin: () => _openLogin(context, ref),
    );
  }

  _DiscoverCardData _seedCard({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required AsyncValue<rust_netease.UiNeteasePlaylist?> liked,
    required String source,
    required Future<List<rust.UiTrack>> Function() load,
  }) {
    final playlist = liked.value;
    final hasData = playlist != null && playlist.trackCount > 0;
    final state = _stateFor(liked, hasData: hasData);
    return _DiscoverCardData(
      title: title,
      subtitle: subtitle,
      coverUrl: hasData ? playlist.coverUrl : null,
      state: state,
      message: switch (state) {
        _CardState.error => '加载失败，点击重试',
        _CardState.empty => '还没有红心歌曲',
        _ => null,
      },
      onTap: hasData
          ? () => unawaited(_playFuture(context, ref, load(), source))
          : null,
      onRetry: () => ref.invalidate(neteaseLikedPlaylistProvider),
      onLogin: () => _openLogin(context, ref),
    );
  }

  Future<void> _playFuture(
    BuildContext context,
    WidgetRef ref,
    Future<List<rust.UiTrack>> future,
    String source,
  ) async {
    try {
      final tracks = await future;
      if (!context.mounted) return;
      _playTracks(context, ref, tracks, source);
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, '$error');
    }
  }

  void _playTracks(
    BuildContext context,
    WidgetRef ref,
    List<rust.UiTrack> tracks,
    String source,
  ) {
    if (tracks.isEmpty) {
      _showMessage(context, '网易云暂时没有返回可播放的歌曲');
      return;
    }
    ref.read(playerProvider.notifier).load(tracks, 0, source: source);
  }
}

Future<void> _openLogin(BuildContext context, WidgetRef ref) async {
  await pushMobileRootPage<bool>(
    context,
    const MobileNeteaseLoginPage(),
    name: MobileRoutes.neteaseLogin,
  );
  ref.invalidate(neteaseLikedPlaylistProvider);
  ref.invalidate(neteaseDailyProvider);
  ref.invalidate(neteasePersonalizedPlaylistsProvider);
  ref.invalidate(neteaseRadarPlaylistsProvider);
  ref.invalidate(neteasePersonalFmProvider);
  ref.invalidate(neteaseLikedSongRecommendationsProvider);
  ref.invalidate(neteaseHomeSectionsProvider);
}

Future<void> _refreshDiscover(WidgetRef ref) async {
  ref.read(neteaseHomeRefreshTokenProvider.notifier).refresh();
  ref.invalidate(neteaseDailyProvider);
  ref.invalidate(neteasePersonalizedPlaylistsProvider);
  ref.invalidate(neteaseRadarPlaylistsProvider);
  ref.invalidate(neteasePersonalFmProvider);
  ref.invalidate(neteaseLikedSongRecommendationsProvider);
  ref.invalidate(neteaseLikedPlaylistProvider);
  await ref.read(neteaseHomeSectionsProvider.future);
}

class _LikedSongRecommendationsSection extends ConsumerWidget {
  const _LikedSongRecommendationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final pageGutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    final recommendations = ref.watch(neteaseLikedSongRecommendationsProvider);
    final tracks = recommendations.value ?? const <rust.UiTrack>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pageGutter),
          child: AppSectionHeader(
            title: '根据你喜爱的歌曲推荐',
            titleRole: AppTextRole.titleMedium,
            leading: _TasteGlyph(scheme: scheme),
            trailing: M3EIconButton(
              variant: M3EIconButtonVariant.tonal,
              size: M3EIconButtonSize.sm,
              icon: const Icon(M3EIcons.play_arrow),
              tooltip: '播放全部',
              onPressed: tracks.isEmpty
                  ? null
                  : () => ref
                        .read(playerProvider.notifier)
                        .load(tracks, 0, source: '根据你喜爱的歌曲推荐'),
            ),
            padding: AppInsets.sectionHeader,
          ),
        ),
        recommendations.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: NeteaseLoadingIndicator()),
          ),
          error: (error, _) {
            final needsLogin = _needsLogin(error);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: pageGutter),
              child: AppEmptyState(
                title: needsLogin ? '登录后查看推荐' : '推荐加载失败',
                message: needsLogin ? '登录网易云后会根据你喜爱的歌曲生成推荐。' : '$error',
                icon: needsLogin ? M3EIcons.lock : M3EIcons.error,
                action: M3EButton(
                  style: M3EButtonStyle.tonal,
                  label: Text(needsLogin ? '登录网易云' : '重试'),
                  onPressed: needsLogin
                      ? () => _openLogin(context, ref)
                      : () => ref.invalidate(
                          neteaseLikedSongRecommendationsProvider,
                        ),
                ),
              ),
            );
          },
          data: (items) {
            if (items.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: pageGutter),
                child: const AppEmptyState(
                  title: '暂时没有推荐',
                  message: '网易云首页暂时没有返回「根据你喜爱的歌曲推荐」。',
                  icon: M3EIcons.favorite_border,
                ),
              );
            }
            return _NeteaseSongColumns(tracks: items, source: '根据你喜爱的歌曲推荐');
          },
        ),
      ],
    );
  }
}

class _TasteGlyph extends StatelessWidget {
  const _TasteGlyph({required this.scheme});

  final M3EColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: M3EShapeContainer.cookie9Sided(
        width: 32,
        height: 32,
        color: scheme.primaryContainer,
        child: Center(
          child: Icon(
            M3EIcons.favorite,
            size: AppIconSize.sm,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _NeteaseSongColumns extends ConsumerWidget {
  const _NeteaseSongColumns({required this.tracks, required this.source});

  static const int _rowsPerColumn = 4;
  static const double _rowHeight = 56;
  static const double _columnGap = AppSpacing.lg;

  final List<rust.UiTrack> tracks;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageGutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    final columnWidth = (MediaQuery.sizeOf(context).width * 0.78).clamp(
      240.0,
      360.0,
    );
    final columnCount = (tracks.length / _rowsPerColumn).ceil();
    final scheme = M3ETheme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: pageGutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (
            var columnIndex = 0;
            columnIndex < columnCount;
            columnIndex++
          ) ...[
            if (columnIndex > 0) const SizedBox(width: _columnGap),
            SizedBox(
              width: columnWidth,
              child: Builder(
                builder: (BuildContext context) {
                  final start = columnIndex * _rowsPerColumn;
                  final rawEnd = start + _rowsPerColumn;
                  final end = rawEnd > tracks.length ? tracks.length : rawEnd;
                  final columnTracks = tracks.sublist(start, end);
                  return m3e_core.M3ESegmentedList.builder(
                    itemCount: columnTracks.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    listPadding: EdgeInsets.zero,
                    onTap: (int index) => ref
                        .read(playerProvider.notifier)
                        .load(tracks, start + index, source: source),
                    decoration: m3e_core.M3ESegmentedListDecoration(
                      color: scheme.secondaryContainer,
                      splashColor: scheme.onSecondaryContainer.withValues(
                        alpha: 0.12,
                      ),
                      highlightColor: scheme.onSecondaryContainer.withValues(
                        alpha: 0.08,
                      ),
                      hoverColor: scheme.onSecondaryContainer.withValues(
                        alpha: 0.08,
                      ),
                      outerRadius: 24,
                      innerRadius: 12,
                      pressedRadius: 8,
                      pressedScale: 0.98,
                      hoveredRadius: 16,
                      gap: 4,
                      padding: const EdgeInsets.all(4),
                      margin: EdgeInsets.zero,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      return _LikedSongRow(track: columnTracks[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LikedSongRow extends StatelessWidget {
  const _LikedSongRow({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    return m3e_core.M3EListItem(
      minHeight: _NeteaseSongColumns._rowHeight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: _CompactTrackCover(track: track),
      headline: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      supportingText: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      headlineStyle: theme.typeScale.bodyMedium.copyWith(
        color: scheme.onSecondaryContainer,
      ),
      supportingTextStyle: theme.typeScale.bodySmall.copyWith(
        color: scheme.onSecondaryContainer.withValues(alpha: 0.75),
      ),
      trailing: NeteaseTrackMenu(
        track: track,
        color: scheme.onSecondaryContainer,
      ),
    );
  }
}

class _CompactTrackCover extends ConsumerWidget {
  const _CompactTrackCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final cacheSize = (48 * MediaQuery.devicePixelRatioOf(context)).round();

    return ClipRRect(
      borderRadius: AppRadii.smAll,
      child: SizedBox.square(
        dimension: 48,
        child: bytes == null || bytes.isEmpty
            ? ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  M3EIcons.music_note,
                  size: AppIconSize.sm,
                  color: scheme.onSurfaceVariant,
                ),
              )
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: cacheSize,
                cacheHeight: cacheSize,
              ),
      ),
    );
  }
}

class _HomeSectionsSection extends ConsumerWidget {
  const _HomeSectionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageGutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    final sections = ref.watch(neteaseHomeSectionsProvider);

    return sections.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: NeteaseLoadingIndicator()),
      ),
      error: (error, _) {
        final needsLogin = _needsLogin(error);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: pageGutter),
          child: AppEmptyState(
            title: needsLogin ? '登录后查看推荐' : '首页推荐加载失败',
            message: needsLogin ? '登录网易云后会显示首页推荐。' : '$error',
            icon: needsLogin ? M3EIcons.lock : M3EIcons.error,
            action: M3EButton(
              style: M3EButtonStyle.tonal,
              label: Text(needsLogin ? '登录网易云' : '重试'),
              onPressed: needsLogin
                  ? () => _openLogin(context, ref)
                  : () => ref.invalidate(neteaseHomeSectionsProvider),
            ),
          ),
        );
      },
      data: (items) {
        final visible = items
            .where((section) {
              if (section.title.trim().isEmpty) return false;
              if (section.title.contains('根据你喜爱的歌曲推荐')) return false;
              return section.cards.isNotEmpty || section.tracks.isNotEmpty;
            })
            .toList(growable: false);
        if (visible.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final section in visible) ...<Widget>[
              _HomeBlockSection(section: section),
              const SizedBox(height: AppSpacing.xl),
            ],
          ],
        );
      },
    );
  }
}

class _HomeBlockSection extends ConsumerWidget {
  const _HomeBlockSection({required this.section});

  final rust_netease.UiNeteaseHomeSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageGutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    final scheme = M3ETheme.of(context).colorScheme;
    final hasTracks = section.tracks.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pageGutter),
          child: AppSectionHeader(
            title: section.title,
            titleRole: AppTextRole.titleMedium,
            leading: _TasteGlyph(scheme: scheme),
            trailing: hasTracks
                ? M3EIconButton(
                    variant: M3EIconButtonVariant.tonal,
                    size: M3EIconButtonSize.sm,
                    icon: const Icon(M3EIcons.play_arrow),
                    tooltip: '播放全部',
                    onPressed: () => ref
                        .read(playerProvider.notifier)
                        .load(section.tracks, 0, source: section.title),
                  )
                : null,
            padding: AppInsets.sectionHeader,
          ),
        ),
        if (section.cards.isNotEmpty) _HomeCardCarousel(cards: section.cards),
        if (section.cards.isNotEmpty && hasTracks)
          const SizedBox(height: AppSpacing.md),
        if (hasTracks)
          _NeteaseSongColumns(tracks: section.tracks, source: section.title),
      ],
    );
  }
}

class _HomeCardCarousel extends StatelessWidget {
  const _HomeCardCarousel({required this.cards});

  final List<rust_netease.UiNeteaseHomeCard> cards;

  @override
  Widget build(BuildContext context) {
    final pageGutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    final available = MediaQuery.sizeOf(context).width - pageGutter * 2;
    final cardWidth = ((available - AppSpacing.lg * 2) / 2.35).clamp(
      120.0,
      180.0,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: pageGutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var index = 0; index < cards.length; index++) ...[
            if (index > 0) const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: cardWidth,
              child: _HomeCard(card: cards[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeCard extends ConsumerWidget {
  const _HomeCard({required this.card});

  final rust_netease.UiNeteaseHomeCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final onTap = _target(context, ref);

    return Semantics(
      button: onTap != null,
      label: card.title,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadii.lgAll,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: AppRadii.lgAll,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _HomeCardCover(card: card),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                card.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typeScale.bodyMedium.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  VoidCallback? _target(BuildContext context, WidgetRef ref) {
    final id = BigInt.tryParse(card.id);
    if (id == null) return null;
    switch (card.kind) {
      case 'playlist':
        final playlist = rust_netease.UiNeteasePlaylist(
          id: id,
          name: card.title,
          coverUrl: card.coverUrl,
          trackCount: 0,
          creator: null,
          playCount: card.playCount,
          specialType: card.specialType,
        );
        return () {
          prefetchNeteaseCover(ref, playlist.coverUrl);
          pushMobileRootPage(
            context,
            NeteasePlaylistDetailPage(playlist: playlist),
            name: MobileRoutes.libraryPlaylists,
          );
        };
      case 'album':
        final album = rust_netease.UiNeteaseAlbum(
          id: id,
          name: card.title,
          artist: card.artist ?? '',
          artistId: card.artistId ?? BigInt.zero,
          coverUrl: card.coverUrl,
          trackCount: 0,
          publishTimeMs: null,
        );
        return () {
          prefetchNeteaseCover(ref, album.coverUrl);
          pushMobileRootPage(
            context,
            NeteaseAlbumDetailPage(album: album),
            name: MobileRoutes.albumDetail,
          );
        };
      default:
        return null;
    }
  }
}

class _HomeCardCover extends ConsumerWidget {
  const _HomeCardCover({required this.card});

  final rust_netease.UiNeteaseHomeCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final url = card.coverUrl;
    final fallbackIcon = _iconForKind(card.kind);

    if (url == null || url.isEmpty) {
      return _CoverPlaceholder(
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurfaceVariant,
        icon: fallbackIcon,
      );
    }

    final image = ref.watch(neteaseImageProvider(url));
    return image.when(
      data: (bytes) {
        if (bytes == null || bytes.isEmpty) {
          return _CoverPlaceholder(
            background: scheme.surfaceContainerHighest,
            foreground: scheme.onSurfaceVariant,
            icon: fallbackIcon,
          );
        }
        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      },
      loading: () => _CoverPlaceholder(
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurfaceVariant,
        child: const NeteaseLoadingIndicator(size: 32),
      ),
      error: (_, _) => _CoverPlaceholder(
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurfaceVariant,
        icon: M3EIcons.error,
      ),
    );
  }

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'playlist':
        return M3EIcons.queue_music;
      case 'album':
        return M3EIcons.album;
      case 'video_playlist':
        return M3EIcons.videocam;
      case 'topic':
        return M3EIcons.tag;
      case 'event':
        return M3EIcons.event;
      case 'voice':
        return M3EIcons.mic;
      case 'article':
        return M3EIcons.article;
      default:
        return M3EIcons.music_note;
    }
  }
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.data, required this.width});

  final _DiscoverCardData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final onTap = switch (data.state) {
      _CardState.login => data.onLogin,
      _CardState.error => data.onRetry,
      _CardState.data => data.onTap,
      _CardState.loading || _CardState.empty => null,
    };

    return Semantics(
      button: onTap != null,
      label: '${data.title}，${data.subtitle}',
      child: SizedBox(
        width: width,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadii.lgAll,
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typeScale.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typeScale.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: width,
                  height: width * 9 / 16,
                  child: ClipRRect(
                    borderRadius: AppRadii.lgAll,
                    child: _DiscoverCover(data: data),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverCover extends ConsumerWidget {
  const _DiscoverCover({required this.data});

  final _DiscoverCardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;

    switch (data.state) {
      case _CardState.login:
        return _CoverPlaceholder(
          background: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
          icon: M3EIcons.lock,
          text: '登录后查看',
        );
      case _CardState.loading:
        return _CoverPlaceholder(
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurfaceVariant,
          child: const NeteaseLoadingIndicator(size: 32),
        );
      case _CardState.error:
        return _CoverPlaceholder(
          background: scheme.errorContainer,
          foreground: scheme.onErrorContainer,
          icon: M3EIcons.error,
          text: data.message ?? '加载失败',
        );
      case _CardState.empty:
        return _CoverPlaceholder(
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurfaceVariant,
          icon: M3EIcons.music_note,
          text: data.message ?? '暂无内容',
        );
      case _CardState.data:
        final url = data.coverUrl;
        if (url == null || url.isEmpty) {
          return _CoverPlaceholder(
            background: scheme.surfaceContainerHighest,
            foreground: scheme.onSurfaceVariant,
            icon: M3EIcons.music_note,
            text: '暂无封面',
          );
        }
        final image = ref.watch(neteaseImageProvider(url));
        return image.when(
          data: (bytes) {
            if (bytes == null || bytes.isEmpty) {
              return _CoverPlaceholder(
                background: scheme.surfaceContainerHighest,
                foreground: scheme.onSurfaceVariant,
                icon: M3EIcons.music_note,
                text: '暂无封面',
              );
            }
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            );
          },
          loading: () => _CoverPlaceholder(
            background: scheme.surfaceContainerHighest,
            foreground: scheme.onSurfaceVariant,
            child: const NeteaseLoadingIndicator(size: 32),
          ),
          error: (_, _) => _CoverPlaceholder(
            background: scheme.surfaceContainerHighest,
            foreground: scheme.onSurfaceVariant,
            icon: M3EIcons.error,
            text: '封面加载失败',
          ),
        );
    }
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({
    required this.background,
    required this.foreground,
    this.icon,
    this.text,
    this.child,
  });

  final Color background;
  final Color foreground;
  final IconData? icon;
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return ColoredBox(
      color: background,
      child: Center(
        child:
            child ??
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null)
                  Icon(icon, size: AppIconSize.lg, color: foreground),
                if (text != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    text!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typeScale.labelMedium.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
              ],
            ),
      ),
    );
  }
}

enum _CardState { data, loading, empty, error, login }

class _DiscoverCardData {
  const _DiscoverCardData({
    required this.title,
    required this.subtitle,
    required this.state,
    this.coverUrl,
    this.message,
    this.onTap,
    this.onRetry,
    this.onLogin,
  });

  final String title;
  final String subtitle;
  final String? coverUrl;
  final _CardState state;
  final String? message;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onLogin;
}

_CardState _stateFor<T>(AsyncValue<T> value, {required bool hasData}) {
  if (value.isLoading && !value.hasValue) return _CardState.loading;
  if (value.hasError) {
    return _needsLogin(value.error) ? _CardState.login : _CardState.error;
  }
  return hasData ? _CardState.data : _CardState.empty;
}

bool _needsLogin(Object? error) {
  final text = '$error';
  return text.contains('301') || text.contains('需要登录') || text.contains('请先登录');
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
