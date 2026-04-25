import 'dart:io';

import 'package:args/args.dart';

/// Generates "lib/app.dart".
void main(List<String> arguments) {
  ArgParser parser = ArgParser()
    ..addOption(
      'app-name',
      defaultsTo: 'Open Authenticator',
      help: 'The app name.',
    )
    ..addOption(
      'app-author',
      defaultsTo: 'Skyost',
      help: 'The app author.',
    )
    ..addOption(
      'app-package-name',
      defaultsTo: 'app.openauthenticator',
      help: 'The app package name.',
    )
    ..addOption(
      'default-backend-url',
      defaultsTo: 'https://backend.openauthenticator.app',
      help: 'The app backend URL.',
    )
    ..addOption(
      'github-repository-url',
      defaultsTo: 'https://github.com/openauthenticator-app/openauthenticator',
      help: 'The Github repository URL.',
    )
    ..addOption(
      'app-translation-url',
      defaultsTo: 'https://openauthenticator.app/translate/',
      help: 'The app translation URL.',
    )
    ..addOption(
      'sentry-dsn',
      defaultsTo: '',
      help: 'The Sentry DSN.',
    )
    ..addOption(
      'revenue-cat-public-key-android',
      defaultsTo: '',
      help: 'The RevenueCat Android public key.',
    )
    ..addOption(
      'revenue-cat-public-key-darwin',
      defaultsTo: '',
      help: 'The RevenueCat iOS / macOS public key.',
    )
    ..addOption(
      'revenue-cat-public-key-windows-linux',
      defaultsTo: '',
      help: 'The RevenueCat Windows / Linux public key.',
    )
    ..addOption(
      'revenue-cat-offering-id',
      defaultsTo: '',
      help: 'The Contributor Plan offering id.',
    )
    ..addOption(
      'logo-dev-api-key',
      defaultsTo: '',
      help: 'The `logo.dev` API key.',
    )
    ..addOption(
      'google-play-identifier',
      defaultsTo: '',
      help: 'The Google Play app identifier.',
    )
    ..addOption(
      'app-store-identifier',
      defaultsTo: '',
      help: 'The Apple App Store app identifier.',
    )
    ..addOption(
      'privacy-policy-link',
      defaultsTo: 'https://openauthenticator.app/privacy-policy',
      help: 'The link to the privacy policy.',
    )
    ..addOption(
      'terms-of-service-link',
      defaultsTo: 'https://openauthenticator.app/terms-of-service',
      help: 'The link to the terms of service.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message.',
    );

  ArgResults results = parser.parse(arguments);
  if (results['help']) {
    stdout.writeln(parser.usage);
    return;
  }

  String content =
      '''
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
  static const String revenueCatPublicKeyWindows = '${results['revenue-cat-public-key-windows-linux']}';

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
