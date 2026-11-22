import 'package:flutter/widgets.dart';

import '../../tokens/app_shape_tokens.dart';

/// Artwork shape semantics.
///
/// `m3eSquare` uses the Material 3 Expressive shape family; the other values
/// are simple geometric clips.
enum AppArtworkShape { square, rounded, circle, pill, m3eSquare }

extension AppArtworkShapeX on AppArtworkShape {
  /// Border radius for the non-M3E shape variants.
  BorderRadius? get borderRadius {
    return switch (this) {
      AppArtworkShape.square => BorderRadius.zero,
      AppArtworkShape.rounded => AppRadii.lgAll,
      AppArtworkShape.circle || AppArtworkShape.pill => AppRadii.fullAll,
      AppArtworkShape.m3eSquare => null,
    };
  }
}
