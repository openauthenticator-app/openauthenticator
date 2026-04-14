import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/main.dart';
import 'package:open_authenticator/model/crypto.dart';
import 'package:open_authenticator/model/totp/algorithm.dart';
import 'package:open_authenticator/model/totp/decrypted.dart';
import 'package:open_authenticator/model/totp/limit.dart';
import 'package:open_authenticator/model/totp/repository.dart';
import 'package:open_authenticator/model/totp/totp.dart';
import 'package:open_authenticator/pages/home/page.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/brightness_listener.dart';
import 'package:open_authenticator/utils/form_label.dart';
import 'package:open_authenticator/utils/result.dart';
import 'package:open_authenticator/utils/utils.dart';
import 'package:open_authenticator/widgets/app_scaffold.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/confirmation_dialog.dart';
import 'package:open_authenticator/widgets/dialog/logo_search/dialog.dart';
import 'package:open_authenticator/widgets/dialog/totp_limit_dialog.dart';
import 'package:open_authenticator/widgets/expandable_tile.dart';
import 'package:open_authenticator/widgets/form/password_form_field.dart';
import 'package:open_authenticator/widgets/toast.dart';
import 'package:open_authenticator/widgets/totp/image.dart';
import 'package:open_authenticator/widgets/waiting_overlay.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Allows to edit a TOTP.
class TotpPage extends ConsumerStatefulWidget {
  /// The TOTP page name.
  static const String name = '/totp';

  /// The TOTP instance.
  final DecryptedTotp? totp;

  /// The image size.
  final double imageSize;

  /// Whether we should add a TOTP or edit a TOTP.
  final bool add;

  /// Creates a new TOTP display page instance.
  const TotpPage({
    super.key,
    this.totp,
    this.imageSize = 150,
    bool? add,
  }) : add = add ?? totp == null;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _TotpPageState();

  /// Opens this page from a scanned [uri].
  static Future<void> openFromUri(BuildContext context, WidgetRef ref, Uri uri) async {
    CryptoStore? cryptoStore = await ref.read(cryptoStoreProvider.future);
    DecryptedTotp? totp = await DecryptedTotp.fromUri(uri, cryptoStore);
    if (!context.mounted) {
      return;
    }
    if (totp == null) {
      showErrorToast(context, text: translations.totp.page.uriError);
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      TotpPage.name,
      (route) => route.settings.name == HomePage.name,
      arguments: {
        OpenAuthenticatorApp.kRouteParameterTotp: totp,
        OpenAuthenticatorApp.kRouteParameterAddTotp: true,
      },
    );
  }
}

/// The TOTP edit page state.
class _TotpPageState extends ConsumerState<TotpPage> with BrightnessListener {
  /// The form key.
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  /// The TOTP image URL.
  late String? imageUrl = widget.totp?.imageUrl;

  /// The TOTP label.
  late String label = widget.totp?.label ?? '';

  /// The TOTP data.
  late String secret = widget.totp?.secret ?? '';

  /// The TOTP issuer.
  late String issuer = widget.totp?.issuer ?? '';

  /// The TOTP algorithm.
  late Algorithm? algorithm = widget.totp?.algorithm;

  /// The TOTP digits.
  late int? digits = widget.totp?.digits;

  /// The TOTP validity.
  late Duration? validity = widget.totp?.validity;

  /// The label controller.
  late final TextEditingController labelController = TextEditingController(text: label)
    ..addListener(() {
      if (mounted) {
        setState(() => label = labelController.value.text);
      }
    });

  /// The secret controller.
  late final TextEditingController secretController = TextEditingController(text: secret)
    ..addListener(() {
      if (mounted) {
        setState(() => secret = secretController.value.text);
      }
    });

  /// The issuer controller.
  late final TextEditingController issuerController = TextEditingController(text: issuer)
    ..addListener(() {
      if (mounted) {
        setState(() => issuer = issuerController.value.text);
      }
    });

  /// The algorithm controller.
  late final FSelectController<Algorithm> algorithmController =
      FSelectController(
        value: algorithm,
      )..addListener(() {
        if (mounted) {
          setState(() => algorithm = algorithmController.value);
        }
      });

  /// The digits controller.
  late final TextEditingController digitsController = TextEditingController(text: digits?.toString())
    ..addListener(() {
      if (mounted) {
        setState(() => digits = int.tryParse(digitsController.value.text));
      }
    });

  /// The validity controller.
  late final TextEditingController validityController = TextEditingController(text: validity?.inSeconds.toString())
    ..addListener(() {
      if (mounted) {
        int? validity = int.tryParse(validityController.value.text);
        setState(() => this.validity = validity == null ? null : Duration(seconds: validity));
      }
    });

