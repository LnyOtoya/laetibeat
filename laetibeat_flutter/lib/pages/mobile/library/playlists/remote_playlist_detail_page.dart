import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/src/rust/api/subsonic.dart' as rust_subsonic;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/playlist_provider.dart';
import 'package:laetibeat/widgets/remote_browser_provider.dart';
import 'package:laetibeat/widgets/settings/favorites_provider.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'playlist_actions.dart';
import 'playlist_dialogs.dart';

/// Navidrome 歌单封面色缓存。
final _remotePlaylistCoverColorProvider =
    FutureProvider.family<Color, Uint8List>(
      (ref, bytes) => dominantCoverColor(bytes),
    );

/// Navidrome（OpenSubsonic）歌单详情页。
///
/// 与专辑/艺人详情页统一：
/// - 顶部整块大封面，底部透明渐隐到内容区；
/// - 歌单名 / 来源与 owner / 歌曲数与总时长；
/// - tonal 按钮组：随机 / 播放暂停 / 收藏；
/// - comment 存在时显示两行可展开的简介；
/// - 歌曲用 m3e_core 分段列表，右侧三点菜单。
class RemotePlaylistDetailPage extends ConsumerStatefulWidget {
  const RemotePlaylistDetailPage({
    super.key,
    required this.sourceId,
    required this.playlist,
  });

  final String sourceId;
  final rust_subsonic.UiRemotePlaylist playlist;

  @override
  ConsumerState<RemotePlaylistDetailPage> createState() =>
      _RemotePlaylistDetailPageState();
}

