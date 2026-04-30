# 📰 Open Authenticator changelog

## v2.0.2
Released on May 1, 2026.

* **FEAT**: Now using `Auth Tabs` on Android and `ASWebAuthenticationSession` on Darwin to handle authentication links. ([#1153cd8](https://github.com/openauthenticator-app/openauthenticator/commit/1153cd8))
* **FIX**: Fixed an `AccessDenied` error occurring in snap. ([#5c08b29](https://github.com/openauthenticator-app/openauthenticator/commit/5c08b29))
* **FIX**: Fixed some `UnmountedRefException` occurring with backups. ([#69f564f](https://github.com/openauthenticator-app/openauthenticator/commit/69f564f))
* **FIX**: Fixed the `app.dart` build script. ([#f357e3b](https://github.com/openauthenticator-app/openauthenticator/commit/f357e3b))
* **FIX**: Networks requests will not automatically fail if there is an error in `ConnectivityStateNotifier`. ([#7fc8c48](https://github.com/openauthenticator-app/openauthenticator/commit/7fc8c48))
* **CHORE**: Added `network-status` and silenced various network warnings. ([#2897fee](https://github.com/openauthenticator-app/openauthenticator/commit/2897fee))
* **CHORE**: Added support for `SentryNavigatorObserver`. ([#041eb44](https://github.com/openauthenticator-app/openauthenticator/commit/041eb44))
* **CHORE**: Improved the logo picker dialog. ([#a469a5c](https://github.com/openauthenticator-app/openauthenticator/commit/a469a5c))
* **CHORE**: Improved the master password unlock method. ([#f711d45](https://github.com/openauthenticator-app/openauthenticator/commit/f711d45))
* **CHORE**: Now handling errors in `EnableLocalAuthSettingsEntryWidget`. ([#22da7ce](https://github.com/openauthenticator-app/openauthenticator/commit/22da7ce))
* **CHORE**: Now supporting localization in redirect routes. ([#3dfe096](https://github.com/openauthenticator-app/openauthenticator/commit/3dfe096))
* **CHORE**: Now using `.afterFirstUnlock` for keychain accessibility. ([#b33a85d](https://github.com/openauthenticator-app/openauthenticator/commit/b33a85d))
* **REFACTOR**: Added a `CryptoKey` that unifies both `Salt` and `DerivedKey`. ([#5a5bb60](https://github.com/openauthenticator-app/openauthenticator/commit/5a5bb60))
* **REFACTOR**: Added a `StoredSalt` to add a distinction between a `Salt` object and the stored `Salt` object. ([#897a04d](https://github.com/openauthenticator-app/openauthenticator/commit/897a04d))
* **REFACTOR**: `CryptoStore.createHmacKey()` is now `CryptoStore.hmacSecretKey`. Also dropped support of `memEquals` in favor of hashlib `isEqual`. ([#5574431](https://github.com/openauthenticator-app/openauthenticator/commit/5574431))

## v2.0.1
Released on April 24, 2026.

* **FEAT**: Instead of failing, the app now tries to get the salt back from TOTP list. ([#3da8a66](https://github.com/openauthenticator-app/openauthenticator/commit/3da8a66))
* **FIX**: Fixed a bug with old backups restoring. ([#fb95911](https://github.com/openauthenticator-app/openauthenticator/commit/fb95911))
* **FIX**: Fixed some app links being consumed more than once. ([#29cdfcf](https://github.com/openauthenticator-app/openauthenticator/commit/29cdfcf))
* **FIX**: Fixed some user related errors being incorrectly sent to Sentry. ([#5b11363](https://github.com/openauthenticator-app/openauthenticator/commit/5b11363))
* **CHORE**: Backend URL change now displays more info. ([#5448423](https://github.com/openauthenticator-app/openauthenticator/commit/5448423))
* **CHORE**: Fixed some app links being consumed more than once. ([#0c01a83](https://github.com/openauthenticator-app/openauthenticator/commit/0c01a83))
* **CHORE**: Improved `Result`s handling. ([#c35cc8c](https://github.com/openauthenticator-app/openauthenticator/commit/c35cc8c))
* **CHORE**: Updated push and pull timeouts. ([#c604633](https://github.com/openauthenticator-app/openauthenticator/commit/c604633))
* **REFACTOR**: Now using `xdg_desktop_portal` instead of `connectivity_plus`. ([#1eac66e](https://github.com/openauthenticator-app/openauthenticator/commit/1eac66e))

## v2.0.0
Released on April 24, 2026.

**This is a big release !** Only notable change are listed below.

* **FIX**: Fixed various bugs with backups. ([#047a561](https://github.com/Skyost/OpenAuthenticator/commit/047a561))
* **CHORE**: Improved TOTPs images cache and display. ([#88b2a96](https://github.com/Skyost/OpenAuthenticator/commit/88b2a96))
* **CHORE**: Updated the `lib/app.dart` generator. ([#b1ccd3d](https://github.com/Skyost/OpenAuthenticator/commit/b1ccd3d))
* **CHORE**: Updated the app design. ([#db514e6](https://github.com/Skyost/OpenAuthenticator/commit/db514e6))
* **CHORE**: Updated the app to use a custom backend. ([#94e632d](https://github.com/Skyost/OpenAuthenticator/commit/94e632d))
* **REFACTOR**: Completely removed dependency on `webcrypto`. ([#e427d7f](https://github.com/Skyost/OpenAuthenticator/commit/e427d7f))

## v1.4.3
Released on December 23, 2025.

* **FEAT**: Added an experimental way to build Flatpaks. ([#38a608b](https://github.com/Skyost/OpenAuthenticator/commit/38a608b))
* **CHORE**: Now using `.gradle.kts` file format instead of `.gradle`. ([#a4adcd0](https://github.com/Skyost/OpenAuthenticator/commit/a4adcd0))
* **CHORE**: Updated snap links. ([#c07b6fb](https://github.com/Skyost/OpenAuthenticator/commit/c07b6fb))

## v1.4.2
Released on September 24, 2025.

* **FEAT**: Added a way to display the search bar by scrolling above the list. ([#3af4645](https://github.com/Skyost/OpenAuthenticator/commit/3af4645))
* **FEAT**: Added a whole route to configure the app theme. ([#9b828ea](https://github.com/Skyost/OpenAuthenticator/commit/9b828ea))
* **FEAT**: Better handling of cases where the user is not logged in. ([#9b8028e](https://github.com/Skyost/OpenAuthenticator/commit/9b8028e))
* **FEAT**: Enabled `logo.dev` fetching. ([#aa7c766](https://github.com/Skyost/OpenAuthenticator/commit/aa7c766))
* **FIX**: Fixed some problems occurring when refreshing the list. ([#2ee63ca](https://github.com/Skyost/OpenAuthenticator/commit/2ee63ca))
* **CHORE**: Better handling of QR codes (reading and displaying). ([#10107ad](https://github.com/Skyost/OpenAuthenticator/commit/10107ad))
* **CHORE**: Improved the TOTP page. ([#a80f55c](https://github.com/Skyost/OpenAuthenticator/commit/a80f55c))
* **CHORE**: Updated Linux metadata. ([#97a2d92](https://github.com/Skyost/OpenAuthenticator/commit/97a2d92))
* **CHORE**: Updated changelog. ([#91a23fb](https://github.com/Skyost/OpenAuthenticator/commit/91a23fb))
* **CHORE**: Updated dependencies and fixed resulting lint warnings. ([#4aaa6de](https://github.com/Skyost/OpenAuthenticator/commit/4aaa6de))
* **CHORE**: Updated native libraries. ([#48624f5](https://github.com/Skyost/OpenAuthenticator/commit/48624f5))

## v1.4.1
Released on May 22, 2025.

* **FEAT** : Migrated from PAM to Polkit. ([#a073fc5](https://github.com/Skyost/OpenAuthenticator/commit/a073fc5))

## v1.4.0
Released on May 4, 2025.

* **FEAT** : Initial implementation of Firebase AppCheck for Windows. ([#c9143d4](https://github.com/Skyost/OpenAuthenticator/commit/c9143d4))
* **FEAT** : Initial implementation of Open Authenticator for linux. ([#2c10b16](https://github.com/Skyost/OpenAuthenticator/commit/2c10b16))
* **FEAT** : Now allowing `otpauth` links to be opened by the app on all platforms. ([#fdeb999](https://github.com/Skyost/OpenAuthenticator/commit/fdeb999))
* **CHORE** : Improved the empty home screen. ([#670c8fb](https://github.com/Skyost/OpenAuthenticator/commit/670c8fb))
* **CHORE** : Migrated from Clearbit to Logo.dev. ([#6b23064](https://github.com/Skyost/OpenAuthenticator/commit/6b23064))
* **CHORE** : Various updates in the app look and feel. ([#19b2714](https://github.com/Skyost/OpenAuthenticator/commit/19b2714))

## v1.3.1
Released on Apr 2, 2025.

* **FEAT** : Improved errors handling. ([#4cbbdca](https://github.com/Skyost/OpenAuthenticator/commit/4cbbdca))
* **FEAT** : Improved the paywall. ([#f549ecb](https://github.com/Skyost/OpenAuthenticator/commit/f549ecb))
* **FIX** : Fixed a bug with login links. ([#848f806](https://github.com/Skyost/OpenAuthenticator/commit/848f806))
* **CHORE** : Improved some dialogs. ([#6cdd405](https://github.com/Skyost/OpenAuthenticator/commit/6cdd405))

## v1.3.0
Released on Mar 30, 2025.

* **FEAT** : Now hiding the home page floating action button on scroll. ([#62e5aba](https://github.com/Skyost/OpenAuthenticator/commit/62e5aba))
* **FEAT** : Translated the app into `it`. ([#c765c8e](https://github.com/Skyost/OpenAuthenticator/commit/c765c8e))
* **FEAT** : Translated the app into `pt`. ([#75615ea](https://github.com/Skyost/OpenAuthenticator/commit/75615ea))
* **CHORE** : Improved the app dialogs. ([#04c89d4](https://github.com/Skyost/OpenAuthenticator/commit/04c89d4))
* **CHORE** : Improved the fallback paywall. ([#289836e](https://github.com/Skyost/OpenAuthenticator/commit/289836e))
* **CHORE** : Improved the logo search dialog. ([#0b2659e](https://github.com/Skyost/OpenAuthenticator/commit/0b2659e))
* **CHORE** : Now got rid of `MediaQuery.of` when it's not needed. ([#081caf2](https://github.com/Skyost/OpenAuthenticator/commit/081caf2))

## v1.2.2
Released on Feb 13, 2025.

* **FEAT** : Added a better sign-in dialog. ([#8e96185](https://github.com/Skyost/OpenAuthenticator/commit/8e96185))
* **FEAT** : Better adaptation to small screens. ([#9f3934e](https://github.com/Skyost/OpenAuthenticator/commit/9f3934e))
* **FEAT** : Improved `UnlockChallengeWidget`. ([#c55ba67](https://github.com/Skyost/OpenAuthenticator/commit/c55ba67))
* **FIX** : Fixed various problems with TOTPs circular progress indicators. ([#c78d96c](https://github.com/Skyost/OpenAuthenticator/commit/c78d96c))
* **CHORE** : Disabled `dense` property on `ListTile`s on desktop. ([#fa37adf](https://github.com/Skyost/OpenAuthenticator/commit/fa37adf))

## v1.2.1
Released on Feb 12, 2025.

* **FEAT** : Improved app dialogs. ([#a0f764a](https://github.com/Skyost/OpenAuthenticator/commit/a0f764a))
* **CHORE** : Added `de` localization to Xcode. ([#5366d36](https://github.com/Skyost/OpenAuthenticator/commit/5366d36))

## v1.2.0
Released on Feb 9, 2025.

* **REFACTOR** : Refactored authentication / confirmation providers. ([#5a0430b](https://github.com/Skyost/OpenAuthenticator/commit/5a0430b))
* **REFACTOR** : `createDefaultAuthMethod` does not need `BuildContext` anymore. ([#6af1af0](https://github.com/Skyost/OpenAuthenticator/commit/6af1af0))
* **FEAT** : Improved error handling (for instance : if crypto store cannot be loaded). ([#db48590](https://github.com/Skyost/OpenAuthenticator/commit/db48590))
* **FEAT** : Now allowing the user to unlock the app if local auth is not available even though it has been enabled. ([#215b344](https://github.com/Skyost/OpenAuthenticator/commit/215b344))
* **FEAT** : Translated `app_unlock.json` into `de`. ([#112de83](https://github.com/Skyost/OpenAuthenticator/commit/112de83))
* **FEAT** : Translated `authentication.json` into `de`. ([#2c2b252](https://github.com/Skyost/OpenAuthenticator/commit/2c2b252))
* **FEAT** : Translated `contributor_plan.json` into `de`. ([#f2cd8b3](https://github.com/Skyost/OpenAuthenticator/commit/f2cd8b3))
* **FEAT** : Translated `error.json` into `de`. ([#c51b5d0](https://github.com/Skyost/OpenAuthenticator/commit/c51b5d0))
* **FEAT** : Translated `home.json` into `de`. ([#c2608ae](https://github.com/Skyost/OpenAuthenticator/commit/c2608ae))
* **FEAT** : Translated `intro.json` into `de`. ([#4247ce8](https://github.com/Skyost/OpenAuthenticator/commit/4247ce8))
* **FEAT** : Translated `local_auth.json` into `de`. ([#e6ca2e4](https://github.com/Skyost/OpenAuthenticator/commit/e6ca2e4))
* **FEAT** : Translated `logo_search.json` into `de`. ([#0f3cf53](https://github.com/Skyost/OpenAuthenticator/commit/0f3cf53))
* **FEAT** : Translated `master_password.json` into `de`. ([#bbc1d88](https://github.com/Skyost/OpenAuthenticator/commit/bbc1d88))
* **FEAT** : Translated `miscellaneous.json` into `de`. ([#049de5e](https://github.com/Skyost/OpenAuthenticator/commit/049de5e))
* **FEAT** : Translated `settings.json` into `de`. ([#08ffaae](https://github.com/Skyost/OpenAuthenticator/commit/08ffaae))
* **FEAT** : Translated `storage_migration.json` into `de`. ([#27399dd](https://github.com/Skyost/OpenAuthenticator/commit/27399dd))
* **FEAT** : Translated `totp.json` into `de`. ([#0470586](https://github.com/Skyost/OpenAuthenticator/commit/0470586))
* **FEAT** : Translated `totp_limit.json` into `de`. ([#5ca92e3](https://github.com/Skyost/OpenAuthenticator/commit/5ca92e3))
* **FEAT** : Translated `validation.json` into `de`. ([#dadcf4c](https://github.com/Skyost/OpenAuthenticator/commit/dadcf4c))
* **FIX** : Fixed a problem with theme brightness not always being updated. ([#bfe8b06](https://github.com/Skyost/OpenAuthenticator/commit/bfe8b06))
* **FIX** : Fixed a typo. ([#cb870e2](https://github.com/Skyost/OpenAuthenticator/commit/cb870e2))
* **FIX** : Fixed an error with `HttpServer.bind`. ([#04af98e](https://github.com/Skyost/OpenAuthenticator/commit/04af98e))
* **FIX** : Fixed crypto store not being saved on local storage under certain circumstances. ([#eac2a1f](https://github.com/Skyost/OpenAuthenticator/commit/eac2a1f))
* **FIX** : Fixed various problems with authentication. ([#97d2609](https://github.com/Skyost/OpenAuthenticator/commit/97d2609))
* **FIX** : Now correctly opening Stripe management URL on mobile platforms. ([#72d28a0](https://github.com/Skyost/OpenAuthenticator/commit/72d28a0))
* **CHORE** : Ignored various warnings. ([#930c195](https://github.com/Skyost/OpenAuthenticator/commit/930c195))
* **CHORE** : Improved storage migration. ([#0f450dd](https://github.com/Skyost/OpenAuthenticator/commit/0f450dd))

## v1.1.3
Released on Jan 21, 2025.

* **FIX** : Fixed a problem with permissions on iOS. ([#6f330ab](https://github.com/Skyost/OpenAuthenticator/commit/6f330ab))
* **FIX** : Fixed various problems with backups. ([#68e16bd](https://github.com/Skyost/OpenAuthenticator/commit/68e16bd))

## v1.1.2
Released on Jan 21, 2025.

* **REFACTOR** : Put all settings entry widgets at the same place and copying URLs if they can't be opened. ([#f1d51c6](https://github.com/Skyost/OpenAuthenticator/commit/f1d51c6))
* **FEAT** : Improved backup manager. ([#6f0e559](https://github.com/Skyost/OpenAuthenticator/commit/6f0e559))
* **FIX** : Fixed some icons display in the settings page. ([#38de554](https://github.com/Skyost/OpenAuthenticator/commit/38de554))
* **CHORE** : Updated top padding on intro page. ([#3404fbd](https://github.com/Skyost/OpenAuthenticator/commit/3404fbd))

## v1.1.1
Released on Jan 13, 2025.

* **FIX** : Better handling of HTTPS links in the app settings. ([#78c5cf3](https://github.com/Skyost/OpenAuthenticator/commit/78c5cf3))

## v1.1.0
Released on Jan 11, 2025.

* **REFACTOR** : More coherence with `try` functions in unlock methods. ([#02c29fd](https://github.com/Skyost/OpenAuthenticator/commit/02c29fd))
* **REFACTOR** : Riverpod notifiers fields are now private. ([#f1fbe0b](https://github.com/Skyost/OpenAuthenticator/commit/f1fbe0b))
* **REFACTOR** : Using `Navigator.defaultRouteName` instead of `/` and `logIn` instead of `login`. ([#f83d479](https://github.com/Skyost/OpenAuthenticator/commit/f83d479))
* **FEAT** : Added a link to the translation platform in the app settings. ([#c0013eb](https://github.com/Skyost/OpenAuthenticator/commit/c0013eb))
* **FEAT** : Now allowing to decrypt and save more than one TOTP on home page. ([#a73b9db](https://github.com/Skyost/OpenAuthenticator/commit/a73b9db))
* **FIX** : Fixed a bug where text fields were not accepting any input after local authentication. ([#152628e](https://github.com/Skyost/OpenAuthenticator/commit/152628e))
* **FIX** : Only scanning one QR code at once. ([#82e0770](https://github.com/Skyost/OpenAuthenticator/commit/82e0770))
* **FIX** : Various fixes with deep links. ([#4da5b09](https://github.com/Skyost/OpenAuthenticator/commit/4da5b09))
* **CHORE** : Improved Windows icon. ([#250c50f](https://github.com/Skyost/OpenAuthenticator/commit/250c50f))
* **CHORE** : Not storing the common salt using `Storage`. ([#f23577a](https://github.com/Skyost/OpenAuthenticator/commit/f23577a))
* **CHORE** : Saving shared preferences in a different file in debug mode. ([#7ea7b1e](https://github.com/Skyost/OpenAuthenticator/commit/7ea7b1e))

## v1.0.8
Released on Nov 4, 2024.

* **FEAT** : Now directly copying TOTP code when tapped on by search (if enabled in the app settings). ([#e1d2447](https://github.com/Skyost/OpenAuthenticator/commit/e1d2447))
* **CHORE** : Now using `mobile_scanner` instead of `google_mlkit_barcode_scanning`. ([#f684564](https://github.com/Skyost/OpenAuthenticator/commit/f684564))

## v1.0.7
Released on Oct 28, 2024.

* **FEAT** : Added the ability to export a given backup. Fixes #3. ([#5a7ce70](https://github.com/Skyost/OpenAuthenticator/commit/5a7ce70))
* **FEAT** : Improved `ExpandListTile` widget with an animation. ([#2cd61bc](https://github.com/Skyost/OpenAuthenticator/commit/2cd61bc))
* **FIX** : Better handling of durations. Fixes #4. ([#61b58f4](https://github.com/Skyost/OpenAuthenticator/commit/61b58f4))

## v1.0.6
Released on Oct 24, 2024.

* **FEAT** : Added a fade-in to `SmartImageWidget`. ([#69be9e9](https://github.com/Skyost/OpenAuthenticator/commit/69be9e9))
* **FEAT** : Dropped `flutter_svg` support in favor of `jovial_svg`. ([#dbb7302](https://github.com/Skyost/OpenAuthenticator/commit/dbb7302))
* **FEAT** : Improved overall app speed by compiling SVG files into SI. ([#27c9d4f](https://github.com/Skyost/OpenAuthenticator/commit/27c9d4f))
* **FIX** : Fixed some SI files that were not loading. ([#be0cf0c](https://github.com/Skyost/OpenAuthenticator/commit/be0cf0c))
* **CHORE** : Did some refactoring with `jovial_svg`. ([#e230f94](https://github.com/Skyost/OpenAuthenticator/commit/e230f94))
* **CHORE** : Made `SizedScalableImageWidget` only supporting project assets, not files. ([#9f60f63](https://github.com/Skyost/OpenAuthenticator/commit/9f60f63))
* **CHORE** : Various improvements made to `SmartImageWidget`. ([#eabba24](https://github.com/Skyost/OpenAuthenticator/commit/eabba24))

## v1.0.5
Released on Jul 25, 2024.

* **FIX** : Fixed a problem with Firebase authentication. ([#23e5f25](https://github.com/Skyost/OpenAuthenticator/commit/23e5f25))

## v1.0.4
Released on Jul 25, 2024.

* **FEAT** : Added a settings entry for displaying a copy button next to TOTPs. ([#0f040e0](https://github.com/Skyost/OpenAuthenticator/commit/0f040e0))
* **FEAT** : Fully localized `local_auth` messages. ([#8625688](https://github.com/Skyost/OpenAuthenticator/commit/8625688))
* **FIX** : Fixed a bug where the search page was displaying wrong TOTP codes. ([#f738109](https://github.com/Skyost/OpenAuthenticator/commit/f738109))
* **FIX** : Fixed an error occurring with type casting. ([#e7f82e1](https://github.com/Skyost/OpenAuthenticator/commit/e7f82e1))
* **FIX** : Fixed app exiting on iOS. ([#7e8c8f2](https://github.com/Skyost/OpenAuthenticator/commit/7e8c8f2))

## v1.0.3
Released on Jul 12, 2024.

* **FEAT** : Added a back button to the scan page. ([#756794f](https://github.com/Skyost/OpenAuthenticator/commit/756794f))
* **FEAT** : Added a fallback paywall. ([#e9c9f8a](https://github.com/Skyost/OpenAuthenticator/commit/e9c9f8a))
* **FEAT** : Added a settings entry for clearing all data. ([#db2bc6e](https://github.com/Skyost/OpenAuthenticator/commit/db2bc6e))
* **FEAT** : Implemented a search button. ([#8f92304](https://github.com/Skyost/OpenAuthenticator/commit/8f92304))
* **FIX** : Fixed a bug with the image cache. ([#087101c](https://github.com/Skyost/OpenAuthenticator/commit/087101c))
* **FIX** : Fixed a problem with deep links callbacks being triggered multiple times. ([#94f0c29](https://github.com/Skyost/OpenAuthenticator/commit/94f0c29))
* **FIX** : Not displaying desktop action on mobile in debug mode anymore. ([#7467218](https://github.com/Skyost/OpenAuthenticator/commit/7467218))
* **CHORE** : Not using the same storage location in debug mode. ([#23e5b47](https://github.com/Skyost/OpenAuthenticator/commit/23e5b47))
* **CHORE** : Removed some safe margins. ([#67f51a5](https://github.com/Skyost/OpenAuthenticator/commit/67f51a5))

## v1.0.2
Released on Jul 11, 2024.

* **FEAT** : Added a cache manager for easily handling cached images. ([#9b6b2d2](https://github.com/Skyost/OpenAuthenticator/commit/9b6b2d2))
* **FEAT** : Lowercase secrets are now accepted. ([#07d9aba](https://github.com/Skyost/OpenAuthenticator/commit/07d9aba))
* **FIX** : Fixed errors with secret validation. ([#6f61c3c](https://github.com/Skyost/OpenAuthenticator/commit/6f61c3c))

## v1.0.1
Released on Jul 11, 2024.

* **FIX** : Fixed an issue with QR code scanning on Android. ([#d711b50](https://github.com/Skyost/OpenAuthenticator/commit/d711b50))
* **FIX** : Fixed some remaining problems with QR code scanning and URI parsing. ([#be3a739](https://github.com/Skyost/OpenAuthenticator/commit/be3a739))
* **FIX** : Fixed various problems with deep links. ([#dcfa646](https://github.com/Skyost/OpenAuthenticator/commit/dcfa646))

## v1.0.0
Released on Jul 11, 2024.

* **FEAT** : Added `otpauth` protocol support on Android. ([#b0de12d](https://github.com/Skyost/OpenAuthenticator/commit/b0de12d))
* **FEAT** : Added a way to clear a RevenueCat user cache. ([#6d0904c](https://github.com/Skyost/OpenAuthenticator/commit/6d0904c))
* **FEAT** : Enabled `otpauth` protocol support on iOS. ([#ba3aded](https://github.com/Skyost/OpenAuthenticator/commit/ba3aded))
* **BREAKING FIX** : Fixed incorrect TOTP generation. ([#42c6801](https://github.com/Skyost/OpenAuthenticator/commit/42c6801))
* **FIX** : Fixed various Firebase related problems. ([#2e06a5b](https://github.com/Skyost/OpenAuthenticator/commit/2e06a5b))
* **FIX** : Fixed various remaining bugs. ([#48e3a2b](https://github.com/Skyost/OpenAuthenticator/commit/48e3a2b))
* **CHORE** : Removed various remaining `print` calls. ([#cb3254f](https://github.com/Skyost/OpenAuthenticator/commit/cb3254f))
* **CHORE** : Updated README. ([#a34df82](https://github.com/Skyost/OpenAuthenticator/commit/a34df82))
* **CHORE** : Updated dependencies. ([#6805c3e](https://github.com/Skyost/OpenAuthenticator/commit/6805c3e))
