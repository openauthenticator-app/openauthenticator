import 'dart:async';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// The headless worker is a development-only Flutter test entry point.
// ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/core/app_unlock/state.dart';
import 'package:open_authenticator/core/backend/synchronization/queue.dart';
import 'package:open_authenticator/core/backend/synchronization/status.dart';
import 'package:open_authenticator/core/crypto/salt.dart';
import 'package:open_authenticator/core/crypto/store.dart';
import 'package:open_authenticator/core/settings/display_copy_button.dart';
import 'package:open_authenticator/core/settings/display_search_button.dart';
import 'package:open_authenticator/core/settings/storage_type.dart';
import 'package:open_authenticator/core/settings/theme.dart';
import 'package:open_authenticator/core/totp/decrypted.dart';
import 'package:open_authenticator/core/totp/image_cache.dart';
import 'package:open_authenticator/core/totp/repository.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/pages/home/page.dart';
import 'package:open_authenticator/pages/totp.dart';
import 'package:open_authenticator/themes.dart';
import 'package:open_authenticator/utils/image_type.dart';
import 'package:open_authenticator/utils/platform.dart' as app;
import 'package:open_authenticator/widgets/expandable_tile.dart';
import 'package:open_authenticator/widgets/totp/code.dart';
import 'package:open_authenticator/widgets/window_frame.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'campaign.dart';
import 'render.dart';

/// Fictional accounts use the project's own provider artwork, including a
/// white margin so monochrome logos stay visible in both themes.
class DemoAccounts {
  /// Ephemeral store, disconnected from application storage.
  final CryptoStore store;

  /// Accounts in display order.
  final List<DecryptedTotp> accounts;

  DemoAccounts._(this.store, this.accounts);

  /// Creates the fixture images in a private temporary directory.
  static Future<DemoAccounts> create(io.Directory directory) async {
    final CryptoStore store = await CryptoStore.fromPasswordInIsolate('screenshot fixture', Salt.generate());
    const providers = [
      ('github', 'GitHub', '365214'),
      ('google', 'Google', '907362'),
      ('microsoft', 'Microsoft', '218604'),
      ('apple', 'Apple', '482910'),
      ('x', 'X', '513892'),
      ('email', 'Mail', '780341'),
    ];
    final accounts = <DecryptedTotp>[];
    for (final (asset, issuer, code) in providers) {
      final path = '${directory.path}/$asset.si';
      final String source = io.File('assets/svg/authentication/$asset.svg').readAsStringSync();
      final RegExpMatch svg = RegExp(r'<svg\b[^>]*>([\s\S]*)</svg>').firstMatch(source)!;
      final ScalableImage original = ScalableImage.fromSIBytes(io.File('assets/images/authentication/$asset.si').readAsBytesSync());
      final double scale = 360 / original.viewport.width;
      final String padded =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" fill="white"/>'
          '<g transform="translate(76 76) scale($scale)">${svg[1]}</g></svg>';
      io.File(path).writeAsBytesSync(ScalableImage.fromSvgString(padded, compact: true).toSIBytes());
      final DecryptedTotp totp = DecryptedTotp.create(
        cryptoStore: store,
        uuid: 'demo-$asset',
        issuer: issuer,
        label: 'alex@example.org',
        secret: 'JBSWY3DPEHPK3PXP',
        imageUrl: path,
      )!;
      accounts.add(_DemoTotp(totp, code));
    }
    return DemoAccounts._(store, accounts);
  }
}

class _DemoTotp extends DecryptedTotp {
  final String code;

  _DemoTotp(DecryptedTotp totp, this.code) : super.fromTotp(totp: totp, decryptedData: totp.decryptedData);

  @override
  String generateCode() => code;
}

// Keep the production controls enabled in their restored-window state, without
// binding the headless capture to a window on the machine running the campaign.
class _RestoredWindow extends Fake implements Window {
  @override
  bool get isMaximized => false;

  @override
  ListenerId addListener(FutureOr<void> Function(WindowEvent) callback) => 1;

  @override
  bool removeListener(ListenerId listenerId) => true;
}

// The graphite and button colors come from the campaign's macOS mockup.
class _MacWindowFrame extends StatelessWidget {
  final Widget child;

