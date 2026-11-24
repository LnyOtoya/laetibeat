import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../widgets/player/cover_provider.dart';
import '../../../widgets/player/playback_panel.dart';
import '../../../widgets/player/player_provider.dart';
import '../mobile_navigation.dart';
import 'mobile_playback_page.dart';

/// 移动端全局迷你播放器。
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  /// 与导航栏保持一致的屏幕左右留白。
  static const double _horizontalMargin = AppSpacing.xxl;
  static const double _height = 64;

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

          final Widget player = Material(
            color: background,
            elevation: 3,
            shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.24),
            shape: RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: _height,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openPlayer(context),
                    child: Hero(
                      tag: mobileNowPlayingCoverHeroTag,
                      child: _MiniCover(cover: cover),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _tappableTitle(
                          context,
                          track.title,
                          theme.typeScale.titleSmall.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _tappableTitle(
                          context,
                          track.artist,
                          theme.typeScale.bodySmall.copyWith(
                            color: foreground.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  M3EIconButton(
                    variant: M3EIconButtonVariant.standard,
                    icon: Icon(M3EIcons.skip_previous, color: foreground),
                    semanticLabel: AppLocalizations.of(
                      context,
                    ).previousTrack,
                    onPressed: notifier.prev,
                  ),
                  M3EIconButton(
                    variant: M3EIconButtonVariant.filled,
                    icon: Icon(
                      isPlaying ? M3EIcons.pause : M3EIcons.play_arrow,
                      color: foreground,
                    ),
                    semanticLabel: isPlaying
                        ? AppLocalizations.of(context).pause
                        : AppLocalizations.of(context).play,
                    onPressed: notifier.toggle,
                  ),
                  M3EIconButton(
                    variant: M3EIconButtonVariant.standard,
                    icon: Icon(M3EIcons.skip_next, color: foreground),
                    semanticLabel: AppLocalizations.of(context).nextTrack,
                    onPressed: notifier.next,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ),
            ),
          );

          return _MiniPlayerDragRegion(
            onOpen: () => _openPlayer(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalMargin,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: player,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tappableTitle(BuildContext context, String text, TextStyle style) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openPlayer(context),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
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
