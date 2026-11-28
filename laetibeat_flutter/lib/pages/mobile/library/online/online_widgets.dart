import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/design.dart';
import '../../../../widgets/settings/online_settings.dart';

/// 网易云图片 CDN 会对 Dart 默认 HTTP 客户端返回 403。
/// 封面统一走本机 host 的 reqwest 图片代理，避免同一批图片部分失败。
String? onlineImageProxyUrl(WidgetRef ref, String url) {
  final baseUrl = ref.watch(onlineBaseUrlProvider);
  final token = ref.watch(onlineTokenProvider).value;
  if (baseUrl.isEmpty || token == null || token.isEmpty) return null;
  return '$baseUrl/api/v1/image?url=${Uri.encodeComponent(url)}';
}

Map<String, String> onlineImageRequestHeaders(WidgetRef ref) {
  final token = ref.watch(onlineTokenProvider).value;
  if (token == null || token.isEmpty) return const <String, String>{};
  return <String, String>{'Authorization': 'Bearer $token'};
}

Widget _coverPlaceholder(M3EColorScheme scheme, double size) {
  return ColoredBox(
    color: scheme.secondaryContainer,
    child: Icon(
      M3EIcons.music_note,
      size: size * 0.45,
      color: scheme.onSecondaryContainer,
    ),
  );
}

/// 在线音源封面（本机代理加载，失败时回退音符图标）。
class OnlineCover extends ConsumerWidget {
  const OnlineCover({super.key, required this.url, this.size = 44});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final value = url?.trim() ?? '';
    final proxyUrl = value.isEmpty ? null : onlineImageProxyUrl(ref, value);
    return ClipRRect(
      borderRadius: AppRadii.smAll,
      child: SizedBox.square(
        dimension: size,
        child: proxyUrl == null
            ? _coverPlaceholder(scheme, size)
            : Image.network(
                proxyUrl,
                headers: onlineImageRequestHeaders(ref),
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                fit: BoxFit.cover,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) {
                      return _coverPlaceholder(scheme, size);
                    },
              ),
      ),
    );
  }
}
