import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// APK / 安装包的真实版本信息。
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// 设置页展示用的 versionName，例如 `1.0.0`。
final appVersionLabelProvider = FutureProvider<String>((ref) async {
  final info = await ref.watch(packageInfoProvider.future);
  return info.version;
});
