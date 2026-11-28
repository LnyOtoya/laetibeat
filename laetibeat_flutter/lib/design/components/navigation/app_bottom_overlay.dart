import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../tokens/app_motion_tokens.dart';
import '../../tokens/app_size_tokens.dart';

/// Floating shell chrome: mini player above the navigation bar.
///
/// The overlay paints above the page and never participates in the page
/// layout. The navigation bar stays on top; the mini player slides down behind
/// the navigation bar and is clipped at the overlay's bottom edge.
class AppBottomOverlay extends StatefulWidget {
  const AppBottomOverlay({
    super.key,
    required this.navigationBar,
    required this.navigationBarHeight,
    required this.miniPlayer,
    required this.miniVisible,
    this.miniPlayerHeight = AppComponentSize.miniPlayerAccessory,
    this.navBarScrollState,
  });

  final Widget navigationBar;

  /// Resolved height of [navigationBar], including its safe-area padding.
  final double navigationBarHeight;

  final Widget miniPlayer;
  final bool miniVisible;

  /// Height reserved for the mini player, including its outer vertical
  /// padding above and below the rounded player surface.
  final double miniPlayerHeight;
  final M3EFloatingToolbarState? navBarScrollState;

  @override
  State<AppBottomOverlay> createState() => _AppBottomOverlayState();
}

class _AppBottomOverlayState extends State<AppBottomOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _miniController;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _miniController = AnimationController(
      vsync: this,
      duration: AppMotion.standard,
      value: widget.miniVisible ? 1 : 0,
    );
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _miniController, curve: AppMotion.standardCurve),
    );
    _fade = CurvedAnimation(
      parent: _miniController,
      curve: AppMotion.standardCurve,
    );
  }

  @override
  void didUpdateWidget(covariant AppBottomOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.miniVisible != oldWidget.miniVisible) {
      if (widget.miniVisible) {
        _miniController.forward();
      } else {
        _miniController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _miniController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double totalHeight =
        widget.navigationBarHeight + widget.miniPlayerHeight;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.navigationBarHeight,
            height: widget.miniPlayerHeight,
            child: IgnorePointer(
              ignoring: !widget.miniVisible,
              child: ExcludeSemantics(
                excluding: !widget.miniVisible,
                child: AnimatedBuilder(
                  animation:
                      widget.navBarScrollState ??
                      const AlwaysStoppedAnimation<double>(0),
                  builder: (BuildContext context, Widget? child) {
                    final state = widget.navBarScrollState;
                    final double shift = state == null
                        ? 0
                        : (-state.offset)
                              .clamp(0.0, widget.navigationBarHeight)
                              .toDouble();
                    return Transform.translate(
                      offset: Offset(0, shift),
                      child: child,
                    );
                  },
                  child: ClipRect(
                    child: FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: widget.miniPlayer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: widget.navigationBar),
        ],
      ),
    );
  }
}
