import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../widgets/player/cover_provider.dart';
import '../../../widgets/player/player_provider.dart';
import '../../../widgets/player/squish_button_pair.dart';

/// 移动端首页：随机 Shape + 当前歌曲 + 播放控制。
class MobileHomeContent extends ConsumerStatefulWidget {
  const MobileHomeContent({super.key});

  @override
  ConsumerState<MobileHomeContent> createState() => _MobileHomeContentState();
}

class _MobileHomeContentState extends ConsumerState<MobileHomeContent> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final player = ref.watch(playerProvider);
    final cover = ref.watch(playbackCoverProvider).value;
    final track = player.current;
    final isPlaying = player.isPlaying;
    final total = player.duration.inMilliseconds;
    final progress = total > 0
        ? (player.position.inMilliseconds / total).clamp(0.0, 1.0)
        : 0.0;
    final sliderValue = _dragValue ?? progress;
    final displayPosition = _dragValue == null
        ? player.position
        : Duration(milliseconds: (_dragValue! * total).round());
    final notifier = ref.read(playerProvider.notifier);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final contentWidth = math.max(0.0, constraints.maxWidth - 48);
        final shapeHeight = math.min(
          contentWidth,
          math.max(220.0, constraints.maxHeight * 0.42),
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: SizedBox(
            height: math.max(constraints.maxHeight - 56, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: _HomeHeroShape(
                    width: contentWidth,
                    height: shapeHeight,
                    cover: cover,
                  ),
                ),
                const Spacer(),
                Text(
                  track == null
                      ? l10n.nothingPlaying
                      : (track.album.trim().isEmpty
                            ? track.title
                            : track.album),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.typeScale.displayLarge.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                SquishButtonPair(
                  expand: true,
                  isPlaying: isPlaying,
                  toggleEnabled: track != null,
                  nextEnabled: player.queue.isNotEmpty,
                  onToggle: notifier.toggle,
                  onNext: notifier.next,
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 84,
                      child: M3EIconButton(
                        icon: Icon(
                          M3EIcons.skip_previous,
                          color: player.queue.isEmpty
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.38,
                                )
                              : theme.colorScheme.onSecondaryContainer,
                        ),
                        variant: M3EIconButtonVariant.tonal,
                        size: M3EIconButtonSize.lg,
                        shape: M3EIconButtonShapeVariant.round,
                        matchParentConstraints: true,
                        tooltip: l10n.previousTrack,
                        onPressed: player.queue.isEmpty ? null : notifier.prev,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          isPlaying
                              ? M3ESlider.wavy(
                                  value: sliderValue,
                                  trackThickness: 10,
                                  onChanged: total > 0
                                      ? (value) =>
                                            setState(() => _dragValue = value)
                                      : null,
                                  onChangeEnd: total > 0
                                      ? (value) {
                                          setState(() => _dragValue = null);
                                          notifier.seek(
                                            Duration(
                                              milliseconds: (value * total)
                                                  .round(),
                                            ),
                                          );
                                        }
                                      : null,
                                )
                              : M3ESlider(
                                  value: sliderValue,
                                  trackThickness: 10,
                                  onChanged: total > 0
                                      ? (value) =>
                                            setState(() => _dragValue = value)
                                      : null,
                                  onChangeEnd: total > 0
                                      ? (value) {
                                          setState(() => _dragValue = null);
                                          notifier.seek(
                                            Duration(
                                              milliseconds: (value * total)
                                                  .round(),
                                            ),
                                          );
                                        }
                                      : null,
                                ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(displayPosition),
                                style: theme.typeScale.labelMedium.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                _formatDuration(player.duration),
                                style: theme.typeScale.labelMedium.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final two = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$two';
    }
    return '$minutes:$two';
  }
}

class _HomeHeroShape extends StatefulWidget {
  const _HomeHeroShape({
    required this.width,
    required this.height,
    required this.cover,
  });

  final double width;
  final double height;
  final PlaybackCover? cover;

  @override
  State<_HomeHeroShape> createState() => _HomeHeroShapeState();
}

class _HomeHeroShapeState extends State<_HomeHeroShape> {
  static const List<M3EShapeKind> _kinds = <M3EShapeKind>[
    M3EShapeKind.bun,
    M3EShapeKind.puffy,
    M3EShapeKind.clamShell,
  ];

  late final M3EShapeKind _kind = _kinds[math.Random().nextInt(_kinds.length)];

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    final bytes = widget.cover?.bytes;
    final hasCover = bytes != null && bytes.isNotEmpty;

    return M3EShapeContainer(
      kind: _kind,
      width: widget.width,
      height: widget.height,
      gradient: hasCover
          ? null
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                scheme.primaryContainer,
                scheme.tertiaryContainer,
              ],
            ),
      color: scheme.primaryContainer,
      child: hasCover
          ? Image.memory(
              bytes,
              width: widget.width,
              height: widget.height,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          : Center(
              child: Icon(
                M3EIcons.music_note,
                size: math.min(widget.width, widget.height) * 0.28,
                color: scheme.onPrimaryContainer,
              ),
            ),
    );
  }
}