  const _MacWindowFrame({required this.child});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        height: 40,
        color: const Color(0xff363636),
        padding: const EdgeInsets.only(left: 26),
        child: Row(
          spacing: 9,
          children: [
            for (final color in const [Color(0xfffc625d), Color(0xfffdbe3f), Color(0xff30c949)])
              SizedBox.square(
                dimension: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                ),
              ),
          ],
        ),
      ),
      Expanded(child: child),
    ],
  );
}

/// Captures the real home or edit page. Only their data providers are replaced.
Future<void> captureScreen(WidgetTester tester, Capture capture, DemoAccounts demo, double ratio, io.File destination) async {
  final Device device = capture.device;
  final app.Platform previousPlatform = app.currentPlatform;
  final TargetPlatform? previousTarget = debugDefaultTargetPlatformOverride;
  app.currentPlatform = device.platform;
  debugDefaultTargetPlatformOverride = TargetPlatform.values.byName(device.platform.name);
  final GlobalKey key = GlobalKey();
  try {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = device.size;
    await tester.binding.setSurfaceSize(device.size);
    await tester.runAsync(() => LocaleSettings.setLocale(capture.locale));
    // Advance the widget test clock to the same point in a 30-second period.
    await tester.pump(const Duration(seconds: 11));
    final FPlatformThemeData variant = capture.dark ? greenTheme.dark : greenTheme.light;
    final FThemeData theme = device.platform.isDesktop ? variant.desktop : variant.touch;
    final Widget page = capture.setup ? TotpPage(totp: demo.accounts.first, imageSize: 76) : HomePage(useFloatingAddButton: device.platform == app.Platform.android);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          totpRepositoryProvider.overrideWithBuild((ref, notifier) => demo.accounts),
          cryptoStoreProvider.overrideWithBuild((ref, notifier) => demo.store),
          appLockStateProvider.overrideWithBuild((ref, notifier) => .unlocked),
          displaySearchButtonSettingsEntryProvider.overrideWithBuild((ref, notifier) => true),
          displayCopyButtonSettingsEntryProvider.overrideWithBuild((ref, notifier) => true),
          storageTypeSettingsEntryProvider.overrideWithBuild((ref, notifier) => .shared),
          themeSettingsEntryProvider.overrideWithBuild((ref, notifier) => capture.dark ? .dark : .light),
          synchronizationControllerProvider.overrideWithBuild((ref, notifier) => SynchronizationStatus(phase: const SynchronizationPhaseUpToDate())),
          pushOperationsErrorsProvider.overrideWithValue(const AsyncData([])),
          totpResolvedImageProvider.overrideWith((ref, args) => (source: args.imageUrl!, imageType: ImageType.si)),
        ],
        child: MaterialApp(
          locale: capture.locale.flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: theme.toApproximateMaterialTheme(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) => FTheme(
            data: theme,
            child: FToaster(child: child!),
          ),
          home: RepaintBoundary(
            key: key,
            child: switch (device.platform) {
              app.Platform.linux || app.Platform.windows => DesktopWindowFrame(window: _RestoredWindow(), child: page),
              app.Platform.macOS => _MacWindowFrame(child: page),
              _ => page,
            },
          ),
        ),
      ),
    );
    await tester.pump();
    if (capture.setup) {
      final Finder tile = find.widgetWithText(ExpandableTile, translations.totp.page.showQrCode);
      await tester.ensureVisible(tile);
      await tester.tap(find.descendant(of: tile, matching: find.byIcon(FLucideIcons.chevronRight)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final Finder qr = find.byType(QrImageView);
      await tester.ensureVisible(qr);
      await tester.pump();
      expect(find.text(translations.totp.page.title.edit), findsOneWidget);
      expect(qr.hitTestable(), findsOneWidget);
    } else {
      expect(find.byType(TotpCode), findsWidgets);
    }
    await tester.pump(const Duration(milliseconds: 350));
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: ratio);
      try {
        await writePng(destination, image);
      } finally {
        image.dispose();
      }
    });
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
    debugDefaultTargetPlatformOverride = previousTarget;
    app.currentPlatform = previousPlatform;
  }
}
