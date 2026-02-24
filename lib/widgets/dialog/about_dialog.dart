import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/centered_circular_progress_indicator.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';
import 'package:open_authenticator/widgets/error.dart';

/// Allows to show an about dialog.
class AboutAppDialog extends StatelessWidget {
  /// The application name.
  final String? applicationName;

  /// The application version.
  final String? applicationVersion;

  /// The application icon.
  final Widget? applicationIcon;

  /// The application legalese.
  final String? applicationLegalese;

  /// Creates a new about dialog instance.
  const AboutAppDialog({
    super.key,
    this.applicationName,
    this.applicationVersion,
    this.applicationIcon,
    this.applicationLegalese,
  });

  @override
  Widget build(BuildContext context) => AppDialog(
    title: applicationName == null ? null : Text(MaterialLocalizations.of(context).aboutListTileTitle(applicationName!)),
    actions: [
      if (applicationLegalese != null)
        ClickableButton(
          variant: .secondary,
          onPress: () => _LicensesDialog.show(context),
          child: ButtonText(MaterialLocalizations.of(context).licensesPageTitle),
        ),
      ClickableButton(
        variant: .secondary,
        onPress: () => Navigator.pop(context),
        child: ButtonText(MaterialLocalizations.of(context).closeButtonLabel),
      ),
    ],
    children: [
      if (applicationIcon != null)
        Center(
          child: applicationIcon!,
        ),
      Center(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: applicationName,
                style: const TextStyle(fontWeight: .bold),
              ),
              if (applicationVersion != null)
                TextSpan(
                  text: ' $applicationVersion',
                ),
            ],
          ),
          style: context.theme.typography.lg,
        ),
      ),
      if (applicationLegalese != null)
        Center(
          child: Text(applicationLegalese!),
        ),
    ],
  );

  /// Opens the about dialog.
  static Future<void> show(
    BuildContext context, {
    String? applicationName,
    String? applicationVersion,
    Widget? applicationIcon,
    String? applicationLegalese,
  }) => showFDialog(
    context: context,
    builder: (context, style, animation) => AboutAppDialog(
      applicationName: applicationName,
      applicationVersion: applicationVersion,
      applicationIcon: applicationIcon,
      applicationLegalese: applicationLegalese,
    ),
  );
}

/// The licenses dialog.
class _LicensesDialog extends StatefulWidget {
  /// Creates a new licenses dialog instance.
  const _LicensesDialog();

  @override
  State<_LicensesDialog> createState() => _LicensesDialogState();

  /// Allows to show the licenses dialog.
  static Future<void> show(BuildContext context) => showFDialog(
    context: context,
    builder: (context, style, animation) => const _LicensesDialog(),
  );
}

/// The licenses dialog state.
class _LicensesDialogState extends State<_LicensesDialog> {
  @override
  Widget build(BuildContext context) => FutureBuilder<List<_PackageLicense>>(
    future: _loadLicenses(),
    builder: (context, snapshot) => AppDialog(
      title: Text(MaterialLocalizations.of(context).licensesPageTitle),
      actions: [
        ClickableButton(
          variant: .secondary,
          onPress: () => Navigator.of(context).pop(),
          child: ButtonText(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
      children: [
        if (snapshot.hasError) ErrorWithStackTrace(error: snapshot.error),
        if (snapshot.data == null)
          const Padding(
            padding: EdgeInsets.all(kBigSpace),
            child: CenteredCircularProgressIndicator(),
          )
        else
          for (_PackageLicense package in snapshot.data!)
            _PackageRow(
              title: package.package,
              onPress: () => _openDetails(
                context,
                package: package,
              ),
            ),
      ],
    ),
  );

  /// Loads the licenses.
  Future<List<_PackageLicense>> _loadLicenses() async {
    List<LicenseEntry> entries = await LicenseRegistry.licenses.toList();

    Map<String, List<LicenseParagraph>> byPkg = {};
    for (LicenseEntry entry in entries) {
      for (String pkg in entry.packages) {
        (byPkg[pkg] ??= []).addAll(entry.paragraphs);
      }
    }

    return [
      for (MapEntry<String, List<LicenseParagraph>> entry in byPkg.entries)
        _PackageLicense(
          package: entry.key,
          paragraphs: entry.value,
        ),
    ]..sort((a, b) => a.package.toLowerCase().compareTo(b.package.toLowerCase()));
  }

  /// Opens the details of a package.
  Future<void> _openDetails(
    BuildContext context, {
    required _PackageLicense package,
  }) => showFDialog(
    context: context,
    builder: (context, style, animation) => AppDialog(
      title: Text(package.package),
      actions: [
        ClickableButton(
          variant: .secondary,
          onPress: () => Navigator.of(context).pop(),
          child: ButtonText(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
      children: [
        for (LicenseParagraph paragraph in package.paragraphs)
          Padding(
            padding: EdgeInsets.only(
              left: math.max(0, paragraph.indent) * 12,
              bottom: kSpace,
            ),
            child: Text(paragraph.text),
          ),
      ],
    ),
  );
}

/// Represents a package row.
class _PackageRow extends StatelessWidget {
  /// The title of the row.
  final String title;

  /// The action to perform when the row is pressed.
  final VoidCallback onPress;

  /// Creates a new package row instance.
  const _PackageRow({
    required this.title,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) => ClickableTile(
    title: Text(title),
    onPress: onPress,
    suffix: const Icon(FIcons.chevronRight),
  );
}

/// Represents a package license.
class _PackageLicense {
  /// The package.
  final String package;

  /// The paragraphs.
  final List<LicenseParagraph> paragraphs;

  /// Creates a new package license instance.
  const _PackageLicense({
    required this.package,
    required this.paragraphs,
  });
}
