import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../l10n/generated/app_localizations.dart';

/// 播放/暂停 + 下一首的 neighbor-squish 双按钮行。
///
/// 按压其中一个时，该按钮变宽，另一个按相同宽度收缩，整行总宽保持不变。
/// 视觉层仍使用 M3EButton / M3EIconButton，手势与宽度动画由外层驱动。
class SquishButtonPair extends StatefulWidget {
  const SquishButtonPair({
    super.key,
    required this.isPlaying,
    required this.toggleEnabled,
    required this.nextEnabled,
    required this.onToggle,
    required this.onNext,
    this.expand = false,
    this.expandedRatio = 0.35,
    this.haptic = M3EHapticFeedback.light,
  });

  final bool isPlaying;
  final bool toggleEnabled;
  final bool nextEnabled;
  final VoidCallback? onToggle;
  final VoidCallback? onNext;

  /// 是否按父级可用宽度拉伸两按钮并填满。
  final bool expand;
  final double expandedRatio;
  final M3EHapticFeedback haptic;

  @override
  State<SquishButtonPair> createState() => _SquishButtonPairState();
}

class _SquishButtonPairState extends State<SquishButtonPair>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 260),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  int? _pressed;

  static const double _iconButtonWidth = 96;
  static const double _buttonHeight = 84;
  static const double _iconSize = 34;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _enabled(int index) => switch (index) {
    0 => widget.toggleEnabled,
    1 => widget.nextEnabled,
    _ => false,
  };

  void _fire(int index) {
    switch (index) {
      case 0:
        widget.onToggle?.call();
      case 1:
        widget.onNext?.call();
    }
  }

  double _naturalWidth(int index, M3EThemeData theme, String playLabel) {
    if (index == 1) return _iconButtonWidth;
    final painter = TextPainter(
      text: TextSpan(text: playLabel, style: theme.typeScale.titleMedium),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return _iconButtonWidth + painter.width + _iconSize + theme.spacing.xl * 2;
  }

  List<double> _fitWidths(List<double> natural, double gap, double available) {
    if (!widget.expand || available <= 0) return natural;
    final total = natural.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return natural;
    final ratio = math.max(0.0, (available - gap) / total);
    return natural.map((value) => value * ratio).toList(growable: false);
  }

  List<double> _sizes(List<double> natural) {
    final sizes = List<double>.of(natural);
    final pressed = _pressed;
    final t = _curve.value;
    if (pressed == null || t <= 0) return sizes;

    final growth = natural[pressed] * widget.expandedRatio * t;
    sizes[pressed] += growth;
    final other = pressed == 0 ? 1 : 0;
    sizes[other] = math.max(0, sizes[other] - growth);
    return sizes;
  }

  void _press(int index) {
    if (!_enabled(index)) return;
    M3EHaptics.trigger(widget.haptic);
    setState(() => _pressed = index);
    _controller.forward(from: 0);
  }

  void _release(int index) {
    if (_pressed != index) return;
    setState(() => _pressed = null);
    _controller.reverse();
    _fire(index);
  }

  void _cancel(int index) {
    if (_pressed != index) return;
    setState(() => _pressed = null);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final playLabel = widget.isPlaying ? l10n.pause : l10n.play;

    final gap = theme.spacing.sm;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0.0;
        final natural = <double>[
          _naturalWidth(0, theme, playLabel),
          _naturalWidth(1, theme, playLabel),
        ];
        final baseWidths = _fitWidths(natural, gap, available);

        return SizedBox(
          width: widget.expand && available > 0 ? available : null,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final sizes = _sizes(baseWidths);
              return Row(
                mainAxisSize: widget.expand
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                children: [
                  _button(
                    0,
                    sizes[0],
                    icon: widget.isPlaying ? Icons.pause : Icons.play_arrow,
                    label: playLabel,
                    tooltip: playLabel,
                    scheme: scheme,
                  ),
                  SizedBox(width: gap),
                  _button(
                    1,
                    sizes[1],
                    icon: Icons.skip_next,
                    label: null,
                    tooltip: l10n.nextTrack,
                    scheme: scheme,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _button(
    int index,
    double width, {
    required IconData icon,
    required String? label,
    required String tooltip,
    required M3EColorScheme scheme,
  }) {
    final enabled = _enabled(index);
    final Widget visual;
    if (label == null) {
      visual = M3EIconButton(
        icon: Icon(icon),
        variant: M3EIconButtonVariant.tonal,
        size: M3EIconButtonSize.lg,
        shape: M3EIconButtonShapeVariant.round,
        matchParentConstraints: true,
        tooltip: tooltip,
        // 外层 GestureDetector 负责实际点击，这里必须传 onPressed，
        // 否则 M3E 会把按钮当成 disabled，tonal 颜色会被 disabled 色覆盖。
        onPressed: enabled ? () {} : null,
      );
    } else {
      visual = M3EButton(
        icon: Icon(icon),
        label: Text(label),
        decoration: M3EButtonDecoration(
          fixedSize: Size(width, _buttonHeight),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.12);
            }
            return scheme.tertiary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            return scheme.onTertiary;
          }),
        ),
        onPressed: enabled ? () {} : null,
        enabled: enabled,
        style: M3EButtonStyle.filled,
        size: M3EButtonSize.lg,
        shape: M3EButtonShape.round,
        tooltip: tooltip,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _press(index) : null,
      onTapUp: enabled ? (_) => _release(index) : null,
      onTapCancel: () {
        if (enabled) _cancel(index);
      },
      child: IgnorePointer(
        child: SizedBox(width: width, height: _buttonHeight, child: visual),
      ),
    );
  }
}
