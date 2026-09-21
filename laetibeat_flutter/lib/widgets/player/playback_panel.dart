import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:laetibeat/src/rust/api/simple.dart' as rust;
import '../../animations.dart';
import 'player_provider.dart';

//共享播放面板:三个区域(来源区/播放显示区/控制区)
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

    //三段撑满右区:上来源(居中)/中封面+歌名/底控制条
    return LayoutBuilder(
      builder: (context, c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sourceRegion(theme, scheme, player),
          SizedBox(height: theme.spacing.lg),
          Expanded(child: _displayRegion(context, theme, track, c.maxHeight)),
          SizedBox(height: theme.spacing.lg),
          _controlRegion(theme, scheme, player, ref),
        ],
      ),
    );
  }

  //区域1:来源区 - 居中显示'正在播放' + 来源名
  Widget _sourceRegion(
    M3EThemeData theme,
    M3EColorScheme scheme,
    PlayerState player,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: Text(
            '正在播放',
            style: theme.typeScale.labelMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Align(
          alignment: Alignment.center,
          child: Text(player.source, style: theme.typeScale.titleSmall),
        ),
      ],
    );
  }

  //区域2:播放显示区 - 居中大封面 + 左(歌名/歌手)右(全屏/歌词)
  Widget _displayRegion(
    BuildContext context,
    M3EThemeData theme,
    rust.UiTrack? track,
    double maxHeight,
  ) {
    final side = (fullscreen ? maxHeight * 0.55 : maxHeight * 0.42).clamp(120.0, 360.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: _cover(theme, side)),
        SizedBox(height: theme.spacing.lg),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track?.title ?? '未在播放',
                    style: theme.typeScale.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    track == null ? '' : '${track.artist} · ${track.album}',
                    style: theme.typeScale.bodyMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            M3EIconButton(
              size: M3EIconButtonSize.md,
              icon: const Icon(Icons.fullscreen),
              tooltip: '全屏',
              onPressed: () => _openFullscreen(context),
            ),
            M3EIconButton(
              size: M3EIconButtonSize.md,
              icon: const Icon(Icons.lyrics),
              tooltip: '歌词',
              onPressed: () {}, //歌词逻辑未接入
            ),
          ],
        ),
      ],
    );
  }

  //封面
  Widget _cover(M3EThemeData theme, double side) {
    return M3EShapeContainer.square(
      width: side,
      height: side,
      color: theme.colorScheme.secondaryContainer,
      child: Icon(M3EIcons.music_note, size: side * 0.4),
    );
  }

  //区域3:控制区 - 进度条+时长 / 上一首播放暂停下一首 / 底部按钮组+菜单
  Widget _controlRegion(
    M3EThemeData theme,
    M3EColorScheme scheme,
    PlayerState player,
    WidgetRef ref,
  ) {
    final total = player.duration.inMilliseconds;
    final value = total > 0
        ? (player.position.inMilliseconds / total).clamp(0.0, 1.0)
        : 0.0;
    final notifier = ref.read(playerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        //拖拽进度条:播放时wavy曲线,暂停/未播放时为直线continuous
        if (player.isPlaying)
          M3ESlider.wavy(
            value: value,
            trackThickness: 10,
            onChanged: (v) =>
                notifier.seek(Duration(milliseconds: (v * total).round())),
          )
        else
          M3ESlider(
            value: value,
            trackThickness: 10,
            onChanged: (v) =>
                notifier.seek(Duration(milliseconds: (v * total).round())),
          ),
        //时长
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(player.position), style: theme.typeScale.labelSmall),
            Text(_fmt(player.duration), style: theme.typeScale.labelSmall),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        //上一首 / 播放暂停 / 下一首
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            M3EIconButton(
              size: M3EIconButtonSize.md,
              icon: const Icon(Icons.skip_previous),
              tooltip: '上一首',
              onPressed:
                  player.queue.isEmpty ? null : () => notifier.prev(),
            ),
            SizedBox(width: theme.spacing.md),
            M3EIconButton(
              size: M3EIconButtonSize.lg,
              icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
              tooltip: player.isPlaying ? '暂停' : '播放',
              onPressed:
                  player.current == null ? null : () => notifier.toggle(),
            ),
            SizedBox(width: theme.spacing.md),
            M3EIconButton(
              size: M3EIconButtonSize.md,
              icon: const Icon(Icons.skip_next),
              tooltip: '下一首',
              onPressed:
                  player.queue.isEmpty ? null : () => notifier.next(),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        //底部:左侧按钮组(播放列表/随机/顺序) + 右侧三点菜单
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                M3EIconButton(
                  size: M3EIconButtonSize.sm,
                  icon: const Icon(Icons.playlist_play),
                  tooltip: '播放列表',
                  onPressed: () {},
                ),
                M3EIconButton(
                  size: M3EIconButtonSize.sm,
                  icon: const Icon(Icons.shuffle),
                  tooltip: '随机播放',
                  onPressed: () {},
                ),
                M3EIconButton(
                  size: M3EIconButtonSize.sm,
                  icon: const Icon(Icons.repeat),
                  tooltip: '顺序播放',
                  onPressed: () {},
                ),
              ],
            ),
            _moreMenu(),
          ],
        ),
      ],
    );
  }

  //竖向三点菜单
  Widget _moreMenu() {
    return M3EMenu.entries(
      position: M3EMenuAnchorPosition.bottomEnd,
      entries: const [
        M3EMenuEntry(label: '添加到播放队列'),
        M3EMenuEntry(label: '查看歌词'),
      ],
      anchorBuilder: (context, open) => M3EIconButton(
        size: M3EIconButtonSize.sm,
        icon: const Icon(Icons.more_vert),
        tooltip: '更多',
        onPressed: open,
      ),
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