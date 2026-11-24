import 'dart:math' as math;

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
                  _ShapePlayPauseButton(
                    isPlaying: isPlaying,
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

/// Play/pause control whose background morphs between a circle and a
/// rotating nine-sided cookie shape.
class _ShapePlayPauseButton extends StatefulWidget {
  const _ShapePlayPauseButton({
    required this.isPlaying,
    required this.semanticLabel,
    required this.onPressed,
  });

  final bool isPlaying;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  State<_ShapePlayPauseButton> createState() => _ShapePlayPauseButtonState();
}

class _ShapePlayPauseButtonState extends State<_ShapePlayPauseButton>
    with TickerProviderStateMixin {
  static const Duration _rotationDuration = Duration(seconds: 8);
  static const double _shapeSize = 40;
  static const double _buttonSize = 48;

  late final AnimationController _morphController;
  late final AnimationController _rotationController;
  late final Morph _morph;

  @override
  void initState() {
    super.initState();
    _morph = Morph(
      M3EShapeKind.circle.polygon,
      M3EShapeKind.cookie9Sided.polygon,
    );
    _morphController = AnimationController(
      vsync: this,
      duration: AppMotion.standard,
      value: widget.isPlaying ? 1 : 0,
    );
    _rotationController = AnimationController(
      vsync: this,
      duration: _rotationDuration,
    );
    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ShapePlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying == oldWidget.isPlaying) return;

    if (widget.isPlaying) {
      _morphController.forward();
      _rotationController.repeat();
    } else {
      _morphController.reverse();
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          M3EHaptics.trigger(M3EHapticFeedback.light);
          widget.onPressed();
        },
        child: SizedBox.square(
          dimension: _buttonSize,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[
                  _morphController,
                  _rotationController,
                ]),
                builder: (BuildContext context, Widget? child) {
                  final double progress = Curves.easeInOutCubic.transform(
                    _morphController.value,
                  );
                  final double rotation =
                      _rotationController.value * 2 * math.pi;
                  return Transform.rotate(
                    angle: rotation,
                    child: SizedBox.square(
                      dimension: _shapeSize,
                      child: CustomPaint(
                        painter: _MorphShapePainter(
                          morph: _morph,
                          progress: progress,
                          color: scheme.primary,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  );
                },
              ),
              Icon(
                widget.isPlaying ? M3EIcons.pause : M3EIcons.play_arrow,
                size: 22,
                color: scheme.onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MorphShapePainter extends CustomPainter {
  const _MorphShapePainter({
    required this.morph,
    required this.progress,
    required this.color,
  });

  final Morph morph;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = morph.toPath(progress: progress);
    final Rect bounds = path.getBounds();
    if (bounds.isEmpty) return;

    final Matrix4 matrix = Matrix4.diagonal3Values(
      size.width / bounds.width,
      size.height / bounds.height,
      1,
    );
    final Path scaledPath = path.transform(matrix.storage);
    final Rect scaledBounds = scaledPath.getBounds();
    final Path centeredPath = scaledPath.shift(
      Offset(size.width / 2, size.height / 2) - scaledBounds.center,
    );

    canvas.drawPath(
      centeredPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _MorphShapePainter oldDelegate) {
    return oldDelegate.morph != morph ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color;
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

    return M3EShapeContainer.cookie4Sided(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
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
    );
  }
}
