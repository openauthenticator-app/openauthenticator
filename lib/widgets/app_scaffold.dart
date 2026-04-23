import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/widgets/error.dart';

/// Scaffold for the app.
class AppScaffold extends StatelessWidget {
  /// The header of the scaffold.
  final Widget? header;

  /// The children of the scaffold.
  final List<Widget> children;

  /// The footer of the scaffold.
  final Widget? footer;

  /// Whether to center the list.
  final bool center;

  /// The padding of the scaffold.
  final EdgeInsets? padding;

  /// The scaffold style.
  final FScaffoldStyleDelta scaffoldStyle;

  /// Builds a list of widgets.
  final Widget Function(List<Widget> children, EdgeInsets padding) _widgetBuilder;

  /// Creates a new app scaffold instance.
  const AppScaffold({
    super.key,
    this.header,
    required this.children,
    this.footer,
    this.center = false,
    this.padding,
    this.scaffoldStyle = const .context(),
  }) : _widgetBuilder = _defaultWidgetBuilder;

  /// Creates a new scrollable app scaffold instance.
  const AppScaffold.scrollable({
    super.key,
    this.header,
    required this.children,
    this.footer,
    this.center = false,
    this.padding,
    this.scaffoldStyle = const .context(),
  }) : _widgetBuilder = _defaultScrollableWidgetBuilder;

  /// Creates a new app scaffold instance from an [asyncValue].
  static AppScaffold asyncValue<T>({
    bool scrollable = true,
    Widget? header,
    Widget Function(T value)? headerBuilder,
    Widget? footer,
    Widget Function(T value)? footerBuilder,
    EdgeInsets? padding,
    EdgeInsets Function(T value)? paddingBuilder,
    bool? center,
    FScaffoldStyleDelta scaffoldStyle = const .context(),
    required AsyncValue<T> asyncValue,
    required List<Widget> Function(T value) builder,
    VoidCallback? onRetryPressed,
  }) => (scrollable ? AppScaffold.scrollable : AppScaffold.new)(
    header: switch (asyncValue) {
      AsyncValue(:final value, hasValue: true) => headerBuilder?.call(value!) ?? header,
      AsyncError() => header,
      _ => header,
    },
    footer: switch (asyncValue) {
      AsyncValue(:final value, hasValue: true) => footerBuilder?.call(value!) ?? footer,
      AsyncError() => footer,
      _ => footer,
    },
    scaffoldStyle: scaffoldStyle,
    padding: switch (asyncValue) {
      AsyncValue(:final value, hasValue: true) => paddingBuilder?.call(value!) ?? padding,
      AsyncError() => padding,
      _ => padding,
    },
    center: (() {
      if (asyncValue.hasError) {
        return false;
      }
      if (asyncValue.isLoading || !asyncValue.hasValue) {
        return true;
      }
      if (center != null) {
        return center;
      }
      if (asyncValue.value is Iterable) {
        return (asyncValue.value as Iterable).isEmpty;
      }
      return false;
    })(),
    children: switch (asyncValue) {
      AsyncValue(:final value, hasValue: true) => builder(value!),
      AsyncError(:final error, :final stackTrace) => [
        ErrorAlert(
          error: error,
          stackTrace: stackTrace,
          onRetryPressed: onRetryPressed,
        ),
      ],
      _ => [
        const CircularProgressIndicator(),
      ],
    },
  );

  @override
  Widget build(BuildContext context) {
    Widget child = _widgetBuilder.call(children, padding ?? context.theme.style.pagePadding);
    return FScaffold(
      scaffoldStyle: scaffoldStyle,
      childPad: false,
      header: header,
      footer: footer,
      child: center ? Center(child: child) : child,
    );
  }

  /// Builds the non-scrollable widget.
  static Widget _defaultWidgetBuilder(List<Widget> children, EdgeInsets padding) => Padding(
    padding: padding,
    child: children.length == 1
        ? children.first
        : Column(
            mainAxisSize: .min,
            children: children,
          ),
  );

  /// Builds the scrollable widget.
  static Widget _defaultScrollableWidgetBuilder(List<Widget> children, EdgeInsets padding) => children.length == 1
      ? SingleChildScrollView(
          padding: padding,
          child: children.first,
        )
      : ListView(
          shrinkWrap: true,
          padding: padding,
          children: children,
        );
}
