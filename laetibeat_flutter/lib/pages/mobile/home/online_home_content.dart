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
import '../library/online/online_detail_pages.dart';
import '../library/online/online_widgets.dart';
import '../mobile_navigation.dart';
import '../routes.dart';

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
            _FeedHeader(onRefresh: _refresh),
            for (final block in blocks) ..._buildBlock(context, block),
          ],
        );
      },
    );
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
