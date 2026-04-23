part of '../page.dart';

/// A widget that triggers a callback when the user scrolls, so that the search box can be hidden or shown.
class _RevealSearchBoxWidget extends ConsumerWidget {
  /// Called when the user scrolls up.
  final VoidCallback? onShowSearchBox;

  /// Called when the user scrolls down.
  final VoidCallback? onHideSearchBox;

  /// The child widget.
  final Widget child;

  /// Creates a new reveal search box widget instance.
  const _RevealSearchBoxWidget({
    super.key,
    this.onShowSearchBox,
    this.onHideSearchBox,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => (ref.watch(displaySearchButtonSettingsEntryProvider).value ?? true)
      ? child
      : NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is OverscrollNotification && notification.overscroll < 0) {
              onShowSearchBox?.call();
              return true;
            } else if ((notification is OverscrollNotification && notification.overscroll > 0) || (notification is ScrollUpdateNotification && notification.metrics.pixels > 0)) {
              onHideSearchBox?.call();
            }
            return false;
          },
          child: child,
        );
}
