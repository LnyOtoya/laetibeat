import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

class MobileSettingsSection extends StatelessWidget {
  const MobileSettingsSection({
    super.key,
    this.title,
    required this.children,
    this.onTap,
    this.selectedIndices,
    this.onSelectionChanged,
    this.selectionMode = m3e_core.M3ESelectionMode.none,
    this.showSelectionCheckmark = false,
    this.isEnabled,
  });

  final String? title;
  final List<Widget> children;
  final ValueChanged<int>? onTap;
  final Set<int>? selectedIndices;
  final ValueChanged<Set<int>>? onSelectionChanged;
  final m3e_core.M3ESelectionMode selectionMode;
  final bool showSelectionCheckmark;
  final bool Function(int index)? isEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final heading = title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heading != null) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16),
            child: Text(
              heading,
              style: theme.typeScale.titleSmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        m3e_core.M3ESegmentedColumn(
          decoration: const m3e_core.M3ESegmentedListDecoration(
            outerRadius: 24,
            innerRadius: 4,
            gap: 2,
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            pressedRadius: 8,
            pressedScale: 0.985,
            hoveredRadius: 16,
            motion: m3e_core.M3EMotion.standardSpatialDefault,
            pressedMotion: m3e_core.M3EMotion.expressiveSpatialFast,
          ),
          color: theme.colorScheme.surfaceContainer,
          onTap: onTap,
          selectedIndices: selectedIndices,
          onSelectionChanged: onSelectionChanged,
          selectionMode: selectionMode,
          showSelectionCheckmark: showSelectionCheckmark,
          isEnabled: isEnabled,
          children: children,
        ),
      ],
    );
  }
}

class MobileSettingsRow extends StatelessWidget {
  const MobileSettingsRow({
    super.key,
    required this.title,
    this.supportingText,
    this.leading,
    this.trailing,
    this.enabled = true,
  });

  final String title;
  final String? supportingText;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return m3e_core.M3EListItem(
      headline: Text(title),
      supportingText: supportingText == null ? null : Text(supportingText!),
      leading: leading,
      trailing: trailing,
      enabled: enabled,
    );
  }
}
