import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart' as m3e_core;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';

import '../mobile_navigation.dart';
import '../routes.dart';
import '../widgets/mobile_search_bar.dart';
import 'about/mobile_about_settings_page.dart';
import 'appearance/mobile_appearance_settings_page.dart';
import 'audio/mobile_audio_settings_page.dart';
import 'content/mobile_content_settings_page.dart';
import 'storage/mobile_storage_settings_page.dart';

/// 移动端设置页面。
///
/// 顶部使用与 Search 页同款的搜索栏，不显示 AppBar。
/// 设置入口使用 M3E expressive segmented column，只保留 headline / supporting。
class MobileSettingsPage extends ConsumerWidget {
  const MobileSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: MobileSearchBar(
                hintText: l10n.settingsSearchHint,
                variant: MobileSearchBarVariant.outlined,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                children: [
                  m3e_core.M3ESegmentedColumn(
                    decoration: const m3e_core.M3ESegmentedListDecoration(
                      outerRadius: 24.0,
                      innerRadius: 4.0,
                      pressedRadius: 8.0,
                      pressedScale: 0.98,
                      hoveredRadius: 16.0,
                      gap: 2.0,
                      padding: EdgeInsets.all(12.0),
                      margin: EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 4.0,
                      ),
                    ),
                    onTap: (int index) => _openSettings(context, index),
                    children: [
                      m3e_core.M3EListItem(
                        headline: Text(l10n.settingsAppearance),
                        supportingText: Text(l10n.settingsAppearanceSupporting),
                        leading: _SettingsLeadingAvatar(icon: M3EIcons.palette),
                      ),
                      m3e_core.M3EListItem(
                        headline: Text(l10n.settingsPlaybackAudio),
                        supportingText: Text(
                          l10n.settingsPlaybackAudioSupporting,
                        ),
                        leading: _SettingsLeadingAvatar(
                          icon: M3EIcons.graphic_eq,
                        ),
                      ),
                      m3e_core.M3EListItem(
                        headline: Text(l10n.settingsContent),
                        supportingText: Text(l10n.settingsContentSupporting),
                        leading: _SettingsLeadingAvatar(
                          icon: M3EIcons.library_music,
                        ),
                      ),
                      m3e_core.M3EListItem(
                        headline: Text(l10n.settingsStorage),
                        supportingText: Text(l10n.settingsStorageSupporting),
                        leading: _SettingsLeadingAvatar(icon: M3EIcons.storage),
                      ),
                      m3e_core.M3EListItem(
                        headline: Text(l10n.settingsBackupRestore),
                        supportingText: Text(
                          l10n.settingsBackupRestoreSupporting,
                        ),
                        leading: _SettingsLeadingAvatar(
                          icon: M3EIcons.settings_backup_restore,
                        ),
                      ),
                      m3e_core.M3EListItem(
                        headline: Text(l10n.settingsAbout),
                        supportingText: Text(l10n.settingsAboutSupporting),
                        leading: _SettingsLeadingAvatar(icon: M3EIcons.info),
                      ),
                    ],
                  ),
                ],
              ),
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
