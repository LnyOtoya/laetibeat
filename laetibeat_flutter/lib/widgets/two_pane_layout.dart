import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

class TwoPaneLayout extends StatelessWidget {
  const TwoPaneLayout({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              theme.spacing.md,
              0,
              theme.spacing.sm,
              theme.spacing.md,
            ),
            child: left,
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              theme.spacing.sm,
              0,
              theme.spacing.md,
              theme.spacing.md,
            ),
            child: right,
          ),
        ),
      ],
    );
  }
}