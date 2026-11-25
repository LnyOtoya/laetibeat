import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../src/rust/api/simple.dart' as rust;
import '../../../../widgets/player/cover_provider.dart';
import '../../../../widgets/player/player_provider.dart';
import '../../../../widgets/settings/favorites_provider.dart';
import '../../../../widgets/settings/music_library_provider.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../albums/local_album_detail_page.dart';
import '../widgets/library_source_badge.dart';

/// 封面色缓存：同一份封面字节只取色一次。
final _coverColorProvider = FutureProvider.family<Color, Uint8List>(
  (ref, bytes) => dominantCoverColor(bytes),
);

/// 本地艺术家详情页。
///
/// 当前作为新版详情页的试验页：
/// - 大封面延伸到状态栏；
/// - 顶部栏默认透明，向上滚动后淡入封面色表面；
/// - 内容区使用封面派生配色，并与封面底部渐变衔接；
/// - 名称下方是 m3e_core 的 tonal 按钮组（原生 squish，形状后续替换为 cookie）。
class LocalArtistDetailPage extends ConsumerStatefulWidget {
  const LocalArtistDetailPage({super.key, required this.artist});

  final rust.UiArtist artist;

  @override
  ConsumerState<LocalArtistDetailPage> createState() =>
      _LocalArtistDetailPageState();
}

class _LocalArtistDetailPageState extends ConsumerState<LocalArtistDetailPage> {
  static const double _barTintDistance = 120;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _barProgress = ValueNotifier<double>(0);
  bool _showDetails = false;

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
    final state = ref.watch(musicLibraryProvider).value;
    final allTracks = state?.tracks ?? const <rust.UiTrack>[];

    final tracks = allTracks
        .where(
          (track) =>
              track.artistId == widget.artist.id ||
              track.artist == widget.artist.name ||
              track.albumArtist == widget.artist.name,
        )
        .toList(growable: false);
    final albumIds = tracks.map((track) => track.albumId).toSet();
    final albums = (state?.albums ?? const <rust.UiAlbum>[])
        .where(
          (album) =>
              album.artist == widget.artist.name || albumIds.contains(album.id),
        )
        .toList(growable: false);
    final tracksById = <String, rust.UiTrack>{
      for (final track in allTracks) track.id: track,
    };
    final coverTrack = tracksById[widget.artist.coverTrackId];

    final coverAsync = coverTrack == null
        ? null
        : ref.watch(trackCoverProvider(coverTrack));
    final coverBytes = coverAsync?.value;
    final coverColor = coverBytes == null
        ? null
        : ref.watch(_coverColorProvider(coverBytes)).value;

    final scheme = coverColor == null
        ? baseTheme.colorScheme
        : MaterialYouColorScheme.fromSeed(
            coverColor,
            brightness: baseTheme.colorScheme.brightness,
          );
    final contentColor = scheme.surfaceContainer;

    final isCurrentArtist = ref.watch(
      playerProvider.select((PlayerState player) {
        final current = player.current;
        return current != null &&
            (current.artistId == widget.artist.id ||
                current.artist == widget.artist.name ||
                current.albumArtist == widget.artist.name);
      }),
    );
    final isArtistPlaying = ref.watch(
      playerProvider.select((PlayerState player) {
        if (!player.isPlaying) return false;
        final current = player.current;
        return current != null &&
            (current.artistId == widget.artist.id ||
                current.artist == widget.artist.name ||
                current.albumArtist == widget.artist.name);
      }),
    );

    final isFavorite = ref.watch(
      favoriteArtistsProvider.select((ids) => ids.contains(widget.artist.id)),
    );

    void togglePlayback() {
      final notifier = ref.read(playerProvider.notifier);
      if (isCurrentArtist) {
        notifier.toggle();
        return;
      }
      if (tracks.isEmpty) return;
      notifier.load(tracks, 0, source: widget.artist.name);
    }

