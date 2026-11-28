import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_mode.dart';
import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../widgets/settings/online_provider.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import 'library_source_filter.dart';
import 'mobile_library_subpages.dart';
import 'online/online_detail_pages.dart';
import 'online/online_widgets.dart';

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
    final appMode = ref.watch(appModeProvider);
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
        page: const MobileLibraryArtistsPage(
          sourceFilter: LibrarySourceFilter.navidrome,
        ),
      ),
      _LibrarySegment(
        icon: M3EIcons.queue_music,
        title: '歌单',
        routeName: MobileRoutes.libraryPlaylists,
        page: const MobileLibraryPlaylistsPage(
          sourceFilter: LibrarySourceFilter.navidrome,
        ),
      ),
      _LibrarySegment(
        icon: M3EIcons.album,
        title: '专辑',
        routeName: MobileRoutes.libraryAlbums,
        page: const MobileLibraryAlbumsPage(
          sourceFilter: LibrarySourceFilter.navidrome,
        ),
      ),
      _LibrarySegment(
        icon: M3EIcons.download,
        title: '已下载',
        routeName: MobileRoutes.libraryDownloads,
        page: const _LibraryPlaceholderPage(
          title: '已下载',
          message: '下载管理将在这里显示',
          icon: M3EIcons.download,
          showLayout: false,
        ),
      ),
    ];

    final onlineSegments = <_LibrarySegment>[
      _LibrarySegment(
        icon: M3EIcons.favorite,
        title: '我喜欢的音乐',
        routeName: MobileRoutes.librarySongs,
        page: const OnlineLikedSongsPage(),
      ),
      _LibrarySegment(
        icon: M3EIcons.queue_music,
        title: '创建的歌单',
        routeName: MobileRoutes.libraryPlaylists,
        page: const OnlinePlaylistCollectionPage(
          title: '创建的歌单',
          kind: 'created',
        ),
      ),
      _LibrarySegment(
        icon: M3EIcons.playlist_add,
        title: '收藏的歌单',
        routeName: MobileRoutes.libraryPlaylists,
        page: const OnlinePlaylistCollectionPage(
          title: '收藏的歌单',
          kind: 'collected',
        ),
      ),
      _LibrarySegment(
        icon: M3EIcons.album,
        title: '收藏的专辑',
        routeName: MobileRoutes.libraryAlbums,
        page: const OnlineAlbumCollectionPage(),
      ),
      _LibrarySegment(
        icon: M3EIcons.download,
        title: '已下载',
        routeName: MobileRoutes.libraryDownloads,
        page: const _LibraryPlaceholderPage(
          title: '已下载',
          message: '下载管理将在这里显示',
          icon: M3EIcons.download,
          showLayout: false,
        ),
      ),
    ];
    final segments = appMode == AppMode.netease
        ? onlineSegments
        : localSegments;
    final sectionTitle = appMode == AppMode.netease ? '我的音乐' : '本地音乐';
    final sectionKey = appMode == AppMode.netease
        ? const ValueKey<String>('library_group_my_music')
        : const ValueKey<String>('library_group_local');

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
            titleRole: AppTextRole.titleMedium,
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
      appBar: AppPageBar.tab(
        title: l10n.libraryTitle,
        backgroundColor: mobileTabBarBackground(ref, scheme),
        actionsBuilder: (bool _) => mobileTabBarActions(context),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.lg + bottomInset,
        ),
        children: <Widget>[
          if (appMode == AppMode.netease) ...<Widget>[
            const _OnlineUserProfileCard(),
            const SizedBox(height: AppSpacing.lg),
          ],
          buildSection(sectionTitle, sectionKey, segments),
          const SizedBox(height: AppSpacing.lg),
          const _LibrarySettingsEntry(),
        ],
      ),
    );
  }
}

class _LibrarySettingsEntry extends StatelessWidget {
  const _LibrarySettingsEntry();

  @override
  Widget build(BuildContext context) {
    return m3e_core.M3ESegmentedList.builder(
      itemCount: 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      listPadding: EdgeInsets.zero,
      onTap: (_) => Navigator.of(context).pushNamed(MobileRoutes.settings),
      decoration: const m3e_core.M3ESegmentedListDecoration(
        outerRadius: 24.0,
        innerRadius: 12.0,
        pressedRadius: 8.0,
        pressedScale: 0.98,
        hoveredRadius: 16.0,
        gap: 2.0,
        padding: EdgeInsets.all(4.0),
        margin: EdgeInsets.symmetric(
          horizontal: AppSpacing.none,
          vertical: 5.0,
        ),
      ),
      itemBuilder: (BuildContext context, int index) {
        return m3e_core.M3EListItem(
          minHeight: 48,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: const Icon(M3EIcons.settings, size: 20),
          headline: const Text(
            '设置',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: const Icon(M3EIcons.chevron_right, size: 20),
        );
      },
    );
  }
}

class _OnlineUserProfileCard extends ConsumerWidget {
  const _OnlineUserProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onlineUserProfileProvider);
    return profile.when(
      loading: () => const _ProfileSurface(
        child: SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (Object error, StackTrace? stack) => _ProfileSurface(
        child: Row(
          children: <Widget>[
            Icon(
              M3EIcons.lock,
              color: M3ETheme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '无法获取网易云账号信息',
                style: M3ETheme.of(context).typeScale.bodyMedium,
              ),
            ),
            M3EButton(
              style: M3EButtonStyle.tonal,
              size: M3EButtonSize.sm,
              label: const Text('重试'),
              onPressed: () => ref.invalidate(onlineUserProfileProvider),
            ),
          ],
        ),
      ),
      data: (OnlineUserProfile value) =>
          _OnlineUserProfileContent(profile: value),
    );
  }
}

