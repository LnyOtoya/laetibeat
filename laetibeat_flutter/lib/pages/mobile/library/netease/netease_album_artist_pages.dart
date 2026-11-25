import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../src/rust/api/netease.dart' as rust_netease;
import '../../../../src/rust/api/simple.dart' as rust;
import '../../../../widgets/player/cover_provider.dart';
import '../../../../widgets/player/player_provider.dart';
import '../../../../widgets/settings/netease_provider.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';

class NeteaseAlbumDetailPage extends ConsumerWidget {
  const NeteaseAlbumDetailPage({super.key, required this.album});

  final rust_netease.UiNeteaseAlbum album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final detail = ref.watch(neteaseAlbumDetailProvider(album.id));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageBar.detail(),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppEmptyState(
          title: '专辑加载失败',
          message: '$error',
          icon: M3EIcons.error,
          action: M3EButton(
            style: M3EButtonStyle.tonal,
            label: const Text('重试'),
            onPressed: () =>
                ref.invalidate(neteaseAlbumDetailProvider(album.id)),
          ),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.xxl,
          ),
          children: <Widget>[
            _DetailHeader(
              coverUrl: value.album.coverUrl,
              title: value.album.name,
              subtitle: value.album.artist,
              meta: '${value.album.trackCount} 首',
            ),
            const SizedBox(height: AppSpacing.xl),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppLayout.pageGutter),
              child: AppSectionHeader(
                title: '歌曲',
                padding: AppInsets.sectionHeader,
              ),
            ),
            _NeteaseTrackList(tracks: value.tracks, source: '网易云专辑'),
          ],
        ),
      ),
    );
  }
}

class NeteaseArtistDetailPage extends ConsumerWidget {
  const NeteaseArtistDetailPage({super.key, required this.artist});

  final rust_netease.UiNeteaseArtist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final detail = ref.watch(neteaseArtistDetailProvider(artist.id));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageBar.detail(),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppEmptyState(
          title: '艺人加载失败',
          message: '$error',
          icon: M3EIcons.error,
          action: M3EButton(
            style: M3EButtonStyle.tonal,
            label: const Text('重试'),
            onPressed: () =>
                ref.invalidate(neteaseArtistDetailProvider(artist.id)),
          ),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.xxl,
          ),
          children: <Widget>[
            _DetailHeader(
              coverUrl: value.artist.coverUrl,
              title: value.artist.name,
              subtitle: value.artist.alias.isEmpty
                  ? '网易云艺人'
                  : value.artist.alias.join(' / '),
              meta: '${value.artist.albumSize} 张专辑',
              circular: true,
            ),
            const SizedBox(height: AppSpacing.xl),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppLayout.pageGutter),
              child: AppSectionHeader(
                title: '热门歌曲',
                padding: AppInsets.sectionHeader,
              ),
            ),
            _NeteaseTrackList(tracks: value.tracks, source: '网易云艺人'),
            const SizedBox(height: AppSpacing.xl),
            _ArtistAlbumsSection(artistId: value.artist.id),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends ConsumerWidget {
  const _DetailHeader({
    required this.coverUrl,
    required this.title,
    required this.subtitle,
    required this.meta,
    this.circular = false,
  });

  final String? coverUrl;
  final String title;
  final String subtitle;
  final String meta;
  final bool circular;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final gutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Row(
        children: <Widget>[
          _NeteaseImage(
            url: coverUrl,
            size: 88,
            circular: circular,
            fallbackIcon: circular ? M3EIcons.person : M3EIcons.album,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typeScale.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typeScale.bodyMedium.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  meta,
                  style: theme.typeScale.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeteaseTrackList extends ConsumerWidget {
  const _NeteaseTrackList({required this.tracks, required this.source});

  final List<rust.UiTrack> tracks;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tracks.isEmpty) {
      return const AppEmptyState(
        title: '暂无歌曲',
        message: '网易云没有返回歌曲',
        icon: M3EIcons.music_note,
      );
    }
    return m3e_core.M3ESegmentedList.builder(
      itemCount: tracks.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      listPadding: EdgeInsets.zero,
      onTap: (int index) {
        ref.read(playerProvider.notifier).load(tracks, index, source: source);
      },
      decoration: const m3e_core.M3ESegmentedListDecoration(
        outerRadius: 24,
        innerRadius: 16,
        pressedRadius: 8,
        pressedScale: 0.98,
        hoveredRadius: 16,
        selectedRadius: 28,
        gap: 6,
        padding: EdgeInsets.all(4),
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      ),
      itemBuilder: (BuildContext context, int index) {
        final track = tracks[index];
        return m3e_core.M3EListItem(
          headline: Text(track.title),
          supportingText: Text(track.artist),
          leading: _NeteaseTrackCover(track: track),
        );
      },
    );
  }
}

class _ArtistAlbumsSection extends ConsumerWidget {
  const _ArtistAlbumsSection({required this.artistId});

  final BigInt artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final albums = ref.watch(neteaseArtistAlbumsProvider(artistId));

    return albums.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(
          '专辑加载失败：$error',
          style: theme.typeScale.bodySmall.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text('暂无专辑'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppLayout.pageGutter),
              child: AppSectionHeader(
                title: '专辑',
                padding: AppInsets.sectionHeader,
              ),
            ),
            m3e_core.M3ESegmentedList.builder(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              listPadding: EdgeInsets.zero,
              onTap: (int index) => pushMobileRootPage(
                context,
                NeteaseAlbumDetailPage(album: items[index]),
                name: MobileRoutes.libraryAlbums,
              ),
              decoration: const m3e_core.M3ESegmentedListDecoration(
                outerRadius: 24,
                innerRadius: 16,
                pressedRadius: 8,
                pressedScale: 0.98,
                hoveredRadius: 16,
                selectedRadius: 28,
                gap: 6,
                padding: EdgeInsets.all(4),
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              ),
              itemBuilder: (BuildContext context, int index) {
                final album = items[index];
                return m3e_core.M3EListItem(
                  headline: Text(album.name),
                  supportingText: Text(
                    '${album.artist} · ${album.trackCount} 首',
                  ),
                  leading: _NeteaseImage(
                    url: album.coverUrl,
                    size: 48,
                    fallbackIcon: M3EIcons.album,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _NeteaseTrackCover extends ConsumerWidget {
  const _NeteaseTrackCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final bytes = ref.watch(trackCoverProvider(track)).value;
    return ClipRRect(
      borderRadius: AppRadii.xsAll,
      child: SizedBox.square(
        dimension: 40,
        child: bytes == null || bytes.isEmpty
            ? ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  M3EIcons.music_note,
                  size: AppIconSize.sm,
                  color: scheme.onSecondaryContainer,
                ),
              )
            : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }
}

class _NeteaseImage extends ConsumerWidget {
  const _NeteaseImage({
    required this.url,
    required this.size,
    required this.fallbackIcon,
    this.circular = false,
  });

  final String? url;
  final double size;
  final IconData fallbackIcon;
  final bool circular;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final value = url;
    final bytes = value == null || value.isEmpty
        ? null
        : ref.watch(neteaseImageProvider(value)).value;
    return ClipRRect(
      borderRadius: circular ? BorderRadius.circular(size / 2) : AppRadii.mdAll,
      child: SizedBox.square(
        dimension: size,
        child: bytes == null || bytes.isEmpty
            ? ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  fallbackIcon,
                  size: AppIconSize.lg,
                  color: scheme.onSecondaryContainer,
                ),
              )
            : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }
}
