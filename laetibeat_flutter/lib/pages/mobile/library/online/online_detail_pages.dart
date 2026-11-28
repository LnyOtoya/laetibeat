import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/online.dart' as rust_online;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../widgets/player/cover_color.dart';
import '../../../../widgets/player/player_provider.dart';
import '../../../../widgets/settings/favorites_provider.dart';
import '../../../../widgets/settings/online_provider.dart';
import '../../../../widgets/settings/online_settings.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import 'online_widgets.dart';

/// 在线封面主色缓存，详情页用它生成 Material You 配色。
final _onlineCoverColorProvider = FutureProvider.family<Color?, String>((
  ref,
  url,
) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final baseUrl = ref.watch(onlineBaseUrlProvider);
  if (baseUrl.isEmpty) return null;
  final token = await ref.watch(onlineTokenProvider.future);
  if (token == null || token.isEmpty) return null;
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse(
        '$baseUrl/api/v1/image',
      ).replace(queryParameters: <String, String>{'url': trimmed}),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) return null;
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    if (bytes.isEmpty) return null;
    return dominantCoverColor(Uint8List.fromList(bytes));
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
});

class OnlinePlaylistDetailPage extends ConsumerWidget {
  const OnlinePlaylistDetailPage({super.key, required this.playlist});

  final rust_online.UiOnlinePlaylist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(
      onlinePlaylistTracksProvider((source: playlist.source, id: playlist.id)),
    );
    final favoriteKey = 'netease:${playlist.id}';
    final isFavorite = ref.watch(
      favoritePlaylistsProvider.select((ids) => ids.contains(favoriteKey)),
    );
    final description = (playlist.description ?? '').trim();
    return _OnlineTracksScaffold(
      title: playlist.name,
      subtitle: [
        if (playlist.creator != null && playlist.creator!.isNotEmpty)
          playlist.creator!,
        if (playlist.trackCount > 0) '${playlist.trackCount} 首',
      ].join(' · '),
      coverUrl: playlist.coverUrl,
      source: playlist.source,
      tracks: tracks,
      isFavorite: isFavorite,
      onFavorite: () =>
          ref.read(favoritePlaylistsProvider.notifier).toggle(favoriteKey),
      infoText: description.isEmpty ? '来说说创建歌单的理由吧~' : description,
      onInfoTap: () => pushMobileRootPage(
        context,
        const _OnlineInfoPlaceholderPage(title: '歌单简介'),
        name: MobileRoutes.libraryPlaylists,
      ),
    );
  }
}

class OnlineAlbumDetailPage extends ConsumerWidget {
  const OnlineAlbumDetailPage({super.key, required this.album});

  final rust_online.UiOnlineAlbum album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(
      onlineAlbumTracksProvider((source: album.source, id: album.id)),
    );
    final meta = ref.watch(onlineAlbumMetaProvider(album.id)).value;
    final artist = meta?.artist.trim().isNotEmpty == true
        ? meta!.artist
        : (album.artist ?? '');
    final releaseDate = meta != null && meta.publishTime > 0
        ? _formatReleaseDate(meta.publishTime)
        : null;
    final description = meta?.description.trim() ?? '';
    final favoriteKey = 'netease:${album.id}';
    final isFavorite = ref.watch(
      favoriteAlbumsProvider.select((ids) => ids.contains(favoriteKey)),
    );
    return _OnlineTracksScaffold(
      title: album.name,
      subtitle: '',
      coverUrl: album.coverUrl,
      source: album.source,
      tracks: tracks,
      artistName: artist,
      releaseDate: releaseDate,
      isFavorite: isFavorite,
      onFavorite: () =>
          ref.read(favoriteAlbumsProvider.notifier).toggle(favoriteKey),
      infoTitle: '专辑详情',
      infoText: description.isEmpty ? '查看专辑详情' : description,
      onInfoTap: () => pushMobileRootPage(
        context,
        const _OnlineInfoPlaceholderPage(title: '专辑详情'),
        name: MobileRoutes.libraryAlbums,
      ),
    );
  }
}

class OnlineTopListDetailPage extends ConsumerWidget {
  const OnlineTopListDetailPage({super.key, required this.topList});

  final rust_online.UiOnlineTopList topList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(
      onlineTopListSongsProvider((source: topList.source, id: topList.id)),
    );
    return _OnlineTracksScaffold(
      title: topList.name,
      subtitle: topList.updateFrequency ?? '',
      coverUrl: topList.coverUrl,
      source: topList.source,
      tracks: tracks,
    );
  }
}

