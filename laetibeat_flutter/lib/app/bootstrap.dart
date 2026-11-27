import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/src/rust/api/library.dart' as rust_library;
import 'package:laetibeat/src/rust/api/lx.dart' as rust_lx;
import 'package:laetibeat/src/rust/api/playlists.dart' as rust_playlists;
import 'package:laetibeat/src/rust/api/stats.dart' as rust_stats;
import 'package:laetibeat/src/rust/frb_generated.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/playback/just_audio_backend.dart';
import '../widgets/player/lx_search_provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../core/playback/laetibeat_audio_handler.dart';
import '../core/providers/playback_backend_provider.dart';
import '../core/services/directory_picker.dart';
import '../core/services/window_service.dart';
import '../widgets/player/cover_provider.dart';
import '../widgets/player/playback_backend.dart';
import '../widgets/settings/cache_usage_service.dart';
import '../widgets/settings/display_settings.dart';
import '../widgets/settings/online_host.dart';
import '../widgets/settings/persistence.dart';
import '../widgets/settings/subsonic_provider.dart';
import 'app.dart';
import 'app_form_factor.dart';
import 'app_locale.dart';

/// 应用启动装配层：平台判断、平台服务选择、全局初始化都在这里完成。
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final formFactor = detectAppFormFactor();

  final windowService = switch (formFactor) {
    AppFormFactor.desktop => const DesktopWindowService(),
    AppFormFactor.mobile => const NoopWindowService(),
  };
  try {
    await windowService.initialize();
  } catch (e) {
    debugPrint('窗口管理器初始化失败: $e');
  }

  await RustLib.init();

  // 初始化播放统计库(失败不阻塞应用启动)
  try {
    final supportDir = await getApplicationSupportDirectory();
    await supportDir.create(recursive: true);
    await rust_stats.initStatsDb(path: '${supportDir.path}/laetibeat_stats.db');
  } catch (e) {
    debugPrint('初始化播放统计库失败: $e');
  }

  // 初始化本地歌单库(失败不阻塞应用启动)
  try {
    final supportDir = await getApplicationSupportDirectory();
    await supportDir.create(recursive: true);
    await rust_playlists.initPlaylistDb(
      path: '${supportDir.path}/laetibeat_playlists.db',
    );
  } catch (e) {
    debugPrint('初始化本地歌单库失败: $e');
  }

  // 初始化远端音乐库数据库(失败不阻塞应用启动)
  try {
    final supportDir = await getApplicationSupportDirectory();
    await supportDir.create(recursive: true);
    await rust_library.initLibraryDb(
      path: '${supportDir.path}/laetibeat_library.db',
    );
  } catch (e) {
    debugPrint('初始化远端音乐库数据库失败: $e');
  }

  // 初始化 LX 音源存储(失败不阻塞应用启动；音源由用户自行导入)
  try {
    final supportDir = await getApplicationSupportDirectory();
    await supportDir.create(recursive: true);
    await rust_lx.initLxSourceStore(root: '${supportDir.path}/laetibeat_lx');
  } catch (e) {
    debugPrint('初始化 LX 音源存储失败: $e');
  }

  // 预加载本地设置与播放快照,供 Riverpod provider 构建时同步恢复
  final prefs = await SharedPreferences.getInstance();
  final playbackStore = PlaybackSnapshotStore();
  final playbackSnapshot = await playbackStore.load();

  // 后台重连已保存的 OpenSubsonic 服务器,不阻塞启动
  unawaited(reconnectSubsonicServers(prefs));

  final directoryPicker = switch (formFactor) {
    AppFormFactor.desktop => const DesktopDirectoryPicker(),
    AppFormFactor.mobile => const MobileDirectoryPicker(),
  };

  final playbackBackend = switch (formFactor) {
    AppFormFactor.desktop => MediaKitBackend(),
    AppFormFactor.mobile => JustAudioBackend(),
  };

  final container = ProviderContainer(
    overrides: [
      appFormFactorProvider.overrideWithValue(formFactor),
      windowServiceProvider.overrideWithValue(windowService),
      directoryPickerProvider.overrideWithValue(directoryPicker),
      playbackBackendProvider.overrideWithValue(playbackBackend),
      sharedPreferencesProvider.overrideWithValue(prefs),
      playbackSnapshotStoreProvider.overrideWithValue(playbackStore),
      initialPlaybackSnapshotProvider.overrideWithValue(playbackSnapshot),
    ],
  );

  // 仅在 Android 初始化系统媒体服务；桌面继续使用 media_kit 的现有路径。
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      final l10n = await _notificationLocalizations(prefs);
      await AudioService.init(
        builder: () => LaetibeatAudioHandler(container),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.otimeum.laetibeat.playback',
          androidNotificationChannelName: l10n.notificationChannelName,
          androidNotificationChannelDescription:
              l10n.notificationChannelDescription,
          // 暂停时保留前台服务：否则其他应用结束后自动恢复播放，
          // 会在后台触发 startForegroundService 并可能被 Android 12+ 拒绝。
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
          androidNotificationIcon: 'drawable/ic_stat_playback',
          artDownscaleWidth: 512,
          artDownscaleHeight: 512,
        ),
      );
    } catch (e) {
      debugPrint('初始化 Android 音频服务失败: $e');
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const LaetibeatApp(),
    ),
  );

  // 内置在线音源在首帧后启动，避免 Go 进程启动阻塞 UI。
  unawaited(container.read(onlineHostProvider.notifier).startIfNeeded());

  // 启动后套用用户保存的缓存上限；磁盘 LRU 扫描放在首帧之后，避免阻塞启动。
  unawaited(_applyStartupCacheLimits(container));

  // 首帧后再请求高刷新率，确保 Flutter view/surface 已挂载。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_applyStartupHighRefresh(container));
  });

  // 预热洛雪运行时：源脚本初始化可能要十几秒（QuickJS + 脚本自检），
  // 放在后台跑，用户进搜索页时通常已经就绪，不必再等。
  unawaited(_prewarmLxRuntime(container));
}

