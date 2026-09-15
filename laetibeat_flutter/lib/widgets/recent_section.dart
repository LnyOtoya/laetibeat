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

    return Row(
      children: [
        // 三个独立AnimatedContainer,等分横向排列,区块间用spacing.md分隔
        _pane(theme),
        SizedBox(width: theme.spacing.md),
        _pane(theme),
        SizedBox(width: theme.spacing.md),
        _pane(theme),
      ],
    );
  }

  // 单个内容区域
  Widget _pane(M3EThemeData theme) {
    return Expanded(
      flex: 1,
      child: AnimatedContainer(
        height: 300,
        duration: kSectionAnimDuration,
        curve: kSectionAnimCurve,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: M3EDimensions.borderRadiusLarge,
        ),
      ),
    );
  }
}