class OnlinePlaylistCollectionPage extends ConsumerStatefulWidget {
  const OnlinePlaylistCollectionPage({
    super.key,
    required this.title,
    required this.kind,
  });

  final String title;
  final String kind;

  @override
  ConsumerState<OnlinePlaylistCollectionPage> createState() =>
      _OnlinePlaylistCollectionPageState();
}

class _OnlinePlaylistCollectionPageState
    extends ConsumerState<OnlinePlaylistCollectionPage> {
  bool _isGrid = true;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final playlists = widget.kind == 'collected'
        ? ref.watch(onlineCollectedPlaylistsProvider)
        : ref.watch(onlineCreatedPlaylistsProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppPageBar.subpage(
        title: widget.title,
        onSearch: () => openMobileSearch(context),
        showLayout: true,
        isGrid: _isGrid,
        onToggleLayout: () => setState(() => _isGrid = !_isGrid),
      ),
      body: playlists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace? stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '加载失败：$error',
              textAlign: TextAlign.center,
              style: theme.typeScale.bodyMedium,
            ),
          ),
        ),
        data: (List<rust_online.UiOnlinePlaylist> items) {
          if (items.isEmpty) {
            return Center(
              child: Text('暂无歌单', style: theme.typeScale.bodyMedium),
            );
          }
          return _isGrid
              ? _buildGrid(context, items)
              : _buildList(context, items);
        },
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<rust_online.UiOnlinePlaylist> items,
  ) {
    final scheme = M3ETheme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        M3EList(
          color: scheme.surface,
          variant: M3ECardVariant.filled,
          itemCount: items.length,
          onTap: (int index) => _openPlaylist(context, items[index]),
          itemBuilder: (BuildContext context, int index) {
            final playlist = items[index];
            return M3EListItem(
              headline: playlist.name,
              supportingText: _playlistMeta(playlist),
              leading: OnlineCover(url: playlist.coverUrl),
              trailing: const Icon(M3EIcons.chevron_right),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<rust_online.UiOnlinePlaylist> items,
  ) {
    final theme = M3ETheme.of(context);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final playlist = items[index];
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return InkWell(
              borderRadius: AppRadii.mdAll,
              onTap: () => _openPlaylist(context, playlist),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  OnlineCover(
                    url: playlist.coverUrl,
                    size: constraints.maxWidth,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    playlist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typeScale.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _playlistMeta(playlist),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typeScale.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openPlaylist(
    BuildContext context,
    rust_online.UiOnlinePlaylist playlist,
  ) {
    pushMobileRootPage(
      context,
      OnlinePlaylistDetailPage(playlist: playlist),
      name: MobileRoutes.libraryPlaylists,
    );
  }
}

class OnlineAlbumCollectionPage extends ConsumerStatefulWidget {
  const OnlineAlbumCollectionPage({super.key});

  @override
  ConsumerState<OnlineAlbumCollectionPage> createState() =>
      _OnlineAlbumCollectionPageState();
}

class _OnlineAlbumCollectionPageState
    extends ConsumerState<OnlineAlbumCollectionPage> {
  bool _isGrid = true;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final albums = ref.watch(onlineCollectedAlbumsProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppPageBar.subpage(
        title: '收藏的专辑',
        onSearch: () => openMobileSearch(context),
        showLayout: true,
        isGrid: _isGrid,
        onToggleLayout: () => setState(() => _isGrid = !_isGrid),
      ),
      body: albums.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace? stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '加载失败：$error',
              textAlign: TextAlign.center,
              style: theme.typeScale.bodyMedium,
            ),
          ),
        ),
        data: (List<rust_online.UiOnlineAlbum> items) {
          if (items.isEmpty) {
            return Center(
              child: Text('暂无收藏专辑', style: theme.typeScale.bodyMedium),
            );
          }
          return _isGrid
              ? _buildGrid(context, items)
              : _buildList(context, items);
        },
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<rust_online.UiOnlineAlbum> items,
  ) {
    final scheme = M3ETheme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        M3EList(
          color: scheme.surface,
          variant: M3ECardVariant.filled,
          itemCount: items.length,
          onTap: (int index) => _openAlbum(context, items[index]),
          itemBuilder: (BuildContext context, int index) {
            final album = items[index];
            return M3EListItem(
              headline: album.name,
              supportingText: _albumMeta(album),
              leading: OnlineCover(url: album.coverUrl),
              trailing: const Icon(M3EIcons.chevron_right),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<rust_online.UiOnlineAlbum> items,
  ) {
    final theme = M3ETheme.of(context);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final album = items[index];
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return InkWell(
              borderRadius: AppRadii.mdAll,
              onTap: () => _openAlbum(context, album),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  OnlineCover(url: album.coverUrl, size: constraints.maxWidth),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    album.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typeScale.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _albumMeta(album),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typeScale.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openAlbum(BuildContext context, rust_online.UiOnlineAlbum album) {
    pushMobileRootPage(
      context,
      OnlineAlbumDetailPage(album: album),
      name: MobileRoutes.libraryAlbums,
    );
  }
}

class OnlineLikedSongsPage extends ConsumerWidget {
  const OnlineLikedSongsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final liked = ref.watch(onlineLikedPlaylistProvider);

    return liked.when(
      loading: () => Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppPageBar.detail(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace? stack) => Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppPageBar.detail(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '加载失败：$error',
              textAlign: TextAlign.center,
              style: theme.typeScale.bodyMedium,
            ),
          ),
        ),
      ),
      data: (rust_online.UiOnlinePlaylist? playlist) {
        if (playlist == null) {
          return Scaffold(
            backgroundColor: scheme.surface,
            appBar: AppPageBar.detail(),
            body: Center(
              child: Text('暂无喜欢的音乐', style: theme.typeScale.bodyMedium),
            ),
          );
        }
        final tracks = ref.watch(
          onlinePlaylistTracksProvider((
            source: playlist.source,
            id: playlist.id,
          )),
        );
        final profile = ref.watch(onlineUserProfileProvider).value;
        final creatorName = profile?.nickname.trim().isNotEmpty == true
            ? profile!.nickname
            : (playlist.creator?.trim().isNotEmpty == true
                  ? playlist.creator!
                  : '网易云用户');
        return _OnlineTracksScaffold(
          title: '我喜欢的音乐',
          subtitle: '',
          coverUrl: playlist.coverUrl,
          source: playlist.source,
          tracks: tracks,
          showCreatorHeader: true,
          creatorName: creatorName,
          creatorAvatarUrl: profile?.avatarUrl,
          trackCount: playlist.trackCount,
          playCount: playlist.playCount.toInt(),
          onCreatorTap: () => pushMobileRootPage(
            context,
            _OnlineCreatorPlaceholderPage(name: creatorName),
            name: MobileRoutes.libraryArtists,
          ),
        );
      },
    );
  }
}

String _joinMeta(List<String> parts) {
  return parts.where((value) => value.trim().isNotEmpty).join(' · ');
}

String _playlistMeta(rust_online.UiOnlinePlaylist playlist) {
  final creator = playlist.creator?.trim() ?? '';
  return _joinMeta(<String>[
    if (playlist.trackCount > 0) '${playlist.trackCount} 首',
    if (creator.isNotEmpty) creator,
  ]);
}

String _albumMeta(rust_online.UiOnlineAlbum album) {
  final artist = album.artist?.trim() ?? '';
  return _joinMeta(<String>[
    if (album.trackCount > 0) '${album.trackCount} 首',
    if (artist.isNotEmpty) artist,
  ]);
}

class _OnlineTracksScaffold extends ConsumerWidget {
  const _OnlineTracksScaffold({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.source,
    required this.tracks,
    this.showCreatorHeader = false,
    this.creatorName,
    this.creatorAvatarUrl,
    this.onCreatorTap,
    this.trackCount,
    this.playCount,
    this.artistName,
    this.releaseDate,
    this.isFavorite = false,
    this.onFavorite,
    this.infoTitle,
    this.infoText,
    this.onInfoTap,
  });

  final String title;
  final String subtitle;
  final String? coverUrl;
  final String source;
  final AsyncValue<List<rust.UiTrack>> tracks;
  final bool showCreatorHeader;
  final String? creatorName;
  final String? creatorAvatarUrl;
  final VoidCallback? onCreatorTap;
  final int? trackCount;
  final int? playCount;
  final String? artistName;
  final String? releaseDate;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final String? infoTitle;
  final String? infoText;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseTheme = M3ETheme.of(context);
    final coverColor = coverUrl == null
        ? null
        : ref.watch(_onlineCoverColorProvider(coverUrl!)).value;
    final scheme = coverColor == null
        ? baseTheme.colorScheme
        : MaterialYouColorScheme.fromSeed(
            coverColor,
            brightness: baseTheme.colorScheme.brightness,
          );
    final contentColor = detailContentColor(scheme);

    return M3ETheme(
      data: baseTheme.withColorScheme(scheme),
      child: Scaffold(
        backgroundColor: contentColor,
        extendBodyBehindAppBar: true,
        appBar: AppPageBar.detail(backgroundColor: Colors.transparent),
        body: tracks.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace? stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '加载失败：$error',
                textAlign: TextAlign.center,
                style: baseTheme.typeScale.bodyMedium,
              ),
            ),
          ),
          data: (List<rust.UiTrack> items) {
            if (items.isEmpty) {
              return const Center(child: Text('暂无歌曲'));
            }
            final trackSource = onlineSourceLabel(source);
            final isCurrent = ref.watch(
              playerProvider.select((PlayerState player) {
                final current = player.current;
                return current != null &&
                    items.any((rust.UiTrack track) => track.id == current.id);
              }),
            );
            final isPlaying = ref.watch(
              playerProvider.select((PlayerState player) => player.isPlaying),
            );
            void onPlayPause() {
              final notifier = ref.read(playerProvider.notifier);
              if (isCurrent) {
                notifier.toggle();
              } else {
                notifier.load(items, 0, source: trackSource);
              }
            }

            void onShuffle() {
              ref
                  .read(playerProvider.notifier)
                  .playShuffled(items, source: trackSource);
            }

            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: _OnlineDetailHero(coverUrl: coverUrl),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      children: <Widget>[
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: baseTheme.typeScale.headlineMedium.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                        if (showCreatorHeader) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          _OnlineCreatorRow(
                            name: creatorName ?? '网易云用户',
                            avatarUrl: creatorAvatarUrl,
                            onTap: onCreatorTap,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _OnlineStatsRow(
                            trackCount: trackCount ?? items.length,
                            playCount: playCount ?? 0,
                          ),
                        ] else if ((artistName ?? '')
                            .trim()
                            .isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            artistName!.trim(),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: baseTheme.typeScale.bodyLarge.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if ((releaseDate ?? '')
                              .trim()
                              .isNotEmpty) ...<Widget>[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              '发行时间 ${releaseDate!.trim()}',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseTheme.typeScale.bodySmall.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ] else if (subtitle.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: baseTheme.typeScale.bodyLarge.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        _OnlinePlaybackControls(
                          isPlaying: isCurrent && isPlaying,
                          isFavorite: isFavorite,
                          onFavorite: onFavorite,
                          onShuffle: onShuffle,
                          onPlayPause: onPlayPause,
                        ),
                        if (infoTitle != null || infoText != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          _OnlineInfoBox(
                            title: infoTitle,
                            text: infoText ?? '',
                            onTap: onInfoTap,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: m3e_core.M3ESegmentedList.builder(
                      listPadding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      onTap: (int index) => ref
                          .read(playerProvider.notifier)
                          .load(items, index, source: trackSource),
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
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final track = items[index];
                        return m3e_core.M3EListItem(
                          minHeight: 56,
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
                          headlineStyle: baseTheme.typeScale.bodyMedium
                              .copyWith(color: scheme.onSecondaryContainer),
                          supportingTextStyle: baseTheme.typeScale.bodySmall
                              .copyWith(
                                color: scheme.onSecondaryContainer.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OnlineCreatorRow extends StatelessWidget {
  const _OnlineCreatorRow({required this.name, this.avatarUrl, this.onTap});

  final String name;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              M3EShapeContainer.circle(
                width: 32,
                height: 32,
                child: OnlineCover(url: avatarUrl, size: 32),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typeScale.titleSmall.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Icon(
                M3EIcons.chevron_right,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnlineStatsRow extends StatelessWidget {
  const _OnlineStatsRow({required this.trackCount, required this.playCount});

  final int trackCount;
  final int playCount;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.typeScale.bodyMedium.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('$trackCount 首', style: style),
          const SizedBox(width: AppSpacing.md),
          Icon(M3EIcons.play_arrow, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xxs),
          Text('$playCount', style: style),
        ],
      ),
    );
  }
}

class _OnlinePlaybackControls extends StatelessWidget {
  const _OnlinePlaybackControls({
    required this.isPlaying,
    required this.onShuffle,
    required this.onPlayPause,
    this.isFavorite = false,
    this.onFavorite,
  });

  final bool isPlaying;
  final VoidCallback onShuffle;
  final VoidCallback onPlayPause;
  final bool isFavorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    const double capsuleWidth = 88;
    const double capsuleHeight = 56;
    const double cookieSize = 56;
    const double gap = 16;
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double capsuleLeft =
              constraints.maxWidth / 2 - capsuleWidth / 2;
          final double cookieLeft = capsuleLeft - gap - cookieSize;
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Align(
                alignment: Alignment.center,
                child: M3EButton(
                  onPressed: onPlayPause,
                  style: M3EButtonStyle.filled,
                  shape: M3EButtonShape.round,
                  tooltip: isPlaying ? '暂停' : '播放',
                  semanticLabel: isPlaying ? '暂停' : '播放',
                  decoration: const M3EButtonDecoration(
                    minimumSize: Size(capsuleWidth, capsuleHeight),
                    fixedSize: Size(capsuleWidth, capsuleHeight),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  child: Icon(
                    isPlaying ? M3EIcons.pause : M3EIcons.play_arrow,
                    size: 28,
                  ),
                ),
              ),
              Positioned(
                left: math.max(0, cookieLeft),
                top: (64 - cookieSize) / 2,
                child: _CookieShuffleButton(onPressed: onShuffle),
              ),
              if (onFavorite != null)
                Positioned(
                  left: capsuleLeft + capsuleWidth + gap,
                  top: (64 - cookieSize) / 2,
                  child: _VerySunnyFavoriteButton(
                    isFavorite: isFavorite,
                    onPressed: onFavorite!,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CookieShuffleButton extends StatelessWidget {
  const _CookieShuffleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '随机播放',
      child: M3EShapeContainer.cookie4Sided(
        width: 56,
        height: 56,
        color: scheme.secondaryContainer,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Icon(
              M3EIcons.shuffle,
              size: 24,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _VerySunnyFavoriteButton extends StatelessWidget {
  const _VerySunnyFavoriteButton({
    required this.isFavorite,
    required this.onPressed,
  });

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: isFavorite ? '取消收藏' : '收藏',
      child: M3EShapeContainer.verySunny(
        width: 56,
        height: 56,
        color: scheme.secondaryContainer,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Icon(
              isFavorite ? M3EIcons.favorite : M3EIcons.favorite_border,
              size: 24,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _OnlineInfoBox extends StatelessWidget {
  const _OnlineInfoBox({
    required this.title,
    required this.text,
    required this.onTap,
  });

  final String? title;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final heading = title?.trim() ?? '';
    final body = text.trim().isEmpty ? '来说说创建歌单的理由吧~' : text.trim();
    return Material(
      color: scheme.secondaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (heading.isNotEmpty) ...<Widget>[
                      Text(
                        heading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typeScale.titleSmall.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                    ],
                    Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typeScale.bodySmall.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                M3EIcons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnlineInfoPlaceholderPage extends StatelessWidget {
  const _OnlineInfoPlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppPageBar.detail(),
      body: Center(child: Text('$title 将在后续接入')),
    );
  }
}

String _formatReleaseDate(int milliseconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

class _OnlineCreatorPlaceholderPage extends StatelessWidget {
  const _OnlineCreatorPlaceholderPage({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppPageBar.detail(),
      body: Center(child: Text('$name 的主页将在后续接入')),
    );
  }
}

class _OnlineDetailHero extends ConsumerWidget {
  const _OnlineDetailHero({required this.coverUrl});

  final String? coverUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final height = math.min(MediaQuery.sizeOf(context).width, 420.0);
    final value = coverUrl?.trim() ?? '';
    final proxyUrl = value.isEmpty ? null : onlineImageProxyUrl(ref, value);
    final fallback = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          M3EIcons.music_note,
          size: 72,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.white,
                Colors.white,
                Colors.white70,
                Colors.transparent,
              ],
              stops: <double>[0, 0.55, 0.78, 1],
            ).createShader(rect),
            child: proxyUrl == null
                ? fallback
                : Image.network(
                    proxyUrl,
                    headers: onlineImageRequestHeaders(ref),
                    fit: BoxFit.cover,
                    cacheWidth: 900,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stack,
                        ) {
                          return fallback;
                        },
                  ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x59000000), Color(0x00000000)],
                stops: <double>[0, 0.32],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
