import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/integration/media_integration_host.dart';
import 'skin/app_skin.dart';
import 'skin/app_skin_provider.dart';
import 'skin/app_skin_registry.dart';

/// 应用根节点：只负责选择皮肤。
///
/// 皮肤自己构建根 App、导航壳和页面；后续 Spotify / Apple Music 皮肤
/// 不需要改动这里之外的业务 provider。
class LaetibeatApp extends ConsumerWidget {
  const LaetibeatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skinId = ref.watch(appSkinProvider);
    final skin = ref.watch(appSkinRegistryProvider).skinFor(skinId);
    return MediaIntegrationHost(
      child: KeyedSubtree(
        key: ValueKey<AppSkinId>(skinId),
        child: skin.buildRoot(context, ref),
      ),
    );
  }
}
