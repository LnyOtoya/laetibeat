import 'package:flutter/animation.dart';

/// Motion tokens.
///
/// Motion should explain state, hierarchy, or spatial relationships. Keep
/// routine content calm; reserve longer/emphasized transitions for the player
/// and other high-value moments.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration emphasized = Duration(milliseconds: 500);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve exitCurve = Curves.easeInCubic;
}