Future<void> _prewarmLxRuntime(ProviderContainer container) async {
  try {
    // 先拿到缓存的能力声明（毫秒级），再在后台真正加载脚本。
    await container.read(lxRuntimeProvider.future);
    await container.read(lxRuntimeProvider.notifier).warmUp();
  } catch (error) {
    // 失败不阻塞启动：状态留在 provider 里，界面会提示去设置页处理。
    debugPrint('洛雪音源预热失败: $error');
  }
}

Future<void> _applyStartupCacheLimits(ProviderContainer container) async {
  try {
    await applyCacheLimitsToCovers(
      limits: container.read(cacheLimitsProvider),
      localCovers: container.read(coverProvider),
      remoteCovers: container.read(remoteCoverSourceProvider),
      lxCovers: container.read(lxCoverSourceProvider),
    );
  } catch (error) {
    debugPrint('应用启动缓存上限失败: $error');
  }
}

Future<void> _applyStartupHighRefresh(ProviderContainer container) async {
  await applyHighRefreshRatePreference(container.read(highRefreshRateProvider));
}

/// 在 runApp 之前为 Android 通知渠道选择语言。
/// 渠道名只在首次创建时生效；切换应用语言后由系统保留原名称。
Future<AppLocalizations> _notificationLocalizations(SharedPreferences prefs) {
  final saved = prefs.getString(kAppLocaleKey);
  final Locale locale;
  if (saved == 'zh') {
    locale = const Locale('zh');
  } else if (saved == 'en') {
    locale = const Locale('en');
  } else {
    final system = WidgetsBinding.instance.platformDispatcher.locale;
    locale = system.languageCode == 'zh'
        ? const Locale('zh')
        : const Locale('en');
  }
  return AppLocalizations.delegate.load(locale);
}
