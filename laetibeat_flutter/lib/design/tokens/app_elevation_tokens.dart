import 'package:flutter/widgets.dart';

/// Elevation tokens.
///
/// Prefer surface roles and spacing for routine hierarchy. Use elevation only
/// when physical separation or overlap must be communicated.
abstract final class AppElevation {
  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 3;
  static const double level3 = 6;
  static const double level4 = 8;

  static const List<BoxShadow> shadowLevel0 = <BoxShadow>[];

  static const List<BoxShadow> shadowLevel1 = <BoxShadow>[
    BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> shadowLevel2 = <BoxShadow>[
    BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> shadowLevel3 = <BoxShadow>[
    BoxShadow(color: Color(0x29000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
}
