import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/layout/app_bottom_inset.dart';
import '../../../../src/rust/api/simple.dart' as rust;
import '../../../../src/rust/api/subsonic.dart' as rust_subsonic;
import '../../../../widgets/player/cover_provider.dart';
import '../../../../widgets/player/player_provider.dart';
import '../../../../widgets/remote_browser_provider.dart';
import '../../../../widgets/settings/favorites_provider.dart';
import '../playlists/playlist_actions.dart';

/// 专辑封面色缓存。
final _albumCoverColorProvider = FutureProvider.family<Color, Uint8List>(
  (ref, bytes) => dominantCoverColor(bytes),
);

/// 专辑详情页（OpenSubsonic）。
///
/// - 顶部整块大封面，底部透明渐隐到内容区；
/// - 专辑名 / 参与艺术家 / 发行日期三行；
/// - m3e_core tonal 按钮组：随机 / 播放暂停 / 收藏；
/// - 多碟时按碟分组，碟号左对齐显示；
/// - 歌曲用 m3e_core 分段列表，右侧三点菜单。
class AlbumDetailPage extends ConsumerStatefulWidget {
  const AlbumDetailPage({
    super.key,
    required this.sourceId,
    required this.album,
  });

  final String sourceId;
  final rust_subsonic.UiRemoteAlbum album;

  @override
  ConsumerState<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends ConsumerState<AlbumDetailPage> {
  static const double _barTintDistance = 120;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _barProgress = ValueNotifier<double>(0);

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
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final l10n = AppLocalizations.of(context);

    final tracksAsync = ref.watch(
      remoteTracksProvider((
        sourceId: widget.sourceId,
        albumId: widget.album.id,
      )),
    );
    final tracks = (tracksAsync.value ?? const <rust_subsonic.UiRemoteTrack>[])
        .map((track) => remoteTrackToUiTrack(track, widget.sourceId))
        .toList(growable: false);

    final coverBytes = ref
        .watch(
          remoteCoverProvider((
            sourceId: widget.sourceId,
            coverId: widget.album.coverId,
          )),
        )
        .value;
    final coverColor = coverBytes == null
        ? null
        : ref.watch(_albumCoverColorProvider(coverBytes)).value;

    final scheme = coverColor == null
        ? baseTheme.colorScheme
        : MaterialYouColorScheme.fromSeed(
            coverColor,
            brightness: baseTheme.colorScheme.brightness,
          );
    final contentColor = detailContentColor(scheme);

    final isCurrentAlbum = ref.watch(
      playerProvider.select((PlayerState player) {
        final current = player.current;
        return current != null &&
            current.source == 'opensubsonic' &&
            current.sourceId == widget.sourceId &&
            current.albumId == widget.album.id;
      }),
    );
    final isAlbumPlaying = ref.watch(
      playerProvider.select((PlayerState player) {
        if (!player.isPlaying) return false;
        final current = player.current;
        return current != null &&
            current.source == 'opensubsonic' &&
            current.sourceId == widget.sourceId &&
            current.albumId == widget.album.id;
      }),
    );

    final favoriteKey = '${widget.sourceId}:${widget.album.id}';
    final isFavorite = ref.watch(
      favoriteAlbumsProvider.select((ids) => ids.contains(favoriteKey)),
    );

    void playFrom(int index) {
      if (tracks.isEmpty) return;
      ref
          .read(playerProvider.notifier)
          .load(tracks, index, source: widget.album.title);
    }

    void togglePlayback() {
      final notifier = ref.read(playerProvider.notifier);
      if (isCurrentAlbum) {
        notifier.toggle();
        return;
      }
      if (tracks.isEmpty) return;
      notifier.load(tracks, 0, source: widget.album.title);
    }

    void shufflePlay() {
      if (tracks.isEmpty) return;
      ref
          .read(playerProvider.notifier)
          .playShuffled(tracks, source: widget.album.title);
    }

    return M3ETheme(
      data: baseTheme.withColorScheme(scheme),
      child: Scaffold(
        backgroundColor: contentColor,
        extendBodyBehindAppBar: true,
        appBar: _AlbumAppBar(progress: _barProgress, tint: contentColor),
        body: CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            SliverToBoxAdapter(child: _AlbumHero(bytes: coverBytes)),
            SliverToBoxAdapter(
              child: _AlbumSummary(
                title: widget.album.title,
                artist: widget.album.artist,
                releaseText: l10n.releaseDate(
                  widget.album.year?.toString() ?? l10n.unknown,
                ),
                isPlaying: isAlbumPlaying,
                playEnabled: tracks.isNotEmpty,
                isFavorite: isFavorite,
                onShuffle: shufflePlay,
                onPlayPause: togglePlayback,
                onFavorite: () => ref
                    .read(favoriteAlbumsProvider.notifier)
                    .toggle(favoriteKey),
              ),
            ),
            // OpenSubsonic 暂无专辑简介字段；有简介数据时在这里插入两行
            // 可展开的详情区域。
            SliverToBoxAdapter(
              child: _AlbumTracksSection(
                sourceId: widget.sourceId,
                tracksAsync: tracksAsync,
                onPlayIndex: playFrom,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.xxl + bottomInset),
            ),
          ],
        ),
      ),
    );
  }
}

