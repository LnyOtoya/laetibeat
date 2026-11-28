import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/src/rust/api/lx.dart' as rust_lx;
import 'package:laetibeat/src/rust/api/playlists.dart' as rust_playlists;
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import 'package:laetibeat/widgets/player/cover_provider.dart';
import 'package:laetibeat/widgets/player/lx_search_provider.dart';
import 'package:laetibeat/widgets/player/player_provider.dart';
import 'package:laetibeat/widgets/playlist_provider.dart';
import 'package:laetibeat/widgets/settings/favorites_provider.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'playlist_actions.dart';
import 'playlist_cover.dart';
import 'playlist_dialogs.dart';

/// 本地歌单封面色缓存。
final _playlistCoverColorProvider = FutureProvider.family<Color, Uint8List>(
  (ref, bytes) => dominantCoverColor(bytes),
);

/// 本地歌单详情页。
///
/// 视觉与 Subsonic 专辑/艺人详情页统一：
/// - 顶部整块大封面，底部透明渐隐到内容区；
/// - 歌单名 / 来源 / 歌曲数与总时长；
/// - tonal 按钮组：随机 / 播放暂停 / 收藏；
/// - 歌曲用 m3e_core 分段列表，右侧三点菜单。
class LocalPlaylistDetailPage extends ConsumerStatefulWidget {
  const LocalPlaylistDetailPage({super.key, required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<LocalPlaylistDetailPage> createState() =>
      _LocalPlaylistDetailPageState();
}

class _LocalPlaylistDetailPageState
    extends ConsumerState<LocalPlaylistDetailPage> {
  static const double _barTintDistance = 120;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _barProgress = ValueNotifier<double>(0);

  int get _playlistId => widget.playlistId;

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

  Future<void> _rename(rust_playlists.UiLocalPlaylistSummary playlist) async {
    final name = await showPlaylistNameDialog(
      context,
      initialName: playlist.name,
      title: AppLocalizations.of(context).playlistRename,
    );
    if (name == null || !mounted) return;
    try {
      await rust_playlists.renameLocalPlaylist(id: _playlistId, name: name);
      ref.invalidate(localPlaylistDetailProvider(_playlistId));
      ref.invalidate(localPlaylistsProvider);
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> _delete(rust_playlists.UiLocalPlaylistSummary playlist) async {
    final confirmed = await showDeletePlaylistConfirm(
      context,
      name: playlist.name,
    );
    if (!confirmed || !mounted) return;
    try {
      await rust_playlists.deleteLocalPlaylist(id: _playlistId);
      ref.invalidate(localPlaylistsProvider);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> _sync(rust_playlists.UiLocalPlaylistSummary playlist) async {
    final source = playlist.source;
    final sourceListId = playlist.sourceListId;
    if (source == null || sourceListId == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await M3EDialog.show<bool>(
      context,
      dialog: M3EDialog(
        title: l10n.playlistSync,
        icon: const Icon(M3EIcons.sync),
        content: Text(l10n.playlistSyncConfirm),
        actions: <Widget>[
          M3EButton(
            label: Text(l10n.actionCancel),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          M3EButton(
            label: Text(l10n.playlistSync),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final detail = await rust_lx.getLxPlaylistAll(
        platform: source,
        playlistId: sourceListId,
      );
      final inputs = playlistInputsFromLxDetail(detail);
      await rust_playlists.replaceLocalPlaylistTracks(
        playlistId: _playlistId,
        tracks: inputs,
      );
      ref.invalidate(localPlaylistDetailProvider(_playlistId));
      ref.invalidate(localPlaylistsProvider);
      if (mounted) _message(l10n.playlistSyncSuccess);
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> _showActions(
    rust_playlists.UiLocalPlaylistSummary playlist,
  ) async {
    final l10n = AppLocalizations.of(context);
    final canSync = playlist.source != null && playlist.sourceListId != null;
    final actions = <String>[
      l10n.actionRename,
      if (canSync) l10n.playlistSync,
      l10n.actionDelete,
    ];
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final theme = M3ETheme.of(sheetContext);
        return SafeArea(
          top: false,
          child: M3EList(
            itemCount: actions.length,
            color: theme.colorScheme.surfaceContainerHigh,
            variant: M3ECardVariant.filled,
            onTap: (int index) {
              Navigator.of(sheetContext).pop();
              if (index == 0) {
                _rename(playlist);
              } else if (canSync && index == 1) {
                _sync(playlist);
              } else {
                _delete(playlist);
              }
            },
            itemBuilder: (BuildContext context, int index) {
              final isDelete = index == actions.length - 1;
              final isSync = canSync && index == 1;
              return M3EListItem(
                leading: Icon(
                  isDelete
                      ? M3EIcons.delete
                      : isSync
                      ? M3EIcons.sync
                      : M3EIcons.edit,
                ),
                headline: actions[index],
                showDivider: index < actions.length - 1,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _removeItem(rust_playlists.UiLocalPlaylistItem item) async {
    try {
      await rust_playlists.removeLocalPlaylistItem(
        playlistId: _playlistId,
        itemId: item.id,
      );
      ref.invalidate(localPlaylistDetailProvider(_playlistId));
      ref.invalidate(localPlaylistsProvider);
    } catch (error) {
      _message(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final detailAsync = ref.watch(localPlaylistDetailProvider(_playlistId));
    final detail = detailAsync.value;
    final playlist = detail?.playlist;

    final resolved = detail == null
        ? const <rust.UiTrack?>[]
        : resolveLocalPlaylistTracks(ref, detail);
    final playable = <rust.UiTrack>[];
    final playableIndexByItem = <int, int>{};
    for (var index = 0; index < resolved.length; index += 1) {
      final track = resolved[index];
      if (track != null) {
        playableIndexByItem[index] = playable.length;
        playable.add(track);
      }
    }

    final cover = playlist == null
        ? (bytes: null, url: null)
        : resolveLocalPlaylistCoverSource(ref, playlist);
    final fallbackBytes = playable.isEmpty
        ? null
        : ref.watch(trackCoverProvider(playable.first)).value;
    final colorBytes = cover.bytes ?? fallbackBytes;
    final heroBytes = cover.bytes ?? (cover.url == null ? fallbackBytes : null);
    final coverColor = colorBytes == null
        ? null
        : ref.watch(_playlistCoverColorProvider(colorBytes)).value;
    final scheme = coverColor == null
        ? baseTheme.colorScheme
        : MaterialYouColorScheme.fromSeed(
            coverColor,
            brightness: baseTheme.colorScheme.brightness,
          );
    final contentColor = detailContentColor(scheme);

    final items = detail?.items ?? const <rust_playlists.UiLocalPlaylistItem>[];
    final trackIds = <String>{for (final item in items) item.trackId};
    final isCurrent = ref.watch(
      playerProvider.select((PlayerState player) {
        final current = player.current;
        return current != null && trackIds.contains(current.id);
      }),
    );
    final isPlaying =
        ref.watch(
          playerProvider.select((PlayerState player) => player.isPlaying),
        ) &&
        isCurrent;

    final favoriteKey = 'local:$_playlistId';
    final isFavorite = ref.watch(
      favoritePlaylistsProvider.select((ids) => ids.contains(favoriteKey)),
    );

    final sourceName = playlist?.name ?? '';

    void playFrom(int itemIndex) {
      final playIndex = playableIndexByItem[itemIndex];
      if (playIndex == null) {
        _message(l10n.sourceUnavailable);
        return;
      }
      ref
          .read(playerProvider.notifier)
          .load(playable, playIndex, source: sourceName);
    }

    void togglePlayback() {
      final notifier = ref.read(playerProvider.notifier);
      if (isCurrent) {
        notifier.toggle();
        return;
      }
      if (playable.isEmpty) return;
      notifier.load(playable, 0, source: sourceName);
    }

    void shufflePlay() {
      if (playable.isEmpty) return;
      ref
          .read(playerProvider.notifier)
          .playShuffled(playable, source: sourceName);
    }

    return M3ETheme(
      data: AppTheme.withDetailTextEmphasis(
        baseTheme.withColorScheme(scheme),
      ),
      child: Scaffold(
        backgroundColor: contentColor,
        extendBodyBehindAppBar: true,
        appBar: _PlaylistAppBar(
          progress: _barProgress,
          tint: contentColor,
          onMenu: playlist == null ? null : () => _showActions(playlist),
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
            if (detail == null) {
              return Center(child: Text(l10n.playlistEmpty));
            }
            final loaded = detail.playlist;
            return RefreshIndicator(
              onRefresh: () => _sync(loaded),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: _PlaylistHero(bytes: heroBytes, url: cover.url),
                  ),
                  SliverToBoxAdapter(
                    child: _PlaylistSummary(
                      name: loaded.name,
                      sourceLabel: _sourceLabel(l10n, loaded),
                      metaText: l10n.albumSummary(
                        '${loaded.itemCount.toInt()}',
                        _formatTotalDuration(loaded.durationSeconds.toInt()),
                      ),
                      isPlaying: isPlaying,
                      playEnabled: playable.isNotEmpty,
                      isFavorite: isFavorite,
                      onShuffle: shufflePlay,
                      onPlayPause: togglePlayback,
                      onFavorite: () => ref
                          .read(favoritePlaylistsProvider.notifier)
                          .toggle(favoriteKey),
                    ),
                  ),
                  if (detail.items.isEmpty)
                    SliverToBoxAdapter(
                      child: _EmptyPlaylistCard(scheme: scheme, l10n: l10n),
                    )
                  else
                    SliverToBoxAdapter(
                      child: m3e_core.M3ESegmentedList.builder(
                        // 嵌套在页面滚动里，必须清零，否则会套用状态栏 padding。
                        listPadding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: detail.items.length,
                        onTap: playFrom,
                        decoration: m3e_core.M3ESegmentedListDecoration(
                          color: scheme.secondaryContainer,
                          splashColor: scheme.onSecondaryContainer.withValues(
                            alpha: 0.12,
                          ),
                          highlightColor: scheme.onSecondaryContainer
                              .withValues(alpha: 0.08),
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
                          final item = detail.items[index];
                          final track = resolved[index];
                          return m3e_core.M3EListItem(
                            minHeight: 64,
                            leading: _PlaylistTrackCover(track: track),
                            headline: Text(item.title),
                            supportingText: Text(
                              <String>[
                                item.artist,
                                item.album,
                              ].where((value) => value.isNotEmpty).join(' · '),
                            ),
                            headlineStyle: baseTheme.typeScale.bodyLarge
                                .copyWith(color: scheme.onSecondaryContainer),
                            supportingTextStyle: baseTheme.typeScale.bodyMedium
                                .copyWith(
                                  color: scheme.onSecondaryContainer.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                            trailing: _PlaylistTrackMenu(
                              track: track,
                              color: scheme.onSecondaryContainer,
                              onRemove: () => _removeItem(item),
                            ),
                          );
                        },
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xxl + bottomInset),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _sourceLabel(
  AppLocalizations l10n,
  rust_playlists.UiLocalPlaylistSummary playlist,
) {
  final remote = playlist.source != null || playlist.coverSource == 'lx';
  if (!remote) return l10n.librarySourceLocal;
  final platform = playlist.source ?? playlist.coverSourceId ?? 'kw';
  return 'LX · ${lxPlatformLabel(l10n, platform)}';
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
class _PlaylistAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PlaylistAppBar({
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
class _PlaylistHero extends StatelessWidget {
  const _PlaylistHero({required this.bytes, required this.url});

  final Uint8List? bytes;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    final double height = math.min(MediaQuery.sizeOf(context).width, 520);
    final hasArt = bytes != null && bytes!.isNotEmpty;

    final Widget image;
    if (hasArt) {
      image = Image.memory(
        bytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: 900,
      );
    } else if (url != null) {
      image = Image.network(
        url!,
        fit: BoxFit.cover,
        cacheWidth: 900,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _fallback(scheme),
        errorBuilder: (_, _, _) => _fallback(scheme),
      );
    } else {
      image = _fallback(scheme);
    }

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
            child: image,
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

  Widget _fallback(M3EColorScheme scheme) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          M3EIcons.queue_music,
          size: 72,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 歌单名 / 来源 / 歌曲数与总时长 + 随机、播放、收藏按钮组。
class _PlaylistSummary extends StatelessWidget {
  const _PlaylistSummary({
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

class _EmptyPlaylistCard extends StatelessWidget {
  const _EmptyPlaylistCard({required this.scheme, required this.l10n});

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
class _PlaylistTrackCover extends ConsumerWidget {
  const _PlaylistTrackCover({required this.track});

  final rust.UiTrack? track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final track = this.track;
    final bytes = track == null
        ? null
        : ref.watch(trackCoverProvider(track)).value;
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
class _PlaylistTrackMenu extends ConsumerWidget {
  const _PlaylistTrackMenu({
    required this.track,
    required this.color,
    required this.onRemove,
  });

  final rust.UiTrack? track;
  final Color color;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final playable = track != null;

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
              enabled: playable,
              child: Text(l10n.playNext),
            ),
            m3e_core.M3EPopupMenuItem<String>(
              value: 'playlist',
              enabled: playable,
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
            if (track != null) {
              ref.read(playerProvider.notifier).insertNext(<rust.UiTrack>[
                track!,
              ]);
            }
          case 'playlist':
            if (track != null) {
              showAddToPlaylistSheet(context, ref, <rust.UiTrack>[track!]);
            }
          case 'remove':
            onRemove();
        }
      },
    );
  }
}
