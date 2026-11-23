import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/design.dart';
import '../../../src/rust/api/simple.dart' as rust;
import '../../../widgets/player/cover_provider.dart';
import '../../../widgets/player/player_provider.dart';

/// Mobile Home content.
///
/// The first section is a contained horizontal carousel for "继续听".
/// The section title lives inside each carousel card, above the song name.
/// Remaining Home sections will be added in later passes.
class MobileHomeContent extends ConsumerWidget {
  const MobileHomeContent({super.key});

  static const String _itemTitle = '继续听';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final player = ref.watch(
      playerProvider.select((state) => (state.queue, state.currentIndex)),
    );
    final List<rust.UiTrack> queue = player.$1;

    return ListView(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.xxl,
      ),
      children: <Widget>[
        if (queue.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: AppEmptyState(
              title: '还没有继续播放的歌曲',
              message: '播放一首歌后，会出现在这里',
              icon: M3EIcons.music_note,
            ),
          )
        else
          SizedBox(
            height: 228,
            child: _ContinueListeningCarousel(
              queue: queue,
              currentIndex: player.$2.clamp(0, queue.length - 1),
              titleStyle: theme.typeScale.titleSmall.copyWith(
                color: Colors.white,
              ),
              subtitleStyle: theme.typeScale.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
              onTrackSelected: (int index) {
                ref.read(playerProvider.notifier).play(index);
              },
            ),
          ),
      ],
    );
  }
}

class _ContinueListeningCarousel extends StatelessWidget {
  const _ContinueListeningCarousel({
    required this.queue,
    required this.currentIndex,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.onTrackSelected,
  });

  final List<rust.UiTrack> queue;
  final int currentIndex;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final ValueChanged<int> onTrackSelected;

  @override
  Widget build(BuildContext context) {
    final List<int> indices = <int>[
      for (var offset = 0; offset < queue.length; offset++)
        (currentIndex + offset) % queue.length,
    ];

    return M3ECarousel(
      type: M3ECarouselType.contained,
      axis: Axis.horizontal,
      height: 228,
      childElementBorderRadius: AppRadii.xl,
      haptic: M3EHapticFeedback.light,
      children: <M3ECarouselItem>[
        for (var position = 0; position < indices.length; position++)
          M3ECarouselItem(
            image: _TrackCover(track: queue[indices[position]]),
            // Only the focal card gets the section title. M3E normally hides
            // the title on non-large slots, so keep the fixed text visible.
            applyDynamicTextContentTransform: false,
            title: position == 0
                ? Text(MobileHomeContent._itemTitle, style: titleStyle)
                : null,
            subtitle: Text(
              queue[indices[position]].title,
              style: subtitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            showScrim: const M3ECarouselScrim.gradient(),
            semanticLabel: queue[indices[position]].title,
            onTap: () => onTrackSelected(indices[position]),
          ),
      ],
    );
  }
}

class _TrackCover extends ConsumerWidget {
  const _TrackCover({required this.track});

  final rust.UiTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(trackCoverProvider(track)).value;
    final scheme = M3ETheme.of(context).colorScheme;

    if (bytes == null || bytes.isEmpty) {
      return ColoredBox(
        color: scheme.secondaryContainer,
        child: Center(
          child: Icon(
            M3EIcons.music_note,
            size: AppIconSize.xl,
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
