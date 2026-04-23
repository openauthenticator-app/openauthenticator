import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// A widget that is clickable, and therefore displays a [SystemMouseCursors.click] cursor.
class Clickable extends StatelessWidget with FTileMixin, FItemMixin {
  /// The child.
  final Widget child;

  /// Creates a new clickable widget instance.
  const Clickable({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: child,
  );
}

/// Allows to easily make a widget clickable.
extension MakeClickable on Widget {
  /// Makes the current widget clickable.
  Widget clickable({bool clickable = true}) => clickable ? Clickable(child: this) : this;
}

/// A clickable tile.
class ClickableTile extends FTile {
  /// Creates a new clickable tile instance.
  ClickableTile({
    super.key,
    required super.title,
    super.variant,
    super.style,
    super.enabled,
    super.selected = false,
    super.semanticsLabel,
    super.autofocus = false,
    super.focusNode,
    super.onFocusChange,
    super.onHoverChange,
    super.onVariantChange,
    super.onPress,
    super.onLongPress,
    super.onSecondaryPress,
    super.onSecondaryLongPress,
    super.shortcuts,
    super.actions,
    super.prefix,
    Widget? subtitle,
    super.details,
    super.suffix,
    int? maxDescriptionLines = 10,
  }) : super(
         subtitle: maxDescriptionLines == null || subtitle == null
             ? subtitle
             : DefaultTextStyle.merge(
                 maxLines: 10,
                 textAlign: .left,
                 child: subtitle,
               ),
       );

  /// Creates a new clickable raw tile instance.
  ClickableTile.raw({
    super.key,
    required super.child,
    super.variant,
    super.style,
    super.enabled,
    super.selected = false,
    super.semanticsLabel,
    super.autofocus = false,
    super.focusNode,
    super.onFocusChange,
    super.onHoverChange,
    super.onVariantChange,
    super.onPress,
    super.onLongPress,
    super.onSecondaryPress,
    super.onSecondaryLongPress,
    super.shortcuts,
    super.actions,
    super.prefix,
  }) : super.raw();

  @override
  Widget build(BuildContext context) => super
      .build(context)
      .clickable(
        clickable: enabled != false && (onPress != null || onLongPress != null),
      );
}

/// A clickable button.
class ClickableButton extends FButton {
  /// Creates a new clickable button instance.
  ClickableButton({
    super.key,
    required super.onPress,
    required super.child,
    super.variant,
    super.style,
    super.onLongPress,
    super.onSecondaryPress,
    super.onSecondaryLongPress,
    super.autofocus,
    super.focusNode,
    super.onFocusChange,
    super.onHoverChange,
    super.onVariantChange,
    super.selected,
    super.shortcuts,
    super.actions,
    super.mainAxisSize,
    super.mainAxisAlignment,
    super.crossAxisAlignment,
    super.textBaseline,
    super.prefix,
    super.suffix,
  });

  /// Creates a new clickable button icon instance.
  ClickableButton.icon({
    super.key,
    required super.onPress,
    required super.child,
    super.variant,
    super.style,
    super.onLongPress,
    super.onSecondaryPress,
    super.onSecondaryLongPress,
    super.autofocus,
    super.focusNode,
    super.onFocusChange,
    super.onHoverChange,
    super.onVariantChange,
    super.selected,
    super.shortcuts,
    super.actions,
  }) : super.icon();

  /// Creates a new clickable raw button instance.
  const ClickableButton.raw({
    super.key,
    required super.onPress,
    required super.child,
    super.variant,
    super.style,
    super.onLongPress,
    super.onSecondaryPress,
    super.onSecondaryLongPress,
    super.autofocus,
    super.focusNode,
    super.onFocusChange,
    super.onHoverChange,
    super.onVariantChange,
    super.selected,
    super.shortcuts,
    super.actions,
  }) : super.raw();

  @override
  Widget build(BuildContext context) => super
      .build(context)
      .clickable(
        clickable: onPress != null || onLongPress != null,
      );
}

/// A clickable header action.
class ClickableHeaderAction extends FHeaderAction {
  /// Creates a new clickable header action instance.
  const ClickableHeaderAction({
    super.key,
    required super.icon,
    required super.onPress,
    super.style,
    super.semanticsLabel,
    super.selected = false,
    super.autofocus = false,
    super.focusNode,
    super.onFocusChange,
    super.onHoverChange,
    super.onVariantChange,
    super.onLongPress,
    super.onSecondaryPress,
    super.onSecondaryLongPress,
    super.shortcuts,
    super.actions,
  });

  /// Creates a new clickable header back action instance.
  const ClickableHeaderAction.back({
    Key? key,
    required VoidCallback? onPress,
    FHeaderActionStyle? style,
    bool autofocus = false,
    FocusNode? focusNode,
    ValueChanged<bool>? onFocusChange,
    ValueChanged<bool>? onHoverChange,
    FTappableVariantChangeCallback? onVariantChange,
    VoidCallback? onLongPress,
    VoidCallback? onSecondaryPress,
    VoidCallback? onSecondaryLongPress,
    Map<ShortcutActivator, Intent>? shortcuts,
    Map<Type, Action<Intent>>? actions,
  }) : this(
         key: key,
         icon: const Icon(FIcons.arrowLeft),
         onPress: onPress,
         style: style,
         autofocus: autofocus,
         focusNode: focusNode,
         onFocusChange: onFocusChange,
         onHoverChange: onHoverChange,
         onVariantChange: onVariantChange,
         onLongPress: onLongPress,
         onSecondaryPress: onSecondaryPress,
         onSecondaryLongPress: onSecondaryLongPress,
         shortcuts: shortcuts,
         actions: actions,
       );

  /// Creates a new clickable header X action instance.
  const ClickableHeaderAction.x({
    Key? key,
    required VoidCallback? onPress,
    FHeaderActionStyle? style,
    bool autofocus = false,
    FocusNode? focusNode,
    ValueChanged<bool>? onFocusChange,
    ValueChanged<bool>? onHoverChange,
    FTappableVariantChangeCallback? onVariantChange,
    VoidCallback? onLongPress,
    VoidCallback? onSecondaryPress,
    VoidCallback? onSecondaryLongPress,
    Map<ShortcutActivator, Intent>? shortcuts,
    Map<Type, Action<Intent>>? actions,
  }) : this(
         key: key,
         icon: const Icon(FIcons.x),
         onPress: onPress,
         style: style,
         autofocus: autofocus,
         focusNode: focusNode,
         onFocusChange: onFocusChange,
         onHoverChange: onHoverChange,
         onVariantChange: onVariantChange,
         onLongPress: onLongPress,
         onSecondaryPress: onSecondaryPress,
         onSecondaryLongPress: onSecondaryLongPress,
         shortcuts: shortcuts,
         actions: actions,
       );

  @override
  Widget build(BuildContext context) => super
      .build(context)
      .clickable(
        clickable: onPress != null || onLongPress != null,
      );
}
