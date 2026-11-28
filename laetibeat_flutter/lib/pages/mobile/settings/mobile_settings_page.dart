import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/components/navigation/app_page_bar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../mobile_navigation.dart';
import '../routes.dart';
import 'about/mobile_about_settings_page.dart';
import 'appearance/mobile_appearance_settings_page.dart';
import 'audio/mobile_audio_settings_page.dart';
import 'content/mobile_content_settings_page.dart';
import 'mobile_settings_section.dart';
import 'sources/mobile_source_settings_page.dart';
import 'storage/mobile_storage_settings_page.dart';

/// 移动端设置页面。
class MobileSettingsPage extends ConsumerWidget {
  const MobileSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageBar.settings(
        title: l10n.settingsTitle,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            MobileSettingsSection(
              onTap: (index) => _openSettings(context, index),
              children: [
                MobileSettingsRow(
                  title: l10n.settingsAppearance,
                  supportingText: l10n.settingsAppearanceSupporting,
                  leading: _SettingsLeadingAvatar(icon: M3EIcons.palette),
                ),
                MobileSettingsRow(
                  title: l10n.settingsPlaybackAudio,
                  supportingText: l10n.settingsPlaybackAudioSupporting,
                  leading: _SettingsLeadingAvatar(icon: M3EIcons.graphic_eq),
                ),
                MobileSettingsRow(
                  title: l10n.settingsContent,
                  supportingText: l10n.settingsContentSupporting,
                  leading: _SettingsLeadingAvatar(
                    icon: M3EIcons.library_music,
                  ),
                ),
                MobileSettingsRow(
                  title: l10n.settingsSourcesAccounts,
                  supportingText: l10n.settingsSourcesAccountsSupporting,
                  leading: _SettingsLeadingAvatar(icon: M3EIcons.cloud),
                ),
                MobileSettingsRow(
                  title: l10n.settingsStorage,
                  supportingText: l10n.settingsStorageSupporting,
                  leading: _SettingsLeadingAvatar(icon: M3EIcons.storage),
                ),
                MobileSettingsRow(
                  title: l10n.settingsAbout,
                  supportingText: l10n.settingsAboutSupporting,
                  leading: _SettingsLeadingAvatar(icon: M3EIcons.info),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openSettings(BuildContext context, int index) {
    switch (index) {
      case 0:
        pushMobileRootPage(
          context,
          const MobileAppearanceSettingsPage(),
          name: MobileRoutes.appearanceSettings,
        );
      case 1:
        pushMobileRootPage(
          context,
          const MobileAudioSettingsPage(),
          name: MobileRoutes.audioSettings,
        );
      case 2:
        pushMobileRootPage(
          context,
          const MobileContentSettingsPage(),
          name: MobileRoutes.contentSettings,
        );
      case 3:
        pushMobileRootPage(
          context,
          const MobileSourceSettingsPage(),
          name: MobileRoutes.sourceSettings,
        );
      case 4:
        pushMobileRootPage(
          context,
          const MobileStorageSettingsPage(),
          name: MobileRoutes.storageSettings,
        );
      case 5:
        pushMobileRootPage(
          context,
          const MobileAboutSettingsPage(),
          name: MobileRoutes.aboutSettings,
        );
      default:
        break;
    }
  }
}

class _SettingsLeadingAvatar extends StatelessWidget {
  const _SettingsLeadingAvatar({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);

    return SizedBox.square(
      dimension: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
