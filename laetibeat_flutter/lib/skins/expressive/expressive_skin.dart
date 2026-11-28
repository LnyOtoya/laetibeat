import 'package:flutter_localizations/flutter_localizations.dart'
    as flutter_l10n;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_form_factor.dart';
import '../../app/app_locale.dart';
import '../../app/skin/app_skin.dart';
import '../../design/design.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../pages/desktop/desktop_app.dart';
import '../../pages/mobile/mobile_app.dart';
import '../../pages/mobile/mobile_navigation.dart';
import '../../widgets/player/player_error_listener.dart';
import '../../widgets/settings/settings_provider.dart';

/// 当前默认主题：Material 3 Expressive。
///
/// 这个皮肤拥有自己的 MaterialApp、主题宿主、移动/桌面 Shell 和页面。
/// 后续 Spotify / Apple Music 皮肤应各自拥有独立实现，而不是修改这里。
class ExpressiveSkin implements AppSkin {
  const ExpressiveSkin();

  @override
  AppSkinId get id => AppSkinId.expressive;

  @override
  Widget buildRoot(BuildContext context, WidgetRef ref) {
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
      navigatorObservers: formFactor == AppFormFactor.mobile
          ? <NavigatorObserver>[mobileNavigatorObserver]
          : const <NavigatorObserver>[],
      onGenerateRoute: formFactor == AppFormFactor.mobile
          ? mobileOnGenerateRoute
          : null,
      builder: (BuildContext context, Widget? child) {
        final content = child ?? const SizedBox.shrink();
        final appContent = formFactor == AppFormFactor.mobile
            ? MobileShell(child: content)
            : content;

        // Resolve the Material You palette once and project it onto both the
        // expressive theme and material_ui's Theme for the whole navigator.
        return MaterialYouThemeHost(
          density: formFactor == AppFormFactor.desktop
              ? AppThemeDensity.regular
              : AppThemeDensity.compact,
          child: PlayerErrorListener(child: appContent),
        );
      },
      home: switch (formFactor) {
        AppFormFactor.desktop => const DesktopApp(),
        AppFormFactor.mobile => const MobileShellPage(),
      },
    );
  }
}
