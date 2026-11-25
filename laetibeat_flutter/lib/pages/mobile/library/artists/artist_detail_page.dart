import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../src/rust/api/subsonic.dart' as rust_subsonic;
import '../../../../widgets/player/cover_provider.dart';
import '../../../../widgets/player/player_provider.dart';
import '../../../../widgets/remote_browser_provider.dart';
import '../../../../widgets/settings/favorites_provider.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../albums/album_detail_page.dart';

/// 远端艺人封面色缓存。
final _remoteArtistCoverColorProvider = FutureProvider.family<Color, Uint8List>(
  (ref, bytes) => dominantCoverColor(bytes),
);

/// 艺术家详情页（OpenSubsonic）。
///
/// 与本地艺人页共用同一套新版详情页视觉：
/// - 模糊封面背景 + 圆形头像，延伸到状态栏；
/// - 顶部栏默认透明，滚动后淡入封面色表面；
/// - 内容区使用封面派生配色，并与封面底部渐变衔接；
/// - 名称下方是 m3e_core 的 tonal 按钮组；
/// - 详情按钮展开艺人简介，下方是专辑网格。
class ArtistDetailPage extends ConsumerStatefulWidget {
  const ArtistDetailPage({
    super.key,
    required this.sourceId,
    required this.artist,
  });

  final String sourceId;
  final rust_subsonic.UiRemoteArtist artist;

  @override
  ConsumerState<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends ConsumerState<ArtistDetailPage> {
  static const double _barTintDistance = 120;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _barProgress = ValueNotifier<double>(0);
  bool _showDetails = false;
  bool _biographyExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _barProgress.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final double value = (_scrollController.offset / _barTintDistance).clamp(
      0.0,
      1.0,
    );
    if ((_barProgress.value - value).abs() > 0.01) {
      _barProgress.value = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    final coverBytes = ref
        .watch(
          remoteCoverProvider((
            sourceId: widget.sourceId,
            coverId: widget.artist.coverId,
          )),
        )
        .value;
    final coverColor = coverBytes == null
        ? null
        : ref.watch(_remoteArtistCoverColorProvider(coverBytes)).value;

    final scheme = coverColor == null
        ? baseTheme.colorScheme
        : MaterialYouColorScheme.fromSeed(
            coverColor,
            brightness: baseTheme.colorScheme.brightness,
          );
    final contentColor = scheme.surfaceContainer;

    final albumsAsync = ref.watch(
      remoteAlbumsProvider((
        sourceId: widget.sourceId,
        artistId: widget.artist.id,
      )),
    );
    final biographyAsync = ref.watch(
      remoteArtistBiographyProvider((
        sourceId: widget.sourceId,
        artistId: widget.artist.id,
      )),
    );

    final isCurrentArtist = ref.watch(
      playerProvider.select((PlayerState player) {
        final current = player.current;
        return current != null &&
            current.source == 'opensubsonic' &&
            current.sourceId == widget.sourceId &&
            (current.artistId == widget.artist.id ||
                current.artist == widget.artist.name);
      }),
    );
    final isArtistPlaying = ref.watch(
      playerProvider.select((PlayerState player) {
        if (!player.isPlaying) return false;
        final current = player.current;
        return current != null &&
            current.source == 'opensubsonic' &&
            current.sourceId == widget.sourceId &&
            (current.artistId == widget.artist.id ||
                current.artist == widget.artist.name);
      }),
    );

    final favoriteKey = '${widget.sourceId}:${widget.artist.id}';
    final isFavorite = ref.watch(
      favoriteArtistsProvider.select((ids) => ids.contains(favoriteKey)),
    );

    Future<void> togglePlayback() async {
      final notifier = ref.read(playerProvider.notifier);
      if (isCurrentArtist) {
        notifier.toggle();
        return;
      }
      final remoteTracks = await ref.read(
        remoteAllTracksProvider(widget.sourceId).future,
      );
      final tracks = remoteTracks
          .where(
            (track) =>
                track.artistId == widget.artist.id ||
                track.artist == widget.artist.name,
          )
          .map((track) => remoteTrackToUiTrack(track, widget.sourceId))
          .toList(growable: false);
      if (tracks.isEmpty) {
        if (mounted) {
          M3ESnackbar.show(this.context, message: l10n.noSongs);
        }
        return;
      }
      notifier.load(tracks, 0, source: widget.artist.name);
    }

    final albumCount =
        albumsAsync.value?.length ?? widget.artist.albumCount?.toInt();

    return M3ETheme(
      data: baseTheme.withColorScheme(scheme),
      child: Scaffold(
        backgroundColor: contentColor,
        extendBodyBehindAppBar: true,
        appBar: _ArtistAppBar(progress: _barProgress, tint: contentColor),
        body: CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _ArtistHero(bytes: coverBytes, contentColor: contentColor),
            ),
            SliverToBoxAdapter(
              child: _ArtistSummary(
                name: widget.artist.name,
                isPlaying: isArtistPlaying,
                isFavorite: isFavorite,
                showDetails: _showDetails,
                onDetails: () => setState(() => _showDetails = !_showDetails),
                onPlayPause: togglePlayback,
                onFavorite: () => ref
                    .read(favoriteArtistsProvider.notifier)
                    .toggle(favoriteKey),
                details: _ArtistBio(
                  biography: biographyAsync,
                  albumCount: albumCount,
                  expanded: _biographyExpanded,
                  onToggleExpanded: () =>
                      setState(() => _biographyExpanded = !_biographyExpanded),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: l10n.artistAlbums,
                trailing: albumCount == null
                    ? null
                    : l10n.totalAlbums('$albumCount'),
              ),
            ),
            SliverToBoxAdapter(
              child: albumsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: M3ELoadingIndicator()),
                ),
                error: (Object error, StackTrace stackTrace) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.pageGutter,
                    vertical: AppSpacing.lg,
                  ),
                  child: Text(l10n.loadAlbumsFailed),
                ),
                data: (List<rust_subsonic.UiRemoteAlbum> albums) {
                  if (albums.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.pageGutter,
                        vertical: AppSpacing.lg,
                      ),
                      child: Text(l10n.noAlbums),
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppLayout.pageGutter,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisSpacing: AppSpacing.lg,
                          crossAxisSpacing: AppSpacing.lg,
                          childAspectRatio: 0.76,
                        ),
                    itemCount: albums.length,
                    itemBuilder: (BuildContext context, int index) {
                      final album = albums[index];
                      return _RemoteAlbumCard(
                        album: album,
                        sourceId: widget.sourceId,
                        onTap: () => _openAlbum(album),
                      );
                    },
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAlbum(rust_subsonic.UiRemoteAlbum album) {
    pushMobileRootPage(
      context,
      AlbumDetailPage(sourceId: widget.sourceId, album: album),
      name: MobileRoutes.albumDetail,
    );
  }
}

/// 默认透明、滚动后淡入封面色表面的顶部栏。
class _ArtistAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ArtistAppBar({required this.progress, required this.tint});

