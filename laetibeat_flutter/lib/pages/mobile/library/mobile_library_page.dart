import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:laetibeat/shared/layout/app_bottom_inset.dart';
import 'package:laetibeat/widgets/settings/song_source_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import 'mobile_library_subpages.dart';

/// 媒体库首页。
///
/// 只做内容入口，不再直接展示歌曲/专辑/艺术家列表。具体内容页保留原有
/// 布局，后续在各自页面内接入来源筛选。
class MobileLibraryPage extends StatelessWidget {
  const MobileLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final bottomInset = AppBottomInsetScope.bottomInsetOf(context);

    final librarySegments = <_LibrarySegment>[
      _LibrarySegment(
        icon: M3EIcons.library_music,
        title: '曲库',
        routeName: MobileRoutes.librarySongs,
        page: const MobileLibrarySongsPage(),
      ),
      _LibrarySegment(
        icon: M3EIcons.album,
        title: '专辑',
        routeName: MobileRoutes.libraryAlbums,
        page: const MobileLibraryAlbumsPage(),
      ),
      _LibrarySegment(
        icon: M3EIcons.person,
        title: '艺术家',
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
        icon: M3EIcons.radio,
        title: '电台',
        routeName: MobileRoutes.libraryPodcasts,
      ),
    ];

    void openSegment(_LibrarySegment segment) {
      final page = segment.page;
      if (page == null) return;
      pushMobileRootPage(context, page, name: segment.routeName);
    }

    Widget buildSection(String title, Key key) {
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
            segments: librarySegments,
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
        actions: const <Widget>[_LibrarySourceSplitButton()],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.lg + bottomInset,
        ),
        children: <Widget>[
          buildSection('本地音乐', const ValueKey<String>('library_group_local')),
          const SizedBox(height: AppSpacing.xl),
          buildSection('在线音乐', const ValueKey<String>('library_group_online')),
        ],
      ),
    );
  }
}

class _LibrarySourceSplitButton extends ConsumerWidget {
  const _LibrarySourceSplitButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(defaultSongSourceProvider);

    return m3e_core.M3ESplitButton<String>(
      style: m3e_core.M3EButtonStyle.tonal,
      size: m3e_core.M3EButtonSize.md,
      shape: m3e_core.M3EButtonShape.round,
      label: _labelForSongSource(source),
      selectedValue: source,
      leadingTooltip: '当前来源',
      trailingTooltip: '选择来源',
      decoration: m3e_core.M3ESplitButtonDecoration.styleFrom(),
      items: <m3e_core.M3ESplitButtonItem<String>>[
        for (final value in SongSources.all)
          m3e_core.M3ESplitButtonItem<String>(
            value: value,
            child: Text(_labelForSongSource(value)),
          ),
      ],
      onPressed: () {},
      onSelected: (String value) {
        ref.read(defaultSongSourceProvider.notifier).setSource(value);
      },
    );
  }
}

String _labelForSongSource(String source) {
  return switch (source) {
    SongSources.local => '本地',
    SongSources.subsonic => 'Navidrome',
    SongSources.lx => '洛雪',
    _ => '全部',
  };
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