/// 默认透明、滚动后淡入封面色的顶部栏。
class _AlbumAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AlbumAppBar({required this.progress, required this.tint});

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

/// 顶部大封面：铺满上方区域，底部透明渐隐到内容区。
class _AlbumHero extends StatelessWidget {
  const _AlbumHero({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    final double height = math.min(MediaQuery.sizeOf(context).width, 520);
    final hasArt = bytes != null && bytes!.isNotEmpty;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (hasArt)
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
              child: Image.memory(
                bytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: 900,
              ),
            )
          else
            ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  M3EIcons.album,
                  size: 72,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          // 顶部轻微压暗，保证状态栏和顶部按钮可读。
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

/// 专辑名 / 艺术家 / 发行日期 + 随机、播放、收藏按钮组。
class _AlbumSummary extends StatelessWidget {
  const _AlbumSummary({
    required this.title,
    required this.artist,
    required this.releaseText,
    required this.isPlaying,
    required this.playEnabled,
    required this.isFavorite,
    required this.onShuffle,
    required this.onPlayPause,
    required this.onFavorite,
  });

  final String title;
  final String artist;
  final String releaseText;
  final bool isPlaying;
  final bool playEnabled;
  final bool isFavorite;
  final VoidCallback onShuffle;
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
        AppSpacing.sm,
      ),
      child: Column(
        children: <Widget>[
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typeScale.headlineMedium.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            artist,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typeScale.bodyLarge.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            releaseText,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typeScale.labelMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          m3e_core.M3EToggleButtonGroup(
            actions: <m3e_core.M3EToggleButtonGroupAction>[
              m3e_core.M3EToggleButtonGroupAction(
                icon: const Icon(M3EIcons.shuffle),
                semanticLabel: l10n.shufflePlay,
                tooltip: l10n.shufflePlay,
                enabled: playEnabled,
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
            selectedIndices: const <int>{},
            onSelectedIndicesChanged: (Set<int> indices) {
              if (indices.isEmpty) return;
              switch (indices.first) {
                case 0:
                  onShuffle();
                case 1:
                  onPlayPause();
                case 2:
                  onFavorite();
              }
            },
          ),
        ],
      ),
    );
  }
}

/// 歌曲区：多碟时按碟分组，每碟一个 m3e_core 分段列表。
class _AlbumTracksSection extends ConsumerWidget {
  const _AlbumTracksSection({
    required this.sourceId,
    required this.tracksAsync,
    required this.onPlayIndex,
  });

  final String sourceId;
  final AsyncValue<List<rust_subsonic.UiRemoteTrack>> tracksAsync;
  final ValueChanged<int> onPlayIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return tracksAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(child: M3ELoadingIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.pageGutter,
          vertical: AppSpacing.lg,
        ),
        child: Text(
          '${l10n.loadTracksFailed}\n$error',
          textAlign: TextAlign.center,
          style: theme.typeScale.bodyMedium.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
      data: (List<rust_subsonic.UiRemoteTrack> list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: Text(l10n.noTracks)),
          );
        }

