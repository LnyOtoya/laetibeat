import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../animations.dart';

class DailySection extends StatefulWidget {
  const DailySection({super.key});

  @override
  State<DailySection> createState() => _DailySectionState();
}

class _DailySectionState extends State<DailySection> {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      height: 180,
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      decoration: BoxDecoration(
        color: M3ETheme.of(context).colorScheme.surface,
        borderRadius: M3EDimensions.borderRadiusMedium,
      ),
    );
  }
}