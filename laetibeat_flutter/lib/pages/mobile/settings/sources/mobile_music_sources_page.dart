import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../design/components/navigation/app_page_bar.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../mobile_settings_section.dart';
import 'lx/mobile_lx_sources_page.dart';
import 'opensubsonic/mobile_opensubsonic_config_page.dart';

/// 音乐源配置页面。
class MobileMusicSourcesPage extends StatelessWidget {
  const MobileMusicSourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = M3ETheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageBar.settings(
        title: l10n.musicSourcesTitle,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            MobileSettingsSection(
              title: '已接入音源',
              onTap: (int index) {
                if (index == 0) {
                  pushMobileRootPage(
                    context,
                    const MobileOpensubsonicConfigPage(),
                    name: MobileRoutes.opensubsonicConfig,
                  );
                } else if (index == 1) {
                  pushMobileRootPage(
                    context,
                    const MobileLxSourcesPage(),
                    name: MobileRoutes.lxSources,
                  );
                }
              },
              children: [
                MobileSettingsRow(
                  title: 'OpenSubsonic',
                  supportingText: l10n.openSubsonicDescription,
                  leading: const Icon(M3EIcons.cloud),
                  trailing: const Icon(M3EIcons.chevron_right),
                ),
                MobileSettingsRow(
                  title: l10n.sourceLxMusic,
                  supportingText: l10n.lxSourcesSupporting,
                  leading: const Icon(M3EIcons.extension),
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
