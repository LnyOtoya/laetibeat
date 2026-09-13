import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../animations.dart';

class RecentSection extends StatefulWidget {
  const RecentSection({super.key});

  @override
  State<RecentSection> createState() => _RecentSectionState();
}

class _RecentSectionState extends State<RecentSection> {
  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return AnimatedContainer(
      height: 300,
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: M3EDimensions.borderRadiusMedium,
      ),
      padding: EdgeInsets.all(theme.spacing.xl),
      child: M3ECarouselWrapper(
        freeScroll: true,
        itemSnapping: true,
        consumeMaxWeight: false,
        infinite: true,
        flexWeights: const <int>[2, 6, 2],
        backgroundColor: theme.colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        children: const <Widget>[
          SizedBox.expand(),
          SizedBox.expand(),
          SizedBox.expand(),
          SizedBox.expand(),
          SizedBox.expand(),
          SizedBox.expand(),
        ],
      ),
    );
  }
}
