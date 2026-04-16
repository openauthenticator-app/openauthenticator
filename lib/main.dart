import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/model/app_links.dart';
import 'package:open_authenticator/model/backend/authentication/providers/provider.dart';
import 'package:open_authenticator/model/backend/authentication/session.dart';
import 'package:open_authenticator/model/crypto.dart';
import 'package:open_authenticator/model/settings/show_intro.dart';
import 'package:open_authenticator/model/settings/theme.dart';
import 'package:open_authenticator/model/totp/limit.dart';
import 'package:open_authenticator/pages/contributor_plan_paywall/page.dart';
import 'package:open_authenticator/pages/home/page.dart';
import 'package:open_authenticator/pages/intro/page.dart';
import 'package:open_authenticator/pages/scan.dart';
import 'package:open_authenticator/pages/settings/page.dart';
import 'package:open_authenticator/pages/sync_issues.dart';
import 'package:open_authenticator/pages/totp.dart';
import 'package:open_authenticator/themes.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/rate_my_app.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/utils/utils.dart';
import 'package:open_authenticator/widgets/animated_theme.dart';
import 'package:open_authenticator/widgets/app_scaffold.dart';
import 'package:open_authenticator/widgets/centered_circular_progress_indicator.dart';
import 'package:open_authenticator/widgets/dialog/invalid_session_dialog.dart';
import 'package:open_authenticator/widgets/dialog/totp_limit_dialog.dart';
import 'package:open_authenticator/widgets/error.dart';
import 'package:open_authenticator/widgets/migrator.dart';
import 'package:open_authenticator/widgets/unlock_challenge.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';
import 'package:open_authenticator/widgets/window_frame.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:simple_secure_storage/simple_secure_storage.dart';
import 'package:window_manager/window_manager.dart';

