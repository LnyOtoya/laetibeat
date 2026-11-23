import 'package:flutter_localizations/flutter_localizations.dart'
    as flutter_l10n;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../design/design.dart';
import '../l10n/generated/app_localizations.dart';
import '../pages/desktop/desktop_app.dart';
import '../pages/mobile/mobile_app.dart';
import '../pages/mobile/mobile_navigation.dart';
import '../widgets/integration/media_integration_host.dart';
import '../widgets/player/player_error_listener.dart';
import '../widgets/settings/settings_provider.dart';
import 'app_form_factor.dart';
import 'app_locale.dart';

/// 应用根节点：只负责形态选择、主题装配与全局宿主。
class LaetibeatApp extends ConsumerWidget {
  const LaetibeatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formFactor = ref.watch(appFormFactorProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final language = ref.watch(appLanguageProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Laetibeat',
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: localeFor(language),
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
        // Some pages still use widgets from Flutter's material library.
        flutter_l10n.GlobalMaterialLocalizations.delegate,
        flutter_l10n.GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColorTokens.brandSeed,
        fontFamily: 'Google Sans Flex',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColorTokens.brandSeed,
        brightness: Brightness.dark,
        fontFamily: 'Google Sans Flex',
      ),
      themeMode: switch (themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      navigatorKey: formFactor == AppFormFactor.mobile
          ? mobileRootNavigatorKey
          : null,
      builder: (BuildContext context, Widget? child) {
        final content = child ?? const SizedBox.shrink();

        // Resolve the Material You palette once and project it onto both the
        // expressive theme and material_ui's Theme for the whole navigator.
        return MaterialYouThemeHost(
          density: formFactor == AppFormFactor.desktop
              ? AppThemeDensity.regular
              : AppThemeDensity.compact,
          child: PlayerErrorListener(
            child: MediaIntegrationHost(child: content),
          ),
        );
      },
      home: switch (formFactor) {
        AppFormFactor.desktop => const DesktopApp(),
        AppFormFactor.mobile => const MobileShellPage(),
      },
    );
  }
}
