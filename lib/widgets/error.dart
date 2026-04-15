import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/i18n/localizable_exception.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/uri_builder.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/toast.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget displaying an error with the option to retry.
class ErrorAlert extends StatelessWidget {
  /// The error.
  final Object error;

  /// The stacktrace.
  final StackTrace stackTrace;

  /// The callback to call when the user wants to retry.
  final VoidCallback? onRetryPressed;

  /// Creates a new error display widget instance.
  const ErrorAlert({
    super.key,
    required this.error,
    required this.stackTrace,
    this.onRetryPressed,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: kSpace),
        child: FAlert(
          variant: .destructive,
          title: Text(translations.error.widget.title),
          subtitle: ErrorWithStackTrace(
            error: error,
            stackTrace: stackTrace,
          ),
        ),
      ),
      Padding(
        padding: .only(bottom: onRetryPressed == null ? 0 : kSpace),
        child: FutureBuilder(
          future: canLaunchUrl(reportIssueUrl),
          builder: (context, asyncSnapshot) => ClickableButton(
            onPress: asyncSnapshot.data == true ? () => launchUrl(reportIssueUrl) : null,
            variant: .outline,
            prefix: const Icon(FIcons.bug),
            child: ButtonText(translations.error.widget.button.report),
          ),
        ),
      ),
      if (onRetryPressed != null)
        ClickableButton(
          onPress: onRetryPressed,
          prefix: const Icon(FIcons.refreshCcw),
          child: ButtonText(translations.error.widget.button.retry),
        ),
    ],
  );

  /// The issues URL.
  Uri get reportIssueUrl => UriBuilder.prefix(
    prefix: App.githubRepositoryUrl,
    path: '/issues',
  ).build();
}

/// A widget displaying an error.
class ErrorWithStackTrace extends StatefulWidget {
  /// The additional message to display.
  final String? message;

  /// The error.
  final Object? error;

  /// The stacktrace.
  final StackTrace? stackTrace;

  /// The callback to call when the user wants to retry.
  final VoidCallback? onRetryPressed;

  /// Creates an error widget.
  const ErrorWithStackTrace({
    super.key,
    this.message,
    this.error,
    this.stackTrace,
    this.onRetryPressed,
  });

  @override
  State<StatefulWidget> createState() => _ErrorWithStackTraceState();
}

/// The error widget state.
class _ErrorWithStackTraceState extends State<ErrorWithStackTrace> with SingleTickerProviderStateMixin<ErrorWithStackTrace> {
  /// The animation controller.
  late final AnimationController controller = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );

  /// The reveal stacktrace animation.
  late final Animation<double> animation = CurvedAnimation(
    parent: controller,
    curve: Curves.easeInOut,
  );

  /// Whether the stacktrace is expanded.
  bool expanded = false;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: kSpace),
        child: Text(description),
      ),
      if (message != null)
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace),
          child: Text(message!),
        ),
      if (widget.onRetryPressed != null)
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace),
          child: ClickableButton(
            onPress: widget.onRetryPressed,
            child: ButtonText(translations.error.widget.button.retry),
          ),
        ),
      Row(
        mainAxisSize: .max,
        children: [
          Expanded(
            child: FSwitch(
              label: Text(expanded ? translations.error.widget.stackTrace.hide : translations.error.widget.stackTrace.show),
              value: expanded,
              onChange: toggleStackTrace,
              style: .delta(
                trackColor: .delta(
                  [
                    .match({.selected}, context.theme.colors.error),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            ClickableButton.icon(
              onPress: () async {
                try {
                  HapticFeedback.mediumImpact();
                  await Clipboard.setData(
                    ClipboardData(
                      text: details,
                    ),
                  );
                  if (context.mounted) {
                    showSuccessToast(
                      context,
                      text: translations.error.noError,
                    );
                  }
                } catch (ex) {
                  if (context.mounted) {
                    showErrorToast(
                      context,
                      text: translations.error.generic.withException(
                        exception: ex,
                      ),
                    );
                  }
                }
              },
              variant: .ghost,
              child: const Icon(FIcons.copy),
            ),
        ],
      ),
      AnimatedBuilder(
        animation: animation,
        builder: (context, child) => FCollapsible(
          value: animation.value,
          child: child!,
        ),
        child: FCard(
          child: SelectableText(
            details,
            style: TextStyle(fontSize: context.theme.typography.xs.fontSize),
            textAlign: TextAlign.left,
          ),
        ),
      ),
    ],
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Returns the description to display.
  String get description {
    String description;
    if (widget.error != null) {
      String exception;
      if (widget.error is LocalizableException) {
        exception = widget.error.runtimeType.toString();
      } else {
        String error = widget.error.toString();
        exception = error.length > 20 ? '${error.substring(0, 20)}...' : error;
      }
      description = translations.error.generic.withException(exception: exception);
    } else {
      description = translations.error.generic.noException;
    }
    if (message == null) {
      description += ' ${translations.error.generic.tryAgain}';
    }
    return description;
  }

  /// Returns the message to display.
  String? get message {
    if (widget.message != null) {
      return widget.message;
    }
    if (widget.error is LocalizableException) {
      return (widget.error as LocalizableException).localizedErrorMessage;
    }
    return null;
  }

  /// Returns the details to display.
  String get details => '${widget.error}\n${widget.stackTrace ?? StackTrace.current}';

  /// Toggles the stacktrace.
  void toggleStackTrace([bool? value]) {
    setState(() => expanded = value ?? !expanded);
    controller.toggle();
  }
}
