import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

class TwoPaneLayout extends StatelessWidget {
  // leftFlex/rightFlex控制左右占比,默认1:1等分
  const TwoPaneLayout({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: leftFlex,
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
          flex: rightFlex,
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