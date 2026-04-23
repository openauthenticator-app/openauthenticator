part of '../page.dart';

/// A widget that triggers a callback when the user scrolls, so that the floating action button can be hidden or shown.
class _RevealFloatingActionButtonWidget extends StatelessWidget {
  /// Whether to display the floating action button initially.
  static final bool hasFloatingActionButton = currentPlatform == Platform.android || kDebugMode;

  /// Called when the user scrolls up.
  final VoidCallback? onHideFloatingActionButton;

  /// Called when the user scrolls down.
  final VoidCallback? onShowFloatingActionButton;

  /// The child widget.
  final Widget child;

  /// Creates a new reveal floating action button widget instance.
  const _RevealFloatingActionButtonWidget({
    super.key,
    this.onHideFloatingActionButton,
    this.onShowFloatingActionButton,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => hasFloatingActionButton
      ? NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.maxScrollExtent != notification.metrics.minScrollExtent) {
              ScrollDirection direction = notification.direction;
              if (direction == ScrollDirection.reverse) {
                onHideFloatingActionButton?.call();
              } else if (direction == ScrollDirection.forward) {
                onShowFloatingActionButton?.call();
              }
            }
            return false;
          },
          child: child,
        )
      : child;
}

/// The floating add button widget.
class _FloatingAddButton extends StatelessWidget {
  /// Whether to display the floating action button.
  final bool showFloatingActionButton;

  /// Triggered when the "Add" button is pressed.
  final Function(BuildContext) onAddButtonPress;

  /// Creates a new floating add button instance.
  const _FloatingAddButton({
    super.key,
    required this.showFloatingActionButton,
    required this.onAddButtonPress,
  });

  @override
  Widget build(BuildContext context) {
    BoxDecoration createGradient(double darken) => BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: context.theme.style.shadow,
      gradient: LinearGradient(
        begin: const Alignment(-1, -1),
        end: const Alignment(0.8, 0.8),
        colors: [
          for (Color color in AppTitleGradient.gradient.colors) color.darken(amount: darken),
        ],
        stops: AppTitleGradient.gradient.stops,
      ),
    );
    return AnimatedSlide(
      duration: const Duration(milliseconds: 200),
      offset: showFloatingActionButton ? Offset.zero : const Offset(0, 2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: showFloatingActionButton ? 1 : 0,
        child: Padding(
          padding: context.theme.style.pagePadding,
          child: ClickableButton(
            style: .delta(
              decoration: .delta([
                .match({.hovered}, .value(createGradient(0.05))),
                .base(.value(createGradient(0))),
              ]),
            ),
            mainAxisSize: .min,
            child: const Icon(
              FIcons.plus,
              size: 40,
              color: Colors.white,
            ),
            onPress: () => onAddButtonPress(context),
          ),
        ),
      ),
    );
  }
}
