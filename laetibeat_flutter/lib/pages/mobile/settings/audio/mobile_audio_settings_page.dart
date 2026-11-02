import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../widgets/settings/equalizer_settings.dart';
import '../../../../widgets/settings/fade_settings.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';

/// 移动端“播放器与音频”设置页。
///
/// 第一版使用 just_audio 的 AndroidEqualizer，显示 5 个常见频段。
class MobileAudioSettingsPage extends ConsumerWidget {
  const MobileAudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(equalizerSettingsProvider);
    final fade = ref.watch(fadeSettingsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileLargeSubpageAppBar(
        context,
        title: l10n.settingsPlaybackAudio,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _AudioGroupTitle(l10n.equalizer),
          const SizedBox(height: 8),
          M3EList(
            color: theme.colorScheme.surface,
            variant: M3ECardVariant.filled,
            itemCount: 1,
            itemBuilder: (BuildContext context, int index) {
              return M3EListItem(
                headline: l10n.equalizerEnabled,
                supportingText: l10n.equalizerSupporting,
                trailing: M3ESwitch(
                  value: settings.enabled,
                  onChanged: (value) => ref
                      .read(equalizerSettingsProvider.notifier)
                      .setEnabled(value),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 16),
              child: Column(
                children: [
                  SizedBox(
                    height: 228,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < kEqualizerFrequencies.length; i++)
                          Expanded(
                            child: _EqualizerBandSlider(
                              frequency: kEqualizerFrequencies[i],
                              gain: settings.gains[i],
                              enabled: settings.enabled,
                              onChanged: (value) => ref
                                  .read(equalizerSettingsProvider.notifier)
                                  .setBandGain(i, value),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  M3EButton(
                    label: Text(l10n.equalizerReset),
                    style: M3EButtonStyle.tonal,
                    size: M3EButtonSize.sm,
                    shape: M3EButtonShape.round,
                    onPressed: settings.enabled
                        ? () => ref
                              .read(equalizerSettingsProvider.notifier)
                              .reset()
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _AudioGroupTitle(l10n.fadeInOut),
          const SizedBox(height: 8),
          M3EList(
            color: theme.colorScheme.surface,
            variant: M3ECardVariant.filled,
            itemCount: 1,
            itemBuilder: (BuildContext context, int index) {
              return M3EListItem(
                headline: l10n.fadeInOut,
                supportingText: l10n.fadeInOutSupporting,
                trailing: M3ESwitch(
                  value: fade.enabled,
                  onChanged: (value) =>
                      ref.read(fadeSettingsProvider.notifier).setEnabled(value),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                children: [
                  _FadeSlider(
                    label: l10n.fadeIn,
                    seconds: fade.fadeInSeconds,
                    enabled: fade.enabled,
                    onChanged: (value) => ref
                        .read(fadeSettingsProvider.notifier)
                        .setFadeInSeconds(value),
                  ),
                  _FadeSlider(
                    label: l10n.fadeOut,
                    seconds: fade.fadeOutSeconds,
                    enabled: fade.enabled,
                    onChanged: (value) => ref
                        .read(fadeSettingsProvider.notifier)
                        .setFadeOutSeconds(value),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EqualizerBandSlider extends StatelessWidget {
  const _EqualizerBandSlider({
    required this.frequency,
    required this.gain,
    required this.enabled,
    required this.onChanged,
  });

  final double frequency;
  final double gain;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Text(
          _formatGain(gain),
          style: theme.typeScale.labelSmall.copyWith(
            color: enabled ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: M3ESlider.verticalCentered(
            value: gain,
            min: kEqualizerMinGain,
            max: kEqualizerMaxGain,
            divisions: 24,
            size: M3ESliderSize.s,
            enabled: enabled,
            haptic: M3EHapticFeedback.light,
            onChanged: enabled ? onChanged : null,
            semanticLabel: '$frequency Hz',
            semanticFormatterCallback: (value) => '${_formatGain(value)} dB',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatFrequency(frequency),
          style: theme.typeScale.labelSmall.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static String _formatGain(double value) {
    final rounded = value.toStringAsFixed(0);
    return value > 0 ? '+$rounded' : rounded;
  }

  static String _formatFrequency(double value) {
    if (value >= 1000) {
      final k = value / 1000;
      return '${k.toStringAsFixed(k == k.roundToDouble() ? 0 : 1)}k';
    }
    return '${value.round()}';
  }
}

class _FadeSlider extends StatelessWidget {
  const _FadeSlider({
    required this.label,
    required this.seconds,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double seconds;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.typeScale.titleSmall.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${seconds.toStringAsFixed(1)} s',
                style: theme.typeScale.labelMedium.copyWith(
                  color: enabled ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          M3ESlider(
            value: seconds,
            min: 0,
            max: kFadeMaxSeconds,
            divisions: 20,
            size: M3ESliderSize.s,
            enabled: enabled,
            haptic: M3EHapticFeedback.light,
            onChanged: enabled ? onChanged : null,
            semanticLabel: label,
            semanticFormatterCallback: (value) =>
                '${value.toStringAsFixed(1)} s',
          ),
        ],
      ),
    );
  }
}

class _AudioGroupTitle extends StatelessWidget {
  const _AudioGroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16),
      child: Text(
        text,
        style: theme.typeScale.titleSmall.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