    void openAlbum(rust.UiAlbum album) {
      pushMobileRootPage(
        context,
        LocalAlbumDetailPage(album: album),
        name: MobileRoutes.albumDetail,
      );
    }

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
                playEnabled: tracks.isNotEmpty,
                isFavorite: isFavorite,
                showDetails: _showDetails,
                trackCount: tracks.length,
                albumCount: albums.length,
                onDetails: () => setState(() => _showDetails = !_showDetails),
                onPlayPause: togglePlayback,
                onFavorite: () => ref
                    .read(favoriteArtistsProvider.notifier)
                    .toggle(widget.artist.id),
              ),
            ),
            if (albums.isNotEmpty) ...<Widget>[
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: l10n.artistAlbums,
                  trailing: l10n.totalAlbums('${albums.length}'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.pageGutter,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: AppSpacing.lg,
                    crossAxisSpacing: AppSpacing.lg,
                    childAspectRatio: 0.76,
                  ),
                  delegate: SliverChildBuilderDelegate((
                    BuildContext context,
                    int index,
                  ) {
                    final album = albums[index];
                    return _ArtistAlbumCard(
                      album: album,
                      coverTrack: tracksById[album.coverTrackId],
                      onTap: () => openAlbum(album),
                    );
                  }, childCount: albums.length),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: _TopSongsSection(
                tracks: tracks,
                onPlay: (int index) {
                  if (tracks.isEmpty) return;
                  ref
                      .read(playerProvider.notifier)
                      .load(tracks, index, source: widget.artist.name);
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
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final double height = math.min(MediaQuery.sizeOf(context).width * 0.9, 500);
    final hasArt = bytes != null && bytes!.isNotEmpty;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 背景用同一张封面的模糊放大版，避免方形专辑封面直出。
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
          // 顶部压暗保证状态栏/返回按钮可读，底部渐变到内容区。
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
    required this.playEnabled,
    required this.isFavorite,
    required this.showDetails,
    required this.trackCount,
    required this.albumCount,
    required this.onDetails,
    required this.onPlayPause,
    required this.onFavorite,
  });

  final String name;
  final bool isPlaying;
  final bool playEnabled;
  final bool isFavorite;
  final bool showDetails;
  final int trackCount;
  final int albumCount;
  final VoidCallback onDetails;
  final VoidCallback onPlayPause;
  final VoidCallback onFavorite;

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
                enabled: playEnabled,
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
            // 受控空集合：按钮只做瞬时动作，不保留选中态。
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
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        LibrarySourceBadge(
                          label: l10n.librarySourceLocal,
                          remote: false,
                        ),
                        _StatChip(text: l10n.librarySongsCount(trackCount)),
                        _StatChip(text: l10n.totalAlbums('$albumCount')),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadii.fullAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          text,
          style: theme.typeScale.labelMedium.copyWith(
            color: scheme.onSecondaryContainer,
          ),
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

class _ArtistAlbumCard extends StatelessWidget {
  const _ArtistAlbumCard({
    required this.album,
    required this.coverTrack,
    required this.onTap,
  });

  final rust.UiAlbum album;
  final rust.UiTrack? coverTrack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final year = album.year;
    final meta = <String>[
      if (year != null) '$year',
      l10n.librarySongsCount(album.trackCount),
    ].join(' · ');

    return InkWell(
      borderRadius: AppRadii.mdAll,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: _LocalAlbumCover(track: coverTrack),
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

class _TopSongsSection extends StatelessWidget {
  const _TopSongsSection({required this.tracks, required this.onPlay});

  final List<rust.UiTrack> tracks;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(
          title: l10n.topSongs,
          trailing: l10n.librarySongsCount(tracks.length),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppLayout.pageGutter),
          child: M3EList(
            itemCount: tracks.length,
            color: theme.colorScheme.surfaceContainerHigh,
            variant: M3ECardVariant.filled,
            emptyBuilder: Center(child: Text(l10n.noSongs)),
            onTap: onPlay,
            itemBuilder: (BuildContext context, int index) {
              final track = tracks[index];
              return M3EListItem(
                leading: _LocalTrackCover(track: track),
                headline: track.title,
                supportingText: track.album,
                trailingText: track.duration,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LocalAlbumCover extends ConsumerWidget {
  const _LocalAlbumCover({required this.track});

  final rust.UiTrack? track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final track = this.track;
    final bytes = track == null
        ? null
        : ref.watch(trackCoverProvider(track)).value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return M3EShapeContainer.cookie12Sided(
      child: hasArt
          ? Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
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

class _LocalTrackCover extends ConsumerWidget {
  const _LocalTrackCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ClipRRect(
      borderRadius: AppRadii.xsAll,
      child: SizedBox.square(
        dimension: 40,
        child: hasArt
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  M3EIcons.music_note,
                  size: AppIconSize.sm,
                  color: scheme.onSecondaryContainer,
                ),
              ),
      ),
    );
  }
}
