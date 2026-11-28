import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laetibeat/widgets/settings/cover_shape_settings.dart';
import 'package:laetibeat/widgets/settings/display_settings.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_locale.dart';
import '../../../../design/components/navigation/app_page_bar.dart';
import '../../../../widgets/settings/settings_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../mobile_settings_section.dart';
import 'cover_shape_dialog.dart';

/// 移动端外观设置子页面。
class MobileAppearanceSettingsPage extends ConsumerWidget {
  const MobileAppearanceSettingsPage({super.key});

  Future<void> _pickCoverShape(BuildContext context, WidgetRef ref) async {
    final picked = await showCoverShapeDialog(
      context,
      initial: ref.read(coverShapeProvider),
    );
    if (!context.mounted || picked == null) return;
    await ref.read(coverShapeProvider.notifier).setShape(picked);
  }

  Future<void> _pickSearchCoverShape(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final picked = await showCoverShapeDialog(
      context,
      initial: ref.read(searchCoverShapeProvider),
    );
    if (!context.mounted || picked == null) return;
    await ref.read(searchCoverShapeProvider.notifier).setShape(picked);
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(appLanguageProvider);
    final labels = <String>[
      l10n.languageSystem,
      l10n.languageChinese,
      l10n.languageEnglish,
    ];
    final currentLabel = switch (current) {
      AppLanguage.system => l10n.languageSystem,
      AppLanguage.zh => l10n.languageChinese,
      AppLanguage.en => l10n.languageEnglish,
    };
    final picked = await M3EDialog.showSelectionScreen(
      context,
      title: l10n.languageDialogTitle,
      options: labels,
      initialSelection: <String>[currentLabel],
      icon: const Icon(M3EIcons.translate),
    );
    if (!context.mounted || picked == null || picked.isEmpty) return;
    final index = labels.indexOf(picked.first);
    if (index < 0) return;
    await ref
        .read(appLanguageProvider.notifier)
        .select(AppLanguage.values[index]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);
    final highRefreshRate = ref.watch(highRefreshRateProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final appLanguage = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageBar.settings(
        title: l10n.appearanceTitle,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            M3ECard(
              variant: M3ECardVariant.filled,
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.appThemeTitle, style: theme.typeScale.titleSmall),
                  const SizedBox(height: 12),
                  M3ESegmentedButton<AppThemeMode>(
                    segments: <M3ESegment<AppThemeMode>>[
                      M3ESegment(
                        value: AppThemeMode.light,
                        label: l10n.themeLight,
                      ),
                      M3ESegment(
                        value: AppThemeMode.dark,
                        label: l10n.themeDark,
                      ),
                      M3ESegment(
                        value: AppThemeMode.system,
                        label: l10n.themeSystem,
                      ),
                    ],
                    selected: <AppThemeMode>{themeMode},
                    onSelectionChanged: (values) {
                      if (values.isNotEmpty) {
                        ref
                            .read(appThemeModeProvider.notifier)
                            .select(values.first);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            MobileSettingsSection(
              title: l10n.displayGroup,
              onTap: (int index) {
                switch (index) {
                  case 1:
                    _pickCoverShape(context, ref);
                  case 2:
                    _pickSearchCoverShape(context, ref);
                }
              },
              children: [
                MobileSettingsRow(
                  title: l10n.highRefreshRate,
                  supportingText: l10n.highRefreshRateSupporting,
                  leading: const Icon(M3EIcons.speed),
                  trailing: M3ESwitch(
                    value: highRefreshRate,
                    onChanged: (value) => ref
                        .read(highRefreshRateProvider.notifier)
                        .setEnabled(value),
                  ),
                ),
                MobileSettingsRow(
                  title: l10n.coverShape,
                  supportingText: l10n.coverShapeSupporting,
                  leading: const Icon(M3EIcons.album),
                  trailing: const Icon(M3EIcons.chevron_right),
                ),
                MobileSettingsRow(
                  title: l10n.searchCoverShape,
                  supportingText: l10n.searchCoverShapeSupporting,
                  leading: const Icon(M3EIcons.search),
                  trailing: const Icon(M3EIcons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 24),
            MobileSettingsSection(
              title: l10n.language,
              onTap: (_) => _pickLanguage(context, ref),
              children: [
                MobileSettingsRow(
                  title: l10n.language,
                  supportingText: switch (appLanguage) {
                    AppLanguage.system => l10n.languageSystem,
                    AppLanguage.zh => l10n.languageChinese,
                    AppLanguage.en => l10n.languageEnglish,
                  },
                  leading: const Icon(M3EIcons.translate),
                  trailing: const Icon(M3EIcons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
