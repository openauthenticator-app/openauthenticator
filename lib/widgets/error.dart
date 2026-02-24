import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/app.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/widgets/button_text.dart';
import 'package:open_authenticator/widgets/clickable.dart';
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
          title: const Text('Erreur'),
          subtitle: ErrorWithStackTrace(error: error, stackTrace: stackTrace),
        ),
      ),
      Padding(
        padding: EdgeInsets.only(bottom: onRetryPressed == null ? 0 : kSpace),
        child: FutureBuilder(
          future: canLaunchUrl(reportIssueUrl),
          builder: (context, asyncSnapshot) => ClickableButton(
            onPress: asyncSnapshot.data == true ? () => launchUrl(reportIssueUrl) : null,
            variant: .outline,
            prefix: const Icon(FIcons.bug),
            child: const ButtonText('Signaler'),
          ),
        ),
      ),
      if (onRetryPressed != null)
        ClickableButton(
          onPress: onRetryPressed,
          prefix: const Icon(FIcons.refreshCcw),
          child: const ButtonText('Réessayer'),
        ),
    ],
  );

  /// The issues URL.
  Uri get reportIssueUrl => Uri.parse('${App.githubRepositoryUrl}/issues');
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
        child: Text(widget.error == null ? 'Une erreur est survenue.' : 'Une erreur est survenue : "$truncatedError".'),
      ),
      if (widget.message != null)
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace),
          child: Text(widget.message!),
        ),
      if (widget.onRetryPressed != null)
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace),
          child: ClickableButton(
            onPress: widget.onRetryPressed,
            child: const ButtonText('Réessayer'),
          ),
        ),
      FSwitch(
        label: Text(expanded ? 'Masquer la trace' : 'Afficher la trace'),
        value: expanded,
        onChange: toggleStackTrace,
        style: .delta(
          childPadding: .value(EdgeInsets.only(right: context.theme.switchStyle.childPadding.horizontal / 2)),
          trackColor: .delta(
            [
              .match({.selected}, context.theme.colors.error),
            ],
          ),
        ),
      ),
      AnimatedBuilder(
        animation: animation,
        builder: (context, child) => FCollapsible(
          value: animation.value,
          child: child!,
        ),
        child: Text(
          '${widget.error}\n${widget.stackTrace ?? StackTrace.current}',
          style: TextStyle(fontSize: context.theme.typography.xs.fontSize),
          textAlign: TextAlign.left,
        ),
      ),
    ],
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// The truncated error.
  String get truncatedError {
    if (widget.error == null) {
      return '';
    }
    String error = widget.error.toString();
    return error.length > 20 ? '${error.substring(0, 20)}...' : error;
  }

  /// Toggles the stacktrace.
  void toggleStackTrace([bool? value]) {
    setState(() => expanded = value ?? !expanded);
    controller.toggle();
  }
}