class _RemotePlaylistDetailPageState
    extends ConsumerState<RemotePlaylistDetailPage> {
  static const double _barTintDistance = 120;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _barProgress = ValueNotifier<double>(0);

  RemotePlaylistKey get _key =>
      (sourceId: widget.sourceId, playlistId: widget.playlist.id);

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

  void _message(String text) {
    if (!mounted) return;
    M3ESnackbar.show(context, message: text);
  }

  Future<void> _rename(rust_subsonic.UiRemotePlaylist current) async {
    final name = await showPlaylistNameDialog(
      context,
      initialName: current.name,
      title: AppLocalizations.of(context).playlistRename,
    );
    if (name == null || !mounted) return;
    try {
      await rust_subsonic.subsonicUpdatePlaylist(
        sourceId: widget.sourceId,
        playlistId: current.id,
        name: name,
        addSongIds: const [],
        removeIndexes: const [],
      );
      ref.invalidate(remotePlaylistDetailProvider(_key));
      ref.invalidate(remotePlaylistsProvider(widget.sourceId));
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> _delete(rust_subsonic.UiRemotePlaylist current) async {
    final confirmed = await showDeletePlaylistConfirm(
      context,
      name: current.name,
    );
    if (!confirmed || !mounted) return;
    try {
      await rust_subsonic.subsonicDeletePlaylist(
        sourceId: widget.sourceId,
        playlistId: current.id,
      );
      ref.invalidate(remotePlaylistsProvider(widget.sourceId));
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> _showActions(rust_subsonic.UiRemotePlaylist current) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final theme = M3ETheme.of(sheetContext);
        return SafeArea(
          top: false,
          child: M3EList(
            itemCount: 2,
            color: theme.colorScheme.surfaceContainerHigh,
            variant: M3ECardVariant.filled,
            onTap: (int index) {
              Navigator.of(sheetContext).pop();
              if (index == 0) {
                _rename(current);
              } else {
                _delete(current);
              }
            },
            itemBuilder: (BuildContext context, int index) {
              return M3EListItem(
                leading: Icon(index == 0 ? M3EIcons.edit : M3EIcons.delete),
                headline: index == 0 ? l10n.actionRename : l10n.actionDelete,
                showDivider: index == 0,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _removeTrack({
    required String playlistId,
    required int index,
  }) async {
    try {
      await rust_subsonic.subsonicUpdatePlaylist(
        sourceId: widget.sourceId,
        playlistId: playlistId,
        addSongIds: const [],
        removeIndexes: <int>[index],
      );
      ref.invalidate(remotePlaylistDetailProvider(_key));
      ref.invalidate(remotePlaylistsProvider(widget.sourceId));
    } catch (error) {
      _message(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final detailAsync = ref.watch(remotePlaylistDetailProvider(_key));
    final detail = detailAsync.value;
    final playlist = detail?.playlist ?? widget.playlist;

    final tracks = detail == null
        ? const <rust.UiTrack>[]
        : detail.tracks
              .map((track) => remoteTrackToUiTrack(track, widget.sourceId))
              .toList(growable: false);

    final coverId = playlist.coverId;
    final coverBytes = coverId == null || coverId.isEmpty
        ? null
        : ref
              .watch(
                remoteCoverProvider((
                  sourceId: widget.sourceId,
                  coverId: coverId,
                )),
              )
              .value;
    final fallbackBytes = tracks.isEmpty
        ? null
        : ref.watch(trackCoverProvider(tracks.first)).value;
    final heroBytes = coverBytes ?? fallbackBytes;
    final coverColor = heroBytes == null
        ? null
        : ref.watch(_remotePlaylistCoverColorProvider(heroBytes)).value;
    final scheme = coverColor == null
        ? baseTheme.colorScheme
        : MaterialYouColorScheme.fromSeed(
            coverColor,
            brightness: baseTheme.colorScheme.brightness,
          );
    final contentColor = detailContentColor(scheme);

    final trackIds = <String>{for (final track in tracks) track.id};
    final isCurrent = ref.watch(
      playerProvider.select((PlayerState player) {
        final current = player.current;
        return current != null &&
            current.source == 'opensubsonic' &&
            current.sourceId == widget.sourceId &&
            trackIds.contains(current.id);
      }),
    );
    final isPlaying =
        ref.watch(
          playerProvider.select((PlayerState player) => player.isPlaying),
        ) &&
        isCurrent;

    final favoriteKey = '${widget.sourceId}:${playlist.id}';
    final isFavorite = ref.watch(
      favoritePlaylistsProvider.select((ids) => ids.contains(favoriteKey)),
    );

    void playFrom(int index) {
      if (tracks.isEmpty) return;
      ref
          .read(playerProvider.notifier)
          .load(tracks, index, source: playlist.name);
    }

    void togglePlayback() {
      final notifier = ref.read(playerProvider.notifier);
      if (isCurrent) {
        notifier.toggle();
        return;
      }
      if (tracks.isEmpty) return;
      notifier.load(tracks, 0, source: playlist.name);
    }

    void shufflePlay() {
      if (tracks.isEmpty) return;
      ref
          .read(playerProvider.notifier)
          .playShuffled(tracks, source: playlist.name);
    }

    return M3ETheme(
      data: baseTheme.withColorScheme(scheme),
      child: Scaffold(
        backgroundColor: contentColor,
        extendBodyBehindAppBar: true,
        appBar: _RemotePlaylistAppBar(
          progress: _barProgress,
          tint: contentColor,
          onMenu: detail == null ? null : () => _showActions(detail.playlist),
        ),
        body: detailAsync.when(
          loading: () => Center(
            child: M3ELoadingIndicator(
              color: scheme.primary,
              containerColor: scheme.surfaceContainerHighest,
            ),
          ),
          error: (Object error, StackTrace stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppLayout.pageGutter),
              child: Text(
                '${l10n.loadPlaylistsFailed}\n$error',
                textAlign: TextAlign.center,
                style: baseTheme.typeScale.bodyMedium.copyWith(
                  color: scheme.error,
                ),
              ),
            ),
          ),
          data: (detail) {
            final loaded = detail.playlist;
            final count = loaded.songCount?.toInt() ?? detail.tracks.length;
            final totalSeconds =
                loaded.durationSeconds?.toInt() ??
                detail.tracks.fold<int>(
                  0,
                  (sum, track) => sum + track.durationSeconds.toInt(),
                );
            final comment = loaded.comment;

            return CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: _RemotePlaylistHero(bytes: heroBytes),
                ),
                SliverToBoxAdapter(
                  child: _RemotePlaylistSummary(
                    name: loaded.name,
                    sourceLabel: _remoteSourceLabel(loaded),
                    metaText: l10n.albumSummary(
                      '$count',
                      _formatTotalDuration(totalSeconds),
                    ),
                    isPlaying: isPlaying,
                    playEnabled: tracks.isNotEmpty,
                    isFavorite: isFavorite,
                    onShuffle: shufflePlay,
                    onPlayPause: togglePlayback,
                    onFavorite: () => ref
                        .read(favoritePlaylistsProvider.notifier)
                        .toggle(favoriteKey),
                  ),
                ),
                if (comment != null && comment.trim().isNotEmpty)
                  SliverToBoxAdapter(
                    child: _PlaylistDescription(comment: comment),
                  ),
                if (detail.tracks.isEmpty)
                  SliverToBoxAdapter(
                    child: _RemoteEmptyCard(scheme: scheme, l10n: l10n),
                  )
                else
                  SliverToBoxAdapter(
                    child: m3e_core.M3ESegmentedList.builder(
                      // 嵌套在页面滚动里，必须清零，否则会套用状态栏 padding。
                      listPadding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tracks.length,
                      onTap: playFrom,
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
                        final track = tracks[index];
                        return m3e_core.M3EListItem(
                          minHeight: 64,
                          leading: _RemoteTrackCover(track: track),
                          headline: Text(track.title),
                          supportingText: Text(
                            <String>[
                              track.artist,
                              track.album,
                            ].where((value) => value.isNotEmpty).join(' · '),
                          ),
                          headlineStyle: baseTheme.typeScale.bodyLarge.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                          supportingTextStyle: baseTheme.typeScale.bodyMedium
                              .copyWith(
                                color: scheme.onSecondaryContainer.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                          trailing: _RemoteTrackMenu(
                            track: track,
                            color: scheme.onSecondaryContainer,
                            onRemove: () => _removeTrack(
                              playlistId: loaded.id,
                              index: index,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxl + bottomInset),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _remoteSourceLabel(rust_subsonic.UiRemotePlaylist playlist) {
  final owner = playlist.owner;
  if (owner == null || owner.isEmpty) return 'Subsonic';
  return 'Subsonic · $owner';
}

String _formatTotalDuration(int seconds) {
  if (seconds <= 0) return '--';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$rest';
  }
  return '$minutes:$rest';
}

/// 默认透明、滚动后淡入内容色的顶部栏。
class _RemotePlaylistAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _RemotePlaylistAppBar({
    required this.progress,
    required this.tint,
    required this.onMenu,
  });

  final ValueListenable<double> progress;
  final Color tint;
  final VoidCallback? onMenu;

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
          onMenu: onMenu,
          backgroundColor: Color.lerp(Colors.transparent, tint, value),
        );
      },
    );
  }
}

/// 顶部大封面：铺满上方区域，底部透明渐隐到内容区。
class _RemotePlaylistHero extends StatelessWidget {
  const _RemotePlaylistHero({required this.bytes});

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
                  M3EIcons.queue_music,
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

/// 歌单名 / 来源与 owner / 歌曲数与总时长 + 随机、播放、收藏按钮组。
class _RemotePlaylistSummary extends StatelessWidget {
  const _RemotePlaylistSummary({
    required this.name,
    required this.sourceLabel,
    required this.metaText,
    required this.isPlaying,
    required this.playEnabled,
    required this.isFavorite,
    required this.onShuffle,
    required this.onPlayPause,
    required this.onFavorite,
  });

  final String name;
  final String sourceLabel;
  final String metaText;
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
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typeScale.headlineMedium.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            sourceLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typeScale.bodyLarge.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            metaText,
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

/// 可展开的歌单简介：默认两行，超出时显示“查看更多”。
class _PlaylistDescription extends StatefulWidget {
  const _PlaylistDescription({required this.comment});

  final String comment;

  @override
  State<_PlaylistDescription> createState() => _PlaylistDescriptionState();
}

class _PlaylistDescriptionState extends State<_PlaylistDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final style = theme.typeScale.bodyMedium.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayout.pageGutter,
        0,
        AppLayout.pageGutter,
        AppSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final painter = TextPainter(
                text: TextSpan(text: widget.comment, style: style),
                maxLines: 2,
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: constraints.maxWidth);
              final overflows = painter.didExceedMaxLines;
              painter.dispose();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AnimatedSize(
                    duration: AppMotion.standard,
                    curve: AppMotion.standardCurve,
                    alignment: Alignment.topCenter,
                    child: Text(
                      widget.comment,
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                  if (overflows || _expanded)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.primary,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _expanded
                              ? l10n.lyricsSearchCollapse
                              : l10n.lyricsSearchShowMore,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RemoteEmptyCard extends StatelessWidget {
  const _RemoteEmptyCard({required this.scheme, required this.l10n});

  final M3EColorScheme scheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayout.pageGutter,
        vertical: AppSpacing.md,
      ),
      child: M3ECard(
        variant: M3ECardVariant.filled,
        color: scheme.surfaceContainerHigh,
        expanded: true,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              Icon(
                M3EIcons.queue_music,
                size: 40,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.playlistNoTracks,
                style: theme.typeScale.titleMedium.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 歌单里的曲目封面（40dp）。
class _RemoteTrackCover extends ConsumerWidget {
  const _RemoteTrackCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: 40,
        child: hasArt
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  M3EIcons.music_note,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

/// 歌曲右侧三点菜单：下一首播放 / 添加到歌单 / 从歌单移除。
class _RemoteTrackMenu extends ConsumerWidget {
  const _RemoteTrackMenu({
    required this.track,
    required this.color,
    required this.onRemove,
  });

  final rust.UiTrack track;
  final Color color;
  final VoidCallback onRemove;

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
            m3e_core.M3EPopupMenuItem<String>(
              value: 'remove',
              child: Text(l10n.playlistRemoveTrack),
            ),
          ],
      onSelected: (String value) {
        switch (value) {
          case 'next':
            ref.read(playerProvider.notifier).insertNext(<rust.UiTrack>[track]);
          case 'playlist':
            showAddToPlaylistSheet(context, ref, <rust.UiTrack>[track]);
          case 'remove':
            onRemove();
        }
      },
    );
  }
}
