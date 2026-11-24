import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../src/rust/api/simple.dart' as rust;
import '../../../widgets/player/cover_provider.dart';
import '../../../widgets/player/player_provider.dart';
import '../../../widgets/recommendation_provider.dart';
import '../widgets/mobile_large_subpage_app_bar.dart';

/// 「为你发现」的完整歌曲列表。
class DiscoveryPage extends ConsumerWidget {
  const DiscoveryPage({super.key, required this.result});

  final DiscoveryResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final pageGutter = AppLayout.gutterFor(MediaQuery.sizeOf(context).width);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: mobileLargeSubpageAppBar(context, title: '为你发现'),
      body: ListView(
        padding: const EdgeInsets.only(
          top: AppSpacing.lg,
          bottom: AppSpacing.xxl,
        ),
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pageGutter),
            child: Row(
              children: <Widget>[
                SizedBox.square(
                  dimension: 72,
                  child: ClipRRect(
                    borderRadius: AppRadii.mdAll,
                    child: _DiscoveryArtistCover(artist: result.artist),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        result.artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typeScale.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '根据最近聆听的歌手为你推荐',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typeScale.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pageGutter),
            child: const AppSectionHeader(
              title: '相似歌曲',
              padding: AppInsets.sectionHeader,
            ),
          ),
          m3e_core.M3ESegmentedList.builder(
            itemCount: result.tracks.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            listPadding: EdgeInsets.zero,
            onTap: (int index) {
              ref
                  .read(playerProvider.notifier)
                  .load(result.tracks, index, source: '为你发现');
            },
            decoration: const m3e_core.M3ESegmentedListDecoration(
              outerRadius: 24,
              innerRadius: 16,
              pressedRadius: 8,
              pressedScale: 0.98,
              hoveredRadius: 16,
              selectedRadius: 28,
              gap: 6,
              padding: EdgeInsets.all(4),
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            ),
            itemBuilder: (BuildContext context, int index) {
              final track = result.tracks[index];
              return m3e_core.M3EListItem(
                headline: Text(track.title),
                supportingText: Text(track.artist),
                leading: _DiscoveryTrackCover(track: track),
                trailing: M3EIconButton(
                  variant: M3EIconButtonVariant.standard,
                  size: M3EIconButtonSize.sm,
                  icon: const Icon(M3EIcons.favorite_border),
                  semanticLabel: l10n.addToFavorites,
                  onPressed: () {},
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DiscoveryArtistCover extends ConsumerWidget {
  const _DiscoveryArtistCover({required this.artist});

  final DiscoveryArtist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final bytes = ref
        .watch(
          remoteCoverProvider((
            sourceId: artist.sourceId,
            coverId: artist.coverId,
          )),
        )
        .value;

    if (bytes == null || bytes.isEmpty) {
      return ColoredBox(
        color: scheme.secondaryContainer,
        child: Center(
          child: Icon(
            M3EIcons.person,
            size: AppIconSize.lg,
            color: scheme.onSecondaryContainer,
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }
}

class _DiscoveryTrackCover extends ConsumerWidget {
  const _DiscoveryTrackCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = M3ETheme.of(context).colorScheme;
    final bytes = ref.watch(trackCoverProvider(track)).value;

    return ClipRRect(
      borderRadius: AppRadii.xsAll,
      child: SizedBox.square(
        dimension: 40,
        child: bytes == null || bytes.isEmpty
            ? ColoredBox(
                color: scheme.secondaryContainer,
                child: Icon(
                  M3EIcons.music_note,
                  size: AppIconSize.sm,
                  color: scheme.onSecondaryContainer,
                ),
              )
            : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }
}