  final ValueListenable<double> progress;
  final Color tint;

  static final Size _preferredSize = M3EAppBar.top(
    variant: M3EAppBarVariant.small,
    density: M3EAppBarDensity.compact,
    shapeFamily: M3EAppBarShapeFamily.square,
    safeArea: true,
    titleText: '',
  ).preferredSize;

  @override
  Size get preferredSize => _preferredSize;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (BuildContext context, double value, Widget? child) {
        return AppPageBar.detail(
          backgroundColor: Color.lerp(Colors.transparent, tint, value),
        );
      },
    );
  }
}

/// 艺人页头部：模糊封面色背景 + 大圆形艺人头像，延伸至状态栏。
class _ArtistHero extends StatelessWidget {
  const _ArtistHero({required this.bytes, required this.contentColor});

  final Uint8List? bytes;
  final Color contentColor;

  static const double _avatarSize = 176;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    final double height = math.min(MediaQuery.sizeOf(context).width * 0.9, 500);
    final hasArt = bytes != null && bytes!.isNotEmpty;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (hasArt)
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Transform.scale(
                scale: 1.25,
                child: Image.memory(
                  bytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  cacheWidth: 640,
                ),
              ),
            )
          else
            ColoredBox(color: scheme.surfaceContainerHighest),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.12),
                  contentColor,
                ],
                stops: const <double>[0, 0.55, 1],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _ArtistAvatar(bytes: bytes, size: _avatarSize),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistAvatar extends StatelessWidget {
  const _ArtistAvatar({required this.bytes, required this.size});

  final Uint8List? bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    final hasArt = bytes != null && bytes!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.secondaryContainer,
        border: Border.all(
          color: scheme.surface.withValues(alpha: 0.9),
          width: 3,
        ),
        boxShadow: AppElevation.shadowLevel2,
      ),
      child: hasArt
          ? Image.memory(
              bytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: 640,
            )
          : Icon(
              M3EIcons.person,
              size: size * 0.42,
              color: scheme.onSecondaryContainer,
            ),
    );
  }
}

/// 内容区顶部：居中的艺人名 + 居中的按钮组 + 可展开的详情。
class _ArtistSummary extends StatelessWidget {
  const _ArtistSummary({
    required this.name,
    required this.isPlaying,
    required this.isFavorite,
    required this.showDetails,
    required this.onDetails,
    required this.onPlayPause,
    required this.onFavorite,
    required this.details,
  });

