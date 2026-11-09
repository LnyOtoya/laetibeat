import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persistence.dart';

const String kLxDefaultQualityKey = 'lx.defaultQuality';
const List<String> kLxQualityOptions = <String>['128k', '320k', 'flac'];

/// Default quality requested from LX sources when a track does not carry a
/// more specific bitrate preference.
class LxDefaultQualityNotifier extends Notifier<String> {
  @override
  String build() {
    final saved = ref
        .read(sharedPreferencesProvider)
        .getString(kLxDefaultQualityKey);
    return kLxQualityOptions.contains(saved) ? saved! : '128k';
  }

  void setQuality(String quality) {
    if (!kLxQualityOptions.contains(quality) || quality == state) return;
    state = quality;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(kLxDefaultQualityKey, quality),
    );
  }
}

final lxDefaultQualityProvider =
    NotifierProvider<LxDefaultQualityNotifier, String>(
      LxDefaultQualityNotifier.new,
    );
