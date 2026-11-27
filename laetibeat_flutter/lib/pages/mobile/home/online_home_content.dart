import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/online.dart' as rust_online;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_mode.dart';
import '../../../design/design.dart';
import '../../../shared/layout/app_bottom_inset.dart';
import '../../../widgets/player/player_provider.dart';
import '../../../widgets/settings/online_provider.dart';
import '../../../widgets/settings/online_settings.dart';
import '../library/online/online_detail_pages.dart';
import '../library/online/online_widgets.dart';
import '../mobile_navigation.dart';
import '../widgets/mobile_large_subpage_app_bar.dart';
import '../routes.dart';
import 'online_daily_page.dart';

/// 在线模式首页：网易云首页动态 feed。
///
/// block 不按位置硬编码；已知 block 用 renderer，未知 block 跳过。
class OnlineHomeContent extends ConsumerStatefulWidget {
  const OnlineHomeContent({super.key});

  @override
  ConsumerState<OnlineHomeContent> createState() => _OnlineHomeContentState();
}

class _OnlineHomeContentState extends ConsumerState<OnlineHomeContent> {
  int _generation = 0;
  bool _busy = false;

  void _refresh() {
    setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appModeProvider);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    if (!mode.usesOnlineHost) return const SizedBox.shrink();

    // 网易云 home feed 已接入；QQ 待接对应的 QQ 首页接口。
    if (mode != AppMode.netease) {
      return _Unavailable(
        bottomInset: bottomInset,
        message: '${mode.label} 首页推荐即将接入',
      );
    }

    final source = mode.hostId ?? 'netease';
    final key = (
      source: source,
      refresh: _generation > 0,
      generation: _generation,
    );
    final feed = ref.watch(onlineHomeFeedProvider(key));

