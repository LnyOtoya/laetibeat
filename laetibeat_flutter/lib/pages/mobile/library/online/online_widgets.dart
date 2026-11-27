import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';

/// 在线音源封面（直接 HTTPS 加载，失败时回退音符图标）。
class OnlineCover extends StatelessWidget {
  const OnlineCover({super.key, required this.url, this.size = 44});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    final value = url?.trim() ?? '';
    return ClipRRect(
      borderRadius: AppRadii.smAll,
      child: SizedBox.square(
        dimension: size,
        child: value.isEmpty
            ? ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  M3EIcons.music_note,
                  size: size * 0.45,
                  color: scheme.onSecondaryContainer,
                ),
              )
            : Image.network(
                value,
                fit: BoxFit.cover,
                errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
                  return ColoredBox(
                    color: scheme.secondaryContainer,
                    child: Icon(
                      M3EIcons.music_note,
                      size: size * 0.45,
                      color: scheme.onSecondaryContainer,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
