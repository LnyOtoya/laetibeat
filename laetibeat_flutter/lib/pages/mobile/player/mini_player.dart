import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../widgets/player/cover_provider.dart';
import '../../../widgets/player/playback_panel.dart';
import '../../../widgets/player/player_provider.dart';
import '../mobile_navigation.dart';
import 'mobile_playback_page.dart';

/// 移动端全局迷你播放器。
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(playerProvider.select((state) => state.current));
    if (track == null) {
      return const SizedBox.shrink();
    }

    return PlaybackCoverScope(
      child: Builder(
        builder: (context) {
          final theme = M3ETheme.of(context);
          final isPlaying = ref.watch(
            playerProvider.select((state) => state.isPlaying),
          );
          final cover = ref.watch(playbackCoverProvider).value;
          final notifier = ref.read(playerProvider.notifier);
          final background = playbackPanelBackground(theme, cover);
          final foreground = cover == null
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSecondaryContainer;

          final Widget toolbar = M3EToolbar.floating(
            colorStyle: M3EToolbarColorStyle.standard,
            axis: Axis.horizontal,
            backgroundColor: background,
            foregroundColor: foreground,
            leading: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openPlayer(context),
              child: Hero(
                tag: mobileNowPlayingCoverHeroTag,
                child: _MiniCover(cover: cover),
              ),
            ),
            title: _tappableTitle(context, track.title),
            subtitle: _tappableTitle(context, track.artist),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                M3EIconButton(
                  variant: M3EIconButtonVariant.standard,
                  icon: const Icon(M3EIcons.skip_previous),
                  semanticLabel: AppLocalizations.of(context).previousTrack,
                  onPressed: notifier.prev,
                ),
                M3EIconButton(
                  variant: M3EIconButtonVariant.filled,
                  icon: Icon(isPlaying ? M3EIcons.pause : M3EIcons.play_arrow),
                  semanticLabel: isPlaying
                      ? AppLocalizations.of(context).pause
                      : AppLocalizations.of(context).play,
                  onPressed: notifier.toggle,
                ),
                M3EIconButton(
                  variant: M3EIconButtonVariant.standard,
                  icon: const Icon(M3EIcons.skip_next),
                  semanticLabel: AppLocalizations.of(context).nextTrack,
                  onPressed: notifier.next,
                ),
              ],
            ),
          );
          return _MiniPlayerDragRegion(
            onOpen: () => _openPlayer(context),
            child: toolbar,
          );
        },
      ),
    );
  }

  Widget _tappableTitle(BuildContext context, String text) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPlayer(context),
      child: SizedBox(
        width: double.infinity,
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    pushMobileFullPlayer(context, const MobilePlaybackPage());
  }
}

class _MiniPlayerDragRegion extends StatefulWidget {
  const _MiniPlayerDragRegion({required this.child, required this.onOpen});

  final Widget child;
  final VoidCallback onOpen;

  @override
  State<_MiniPlayerDragRegion> createState() => _MiniPlayerDragRegionState();
}

class _MiniPlayerDragRegionState extends State<_MiniPlayerDragRegion> {
  static const double _openThreshold = 32;

  double _dragDistance = 0;

  void _reset() {
    _dragDistance = 0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _reset(),
      onVerticalDragUpdate: (DragUpdateDetails details) {
        _dragDistance += -details.delta.dy;
      },
      onVerticalDragEnd: (DragEndDetails details) {
        final bool shouldOpen =
            _dragDistance >= _openThreshold ||
            (details.primaryVelocity ?? 0) < -500;
        _reset();
        if (shouldOpen) widget.onOpen();
      },
      onVerticalDragCancel: _reset,
      child: widget.child,
    );
  }
}

class _MiniCover extends StatelessWidget {
  const _MiniCover({this.cover});

  final PlaybackCover? cover;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final size = theme.spacing.xxl * 1.25;
    final bytes = cover?.bytes;
    final hasArt = bytes != null && bytes.isNotEmpty;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hasArt
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  M3EIcons.music_note,
                  size: size * 0.5,
                  color: scheme.onSecondaryContainer,
                ),
              ),
      ),
    );
  }
}
