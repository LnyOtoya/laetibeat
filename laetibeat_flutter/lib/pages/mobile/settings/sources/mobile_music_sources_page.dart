import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../mobile_navigation.dart';
import '../../routes.dart';
import '../../widgets/mobile_large_subpage_app_bar.dart';
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
      backgroundColor: theme.colorScheme.surfaceContainer,
      appBar: mobileLargeSubpageAppBar(
        context,
        title: l10n.musicSourcesTitle,
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            M3EList(
              color: theme.colorScheme.surface,
              variant: M3ECardVariant.filled,
              onTap: (int index) {
                if (index == 0) {
                  pushMobileRootPage(
                    context,
                    const MobileOpensubsonicConfigPage(),
                    name: MobileRoutes.opensubsonicConfig,
                  );
                } else if (index == 3) {
                  pushMobileRootPage(
                    context,
                    const MobileLxSourcesPage(),
                    name: MobileRoutes.lxSources,
                  );
                }
              },
              itemCount: 4,
              itemBuilder: (BuildContext context, int index) {
                return switch (index) {
                  0 => M3EListItem(
                    headline: 'Opensubsonic',
                    supportingText: l10n.openSubsonicDescription,
                  ),
                  1 => M3EListItem(
                    headline: l10n.sourceJellyfin,
                    supportingText: l10n.notAvailable,
                  ),
                  2 => M3EListItem(
                    headline: l10n.sourceEmbyMusic,
                    supportingText: l10n.notAvailable,
                  ),
                  _ => M3EListItem(
                    headline: l10n.sourceLxMusic,
                    supportingText: l10n.lxSourcesSupporting,
                  ),
                };
              },
            ),
          ],
        ),
      ),
    );
  }
}