  /// Whether the form is enabled.
  bool enabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.totp != null) {
        formKey.currentState?.validate();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: AppScaffold.scrollable(
      header: FHeader.nested(
        title: Text(widget.add ? translations.totp.page.title.add : translations.totp.page.title.edit),
        prefixes: [
          if (widget.add)
            ClickableHeaderAction.back(
              onPress: () => Navigator.pop(context),
            )
          else
            ClickableHeaderAction.x(
              onPress: () => Navigator.pop(context),
            ),
        ],
        suffixes: [
          if (!widget.add)
            ClickableHeaderAction(
              onPress: () async {
                bool confirmation = await ConfirmationDialog.ask(
                  context,
                  title: translations.totp.actions.deleteConfirmationDialog.title,
                  message: translations.totp.actions.deleteConfirmationDialog.message,
                  okButtonVariant: .destructive,
                );
                if (!confirmation || !context.mounted) {
                  return;
                }
                Result result = await showWaitingOverlay(
                  context,
                  future: ref.read(totpRepositoryProvider.notifier).deleteTotp(widget.totp!.uuid),
                );
                if (!context.mounted) {
                  return;
                }
                context.handleResult(result);
                if (result is ResultSuccess) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(FIcons.trash),
            ),
        ],
      ),
      footer: ClickableButton(
        style: .delta(
          contentStyle: .delta(
            padding: .value(
              EdgeInsets.only(
                top: kBigSpace,
                right: kBigSpace,
                bottom: kBigSpace + MediaQuery.paddingOf(context).bottom,
                left: kBigSpace,
              ),
            ),
          ),
          decoration: .delta(
            [
              .all(
                const .boxDelta(borderRadius: BorderRadius.zero),
              ),
            ],
          ),
        ),
        onPress: isValidTotp && enabled
            ? () async {
                bool validateResult = formKey.currentState!.validate();
                if (!validateResult) {
                  return;
                }
                setState(() => enabled = false);
                formKey.currentState!.save();
                Result editResult = await (widget.add ? addTotp() : updateTotp());
                if (!context.mounted) {
                  return;
                }
                setState(() => enabled = true);
                context.handleResult(editResult);
                if (editResult is ResultSuccess) {
                  Navigator.pop(context);
                }
              }
            : null,
        prefix: const Icon(FIcons.check),
        child: ButtonText(translations.totp.page.save),
      ),
      children: [
        ClickableTile.raw(
          child: Column(
            spacing: kSpace,
            children: [
              if (enabled)
                FTappable(
                  builder: (context, states, child) => Container(
                    decoration: BoxDecoration(
                      color: (states.contains(FTappableVariant.hovered) || states.contains(FTappableVariant.pressed)) ? context.theme.colors.secondary : context.theme.colors.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.theme.colors.border),
                    ),
                    width: widget.imageSize + 2,
                    height: widget.imageSize + 2,
                    child: child!,
                  ),
                  child: createImageWidget(),
                  onPress: () async {
                    String? imageUrl = await LogoPickerDialog.openDialog(context, initialSearchKeywords: issuer);
                    if (imageUrl != null && mounted) {
                      setState(() => this.imageUrl = imageUrl);
                    }
                  },
                )
              else
                createImageWidget(),
              FTextFormField(
                label: FormLabelWithIcon(
                  icon: FIcons.tag,
                  text: translations.totp.page.label.text,
                ),
                hint: translations.totp.page.label.hint,
                control: .managed(controller: labelController),
                validator: validateLabel,
                enabled: enabled,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              PasswordFormField(
                label: FormLabelWithIcon(
                  icon: FIcons.rectangleEllipsis,
                  text: translations.totp.page.secret.text,
                ),
                hint: translations.totp.page.secret.hint,
                control: .managed(controller: secretController),
                enabled: widget.add && enabled,
                validator: validateSecret,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              FTextFormField(
                label: FormLabelWithIcon(
                  icon: FIcons.rectangleEllipsis,
                  text: translations.totp.page.issuer.text,
                ),
                hint: translations.totp.page.issuer.hint,
                control: .managed(controller: issuerController),
                validator: validateIssuer,
                enabled: enabled,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: kBigSpace),
          child: ExpandableTile(
            title: Text(translations.totp.page.advancedOptions),
            children: createAdvancedOptionsWidgets(),
          ),
        ),
        if (isValidTotp)
          Padding(
            padding: const EdgeInsets.only(top: kBigSpace),
            child: ExpandableTile(
              title: Text(translations.totp.page.showQrCode),
              children: [createQrCodeWidget(context)],
            ),
          ),
      ],
    ),
  );

  /// Creates the advanced options widgets.
  List<Widget> createAdvancedOptionsWidgets() => [
    FSelect<Algorithm>(
      control: .managed(controller: algorithmController),
      label: FormLabelWithIcon(
        icon: FIcons.tag,
        text: translations.totp.page.algorithm,
      ),
      items: {
        for (Algorithm algorithm in Algorithm.values) algorithm.name.toUpperCase(): algorithm,
      },
      hint: Totp.kDefaultAlgorithm.name.toUpperCase(),
      enabled: enabled,
    ),
    FTextFormField(
      control: .managed(controller: digitsController),
      keyboardType: const TextInputType.numberWithOptions(),
      label: FormLabelWithIcon(
        icon: FIcons.binary,
        text: translations.totp.page.digits,
      ),
      hint: Totp.kDefaultDigits.toString(),
      validator: validateDigits,
      enabled: enabled,
    ),
    FTextFormField(
      control: .managed(controller: validityController),
      keyboardType: const TextInputType.numberWithOptions(),
      label: FormLabelWithIcon(
        icon: FIcons.clock,
        text: translations.totp.page.validity,
      ),
      hint: Totp.kDefaultValidity.inSeconds.toString(),
      validator: validateValidity,
      enabled: enabled,
    ),
  ];

  @override
  void dispose() {
    labelController.dispose();
    secretController.dispose();
    issuerController.dispose();
    algorithmController.dispose();
    digitsController.dispose();
    validityController.dispose();
    super.dispose();
  }

  /// Creates the image widget.
  Widget createImageWidget() => UnconstrainedBox(
    child: SizedBox(
      height: widget.imageSize,
      width: widget.imageSize,
      child: TotpImage(
        label: label,
        issuer: issuer,
        imageUrl: imageUrl,
        size: widget.imageSize,
      ),
    ),
  );

  /// Creates the QR code widget.
  Widget createQrCodeWidget(BuildContext context) {
    Color color = currentBrightness == Brightness.light ? context.theme.colors.primary : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpace),
      child: Center(
        child: QrImageView(
          data: DecryptedTotp.toUri(
            secret: secret.toUpperCase(),
            label: label,
            issuer: issuer,
            algorithm: algorithm,
            digits: digits,
            validity: validity,
          ).toString(),
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          size: 200,
          eyeStyle: QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: color,
          ),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: color,
          ),
        ),
      ),
    );
  }

  /// Whether the TOTP is valid.
  bool get isValidTotp => validateSecret() == null && validateLabel() == null && validateIssuer() == null && validateDigits() == null && validateValidity() == null;

  /// Validates the [secret].
  String? validateSecret([String? secret]) {
    secret ??= this.secret;
    secret = secret.toUpperCase();
    if (secret.isEmpty) {
      return translations.error.validation.empty;
    }
    if (!isValidBase32(secret)) {
      return translations.error.validation.secret;
    }
    return null;
  }

  /// Validates the [label].
  String? validateLabel([String? label]) {
    label ??= this.label;
    if (label.isEmpty) {
      return translations.error.validation.empty;
    }
    return null;
  }

  /// Validates the [issuer].
  String? validateIssuer([String? issuer]) {
    issuer ??= this.issuer;
    if (issuer.isEmpty) {
      return translations.error.validation.empty;
    }
    return null;
  }

  /// Validates the [digits].
  String? validateDigits([String? digits]) {
    if (digits == null || digits.isEmpty) {
      return null;
    }
    int? parsedDigits = int.tryParse(digits);
    if (parsedDigits == null) {
      return translations.error.validation.number;
    }
    if (parsedDigits < 6) {
      return translations.error.validation.totpDigits;
    }
    return null;
  }

  /// Validates the [validity].
  String? validateValidity([String? validity]) {
    if (validity == null || validity.isEmpty) {
      return null;
    }
    int? parsedValidity = int.tryParse(validity);
    if (parsedValidity == null) {
      return translations.error.validation.number;
    }
    return null;
  }

  /// Adds the TOTP to the repository.
  Future<Result> addTotp() async {
    bool willExceed = (await ref.read(totpLimitProvider.future)).willExceedIfAddMore(count: 1);
    if (willExceed) {
      if (mounted) {
        await TotpLimitDialog.show(context);
      }
      return const ResultCancelled();
    }

    DecryptedTotp? totp = await _createTotp();
    if (totp == null) {
      return ResultError(exception: _TotpCreationFailed());
    }
    return await ref.read(totpRepositoryProvider.notifier).addTotp(totp);
  }

  /// Updates the TOTP in the repository.
  Future<Result> updateTotp() async {
    DecryptedTotp? totp = await _createTotp();
    if (totp == null) {
      return ResultError(exception: _TotpCreationFailed());
    }
    return await ref.read(totpRepositoryProvider.notifier).updateTotp(totp);
  }

  /// Creates a [DecryptedTotp] corresponding to the current fields.
  Future<DecryptedTotp?> _createTotp() async => await DecryptedTotp.create(
    cryptoStore: await ref.read(cryptoStoreProvider.future),
    uuid: widget.totp?.uuid,
    secret: secret.toUpperCase(),
    label: label,
    issuer: issuer,
    algorithm: algorithm,
    digits: digits,
    validity: validity,
    imageUrl: imageUrl,
  );
}

/// Triggered when TOTP creation has failed.
class _TotpCreationFailed extends LocalizableException {
  /// Creates a new TOTP creation failed exception instance.
  _TotpCreationFailed()
    : super(
        localizedErrorMessage: translations.error.totp.create,
      );
}