/// Hello world !
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SimpleSecureStorage.initialize(_OpenAuthenticatorSSSInitializationOptions());
  if (currentPlatform.isDesktop) {
    await windowManager.ensureInitialized();
    windowManager.waitUntilReadyToShow(
      const WindowOptions(
        title: App.appName,
        size: Size(800, 600),
        minimumSize: Size(400, 400),
        center: true,
        titleBarStyle: TitleBarStyle.hidden,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  await LocaleSettings.useDeviceLocale();
  void appRunner() => runApp(
    ProviderScope(
      child: TranslationProvider(
        child: const OpenAuthenticatorApp(),
      ),
    ),
  );
  return kSentryEnabled
      ? SentryFlutter.init(
          (options) => options..dsn = App.sentryDsn,
          appRunner: appRunner,
        )
      : appRunner();
}

/// Allows to initialize [SimpleSecureStorage] with parameters that depend on the current mode.
class _OpenAuthenticatorSSSInitializationOptions extends InitializationOptions {
  /// Creates a new Open Authenticator SimpleSecureStorage initialization options.
  _OpenAuthenticatorSSSInitializationOptions()
    : super(
        appName: App.appName + (kDebugMode ? ' Debug' : ''),
        namespace: App.appPackageName + (kDebugMode ? '.debug' : ''),
      );
}

/// The main widget class.
class OpenAuthenticatorApp extends ConsumerWidget {
  /// The route "TOTP" argument.
  static const String kRouteParameterTotp = 'totp';

  /// The route "add TOTP" argument.
  static const String kRouteParameterAddTotp = 'addTotp';

  /// Creates a new open authenticator app instance.
  const OpenAuthenticatorApp({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<bool> showIntro = ref.watch(showIntroSettingsEntryProvider);
    AsyncValue<ThemeMode> theme = ref.watch(themeSettingsEntryProvider);
    Locale locale = TranslationProvider.of(context).flutterLocale;
    return switch (showIntro) {
      AsyncData(:bool value) => _createMaterialApp(
        showIntroState: 'data',
        theme: theme,
        locale: locale,
        initialRoute: value ? IntroPage.name : HomePage.name,
      ),
      AsyncError(:final error, :final stackTrace) => _createMaterialApp(
        showIntroState: 'error',
        theme: theme,
        locale: locale,
        home: Builder(
          builder: (context) => AppScaffold.scrollable(
            children: [
              ErrorAlert(
                error: error,
                stackTrace: stackTrace,
              ),
            ],
          ),
        ),
      ),
      _ => _createMaterialApp(
        showIntroState: 'loading',
        theme: theme,
        locale: locale,
        home: const CenteredCircularProgressIndicator(),
      ),
    };
  }

  /// Creates a [MaterialApp] widget.
  Widget _createMaterialApp({
    required String showIntroState,
    required AsyncValue<ThemeMode> theme,
    required Locale locale,
    String? initialRoute,
    Widget? home,
  }) {
    FThemeData light = currentPlatform.isDesktop ? greenTheme.light.desktop : greenTheme.light.touch;
    FThemeData dark = currentPlatform.isDesktop ? greenTheme.dark.desktop : greenTheme.dark.touch;
    return MaterialApp(
      key: ValueKey('materialApp.$showIntroState'),
      title: App.appName,
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocaleUtils.supportedLocales,
      themeMode: theme.value,
      darkTheme: dark.toApproximateMaterialTheme(),
      theme: light.toApproximateMaterialTheme(),
      builder: (context, child) => AnimatedFTheme(
        light: light,
        dark: dark,
        child: FToaster(
          child: DesktopWindowFrame(
            child: child!,
          ),
        ),
      ),
      routes: home == null
          ? {
              IntroPage.name: (_) => const _RouteWidget(
                child: IntroPage(),
              ),
              HomePage.name: (_) => const _RouteWidget(
                listen: true,
                rateMyApp: true,
                child: HomePage(),
              ),
              ScanPage.name: (_) => const _RouteWidget(
                child: ScanPage(),
              ),
              SettingsPage.name: (_) => const _RouteWidget(
                child: SettingsPage(),
              ),
              TotpPage.name: (context) {
                Map<String, dynamic>? arguments = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
                return _RouteWidget(
                  child: TotpPage(
                    totp: arguments?[kRouteParameterTotp],
                    add: arguments?[kRouteParameterAddTotp],
                  ),
                );
              },
              SyncIssuesPage.name: (_) => const _RouteWidget(
                child: SyncIssuesPage(),
              ),
              ContributorPlanPaywallPage.name: (_) => const _RouteWidget(
                child: ContributorPlanPaywallPage(),
              ),
            }
          : {},
      initialRoute: home == null ? initialRoute : null,
      home: home,
    );
  }
}

/// A route that allows to listen to dynamic links and [totpLimitExceededProvider].
class _RouteWidget extends ConsumerStatefulWidget {
  /// The route widget.
  final Widget child;

  /// Listen to [appLinksListenerProvider], [totpLimitProvider], [appUnlockStateProvider] and [cryptoStoreProvider].
  final bool listen;

  /// Whether to initialize and run RateMyApp.
  final bool rateMyApp;

  /// Creates a route widget instance.
  const _RouteWidget({
    required this.child,
    this.listen = false,
    this.rateMyApp = false,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _RouteWidgetState();
}

/// The route widget state.
class _RouteWidgetState extends ConsumerState<_RouteWidget> {
  @override
  void initState() {
    super.initState();
    if (widget.listen) {
      ref.listenManual(
        appLinksListenerProvider,
        (previous, next) async {
          if (previous == next || next is! AsyncData<Uri?> || next.value == null) {
            return;
          }
          Uri uri = next.value!;
          if (uri.scheme == 'openauthenticator') {
            WidgetsBinding.instance.addPostFrameCallback((_) => handleAppLink(uri));
            return;
          }
          if (uri.scheme == 'otpauth') {
            WidgetsBinding.instance.addPostFrameCallback((_) => handleTotpLink(uri));
            return;
          }
        },
        fireImmediately: true,
      );
      ref.listenManual(
        totpLimitProvider,
        (previous, next) async {
          if (previous == next || next is! AsyncData<TotpLimit> || !next.value.isExceeded) {
            return;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) => handleTotpLimitExceeded());
        },
        fireImmediately: true,
      );
      ref.listenManual(
        sessionRefreshManagerProvider,
        (previous, next) {
          if (previous == next) {
            return;
          }
          if (next is SessionRefreshStateInvalidSession) {
            WidgetsBinding.instance.addPostFrameCallback((_) => handleInvalidSession());
          }
        },
        fireImmediately: true,
      );
    }
    if (widget.rateMyApp) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        RateMyApp rateMyApp = RateMyApp.customConditions(
          preferencesPrefix: kDebugMode ? 'flutterDebug.rateMyApp.' : 'flutter.rateMyApp.',
          appStoreIdentifier: Stores.appStoreIdentifier,
          googlePlayIdentifier: Stores.googlePlayIdentifier,
          conditions: [
            SupportedPlatformsCondition(),
          ],
        );
        rateMyApp.populateWithDefaultConditions();
        await rateMyApp.init();
        if (rateMyApp.shouldOpenDialog && mounted) {
          rateMyApp.showRateDialog(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => UnlockChallenge(
    child: Migrator(
      child: widget.child,
    ),
  );

  /// Handles an in-app link.
  Future<void> handleAppLink(Uri appLink) async {
    if (appLink.host == 'auth' && appLink.path.startsWith('/provider/') && appLink.pathSegments.length >= 2) {
      String? providerId = appLink.pathSegments[1];
      AuthenticationProvider? provider = ref.read(authenticationProviders).findProvider(providerId);
      if (provider == null) {
        return;
      }
      Result<RedirectResult> result = await showWaitingOverlay(
        context,
        future: provider.onRedirectReceived(appLink),
      );
      if (mounted) {
        context.handleResult(
          result,
          successMessage: result.valueOrNull?.localizedMessage,
        );
      }
    }
  }

  /// Handles a TOTP link.
  Future<void> handleTotpLink(Uri totpLink) async {
    if (mounted) {
      await showWaitingOverlay(
        context,
        future: TotpPage.openFromUri(context, ref, totpLink),
      );
    }
  }

  /// Handles TOTP limit exceeded.
  Future<void> handleTotpLimitExceeded() async {
    if (mounted) {
      TotpLimitDialog.showAndBlock(context);
    }
  }

  /// Handles an invalid session.
  Future<void> handleInvalidSession() async {
    if (mounted) {
      await InvalidSessionDialog.openDialog(context, ref, handleResult: true);
    }
  }
}
