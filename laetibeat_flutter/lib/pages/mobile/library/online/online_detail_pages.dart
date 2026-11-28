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
    return _OnlineTracksScaffold(
      title: album.name,
      subtitle: [
        if (album.artist != null && album.artist!.isNotEmpty) album.artist!,
        if (album.trackCount > 0) '${album.trackCount} 首',
      ].join(' · '),
      coverUrl: album.coverUrl,
      source: album.source,
      tracks: tracks,
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
        return _OnlineTracksScaffold(
          title: '我喜欢的音乐',
          subtitle: playlist.trackCount > 0 ? '${playlist.trackCount} 首' : '',
          coverUrl: playlist.coverUrl,
          source: playlist.source,
          tracks: tracks,
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
  });

  final String title;
  final String subtitle;
  final String? coverUrl;
  final String source;
  final AsyncValue<List<rust.UiTrack>> tracks;

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
                          style: baseTheme.typeScale.headlineMedium,
                        ),
                        if (subtitle.isNotEmpty) ...<Widget>[
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
                        const SizedBox(height: AppSpacing.lg),
                        M3EButton(
                          style: M3EButtonStyle.filled,
                          label: const Text('播放全部'),
                          onPressed: () => ref
                              .read(playerProvider.notifier)
                              .load(items, 0, source: trackSource),
                        ),
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
                          minHeight: 64,
                          leading: OnlineCover(url: track.coverId),
                          headline: Text(track.title),
                          supportingText: Text(track.artist),
                          headlineStyle: baseTheme.typeScale.bodyLarge.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                          supportingTextStyle: baseTheme.typeScale.bodyMedium
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
