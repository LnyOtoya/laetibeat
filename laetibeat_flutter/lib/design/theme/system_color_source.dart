import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Final Material You roles published by the Android theme.
///
/// Compose reads these resource values directly. Reading the same values keeps
/// the Flutter scheme aligned with the OS instead of re-deriving them from a
/// CorePalette.
class SystemColorRoles {
  const SystemColorRoles({required this.light, required this.dark});

  final Map<String, Color> light;
  final Map<String, Color> dark;

  bool get isEmpty => light.isEmpty && dark.isEmpty;

  Map<String, Color> forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }
}

abstract final class SystemColorSource {
  static const MethodChannel _channel = MethodChannel(
    'com.otimeum.laetibeat/system_colors',
  );

  static Future<SystemColorRoles?> load() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getSystemColors',
      );
      if (raw == null) return null;
      final light = _parse(raw['light']);
      final dark = _parse(raw['dark']);
      final roles = SystemColorRoles(light: light, dark: dark);
      if (kDebugMode) {
        debugPrint(
          '[theme] system colors: light=${light.length}, dark=${dark.length}',
        );
      }
      return roles.isEmpty ? null : roles;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Map<String, Color> _parse(Object? value) {
    if (value is! Map) return const <String, Color>{};
    final result = <String, Color>{};
    for (final entry in value.entries) {
      final key = entry.key;
      final raw = entry.value;
      if (key is! String || raw is! int) continue;
      result[key] = Color(raw);
    }
    return result;
  }
}
