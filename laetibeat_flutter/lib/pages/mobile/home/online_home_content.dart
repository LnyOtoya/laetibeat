import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_mode.dart';
import '../../../design/design.dart';
import '../../../shared/layout/app_bottom_inset.dart';
import '../../../src/rust/api/online.dart' as rust_online;
import '../../../src/rust/api/simple.dart' as rust;
import '../../../widgets/player/player_provider.dart';
import '../../../widgets/settings/online_provider.dart';
import '../../../widgets/settings/online_settings.dart';
import '../library/online/online_detail_pages.dart';
import '../library/online/online_widgets.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import '../settings/online/mobile_online_login_page.dart';
import '../widgets/mobile_large_subpage_app_bar.dart';
import 'online_daily_page.dart';

/// 在线模式首页：沿用 1.0.1 发现页的内容结构。
///
/// 顶部是六张横向大卡，下面是「根据你喜爱的歌曲推荐」，再往下按
/// `/homepage/block/page` 返回的 block 渲染卡片轮播和歌曲分栏。
class OnlineHomeContent extends ConsumerStatefulWidget {
  const OnlineHomeContent({super.key});

  @override
  ConsumerState<OnlineHomeContent> createState() => _OnlineHomeContentState();
}

class _OnlineHomeContentState extends ConsumerState<OnlineHomeContent> {
  int _generation = 0;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appModeProvider);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    if (!mode.usesOnlineHost) return const SizedBox.shrink();

    // 网易云首页已接入；QQ 待接对应首页接口。
    if (mode != AppMode.netease) {
      return _Unavailable(
        bottomInset: bottomInset,
        message: '${mode.label} 首页推荐即将接入',
      );
    }

    final source = mode.hostId ?? 'netease';
    final statuses = ref.watch(onlinePlatformStatusesProvider);

    return statuses.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace? stack) => _Unavailable(
        bottomInset: bottomInset,
        message: '无法获取登录状态：$error',
        onRetry: () => ref.invalidate(onlinePlatformStatusesProvider),
      ),
      data: (List<rust_online.UiOnlinePlatformStatus> list) {
        if (!onlineHasCookie(list, source)) {
          return _LoginRequired(bottomInset: bottomInset, source: source);
        }

        final nickname = ref
            .watch(
              onlineUserPlaylistsProvider((source: source, page: 1, limit: 10)),
            )
            .value
            ?.firstOrNull
            ?.creator;
        final key = (
          source: source,
          refresh: _generation > 0,
          generation: _generation,
        );
        final feed = ref.watch(onlineHomeFeedProvider(key));

        return feed.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace? stack) {
            // Cookie 过期时 host 会返回 401；直接回到登录提示，不展示错误页。
            if (error.toString().contains('需要登录在线音源')) {
              return _LoginRequired(bottomInset: bottomInset, source: source);
            }
            return _Unavailable(
              bottomInset: bottomInset,
              message: '首页加载失败：$error',
              onRetry: _refresh,
            );
          },
          data: (rust_online.UiOnlineHomeFeed value) {
            final sections = _visibleSections(value.blocks);
            return RefreshIndicator(
              onRefresh: _refreshFeed,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: AppSpacing.lg,
                  bottom: AppSpacing.xxl + bottomInset,
                ),
                children: <Widget>[
                  _buildShortcutRow(value),
                  const SizedBox(height: AppSpacing.xl),
                  const _PrivateFmSection(),
                  const SizedBox(height: AppSpacing.xl),
                  for (final block in sections) ...<Widget>[
                    _HomeBlockSection(block: block),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  _RadarHomeSection(nickname: nickname),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 1.0.1 发现页明确跳过的 block；这些入口已由顶部六卡或其他页面承接。
  static const Set<String> _hiddenBlockCodes = <String>{
    'HOMEPAGE_BANNER',
    'HOMEPAGE_BLOCK_OLD_DRAGON_BALL',
    'HOMEPAGE_PODCAST24',
    'HOMEPAGE_BLOCK_STYLE_RCMD',
    'HOMEPAGE_BLOCK_MGC_PLAYLIST',
    'HOMEPAGE_MUSIC_PODCAST_RCMD_BLOCK',
    'HOMPAGE_BLOCK_VIP_RCMD',
    'HOMEPAGE_BLOCK_OFFICIAL_PLAYLIST',
    'HOMEPAGE_BLOCK_YUNCUN_PRODUCED',
    'HOMEPAGE_BLOCK_VIDEO_PLAYLIST',
    'HOMEPAGE_BLOCK_NEW_HOT_COMMENT',
    'HOMEPAGE_BLOCK_NEW_ALBUM_NEW_SONG',
    'HOMEPAGE_BLOCK_HOT_TOPIC',
  };

  List<rust_online.UiOnlineHomeBlock> _visibleSections(
    List<rust_online.UiOnlineHomeBlock> blocks,
  ) {
    return blocks
        .where(
          (block) =>
              !_hiddenBlockCodes.contains(block.code) &&
              block.title.trim().isNotEmpty &&
              block.items.isNotEmpty &&
              block.code != 'HOMEPAGE_BLOCK_TAILORED_SONG' &&
              !block.title.contains('根据你喜爱的歌曲推荐'),
        )
        .toList(growable: false);
  }

  Widget _buildShortcutRow(rust_online.UiOnlineHomeFeed feed) {
    final dailyCover = ref
        .watch(onlineDailySongsProvider)
        .value
        ?.firstOrNull
        ?.coverId;
    final likedCover = ref
        .watch(
          onlineUserPlaylistsProvider((source: 'netease', page: 1, limit: 10)),
        )
        .value
        ?.firstOrNull
        ?.coverUrl;
    final roamCover = ref
        .watch(onlinePersonalFmPreviewProvider)
        .value
        ?.firstOrNull
        ?.coverId;
    final playlistBlock = _findBlock(feed, const <String>{
      'HOMEPAGE_BLOCK_PLAYLIST_RCMD',
      'HOMEPAGE_BLOCK_OFFICIAL_PLAYLIST',
    });
    final radar = ref.watch(onlineRadarPlaylistsProvider);
    return OnlineShortcutRow(
      dailyCover: dailyCover ?? playlistBlock?.items.firstOrNull?.coverUrl,
      heartCover: likedCover,
      playlistCover: playlistBlock?.items.firstOrNull?.coverUrl,
      roamCover: roamCover,
      radarCover: radar.value?.firstOrNull?.coverUrl,
      similarCover: likedCover,
      onDaily: _openDaily,
      onHeart: _playHeart,
      onPlaylists: () =>
          _openBlock(context, title: '推荐歌单', block: playlistBlock),
      onRoam: _playRoam,
      onRadar: _openRadar,
      onSimilar: _playSimilar,
    );
  }

  rust_online.UiOnlineHomeBlock? _findBlock(
    rust_online.UiOnlineHomeFeed feed,
    Set<String> codes,
  ) {
    for (final block in feed.blocks) {
      if (codes.contains(block.code) && block.items.isNotEmpty) return block;
    }
    return null;
  }

  void _refresh() {
    ref.invalidate(onlineRadarPlaylistsProvider);
    ref.invalidate(onlinePersonalFmPreviewProvider);
    setState(() => _generation++);
  }

  Future<void> _refreshFeed() async {
    ref.invalidate(onlineRadarPlaylistsProvider);
    ref.invalidate(onlinePersonalFmPreviewProvider);
    final next = _generation + 1;
    setState(() => _generation = next);
    final source = ref.read(appModeProvider).hostId ?? 'netease';
    try {
      await ref.read(
        onlineHomeFeedProvider((
          source: source,
          refresh: true,
          generation: next,
        )).future,
      );
    } catch (_) {
      // 错误由 provider 状态展示。
    }
  }

  void _openRadar() {
    final playlists =
        ref.read(onlineRadarPlaylistsProvider).value ??
        const <rust_online.UiOnlinePlaylist>[];
    if (playlists.isEmpty) {
      _showMessage('雷达歌单暂时没有内容');
      return;
    }
    pushMobileRootPage(
      context,
      OnlineHomeBlockPage(
        title: '雷达歌单',
        items: <rust_online.UiOnlineHomeItem>[
          for (final playlist in playlists) _radarItemFromPlaylist(playlist),
        ],
      ),
      name: MobileRoutes.libraryPlaylists,
    );
  }

  void _openDaily() {
    pushMobileRootPage(
      context,
      const OnlineDailyPage(),
      name: MobileRoutes.discovery,
    );
  }

  Future<void> _playHeart() async {
    final seed = await _seedTrack('心动模式');
    if (seed == null) return;
    await _runPlayAction('心动模式', () async {
      final (baseUrl, token) = await _clientArgs();
      final playlistId = await _seedPlaylistId(seed);
      return rust_online.onlineIntelligence(
        baseUrl: baseUrl,
        token: token,
        source: 'netease',
        trackId: onlinePlatformId(seed),
        playlistId: playlistId,
        count: 10,
      );
    });
  }

  Future<void> _playRoam() async {
    await _runPlayAction('漫游', () async {
      final (baseUrl, token) = await _clientArgs();
      return rust_online.onlinePersonalFm(
        baseUrl: baseUrl,
        token: token,
        source: 'netease',
        mode: null,
        submode: null,
        limit: 10,
      );
    });
  }

  Future<void> _playSimilar() async {
    final seed = await _seedTrack('相似歌曲');
    if (seed == null) return;
    await _runPlayAction('相似歌曲', () async {
      final (baseUrl, token) = await _clientArgs();
      return rust_online.onlineSimilarSongs(
        baseUrl: baseUrl,
        token: token,
        source: 'netease',
        trackId: onlinePlatformId(seed),
        limit: 30,
      );
    });
  }

  Future<rust.UiTrack?> _seedTrack(String label) async {
    final current = ref.read(playerProvider).current;
    if (current != null && current.source == 'netease') return current;
    try {
      final tracks = await ref.read(onlineDailySongsProvider.future);
      if (tracks.isNotEmpty) return tracks.first;
    } catch (_) {
      // 日推不可用时继续走提示。
    }
    _showMessage('$label 需要先播放一首网易云歌曲或登录后使用');
    return null;
  }

  Future<String?> _seedPlaylistId(rust.UiTrack seed) async {
    try {
      final playlists = await ref.read(
        onlineUserPlaylistsProvider((
          source: 'netease',
          page: 1,
          limit: 10,
        )).future,
      );
      if (playlists.isNotEmpty) return playlists.first.id;
    } catch (_) {
      // 未登录时退回当前歌曲所属专辑 id。
    }
    return seed.albumId.isEmpty ? null : seed.albumId;
  }

  Future<(String, String?)> _clientArgs() async {
    final baseUrl = ref.read(onlineBaseUrlProvider);
    if (baseUrl.isEmpty) throw StateError('当前模式 sidecar 未启动');
    final token = await ref.read(onlineTokenProvider.future);
    return (baseUrl, token);
  }

  Future<void> _runPlayAction(
    String label,
    Future<List<rust.UiTrack>> Function() fetch,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final tracks = await fetch();
      if (tracks.isEmpty) {
        _showMessage('$label 暂时没有歌曲');
        return;
      }
      ref.read(playerProvider.notifier).load(tracks, 0, source: label);
    } catch (error) {
      _showMessage('$label 加载失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openBlock(
    BuildContext context, {
    required String title,
    required rust_online.UiOnlineHomeBlock? block,
  }) {
    if (block == null || block.items.isEmpty) {
      _showMessage('$title 暂时没有内容');
      return;
    }
    pushMobileRootPage(
      context,
      OnlineHomeBlockPage(title: title, items: block.items),
      name: MobileRoutes.libraryPlaylists,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    M3ESnackbar.show(context, message: message);
  }
}

rust_online.UiOnlineHomeItem _radarItemFromPlaylist(
  rust_online.UiOnlinePlaylist playlist,
) {
  return rust_online.UiOnlineHomeItem(
    kind: 'list',
    id: playlist.id,
    title: playlist.name,
    subtitle: playlist.creator ?? '',
    coverUrl: playlist.coverUrl,
    section: '',
    artists: playlist.creator ?? '',
    album: '',
    albumId: '',
    durationSeconds: BigInt.zero,
    playCount: playlist.playCount,
    trackCount: playlist.trackCount,
    action: '',
    source: playlist.source,
  );
}

rust.UiTrack _trackFromHomeItem(rust_online.UiOnlineHomeItem item) {
  final seconds = item.durationSeconds.toInt();
  return rust.UiTrack(
    id: 'netease:${item.id}',
    title: item.title,
    artist: item.artists,
    album: item.album,
    albumArtist: item.artists,
    albumId: item.albumId,
    artistId: '',
    duration: '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
    durationSeconds: item.durationSeconds,
    path: '',
    source: item.source.isEmpty ? 'netease' : item.source,
    sourceId: 'netease',
    coverId: item.coverUrl,
    sourceExtraJson: jsonEncode(<String, String>{
      'platformId': item.id,
      'source': item.source.isEmpty ? 'netease' : item.source,
    }),
  );
}

void _openHomeCard(BuildContext context, rust_online.UiOnlineHomeItem item) {
  if (item.id.isEmpty) return;
  switch (item.kind) {
    case 'list':
      pushMobileRootPage(
        context,
        OnlinePlaylistDetailPage(
          playlist: rust_online.UiOnlinePlaylist(
            source: item.source,
            id: item.id,
            name: item.title,
            coverUrl: item.coverUrl,
            trackCount: item.trackCount,
            playCount: item.playCount,
            creator: item.artists,
            description: item.subtitle,
            link: null,
          ),
        ),
        name: MobileRoutes.libraryPlaylists,
      );
    case 'album':
    case 'digitalAlbum':
      pushMobileRootPage(
        context,
        OnlineAlbumDetailPage(
          album: rust_online.UiOnlineAlbum(
            source: item.source,
            id: item.id,
            name: item.title,
            coverUrl: item.coverUrl,
            trackCount: item.trackCount,
            artist: item.artists,
          ),
        ),
        name: MobileRoutes.albumDetail,
      );
  }
}

class _PrivateFmSection extends ConsumerWidget {
  const _PrivateFmSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final pageGutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    final fm = ref.watch(onlinePersonalFmPreviewProvider);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pageGutter),
      child: AppSurface(
        level: AppSurfaceLevel.container,
        borderRadius: AppRadii.xlAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: AppSectionHeader(
                title: '私人 FM',
                leading: const _PrivateFmGlyph(),
                padding: AppInsets.sectionHeader,
                trailing: m3e_core.M3EButton.icon(
                  style: m3e_core.M3EButtonStyle.tonal,
                  size: m3e_core.M3EButtonSize.sm,
                  shape: m3e_core.M3EButtonShape.round,
                  tooltip: '换一批',
                  icon: const Icon(M3EIcons.refresh),
                  label: const Text('换一批'),
                  onPressed: () =>
                      ref.invalidate(onlinePersonalFmPreviewProvider),
                ),
              ),
            ),
            fm.when(
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(
                  child: M3ELoadingIndicator(
                    color: theme.colorScheme.primary,
                    containerColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: AppEmptyState(
                  title: '暂时无法获取私人 FM',
                  message: '检查网易云登录状态后再试',
                  icon: M3EIcons.auto_awesome,
                ),
              ),
              data: (tracks) {
                if (tracks.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xl,
                    ),
                    child: AppEmptyState(
                      title: '还没有私人 FM 内容',
                      message: '播放一些网易云歌曲后再试',
                      icon: M3EIcons.auto_awesome,
                    ),
                  );
                }
                return _PrivateFmContent(tracks: tracks);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivateFmGlyph extends StatelessWidget {
  const _PrivateFmGlyph();

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;

    return SizedBox.square(
      dimension: 32,
      child: M3EShapeContainer(
        kind: M3EShapeKind.sunny,
        color: scheme.primaryContainer,
        child: Center(
          child: Icon(
            M3EIcons.auto_awesome,
            size: AppIconSize.sm,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _PrivateFmContent extends ConsumerWidget {
  const _PrivateFmContent({required this.tracks});

  final List<rust.UiTrack> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final hero = tracks.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 240,
          child: M3ECard(
            variant: M3ECardVariant.filled,
            padding: EdgeInsets.zero,
            borderRadius: AppRadii.xlAll,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _PrivateFmCover(url: hero.coverId, radius: BorderRadius.zero),
                const _PrivateFmScrim(),
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '根据你的口味为你推荐',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typeScale.titleSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${hero.title} · ${hero.artist}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typeScale.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      m3e_core.M3EButton(
                        style: m3e_core.M3EButtonStyle.filled,
                        size: m3e_core.M3EButtonSize.sm,
                        shape: m3e_core.M3EButtonShape.round,
                        onPressed: () => ref
                            .read(playerProvider.notifier)
                            .load(tracks, 0, source: '私人 FM'),
                        child: const Text('播放全部'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _PrivateFmSongRow(tracks: tracks),
      ],
    );
  }
}

class _PrivateFmScrim extends StatelessWidget {
  const _PrivateFmScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.transparent,
              Colors.black.withValues(alpha: 0.78),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivateFmSongRow extends ConsumerWidget {
  const _PrivateFmSongRow({required this.tracks});

  final List<rust.UiTrack> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 大卡固定使用第 1 首；下面从第 2 首开始展示，避免重复。
    final preview = tracks.skip(1).take(3).toList(growable: false);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = AppSpacing.sm;
        final cardWidth = constraints.maxWidth * 0.42;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var index = 0; index < preview.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: gap),
                SizedBox(
                  width: cardWidth,
                  child: _PrivateFmSongTile(
                    track: preview[index],
                    onTap: () => ref
                        .read(playerProvider.notifier)
                        .load(tracks, index + 1, source: '私人 FM'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PrivateFmSongTile extends StatelessWidget {
  const _PrivateFmSongTile({required this.track, required this.onTap});

  final rust.UiTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${track.title} · ${track.artist}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadii.mdAll,
          onTap: onTap,
          child: ClipRRect(
            borderRadius: AppRadii.mdAll,
            child: AspectRatio(
              aspectRatio: 1,
              child: _PrivateFmCover(
                url: track.coverId,
                radius: AppRadii.mdAll,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivateFmCover extends ConsumerWidget {
  const _PrivateFmCover({required this.url, this.radius = AppRadii.mdAll});

  final String? url;
  final BorderRadiusGeometry radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final value = url?.trim() ?? '';
    final proxyUrl = value.isEmpty ? null : onlineImageProxyUrl(ref, value);
    final placeholder = ColoredBox(
      color: scheme.secondaryContainer,
      child: Center(
        child: Icon(
          M3EIcons.music_note,
          size: AppIconSize.lg,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: radius,
      child: proxyUrl == null
          ? placeholder
          : Image.network(
              proxyUrl,
              headers: onlineImageRequestHeaders(ref),
              cacheWidth: 512,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stack) {
                    return placeholder;
                  },
            ),
    );
  }
}

class _RadarHomeSection extends ConsumerWidget {
  const _RadarHomeSection({required this.nickname});

  final String? nickname;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radar = ref.watch(onlineRadarPlaylistsProvider);
    final cards = <rust_online.UiOnlineHomeItem>[
      for (final playlist
          in radar.value ?? const <rust_online.UiOnlinePlaylist>[])
        _radarItemFromPlaylist(playlist),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();

    final sectionTitle = nickname == null ? '雷达歌单' : '$nickname的雷达歌单';
    final gutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: AppSectionHeader(
            title: sectionTitle,
            titleRole: AppTextRole.titleMedium,
            padding: AppInsets.sectionHeader,
          ),
        ),
        _HomeCardCarousel(cards: cards),
      ],
    );
  }
}

class _HomeBlockSection extends StatelessWidget {
  const _HomeBlockSection({required this.block});

  final rust_online.UiOnlineHomeBlock block;

  @override
  Widget build(BuildContext context) {
    final cards = block.items
        .where((item) => item.kind != 'song')
        .toList(growable: false);
    final tracks = block.items
        .where((item) => item.kind == 'song')
        .map(_trackFromHomeItem)
        .toList(growable: false);
    final gutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: AppSectionHeader(
            title: block.title,
            titleRole: AppTextRole.titleMedium,
            padding: AppInsets.sectionHeader,
          ),
        ),
        if (cards.isNotEmpty) _HomeCardCarousel(cards: cards),
        if (cards.isNotEmpty && tracks.isNotEmpty)
          const SizedBox(height: AppSpacing.md),
        if (tracks.isNotEmpty)
          _HomeSongColumns(tracks: tracks, source: block.title),
      ],
    );
  }
}

class _HomeCardCarousel extends StatelessWidget {
  const _HomeCardCarousel({required this.cards});

  final List<rust_online.UiOnlineHomeItem> cards;

  @override
  Widget build(BuildContext context) {
    final gutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    final available = MediaQuery.sizeOf(context).width - gutter * 2;
    final cardWidth = ((available - AppSpacing.lg * 2) / 2.35).clamp(
      120.0,
      180.0,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var index = 0; index < cards.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: cardWidth,
              child: _HomeCard(item: cards[index], width: cardWidth),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.item, required this.width});

  final rust_online.UiOnlineHomeItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final canOpen =
        item.kind == 'list' ||
        item.kind == 'album' ||
        item.kind == 'digitalAlbum';
    return Semantics(
      button: canOpen,
      label: item.title,
      child: SizedBox(
        width: width,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadii.lgAll,
            onTap: canOpen ? () => _openHomeCard(context, item) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: AppRadii.lgAll,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: OnlineCover(url: item.coverUrl, size: width),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  item.title,
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
      ),
    );
  }
}

class _HomeSongColumns extends ConsumerWidget {
  const _HomeSongColumns({required this.tracks, required this.source});

  static const int _rowsPerColumn = 4;
  static const double _rowHeight = 56;

  final List<rust.UiTrack> tracks;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final gutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    final columnWidth = (MediaQuery.sizeOf(context).width * 0.78).clamp(
      240.0,
      360.0,
    );
    final columnCount = (tracks.length / _rowsPerColumn).ceil();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (
            var columnIndex = 0;
            columnIndex < columnCount;
            columnIndex++
          ) ...<Widget>[
            if (columnIndex > 0) const SizedBox(width: AppSpacing.lg),
            SizedBox(
              width: columnWidth,
              child: Builder(
                builder: (BuildContext context) {
                  final start = columnIndex * _rowsPerColumn;
                  final end = (start + _rowsPerColumn).clamp(0, tracks.length);
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
                      final track = columnTracks[index];
                      return m3e_core.M3EListItem(
                        minHeight: _rowHeight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        leading: OnlineCover(url: track.coverId, size: 48),
                        headline: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        supportingText: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        headlineStyle: theme.typeScale.bodyMedium.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                        supportingTextStyle: theme.typeScale.bodySmall.copyWith(
                          color: scheme.onSecondaryContainer.withValues(
                            alpha: 0.75,
                          ),
                        ),
                      );
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

class OnlineShortcutRow extends StatelessWidget {
  const OnlineShortcutRow({
    super.key,
    required this.dailyCover,
    required this.heartCover,
    required this.playlistCover,
    required this.roamCover,
    required this.radarCover,
    required this.similarCover,
    required this.onDaily,
    required this.onHeart,
    required this.onPlaylists,
    required this.onRoam,
    required this.onRadar,
    required this.onSimilar,
  });

  final String? dailyCover;
  final String? heartCover;
  final String? playlistCover;
  final String? roamCover;
  final String? radarCover;
  final String? similarCover;
  final VoidCallback onDaily;
  final VoidCallback onHeart;
  final VoidCallback onPlaylists;
  final VoidCallback onRoam;
  final VoidCallback onRadar;
  final VoidCallback onSimilar;

  @override
  Widget build(BuildContext context) {
    final gutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    final cardWidth = (MediaQuery.sizeOf(context).width * 0.78).clamp(
      240.0,
      360.0,
    );
    final cardHeight = cardWidth * 9 / 16 + 76;
    final entries = <_ShortcutEntry>[
      _ShortcutEntry(
        title: '今日推荐',
        subtitle: '今日限定好歌推荐',
        icon: M3EIcons.today,
        coverUrl: dailyCover,
        onTap: onDaily,
      ),
      _ShortcutEntry(
        title: '心动模式',
        subtitle: '红心歌曲和相似推荐',
        icon: M3EIcons.favorite,
        coverUrl: heartCover,
        onTap: onHeart,
      ),
      _ShortcutEntry(
        title: '歌单推荐',
        subtitle: '打工人续命歌单',
        icon: M3EIcons.queue_music,
        coverUrl: playlistCover,
        onTap: onPlaylists,
      ),
      _ShortcutEntry(
        title: '漫游',
        subtitle: '多样频道无限唱听',
        icon: M3EIcons.explore,
        coverUrl: roamCover,
        onTap: onRoam,
      ),
      _ShortcutEntry(
        title: '雷达歌单',
        subtitle: '反复聆听你爱的歌',
        icon: M3EIcons.radar,
        coverUrl: radarCover,
        onTap: onRadar,
      ),
      _ShortcutEntry(
        title: '相似歌曲',
        subtitle: '从你喜欢的歌听起',
        icon: M3EIcons.music_note,
        coverUrl: similarCover,
        onTap: onSimilar,
      ),
    ];
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: gutter),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.lg),
        itemBuilder: (BuildContext context, int index) {
          return _ShortcutCard(entry: entries[index], width: cardWidth);
        },
      ),
    );
  }
}

class _ShortcutEntry {
  const _ShortcutEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.coverUrl,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? coverUrl;
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.entry, required this.width});

  final _ShortcutEntry entry;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final coverHeight = width * 9 / 16;
    return Semantics(
      button: true,
      label: '${entry.title}，${entry.subtitle}',
      child: SizedBox(
        width: width,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: entry.onTap,
            borderRadius: AppRadii.lgAll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typeScale.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  entry.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typeScale.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: width,
                  height: coverHeight,
                  child: ClipRRect(
                    borderRadius: AppRadii.lgAll,
                    child: _ShortcutCover(entry: entry),
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

class _ShortcutCover extends ConsumerWidget {
  const _ShortcutCover({required this.entry});

  final _ShortcutEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final cover = entry.coverUrl?.trim() ?? '';
    final proxyUrl = cover.isEmpty ? null : onlineImageProxyUrl(ref, cover);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[scheme.primaryContainer, scheme.tertiaryContainer],
        ),
      ),
      child: Center(
        child: Icon(entry.icon, size: 42, color: scheme.onPrimaryContainer),
      ),
    );
    if (proxyUrl == null) return placeholder;
    return Image.network(
      proxyUrl,
      headers: onlineImageRequestHeaders(ref),
      cacheWidth: 512,
      fit: BoxFit.cover,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return placeholder;
      },
    );
  }
}

class OnlineHomeBlockPage extends ConsumerWidget {
  const OnlineHomeBlockPage({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<rust_online.UiOnlineHomeItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          M3EList(
            color: scheme.surface,
            variant: M3ECardVariant.filled,
            itemCount: items.length,
            onTap: (int index) => _openItem(context, ref, items[index]),
            itemBuilder: (BuildContext context, int index) {
              final item = items[index];
              return M3EListItem(
                headline: item.title,
                supportingText: item.subtitle.isNotEmpty
                    ? item.subtitle
                    : item.artists,
                leading: OnlineCover(url: item.coverUrl, size: 48),
                trailing: const Icon(M3EIcons.chevron_right, size: 20),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openItem(
    BuildContext context,
    WidgetRef ref,
    rust_online.UiOnlineHomeItem item,
  ) {
    if (item.id.isEmpty) return;
    switch (item.kind) {
      case 'list':
        pushMobileRootPage(
          context,
          OnlinePlaylistDetailPage(
            playlist: rust_online.UiOnlinePlaylist(
              source: item.source,
              id: item.id,
              name: item.title,
              coverUrl: item.coverUrl,
              trackCount: item.trackCount,
              playCount: item.playCount,
              creator: item.artists,
              description: item.subtitle,
              link: null,
            ),
          ),
          name: MobileRoutes.libraryPlaylists,
        );
      case 'album':
      case 'digitalAlbum':
        pushMobileRootPage(
          context,
          OnlineAlbumDetailPage(
            album: rust_online.UiOnlineAlbum(
              source: item.source,
              id: item.id,
              name: item.title,
              coverUrl: item.coverUrl,
              trackCount: item.trackCount,
              artist: item.artists,
            ),
          ),
          name: MobileRoutes.albumDetail,
        );
      case 'song':
        ref
            .read(playerProvider.notifier)
            .load(<rust.UiTrack>[_trackFromHomeItem(item)], 0, source: '在线推荐');
    }
  }
}

class _LoginRequired extends ConsumerWidget {
  const _LoginRequired({required this.bottomInset, required this.source});

  final double bottomInset;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: AppEmptyState(
          title: '登录后查看首页推荐',
          message: '网易云首页推荐基于你的账号内容，请先登录网易云账号。',
          icon: M3EIcons.lock,
          action: M3EButton(
            style: M3EButtonStyle.filled,
            label: const Text('去登录'),
            onPressed: () async {
              final ok = await pushMobileRootPage<bool>(
                context,
                MobileOnlineLoginPage(source: source),
                name: 'online-login',
              );
              if (!context.mounted) return;
              ref.invalidate(onlinePlatformStatusesProvider);
              if (ok == true) {
                ref.invalidate(onlineHomeFeedProvider);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.bottomInset,
    required this.message,
    this.onRetry,
  });

  final double bottomInset;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: AppEmptyState(
          title: '首页推荐暂不可用',
          message: message,
          icon: M3EIcons.cloud_off,
          action: onRetry == null
              ? null
              : M3EButton(
                  style: M3EButtonStyle.filled,
                  label: const Text('重试'),
                  onPressed: onRetry,
                ),
        ),
      ),
    );
  }
}
