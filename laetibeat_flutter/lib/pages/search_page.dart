import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../animations.dart';
import '../widgets/two_pane_layout.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  @override
  Widget build(BuildContext context) {
    return TwoPaneLayout(
      left: _pane(context),
      right: _pane(context),
    );
  }

  Widget _pane(BuildContext context) {
    final theme = M3ETheme.of(context);
    return AnimatedContainer(
      duration: kSectionAnimDuration,
      curve: kSectionAnimCurve,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: M3EDimensions.borderRadiusMedium,
      ),
    );
  }
}