/// Typography tokens shared by every page.
///
/// The actual Material 3 type scale lives in `M3ETypography`; this file only
/// centralises the font-family decisions and the semantic role vocabulary.
abstract final class AppTypography {
  /// Primary variable font used by the app.
  static const String fontFamily = 'Google Sans Flex';

  /// Fallback stack for CJK content.
  static const List<String> fontFamilyFallback = <String>[
    'Noto Sans SC',
    'Noto Sans TC',
    'Noto Sans JP',
    'Noto Sans KR',
  ];

  /// Minimum readable metadata size. Do not go below this for body/label text.
  static const double minMetadataSize = 11;
}