class _ProfileSurface extends StatelessWidget {
  const _ProfileSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      level: AppSurfaceLevel.container,
      borderRadius: AppRadii.xlAll,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );
  }
}

class _OnlineUserProfileContent extends StatelessWidget {
  const _OnlineUserProfileContent({required this.profile});

  final OnlineUserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final activeMemberships = profile.activeMemberships;
    final chips = activeMemberships.isEmpty
        ? <Widget>[const M3EChip(label: '普通用户', type: M3EChipType.assist)]
        : <Widget>[
            for (final membership in activeMemberships)
              M3EChip(label: membership.label, type: M3EChipType.assist),
          ];
    final bodySmall = theme.typeScale.bodySmall;
    final textScaler = MediaQuery.textScalerOf(context);
    final signatureLineHeight =
        textScaler.scale(bodySmall?.fontSize ?? 12) *
        (bodySmall?.height ?? 1.4);

    return _ProfileSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: chips,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    M3EShapeContainer.cookie12Sided(
                      width: 80,
                      height: 80,
                      child: OnlineCover(url: profile.avatarUrl, size: 80),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      profile.nickname.isEmpty ? '网易云用户' : profile.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typeScale.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: signatureLineHeight * 3,
                      ),
                      child: Text(
                        profile.signature.trim().isEmpty
                            ? ' '
                            : profile.signature,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          M3EButtonGroup(
            type: M3EButtonGroupType.connected,
            shape: M3EButtonShape.round,
            size: M3EButtonSize.sm,
            style: M3EButtonStyle.tonal,
            overflow: M3EButtonGroupOverflow.scroll,
            actions: <M3EButtonGroupAction>[
              M3EButtonGroupAction(
                icon: const Icon(M3EIcons.person),
                label: Text(_compactCount(profile.follows)),
                tooltip: '关注',
                semanticLabel: '${profile.follows} 关注',
              ),
              M3EButtonGroupAction(
                icon: const Icon(M3EIcons.favorite),
                label: Text(_compactCount(profile.followeds)),
                tooltip: '粉丝',
                semanticLabel: '${profile.followeds} 粉丝',
              ),
              M3EButtonGroupAction(
                icon: const Icon(M3EIcons.star),
                label: Text('${profile.level}'),
                tooltip: '等级',
                semanticLabel: '等级 ${profile.level}',
              ),
              M3EButtonGroupAction(
                icon: const Icon(M3EIcons.bar_chart),
                label: Text('${profile.listenHours}'),
                tooltip: '听歌时长',
                semanticLabel: '${profile.listenHours} 小时',
              ),
            ],
            onSelectedIndexChanged: (int? index) {
              if (index == null) return;
              switch (index) {
                case 0:
                  _openPlaceholder(
                    context,
                    title: '关注',
                    message: '${_compactCount(profile.follows)} 位关注用户将在后续接入',
                    icon: M3EIcons.person,
                  );
                case 1:
                  _openPlaceholder(
                    context,
                    title: '粉丝',
                    message: '${_compactCount(profile.followeds)} 位粉丝将在后续接入',
                    icon: M3EIcons.favorite,
                  );
                case 2:
                  _openPlaceholder(
                    context,
                    title: '等级',
                    message: '当前等级 Lv.${profile.level}，详情将在后续接入',
                    icon: M3EIcons.star,
                  );
                case 3:
                  _openPlaceholder(
                    context,
                    title: '听歌时长',
                    message: '累计听歌 ${profile.listenHours} 小时，详情将在后续接入',
                    icon: M3EIcons.bar_chart,
                  );
              }
            },
          ),
        ],
      ),
    );
  }

  static String _compactCount(int value) {
    if (value >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}亿';
    }
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    }
    return '$value';
  }

  static void _openPlaceholder(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
  }) {
    pushMobileRootPage(
      context,
      _LibraryPlaceholderPage(
        title: title,
        message: message,
        icon: icon,
        showLayout: false,
      ),
      name: MobileRoutes.library,
    );
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
        // 页面壳已经应用 16dp page gutter；这里不再叠加横向 margin，
        // 保证列表距屏幕两侧正好是 AppSpacing.lg。
        margin: EdgeInsets.symmetric(
          horizontal: AppSpacing.none,
          vertical: 5.0,
        ),
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
    this.showLayout = true,
  });

  final String title;
  final String message;
  final IconData icon;

  /// 列表类入口显示禁用的布局按钮；已下载这类非列表页隐藏。
  final bool showLayout;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageBar.subpage(
        title: title,
        onSearch: () => openMobileSearch(context),
        showLayout: showLayout,
      ),
      body: AppEmptyState(title: title, message: message, icon: icon),
    );
  }
}