        final groups = <int, List<rust_subsonic.UiRemoteTrack>>{};
        for (final track in list) {
          groups.putIfAbsent(track.discNumber ?? 1, () => []).add(track);
        }
        final discs = groups.keys.toList()..sort();
        final multiDisc = discs.length > 1;

        final children = <Widget>[];
        var globalIndex = 0;
        for (final disc in discs) {
          final discTracks = groups[disc]!;
          final startIndex = globalIndex;

          if (multiDisc) {
            children.add(
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  startIndex == 0 ? AppSpacing.xs : AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.discNumber(disc),
                    style: theme.typeScale.titleSmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }

          children.add(
            m3e_core.M3ESegmentedList.builder(
              // 嵌套在页面滚动里，必须显式清空，否则 ListView 会套用
              // MediaQuery 的状态栏/底部安全区 padding，形成很大的空档。
              listPadding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: discTracks.length,
              onTap: (int index) => onPlayIndex(startIndex + index),
              decoration: m3e_core.M3ESegmentedListDecoration(
                // 与上方 tonal 按钮组一致：secondaryContainer / onSecondaryContainer。
                color: theme.colorScheme.secondaryContainer,
                splashColor: theme.colorScheme.onSecondaryContainer.withValues(
                  alpha: 0.12,
                ),
                highlightColor: theme.colorScheme.onSecondaryContainer
                    .withValues(alpha: 0.08),
                hoverColor: theme.colorScheme.onSecondaryContainer.withValues(
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
                final track = discTracks[index];
                final number = track.trackNumber ?? index + 1;
                return m3e_core.M3EListItem(
                  minHeight: 64,
                  leading: SizedBox.square(
                    dimension: AppIconSize.xl,
                    child: Center(
                      child: Text(
                        '$number',
                        style: theme.typeScale.titleMedium.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                  headline: Text(track.title),
                  supportingText: Text(track.artist),
                  headlineStyle: theme.typeScale.bodyLarge.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  supportingTextStyle: theme.typeScale.bodyMedium.copyWith(
                    color: theme.colorScheme.onSecondaryContainer.withValues(
                      alpha: 0.75,
                    ),
                  ),
                  trailing: _TrackMenu(
                    track: remoteTrackToUiTrack(track, sourceId),
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                );
              },
            ),
          );

          globalIndex += discTracks.length;
          if (multiDisc) children.add(const SizedBox(height: AppSpacing.md));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

/// 歌曲右侧三点菜单：下一首播放 / 添加到歌单。
class _TrackMenu extends ConsumerWidget {
  const _TrackMenu({required this.track, required this.color});

  final rust.UiTrack track;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return m3e_core.M3EPopupMenuButton<String>(
      tooltip: l10n.more,
      icon: const Icon(M3EIcons.more_vert),
      iconSize: 20,
      iconColor: color,
      triggerStyle: m3e_core.M3EButtonStyle.text,
      triggerDecoration: const m3e_core.M3EButtonDecoration(
        minimumSize: Size(40, 40),
        fixedSize: Size(40, 40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      itemBuilder: (BuildContext context) =>
          <m3e_core.M3EPopupMenuEntry<String>>[
            m3e_core.M3EPopupMenuItem<String>(
              value: 'next',
              child: Text(l10n.playNext),
            ),
            m3e_core.M3EPopupMenuItem<String>(
              value: 'playlist',
              child: Text(l10n.addToPlaylist),
            ),
          ],
      onSelected: (String value) {
        switch (value) {
          case 'next':
            ref.read(playerProvider.notifier).insertNext(<rust.UiTrack>[track]);
          case 'playlist':
            showAddToPlaylistSheet(context, ref, <rust.UiTrack>[track]);
        }
      },
    );
  }
}
