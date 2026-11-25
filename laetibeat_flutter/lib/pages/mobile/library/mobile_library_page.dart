import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/widgets/settings/online_music_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import '../widgets/mobile_large_subpage_app_bar.dart';
import 'library_source_filter.dart';
import 'mobile_library_subpages.dart';
import 'netease/netease_daily_page.dart';

/// 媒体库首页。
///
/// 只做内容入口，不再直接展示歌曲/专辑/艺术家列表。具体内容页保留原有
/// 布局，后续在各自页面内接入来源筛选。
class MobileLibraryPage extends ConsumerWidget {
  const MobileLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);
    final onlineSource = ref.watch(selectedOnlineMusicSourceProvider);

    final localSegments = <_LibrarySegment>[
      _LibrarySegment(
        icon: M3EIcons.cloud,
        title: '私服歌曲',
        routeName: MobileRoutes.librarySongs,
        page: const MobileLibrarySongsPage(
          sourceFilter: LibrarySourceFilter.navidrome,
          title: '私服歌曲',
        ),
      ),
      _LibrarySegment(
        icon: M3EIcons.library_music,
        title: '歌曲',
        routeName: MobileRoutes.librarySongs,
        page: const MobileLibrarySongsPage(
          sourceFilter: LibrarySourceFilter.local,
          title: '歌曲',
        ),
      ),
      _LibrarySegment(
        icon: M3EIcons.person,
        title: '艺人',
        routeName: MobileRoutes.libraryArtists,
        page: const MobileLibraryArtistsPage(),
      ),
      _LibrarySegment(
        icon: M3EIcons.queue_music,
        title: '歌单',
        routeName: MobileRoutes.libraryPlaylists,
        page: const MobileLibraryPlaylistsPage(),
      ),
      _LibrarySegment(
        icon: M3EIcons.album,
        title: '专辑',
        routeName: MobileRoutes.libraryAlbums,
        page: const MobileLibraryAlbumsPage(),
      ),
      _LibrarySegment(
        icon: M3EIcons.download,
        title: '已下载',
        routeName: MobileRoutes.libraryDownloads,
        page: const _LibraryPlaceholderPage(
          title: '已下载',
          message: '下载管理将在这里显示',
          icon: M3EIcons.download,
        ),
      ),
    ];

    final onlineSegments = _buildOnlineSegments(onlineSource);

    void openSegment(_LibrarySegment segment) {
      final page = segment.page;
      if (page == null) return;
      pushMobileRootPage(context, page, name: segment.routeName);
    }

    Widget buildSection(String title, Key key, List<_LibrarySegment> segments) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSectionHeader(
            title: title,
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
          ),
          _LibrarySegmentedList(
            key: key,
            segments: segments,
            onOpen: openSegment,
          ),
        ],
      );
    }

    return AppScaffold(
      background: AppSurfaceLevel.base,
      safeArea: false,
      appBar: M3EAppBar.top(
        backgroundColor: AppSurfaceLevel.base.resolve(scheme),
        variant: M3EAppBarVariant.largeFlexible,
        shapeFamily: M3EAppBarShapeFamily.square,
        safeArea: true,
        titleText: l10n.libraryTitle,
        actions: const <Widget>[],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.lg + bottomInset,
        ),
        children: <Widget>[
          buildSection(
            '本地音乐',
            const ValueKey<String>('library_group_local'),
            localSegments,
          ),
          const SizedBox(height: AppSpacing.xl),
          buildSection(
            '在线音乐 · ${onlineSource.label}',
            const ValueKey<String>('library_group_online'),
            onlineSegments,
          ),
        ],
      ),
    );
  }

  List<_LibrarySegment> _buildOnlineSegments(OnlineMusicSource source) {
    final message = '${source.label}尚未接入，请先在设置中配置 API';

    return <_LibrarySegment>[
      _LibrarySegment(
        icon: M3EIcons.person,
        title: '艺人',
        routeName: MobileRoutes.libraryArtists,
        page: _LibraryPlaceholderPage(
          title: '艺人',
          message: message,
          icon: M3EIcons.person,
        ),
      ),
      _LibrarySegment(
        icon: M3EIcons.queue_music,
        title: '我的在线歌单',
        routeName: MobileRoutes.libraryPlaylists,
        page: _LibraryPlaceholderPage(
          title: '我的在线歌单',
          message: message,
          icon: M3EIcons.queue_music,
        ),
      ),
      _LibrarySegment(
        icon: M3EIcons.auto_awesome,
        title: '每日推荐',
        routeName: MobileRoutes.discovery,
        page: switch (source) {
          OnlineMusicSource.netease => const NeteaseDailyPage(),
        },
      ),
      _LibrarySegment(
        icon: M3EIcons.album,
        title: '专辑',
        routeName: MobileRoutes.libraryAlbums,
        page: _LibraryPlaceholderPage(
          title: '专辑',
          message: message,
          icon: M3EIcons.album,
        ),
      ),
      _LibrarySegment(
        icon: M3EIcons.radio,
        title: '电台',
        routeName: MobileRoutes.libraryPodcasts,
        page: _LibraryPlaceholderPage(
          title: '电台',
          message: message,
          icon: M3EIcons.radio,
        ),
      ),
    ];
  }
}

class _LibrarySegment {
  const _LibrarySegment({
    required this.icon,
    required this.title,
    required this.routeName,
    this.page,
  });

  final IconData icon;
  final String title;
  final String routeName;
  final Widget? page;

  bool get enabled => page != null;
}

class _LibrarySegmentedList extends StatelessWidget {
  const _LibrarySegmentedList({
    super.key,
    required this.segments,
    required this.onOpen,
  });

  final List<_LibrarySegment> segments;
  final ValueChanged<_LibrarySegment> onOpen;

  @override
  Widget build(BuildContext context) {
    return m3e_core.M3ESegmentedList.builder(
      itemCount: segments.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      listPadding: EdgeInsets.zero,
      isEnabled: (int index) => segments[index].enabled,
      onTap: (int index) => onOpen(segments[index]),
      semanticLabelBuilder: (int index) => segments[index].title,
      decoration: const m3e_core.M3ESegmentedListDecoration(
        outerRadius: 24.0,
        innerRadius: 12.0,
        pressedRadius: 8.0,
        pressedScale: 0.98,
        hoveredRadius: 16.0,
        gap: 2.0,
        padding: EdgeInsets.all(4.0),
        margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 5.0),
      ),
      itemBuilder: (BuildContext context, int index) {
        final segment = segments[index];
        return m3e_core.M3EListItem(
          enabled: segment.enabled,
          minHeight: 48,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Icon(segment.icon, size: 20),
          headline: Text(
            segment.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: segment.enabled
              ? const Icon(M3EIcons.chevron_right, size: 20)
              : null,
        );
      },
    );
  }
}

class _LibraryPlaceholderPage extends StatelessWidget {
  const _LibraryPlaceholderPage({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: title),
      body: AppEmptyState(title: title, message: message, icon: icon),
    );
  }
}