    return feed.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace? stack) => _Unavailable(
        bottomInset: bottomInset,
        message: '首页加载失败：$error',
        onRetry: _refresh,
      ),
      data: (rust_online.UiOnlineHomeFeed value) {
        final blocks = value.blocks
            .where(
              (block) =>
                  block.items.isNotEmpty &&
                  _supportedBlocks.contains(block.code),
            )
            .toList(growable: false);
        if (blocks.isEmpty) {
          return _Unavailable(
            bottomInset: bottomInset,
            message: '暂时没有可展示的推荐内容',
            onRetry: _refresh,
          );
        }
        return ListView(
          padding: EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.xxl + bottomInset,
          ),
          children: <Widget>[
            _buildShortcutRow(value),
            _FeedHeader(onRefresh: _refresh),
            for (final block in blocks) ..._buildBlock(context, block),
          ],
        );
      },
    );
  }

  Widget _buildShortcutRow(rust_online.UiOnlineHomeFeed feed) {
    final playlistBlock = _findBlock(feed, const <String>{
      'HOMEPAGE_BLOCK_PLAYLIST_RCMD',
      'HOMEPAGE_BLOCK_OFFICIAL_PLAYLIST',
    });
    final radarBlock = _findBlock(feed, const <String>{
      'HOMEPAGE_BLOCK_MGC_PLAYLIST',
    });
    return OnlineShortcutRow(
      playlistCover: playlistBlock?.items.firstOrNull?.coverUrl,
      radarCover: radarBlock?.items.firstOrNull?.coverUrl,
      onDaily: _openDaily,
      onHeart: _playHeart,
      onPlaylists: () =>
          _openBlock(context, title: '推荐歌单', block: playlistBlock),
      onRoam: _playRoam,
      onRadar: () => _openBlock(context, title: '雷达歌单', block: radarBlock),
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

  Future<(String, String?)> _clientArgs() async {
    final baseUrl = ref.read(onlineBaseUrlProvider);
    if (baseUrl.isEmpty) throw StateError('当前模式 sidecar 未启动');
    final token = await ref.read(onlineTokenProvider.future);
    return (baseUrl, token);
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

  static const Set<String> _supportedBlocks = <String>{
    'HOMEPAGE_BLOCK_PLAYLIST_RCMD',
    'HOMEPAGE_BLOCK_MGC_PLAYLIST',
    'HOMEPAGE_BLOCK_OFFICIAL_PLAYLIST',
    'HOMEPAGE_BLOCK_STYLE_RCMD',
    'HOMEPAGE_BLOCK_NEW_ALBUM_NEW_SONG',
    'HOMEPAGE_BLOCK_NEW_HOT_COMMENT',
  };

  List<Widget> _buildBlock(
    BuildContext context,
    rust_online.UiOnlineHomeBlock block,
  ) {
    switch (block.code) {
      case 'HOMEPAGE_BLOCK_PLAYLIST_RCMD':
      case 'HOMEPAGE_BLOCK_MGC_PLAYLIST':
      case 'HOMEPAGE_BLOCK_OFFICIAL_PLAYLIST':
        return <Widget>[
          _buildHorizontalSection(
            context,
            title: block.title,
            items: block.items,
            height: 218,
          ),
        ];
      case 'HOMEPAGE_BLOCK_STYLE_RCMD':
      case 'HOMEPAGE_BLOCK_NEW_HOT_COMMENT':
        return <Widget>[
          _buildHorizontalSection(
            context,
            title: block.title,
            items: block.items,
            height: 218,
          ),
        ];
      case 'HOMEPAGE_BLOCK_NEW_ALBUM_NEW_SONG':
        final groups = <String, List<rust_online.UiOnlineHomeItem>>{};
        for (final item in block.items) {
          final section = item.section.trim().isEmpty
              ? block.title
              : '${block.title} · ${item.section}';
          groups
              .putIfAbsent(section, () => <rust_online.UiOnlineHomeItem>[])
              .add(item);
        }
        return <Widget>[
          for (final entry in groups.entries)
            _buildHorizontalSection(
              context,
              title: entry.key,
              items: entry.value,
              height: 218,
            ),
        ];
      default:
        return const <Widget>[];
    }
  }

  Widget _buildHorizontalSection(
    BuildContext context, {
    required String title,
    required List<rust_online.UiOnlineHomeItem> items,
    required double height,
  }) {
    final theme = M3ETheme.of(context);
    final gutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: AppSectionHeader(
              title: title.isEmpty ? '推荐' : title,
              padding: AppInsets.sectionHeader,
            ),
          ),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: gutter),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (BuildContext context, int index) {
                final item = items[index];
                return _FeedCard(
                  item: item,
                  theme: theme,
                  onTap: () => _openItem(context, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openItem(BuildContext context, rust_online.UiOnlineHomeItem item) {
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
        _playSong(item);
    }
  }

  void _playSong(rust_online.UiOnlineHomeItem item) {
    final seconds = item.durationSeconds.toInt();
    final track = rust.UiTrack(
      id: 'netease:${item.id}',
      title: item.title,
      artist: item.artists,
      album: item.album,
      albumArtist: item.artists,
      albumId: item.albumId,
      artistId: '',
      duration: _formatDuration(seconds),
      durationSeconds: item.durationSeconds,
      path: '',
      source: 'netease',
      sourceId: 'netease',
      coverId: item.coverUrl,
      sourceExtraJson: jsonEncode(<String, String>{
        'platformId': item.id,
        'source': 'netease',
      }),
    );
    ref
        .read(playerProvider.notifier)
        .load(<rust.UiTrack>[track], 0, source: '网易云首页');
  }

  String _formatDuration(int seconds) {
    final value = seconds <= 0 ? 0 : seconds;
    return '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}';
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final gutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter - 8, AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(child: Text('为你推荐', style: theme.typeScale.titleMedium)),
          M3EIconButton(
            variant: M3EIconButtonVariant.standard,
            icon: const Icon(M3EIcons.refresh),
            tooltip: '换一批',
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.item,
    required this.theme,
    required this.onTap,
  });

  final rust_online.UiOnlineHomeItem item;
  final M3EThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = item.subtitle.isNotEmpty
        ? item.subtitle
        : item.artists.isNotEmpty
        ? item.artists
        : item.section;
    return SizedBox(
      width: 132,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            OnlineCover(url: item.coverUrl, size: 132),
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.title.isEmpty ? '未命名' : item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.typeScale.bodyMedium,
            ),
            if (subtitle.isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typeScale.bodySmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
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

class OnlineShortcutRow extends StatelessWidget {
  const OnlineShortcutRow({
    super.key,
    required this.playlistCover,
    required this.radarCover,
    required this.onDaily,
    required this.onHeart,
    required this.onPlaylists,
    required this.onRoam,
    required this.onRadar,
    required this.onSimilar,
  });

  final String? playlistCover;
  final String? radarCover;
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
        onTap: onDaily,
      ),
      _ShortcutEntry(
        title: '心动模式',
        subtitle: '红心歌曲和相似推荐',
        icon: M3EIcons.favorite,
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

class _ShortcutCover extends StatelessWidget {
  const _ShortcutCover({required this.entry});

  final _ShortcutEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    final cover = entry.coverUrl?.trim() ?? '';
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
    if (cover.isEmpty) return placeholder;
    return Image.network(
      cover,
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
        final seconds = item.durationSeconds.toInt();
        ref
            .read(playerProvider.notifier)
            .load(
              <rust.UiTrack>[
                rust.UiTrack(
                  id: 'netease:${item.id}',
                  title: item.title,
                  artist: item.artists,
                  album: item.album,
                  albumArtist: item.artists,
                  albumId: item.albumId,
                  artistId: '',
                  duration:
                      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                  durationSeconds: item.durationSeconds,
                  path: '',
                  source: 'netease',
                  sourceId: 'netease',
                  coverId: item.coverUrl,
                  sourceExtraJson: jsonEncode(<String, String>{
                    'platformId': item.id,
                    'source': 'netease',
                  }),
                ),
              ],
              0,
              source: '在线推荐',
            );
    }
  }
}
