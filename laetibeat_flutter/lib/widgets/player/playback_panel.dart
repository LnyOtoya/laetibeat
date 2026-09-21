import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../../animations.dart';
import 'player_provider.dart';

//共享播放面板:读全局playerProvider渲染当前曲目+控制条
//主页/搜索/音乐库右侧默认显示;全屏页复用同一面板
class PlaybackPanel extends ConsumerWidget {
  const PlaybackPanel({super.key, this.fullscreen = false});

  //是否处于全屏布局
  final bool fullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final player = ref.watch(playerProvider);
    final track = player.current;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            M3EShapeContainer.square(
              width: theme.spacing.xxl * (fullscreen ? 4 : 2.5),
              height: theme.spacing.xxl * (fullscreen ? 4 : 2.5),
              color: scheme.secondaryContainer,
              child: Icon(
                M3EIcons.music_note,
                size: theme.spacing.xxl * (fullscreen ? 2.5 : 1.5),
              ),
            ),
            SizedBox(width: theme.spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track?.title ?? '未在播放',
                    style: theme.typeScale.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (track != null) ...[
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      '${track.artist} · ${track.album}',
                      style: theme.typeScale.bodyMedium.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            M3EIconButton(
              size: M3EIconButtonSize.sm,
              icon: const Icon(Icons.fullscreen),
              tooltip: '全屏',
              onPressed: () => _openFullscreen(context),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            M3EIconButton(
              size: M3EIconButtonSize.md,
              icon: const Icon(Icons.skip_previous),
              tooltip: '上一首',
              onPressed: player.queue.isEmpty
                  ? null
                  : () => ref.read(playerProvider.notifier).prev(),
            ),
            SizedBox(width: theme.spacing.md),
            M3EIconButton(
              size: fullscreen ? M3EIconButtonSize.lg : M3EIconButtonSize.md,
              icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
              tooltip: player.isPlaying ? '暂停' : '播放',
              onPressed: track == null
                  ? null
                  : () => ref.read(playerProvider.notifier).toggle(),
            ),
            SizedBox(width: theme.spacing.md),
            M3EIconButton(
              size: M3EIconButtonSize.md,
              icon: const Icon(Icons.skip_next),
              tooltip: '下一首',
              onPressed: player.queue.isEmpty
                  ? null
                  : () => ref.read(playerProvider.notifier).next(),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _progress(theme, scheme, player),
      ],
    );
  }

  Widget _progress(
    M3EThemeData theme,
    M3EColorScheme scheme,
    PlayerState player,
  ) {
    final total = player.duration.inMilliseconds;
    final pos = player.isPlaying
        ? (player.position.inMilliseconds + 1000) % (total > 0 ? total : 8000)
        : player.position.inMilliseconds;
    final value = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: value,
          color: scheme.secondary,
          backgroundColor: scheme.surfaceContainer,
        ),
        SizedBox(height: theme.spacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(Duration(milliseconds: pos)),
                style: theme.typeScale.labelSmall),
            Text(_fmt(Duration(milliseconds: total)),
                style: theme.typeScale.labelSmall),
          ],
        ),
      ],
    );
  }

  //打开全屏播放页(全局路由,关闭回到进入前视图)
  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlaybackFullscreenPage()),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

//全屏播放页:复用PlaybackPanel,整体覆盖当前页
class PlaybackFullscreenPage extends StatelessWidget {
  const PlaybackFullscreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: M3EIconButton(
                  size: M3EIconButtonSize.md,
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: AnimatedSwitcher(
                      duration: kSectionAnimDuration,
                      switchInCurve: kSectionAnimCurve,
                      switchOutCurve: kSectionAnimCurve,
                      child: const PlaybackPanel(fullscreen: true),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}