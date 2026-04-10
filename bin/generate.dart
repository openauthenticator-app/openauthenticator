import 'dart:io';

import 'package:args/args.dart';

/// Generates "lib/app.dart".
void main(List<String> arguments) {
  ArgParser parser = ArgParser()
    ..addOption('app-name', defaultsTo: 'Open Authenticator')
    ..addOption('app-author', defaultsTo: 'Skyost')
    ..addOption('app-package-name', defaultsTo: 'app.openauthenticator')
    ..addOption('default-backend-url', defaultsTo: 'https://backend.openauthenticator.app')
    ..addOption('github-repository-url', defaultsTo: 'https://github.com/openauthenticator-app/openauthenticator')
    ..addOption('app-translation-url', defaultsTo: 'https://openauthenticator.app/translate/')
    ..addOption('sentry-dsn', defaultsTo: '')
    ..addOption('revenue-cat-public-key-android', defaultsTo: '')
    ..addOption('revenue-cat-public-key-darwin', defaultsTo: '')
    ..addOption('revenue-cat-public-key-windows', defaultsTo: '')
    ..addOption('revenue-cat-offering-id', defaultsTo: '')
    ..addOption('logo-dev-api-key', defaultsTo: '')
    ..addOption('google-play-identifier', defaultsTo: '')
    ..addOption('app-store-identifier', defaultsTo: '')
    ..addOption('privacy-policy-link', defaultsTo: 'https://openauthenticator.app/privacy-policy')
    ..addOption('terms-of-service-link', defaultsTo: 'https://openauthenticator.app/terms-of-service')
    ..addOption('restore-purchases-link', defaultsTo: 'https://openauthenticator.app/contact');

  final results = parser.parse(arguments);

  final content = '''
import 'package:flutter/foundation.dart';

/// Contains some app constants.
class App {
  /// The app name.
  static const String appName = '${results['app-name']}';

  /// The app author.
  static const String appAuthor = '${results['app-author']}';

  /// The app package name.
  static const String appPackageName = '${results['app-package-name']}';

  /// The app backend URL.
  static const String defaultBackendUrl = '${results['default-backend-url']}';

  /// The Github repository URL.
  static const String githubRepositoryUrl = '${results['github-repository-url']}';

  /// The app translation URL.
  static const String appTranslationUrl = '${results['app-translation-url']}';

  /// The Sentry DSN.
  static const String sentryDsn = '${results['sentry-dsn']}';
}

/// Contains some credentials, required to use with some services.
class AppCredentials {
  /// The RevenueCat Android public key.
  static const String revenueCatPublicKeyAndroid = '${results['revenue-cat-public-key-android']}';

  /// The RevenueCat iOS / macOS public key.
  static const String revenueCatPublicKeyDarwin = '${results['revenue-cat-public-key-darwin']}';

  /// The RevenueCat Windows public key.
  static const String revenueCatPublicKeyWindows = '${results['revenue-cat-public-key-windows']}';

  /// The RevenueCat Linux public key.
  static const String revenueCatPublicKeyLinux = revenueCatPublicKeyWindows;

  /// The `logo.dev` API key.
  static const String logoDevApiKey = '${results['logo-dev-api-key']}';
}

/// The stores identifiers.
class Stores {
  /// The Google Play app identifier.
  static const String googlePlayIdentifier = '${results['google-play-identifier']}';

  /// The Apple App Store app identifier.
  static const String appStoreIdentifier = '${results['app-store-identifier']}';
}

/// Contains all data for the Contributor Plan.
class AppContributorPlan {
  /// The Contributor Plan offering id.
  static const String offeringId = '${results['revenue-cat-offering-id']}';

  /// The link to the privacy policy.
  static const String privacyPolicyLink = '${results['privacy-policy-link']}';

  /// The link to the terms of service.
  static const String termsOfServiceLink = '${results['terms-of-service-link']}';
}

/// Contains all Argon2 parameters.
class Argon2Parameters {
  /// The number of iterations to perform.
  static const int iterations = 3;

  /// The degree of parallelism (ie. number of threads).
  static const int parallelism = 8;

  /// The amount of memory (in kibibytes) to use.
  static const int memorySize = 1 << 12;
}
''';

  File file = File('lib/app.dart');
  file.writeAsStringSync(content);
  stdout.writeln('lib/app.dart generated successfully.');
}
