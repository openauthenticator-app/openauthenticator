part of '../page.dart';

/// Allows to display a refresh indicator.
class _TotpsRefreshIndicatorWidget extends StatelessWidget {
  /// The refresh indicator callback.
  final AsyncCallback onRefresh;

  /// The child widget.
  final Widget child;

  /// Creates a new refresh indicator widget instance.
  const _TotpsRefreshIndicatorWidget({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => CustomRefreshIndicator(
    onRefresh: onRefresh,
    builder: (context, child, controller) {
      double iconSize = 30;
      return Stack(
        alignment: Alignment.center,
        children: [
          if (!controller.isIdle)
            Positioned(
              top: 35 * controller.value,
              left: context.theme.style.pagePadding.left,
              right: context.theme.style.pagePadding.right,
              child: controller.isLoading
                  ? FCircularProgress(
                      style: .delta(
                        iconStyle: .delta(size: iconSize),
                      ),
                    )
                  : Icon(
                      FIcons.loaderCircle,
                      size: iconSize,
                    ),
            ),
          Transform.translate(
            offset: Offset(0, 3 * iconSize * controller.value),
            child: child,
          ),
        ],
      );
    },
    child: child,
  );
}
