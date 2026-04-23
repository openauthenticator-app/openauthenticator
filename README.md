<div align="center">
  <a href="https://openauthenticator.app">
    <img src="https://openauthenticator.app/images/logo.svg" alt="Logo" width="120" height="120">
  </a>

  <h3>Open Authenticator</h3>

  <p>
    A cross-platform OTP app, free and open-source.
    <br />
    <a href="https://openauthenticator.app/#download"><strong>Download now »</strong></a>
    <br />
    <br />
    <a href="https://openauthenticator.app">Website</a>
    ·
    <a href="https://github.com/openauthenticator-app/openauthenticator">App</a>
    ·
    <a href="https://github.com/openauthenticator-app/backend">Backend</a>
    ·
    <a href="https://openauthenticator.app/#contribute">Contribute</a>
  </p>

  <p>
    <img src="https://img.shields.io/github/license/openauthenticator-app/openauthenticator" alt="License">
    <img src="https://img.shields.io/github/languages/top/openauthenticator-app/openauthenticator" alt="Top language">
    <img src="https://img.shields.io/github/stars/openauthenticator-app/openauthenticator" alt="GitHub stars">
  </p>
</div>

## Overview

**Open Authenticator** was created as an alternative to closed OTP applications that lock users into
a single ecosystem or make migration difficult.

The project focuses on three core ideas :

- freedom : your authenticator should stay usable on every major platform ;
- transparency : the app is open-source and auditable ;
- interoperability : sync is available, and the backend can be self-hosted.

Open Authenticator currently targets Android, iOS, Windows, macOS and Linux.

> [!TIP]
> If you like this project, consider starring it on GitHub !

## Features

- Cross-platform Flutter application for mobile and desktop.
- Free and open-source software under the [GPL v3.0 license](https://github.com/openauthenticator-app/openauthenticator/blob/main/LICENSE).
- Secure local storage for your OTP data.
- QR code scanning and `otpauth://` link handling.
- Optional synchronization across devices with self-hostable backend support.
- Backup management and recovery flows.
- Local authentication support on compatible devices.
- Multi-language support, with [community translations](https://openauthenticator.app/translate/).

## Screenshots

<img src="https://openauthenticator.app/images/screenshots/readme/home.png" alt="Main page" height="400">
<img src="https://openauthenticator.app/images/screenshots/readme/edit.png" alt="Edit TOTP page" height="400">
<img src="https://openauthenticator.app/images/screenshots/readme/settings.png" alt="Settings page" height="400">

## Download

Prebuilt packages and store links are available on the [official website](https://openauthenticator.app/#download).

## Development Setup

### Prerequisites

- A recent stable version of **Flutter**.
- **Dart** SDK `>=3.10.0 <4.0.0`.
- Platform toolchains for the targets you want to run.

It is recommended to stay on Flutter stable :

```sh
flutter channel stable
flutter --version
```

### Clone the repository and install dependencies

To clone the repository and install dependencies, run in a shell :

```sh
git clone https://github.com/openauthenticator-app/openauthenticator.git
cd openauthenticator
flutter pub get
```

### Generate required files

Some files used by the app are generated or refreshed during setup.

First, compile SVG assets to `.si` :

```sh
dart run open_authenticator:compile_svg
```

Then, generate source files used by code generation :

```sh
dart run build_runner build --delete-conflicting-outputs
dart run slang
```

Last but not least, generate `lib/app.dart` for your local build :

```sh
dart run open_authenticator:generate
```

`open_authenticator:generate` lets you customize values such as:

- the app name and package identifiers ;
- the backend URL ;
- repository and translation links ;
- Sentry DSN ;
- RevenueCat public keys and offering ID ;
- store identifiers and legal links.

You can inspect the available options with:

```sh
dart run open_authenticator:generate --help
```

The generated file is intended for local or custom builds, so make sure it matches the environment
you want to run against.

### Run the app

To run the app :

```sh
flutter run
```

## Contributing

Contributions are more than welcome. For setup details, contribution rules and PR expectations, read the
[guidelines](https://github.com/openauthenticator-app/backend/blob/main/CONTRIBUTING.md).

You can also help by :

- reporting bugs or suggesting features in the
  [issue tracker](https://github.com/openauthenticator-app/openauthenticator/issues) ;
- improving translations through the
  [translation page](https://openauthenticator.app/translate/) ;
- submitting fixes for documentation, UI text or code.

## Support the project

If you want to support Open Authenticator financially, you can use :

- [Ko-fi](https://ko-fi.com/Skyost)
- [PayPal](https://paypal.me/Skyost)
- [GitHub Sponsors](https://github.com/sponsors/Skyost)

## License

Open Authenticator is licensed under the
[GNU General Public License v3.0](https://github.com/openauthenticator-app/openauthenticator/blob/main/LICENSE).
