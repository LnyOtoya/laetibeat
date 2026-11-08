import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import 'persistence.dart';

const String kCoverShapeKey = 'appearance.cover_shape';

/// 播放页封面使用的 M3E shape，默认 square。
class CoverShapeNotifier extends Notifier<M3EShapeKind> {
  @override
  M3EShapeKind build() {
    final saved = ref.read(sharedPreferencesProvider).getString(kCoverShapeKey);
    return M3EShapeKind.values.firstWhere(
      (kind) => kind.name == saved,
      orElse: () => M3EShapeKind.square,
    );
  }

  Future<void> setShape(M3EShapeKind kind) async {
    if (kind == state) return;
    state = kind;
    await ref
        .read(sharedPreferencesProvider)
        .setString(kCoverShapeKey, kind.name);
  }
}

final coverShapeProvider = NotifierProvider<CoverShapeNotifier, M3EShapeKind>(
  CoverShapeNotifier.new,
);

/// 将 enum 名称转换成适合显示的名称，例如 cookie12Sided -> Cookie12 Sided。
String coverShapeLabel(M3EShapeKind kind) {
  final spaced = kind.name.replaceAllMapped(
    RegExp(r'(?<=[a-z0-9])(?=[A-Z])'),
    (_) => ' ',
  );
  if (spaced.isEmpty) return spaced;
  return spaced[0].toUpperCase() + spaced.substring(1);
}
