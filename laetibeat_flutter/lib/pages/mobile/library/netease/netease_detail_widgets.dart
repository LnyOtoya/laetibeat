import 'dart:math' as math;

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
import '../../../../widgets/settings/netease_provider.dart';
import '../playlists/playlist_actions.dart';

/// 详情页主题从基础色平滑过渡到封面主色，避免取色完成时突然跳变。
class NeteaseAnimatedTheme extends StatelessWidget {
  const NeteaseAnimatedTheme({
    super.key,
    required this.coverColor,
    required this.child,
  });

  final Color? coverColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = M3ETheme.of(context);
    final target = coverColor;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        begin: target ?? base.colorScheme.primary,
        end: target ?? base.colorScheme.primary,
      ),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, Color? color, Widget? child) {
        if (target == null) {
          return M3ETheme(data: base, child: child!);
        }
        final scheme = MaterialYouColorScheme.fromSeed(
          color ?? target,
          brightness: base.colorScheme.brightness,
        );
        return M3ETheme(data: base.withColorScheme(scheme), child: child!);
      },
      child: child,
    );
  }
}

class NeteaseLoadingIndicator extends StatelessWidget {
  const NeteaseLoadingIndicator({
    super.key,
    this.size = 48,
    this.semanticLabel = '正在加载网易云内容',
  });

  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    return M3ELoadingIndicator(
      variant: M3ELoadingIndicatorVariant.contained,
      size: size,
      color: scheme.primary,
      containerColor: scheme.surfaceContainerHighest,
      semanticLabel: semanticLabel,
    );
  }
}

/// 网易云详情页顶部大封面：铺满上方区域，底部透明渐隐到内容区。
class NeteaseDetailHero extends StatelessWidget {
  const NeteaseDetailHero({
    super.key,
    required this.bytes,
    required this.fallbackIcon,
  });