  final String name;
  final bool isPlaying;
  final bool isFavorite;
  final bool showDetails;
  final VoidCallback onDetails;
  final VoidCallback onPlayPause;
  final VoidCallback onFavorite;
  final Widget details;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pageGutter,
        AppSpacing.sm,
        AppLayout.pageGutter,
        AppSpacing.lg,
      ),
      child: Column(
        children: <Widget>[
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typeScale.headlineMedium.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          m3e_core.M3EToggleButtonGroup(
            actions: <m3e_core.M3EToggleButtonGroupAction>[
              m3e_core.M3EToggleButtonGroupAction(
                icon: const Icon(M3EIcons.details),
                semanticLabel: l10n.artistDetails,
                tooltip: l10n.artistDetails,
                decoration: const m3e_core.M3EToggleButtonDecoration(
                  borderRadius: 18,
                ),
              ),
              m3e_core.M3EToggleButtonGroupAction(
                icon: Icon(isPlaying ? M3EIcons.pause : M3EIcons.play_arrow),
                semanticLabel: isPlaying ? l10n.pause : l10n.play,
                tooltip: isPlaying ? l10n.pause : l10n.play,
                width: 88,
                decoration: const m3e_core.M3EToggleButtonDecoration(
                  borderRadius: 999,
                ),
              ),
              m3e_core.M3EToggleButtonGroupAction(
                icon: Icon(
                  isFavorite ? M3EIcons.favorite : M3EIcons.favorite_border,
                ),
                semanticLabel: isFavorite
                    ? l10n.removeFromFavorites
                    : l10n.addToFavorites,
                tooltip: isFavorite
                    ? l10n.removeFromFavorites
                    : l10n.addToFavorites,
                decoration: const m3e_core.M3EToggleButtonDecoration(
                  borderRadius: 18,
                ),
              ),
            ],
            type: m3e_core.M3EButtonGroupType.standard,
            shape: m3e_core.M3EButtonShape.round,
            size: m3e_core.M3EButtonSize.md,
            style: m3e_core.M3EButtonStyle.tonal,
            neighborSquish: true,
            selectedIndices: const <int>{},
            onSelectedIndicesChanged: (Set<int> indices) {
              if (indices.isEmpty) return;
              switch (indices.first) {
                case 0:
                  onDetails();
                case 1:
                  onPlayPause();
                case 2:
                  onFavorite();
              }
            },
          ),
          AnimatedSize(
            duration: AppMotion.standard,
            curve: AppMotion.standardCurve,
            alignment: Alignment.topCenter,
            child: showDetails
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: details,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// 详情面板：艺人简介 + 专辑数。
class _ArtistBio extends StatelessWidget {
  const _ArtistBio({
    required this.biography,
    required this.albumCount,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final AsyncValue<String?> biography;
  final int? albumCount;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadii.lgAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.publicData,
                    style: theme.typeScale.titleSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (albumCount != null)
                  Text(
                    l10n.totalAlbums('$albumCount'),
                    style: theme.typeScale.labelMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            biography.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: M3ELoadingIndicator()),
              ),
              error: (Object error, StackTrace stackTrace) => Text(
                l10n.noArtistBio,
                style: theme.typeScale.bodyMedium.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              data: (String? text) {
                final content = text == null || text.trim().isEmpty
                    ? l10n.noArtistBio
                    : text;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleExpanded,
                  child: AnimatedSize(
                    duration: AppMotion.standard,
                    alignment: Alignment.topCenter,
                    child: Text(
                      content,
                      maxLines: expanded ? null : 4,
                      overflow: expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: theme.typeScale.bodyMedium.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pageGutter,
        AppSpacing.xl,
        AppLayout.pageGutter,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(title, style: theme.typeScale.titleLarge)),
          if (trailing != null)
            Text(
              trailing!,
              style: theme.typeScale.labelMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _RemoteAlbumCard extends StatelessWidget {
  const _RemoteAlbumCard({
    required this.album,
    required this.sourceId,
    required this.onTap,
  });

  final rust_subsonic.UiRemoteAlbum album;
  final String sourceId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final meta = <String>[
      if (album.year != null) '${album.year}',
      _formatApproxDuration(album.durationSeconds?.toInt(), l10n),
    ].join(' · ');

    return InkWell(
      borderRadius: AppRadii.mdAll,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: _RemoteAlbumCover(
              sourceId: sourceId,
              coverId: album.coverId,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typeScale.titleSmall.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typeScale.bodySmall.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteAlbumCover extends ConsumerWidget {
  const _RemoteAlbumCover({required this.sourceId, required this.coverId});

  final String sourceId;
  final String? coverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final id = coverId;
    final bytes = id == null || id.isEmpty
        ? null
        : ref
              .watch(remoteCoverProvider((sourceId: sourceId, coverId: id)))
              .value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return M3EShapeContainer.cookie12Sided(
      child: hasArt
          ? Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              cacheWidth: 512,
            )
          : ColoredBox(
              color: scheme.secondaryContainer,
              child: Center(
                child: Icon(
                  M3EIcons.album,
                  size: 28,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
    );
  }
}

String _formatApproxDuration(int? seconds, AppLocalizations l10n) {
  if (seconds == null || seconds <= 0) return l10n.durationUnknown;
  final minutes = (seconds / 60).round();
  if (minutes <= 0) return l10n.lessThanMinute;
  return l10n.approxMinutes(minutes);
}
