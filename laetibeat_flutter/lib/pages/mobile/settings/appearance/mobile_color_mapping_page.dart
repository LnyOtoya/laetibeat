import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

/// Developer-facing overview of every color role currently resolved by the
/// active Material You scheme.
///
/// The page intentionally uses a pure white background so the swatches and
/// raw ARGB values can be inspected without the app surface tint affecting
/// perception.
class MobileColorMappingPage extends StatelessWidget {
  const MobileColorMappingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = M3ETheme.of(context).colorScheme;
    final groups = _groups(scheme);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: M3EAppBar.top(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        variant: M3EAppBarVariant.small,
        density: M3EAppBarDensity.compact,
        shapeFamily: M3EAppBarShapeFamily.square,
        safeArea: true,
        automaticallyImplyLeading: true,
        titleText: '当前取色映射',
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'Brightness: ${scheme.brightness.name}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            for (final group in groups) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  group.title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final entry in group.entries) _ColorRow(entry: entry),
            ],
          ],
        ),
      ),
    );
  }

  static List<_ColorGroup> _groups(M3EColorScheme scheme) {
    return <_ColorGroup>[
      _ColorGroup('Primary', <_ColorEntry>[
        _ColorEntry('primary', scheme.primary),
        _ColorEntry('onPrimary', scheme.onPrimary),
        _ColorEntry('primaryContainer', scheme.primaryContainer),
        _ColorEntry('onPrimaryContainer', scheme.onPrimaryContainer),
      ]),
      _ColorGroup('Secondary', <_ColorEntry>[
        _ColorEntry('secondary', scheme.secondary),
        _ColorEntry('onSecondary', scheme.onSecondary),
        _ColorEntry('secondaryContainer', scheme.secondaryContainer),
        _ColorEntry('onSecondaryContainer', scheme.onSecondaryContainer),
      ]),
      _ColorGroup('Tertiary', <_ColorEntry>[
        _ColorEntry('tertiary', scheme.tertiary),
        _ColorEntry('onTertiary', scheme.onTertiary),
        _ColorEntry('tertiaryContainer', scheme.tertiaryContainer),
        _ColorEntry('onTertiaryContainer', scheme.onTertiaryContainer),
      ]),
      _ColorGroup('Error', <_ColorEntry>[
        _ColorEntry('error', scheme.error),
        _ColorEntry('onError', scheme.onError),
        _ColorEntry('errorContainer', scheme.errorContainer),
        _ColorEntry('onErrorContainer', scheme.onErrorContainer),
      ]),
      _ColorGroup('Surface', <_ColorEntry>[
        _ColorEntry('surface', scheme.surface),
        _ColorEntry('onSurface', scheme.onSurface),
        _ColorEntry('onSurfaceVariant', scheme.onSurfaceVariant),
        _ColorEntry('surfaceContainerLowest', scheme.surfaceContainerLowest),
        _ColorEntry('surfaceContainerLow', scheme.surfaceContainerLow),
        _ColorEntry('surfaceContainer', scheme.surfaceContainer),
        _ColorEntry('surfaceContainerHigh', scheme.surfaceContainerHigh),
        _ColorEntry('surfaceContainerHighest', scheme.surfaceContainerHighest),
        _ColorEntry('surfaceDim', scheme.surfaceDim),
        _ColorEntry('surfaceBright', scheme.surfaceBright),
      ]),
      _ColorGroup('Inverse', <_ColorEntry>[
        _ColorEntry('inverseSurface', scheme.inverseSurface),
        _ColorEntry('onInverseSurface', scheme.onInverseSurface),
        _ColorEntry('inversePrimary', scheme.inversePrimary),
      ]),
      _ColorGroup('Outline / System', <_ColorEntry>[
        _ColorEntry('outline', scheme.outline),
        _ColorEntry('outlineVariant', scheme.outlineVariant),
        _ColorEntry('shadow', scheme.shadow),
        _ColorEntry('scrim', scheme.scrim),
        _ColorEntry('surfaceTint', scheme.surfaceTint),
      ]),
      _ColorGroup('Expressive / Semantic', <_ColorEntry>[
        _ColorEntry('emphasis', scheme.emphasis),
        _ColorEntry('onEmphasis', scheme.onEmphasis),
        _ColorEntry('info', scheme.info),
        _ColorEntry('success', scheme.success),
        _ColorEntry('warning', scheme.warning),
        _ColorEntry('danger', scheme.danger),
        _ColorEntry('surfaceStrong', scheme.surfaceStrong),
        _ColorEntry('onSurfaceStrong', scheme.onSurfaceStrong),
        _ColorEntry('outlineStrong', scheme.outlineStrong),
      ]),
    ];
  }
}

class _ColorGroup {
  const _ColorGroup(this.title, this.entries);

  final String title;
  final List<_ColorEntry> entries;
}

class _ColorEntry {
  const _ColorEntry(this.name, this.color);

  final String name;
  final Color color;

  String get hex {
    final argb = color
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();
    return '#$argb';
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.entry});

  final _ColorEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: entry.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.hex,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