  final Uint8List? bytes;
  final IconData fallbackIcon;

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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            layoutBuilder:
                (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: <Widget>[...previousChildren, ?currentChild],
                  );
                },
            child: hasArt
                ? ShaderMask(
                    key: const ValueKey<String>('netease-hero-art'),
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
                : ColoredBox(
                    key: const ValueKey<String>('netease-hero-placeholder'),
                    color: scheme.surfaceContainerHighest,
                    child: Center(
                      child: Icon(
                        fallbackIcon,
                        size: 72,
                        color: scheme.onSurfaceVariant,
                      ),
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

/// 默认透明、滚动后淡入内容色的详情页顶部栏。
class NeteaseDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const NeteaseDetailAppBar({
    super.key,
    required this.progress,
    required this.tint,
    this.onMenu,
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

/// 标题 / 副标题 / 元信息 + tonal 按钮组（随机、播放暂停、收藏）。
class NeteaseSummary extends StatelessWidget {
  const NeteaseSummary({
    super.key,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.isPlaying,
    required this.playEnabled,
    required this.isFavorite,
    required this.onShuffle,
    required this.onPlayPause,
    required this.onFavorite,
  });

  final String title;
  final String subtitle;
  final String meta;
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
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typeScale.bodyLarge.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            meta,
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

/// 统一的网易云歌曲分段列表。
class NeteaseTrackList extends ConsumerWidget {
  const NeteaseTrackList({
    super.key,
    required this.tracks,
    required this.source,
    this.onTap,
  });

  final List<rust.UiTrack> tracks;
  final String source;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    if (tracks.isEmpty) {
      return const AppEmptyState(
        title: '暂无歌曲',
        message: '网易云没有返回歌曲',
        icon: M3EIcons.music_note,
      );
    }

    return m3e_core.M3ESegmentedList.builder(
      listPadding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tracks.length,
      onTap:
          onTap ??
          (int index) => ref
              .read(playerProvider.notifier)
              .load(tracks, index, source: source),
      decoration: m3e_core.M3ESegmentedListDecoration(
        color: scheme.secondaryContainer,
        splashColor: scheme.onSecondaryContainer.withValues(alpha: 0.12),
        highlightColor: scheme.onSecondaryContainer.withValues(alpha: 0.08),
        hoverColor: scheme.onSecondaryContainer.withValues(alpha: 0.08),
        outerRadius: 24,
        innerRadius: 12,
        pressedRadius: 8,
        pressedScale: 0.98,
        hoveredRadius: 16,
        gap: 4,
        padding: const EdgeInsets.all(4),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
      ),
      itemBuilder: (BuildContext context, int index) {
        final track = tracks[index];
        return _neteaseTrackRow(context, track);
      },
    );
  }
}

/// A sliver that lazily builds every supplied track as it enters the viewport.
class NeteaseTrackSliver extends ConsumerWidget {
  const NeteaseTrackSliver({
    super.key,
    required this.tracks,
    required this.source,
    this.onTap,
  });

  final List<rust.UiTrack> tracks;
  final String source;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final tracks = this.tracks;
    if (tracks.isEmpty) {
      return const SliverToBoxAdapter(
        child: AppEmptyState(
          title: '暂无歌曲',
          message: '网易云没有返回歌曲',
          icon: M3EIcons.music_note,
        ),
      );
    }

    return m3e_core.SliverM3ESegmentedList(
      itemCount: tracks.length,
      onTap:
          onTap ??
          (int index) => ref
              .read(playerProvider.notifier)
              .load(tracks, index, source: source),
      decoration: m3e_core.M3ESegmentedListDecoration(
        color: scheme.secondaryContainer,
        splashColor: scheme.onSecondaryContainer.withValues(alpha: 0.12),
        highlightColor: scheme.onSecondaryContainer.withValues(alpha: 0.08),
        hoverColor: scheme.onSecondaryContainer.withValues(alpha: 0.08),
        outerRadius: 24,
        innerRadius: 12,
        pressedRadius: 8,
        pressedScale: 0.98,
        hoveredRadius: 16,
        gap: 4,
        padding: const EdgeInsets.all(4),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
      ),
      itemBuilder: (BuildContext context, int index) =>
          _neteaseTrackRow(context, tracks[index]),
    );
  }
}

Widget _neteaseTrackRow(BuildContext context, rust.UiTrack track) {
  final theme = M3ETheme.of(context);
  final scheme = theme.colorScheme;
  return m3e_core.M3EListItem(
    minHeight: 64,
    leading: NeteaseTrackCover(track: track),
    headline: Text(track.title),
    supportingText: Text(track.artist),
    headlineStyle: theme.typeScale.bodyLarge.copyWith(
      color: scheme.onSecondaryContainer,
    ),
    supportingTextStyle: theme.typeScale.bodyMedium.copyWith(
      color: scheme.onSecondaryContainer.withValues(alpha: 0.75),
    ),
    trailing: NeteaseTrackMenu(
      track: track,
      color: scheme.onSecondaryContainer,
    ),
  );
}

/// 40dp 曲目封面。
class NeteaseTrackCover extends ConsumerWidget {
  const NeteaseTrackCover({super.key, required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final cacheSize = (40 * MediaQuery.devicePixelRatioOf(context)).round();

    return ClipRRect(
      borderRadius: AppRadii.xsAll,
      child: SizedBox.square(
        dimension: 40,
        child: bytes == null || bytes.isEmpty
            ? ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  M3EIcons.music_note,
                  size: AppIconSize.sm,
                  color: scheme.onSurfaceVariant,
                ),
              )
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: cacheSize,
                cacheHeight: cacheSize,
              ),
      ),
    );
  }
}

/// 网易云图片（专辑/歌单封面）。
class NeteaseCover extends ConsumerWidget {
  const NeteaseCover({
    super.key,
    required this.url,
    required this.size,
    required this.fallbackIcon,
  });

  final String? url;
  final double size;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final value = url;
    final bytes = value == null || value.isEmpty
        ? null
        : ref.watch(neteaseImageProvider(value)).value;

    return ClipRRect(
      borderRadius: AppRadii.smAll,
      child: SizedBox.square(
        dimension: size,
        child: bytes == null || bytes.isEmpty
            ? ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  fallbackIcon,
                  size: AppIconSize.md,
                  color: scheme.onSurfaceVariant,
                ),
              )
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: cacheSize,
                cacheHeight: cacheSize,
              ),
      ),
    );
  }
}

/// 歌曲右侧三点菜单：下一首播放 / 添加到歌单。
class NeteaseTrackMenu extends ConsumerWidget {
  const NeteaseTrackMenu({super.key, required this.track, required this.color});

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
