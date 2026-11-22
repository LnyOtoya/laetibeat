import 'dart:typed_data';

import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../tokens/app_shape_tokens.dart';
import 'app_artwork_placeholder.dart';
import 'app_artwork_shape.dart';
import 'app_artwork_size.dart';

/// The single artwork/cover primitive used by the design system.
///
/// It accepts raw cover bytes (the player's current model) or an
/// [ImageProvider] (network covers later), clips them with a semantic
/// [AppArtworkShape], and falls back to a tonal placeholder.
class AppArtwork extends StatelessWidget {
  const AppArtwork({
    super.key,
    this.bytes,
    this.imageProvider,
    this.size = AppArtworkSize.md,
    this.shape = AppArtworkShape.rounded,
    this.fit = BoxFit.cover,
    this.fallbackIcon = M3EIcons.music_note,
    this.semanticLabel,
    this.cacheWidth,
    this.cacheHeight,
    this.optimizeImage = true,
    this.backgroundColor,
    this.iconColor,
    this.borderRadiusOverride,
    this.clipBehavior = Clip.antiAlias,
  });

  /// Raw image bytes, typically an embedded cover from Rust.
  final Uint8List? bytes;

  /// Alternative image source for remote artwork.
  final ImageProvider? imageProvider;

  final AppArtworkSize size;
  final AppArtworkShape shape;
  final BoxFit fit;
  final IconData fallbackIcon;
  final String? semanticLabel;

  /// Optional decode-size override. When null and [optimizeImage] is true,
  /// the decode size is derived from [size] and the device pixel ratio.
  final int? cacheWidth;
  final int? cacheHeight;
  final bool optimizeImage;

  final Color? backgroundColor;
  final Color? iconColor;

  /// Overrides the shape token when a page needs a slightly different radius.
  final BorderRadius? borderRadiusOverride;

  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final dimension = size.value;
    final scheme = M3ETheme.of(context).colorScheme;
    final child = _buildImage(context, dimension, scheme);

    return SizedBox.square(
      dimension: dimension,
      child: _applyShape(child, dimension, scheme),
    );
  }

  Widget _buildImage(
    BuildContext context,
    double dimension,
    M3EColorScheme scheme,
  ) {
    final resolvedCache = _resolveCacheSize(context, dimension);

    final Widget image;
    if (bytes != null && bytes!.isNotEmpty) {
      image = Image.memory(
        bytes!,
        width: dimension,
        height: dimension,
        fit: fit,
        gaplessPlayback: true,
        cacheWidth: resolvedCache,
        cacheHeight: resolvedCache,
        filterQuality: FilterQuality.medium,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
      );
    } else if (imageProvider != null) {
      image = Image(
        image: ResizeImage.resizeIfNeeded(
          resolvedCache,
          resolvedCache,
          imageProvider!,
        ),
        width: dimension,
        height: dimension,
        fit: fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
      );
    } else {
      return AppArtworkPlaceholder(
        size: dimension,
        icon: fallbackIcon,
        backgroundColor: backgroundColor,
        iconColor: iconColor,
      );
    }

    if (backgroundColor == null) return image;
    return ColoredBox(color: backgroundColor!, child: image);
  }

  int? _resolveCacheSize(BuildContext context, double dimension) {
    if (!optimizeImage) return null;
    final requested = cacheWidth ?? cacheHeight;
    if (requested != null) return requested;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (dimension * dpr).round();
  }

  Widget _applyShape(Widget child, double dimension, M3EColorScheme scheme) {
    switch (shape) {
      case AppArtworkShape.m3eSquare:
        return M3EShapeContainer.square(
          width: dimension,
          height: dimension,
          color: backgroundColor ?? scheme.secondaryContainer,
          clipBehavior: clipBehavior,
          child: child,
        );
      case AppArtworkShape.circle:
      case AppArtworkShape.pill:
        return ClipOval(clipBehavior: clipBehavior, child: child);
      case AppArtworkShape.rounded:
        return ClipRRect(
          borderRadius: borderRadiusOverride ?? AppRadii.lgAll,
          clipBehavior: clipBehavior,
          child: child,
        );
      case AppArtworkShape.square:
        return ClipRRect(
          borderRadius: borderRadiusOverride ?? BorderRadius.zero,
          clipBehavior: clipBehavior,
          child: child,
        );
    }
  }
}
