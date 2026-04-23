import 'dart:async';

import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:forui/forui.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:window_manager/window_manager.dart';

/// Allows to display a window frame.
class DesktopWindowFrame extends StatelessWidget {
  /// The child widget.
  final Widget child;

  /// Creates a new window frame widget instance.
  const DesktopWindowFrame({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => currentPlatform.isDesktop
      ? Column(
          mainAxisSize: .min,
          children: [
            Container(
              color: context.theme.colors.background,
              padding: const EdgeInsets.all(kSpace),
              child: _DragArea(),
            ),
            Expanded(child: child),
          ],
        )
      : child;
}

/// Drag area for the app.
class _DragArea extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _DragAreaState();
}

/// The drag area widget state.
class _DragAreaState extends State<_DragArea> with WindowListener {
  /// Whether the drag area is loading.
  bool isLoading = false;

  /// Whether the window is maximized.
  bool? isMaximized;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      bool isMaximized = await windowManager.isMaximized();
      if (mounted) {
        setState(() => this.isMaximized = isMaximized);
      }
    });
    windowManager.addListener(this);
  }

  @override
  Widget build(BuildContext context) => DragToMoveArea(
    child: SizedBox(
      width: MediaQuery.sizeOf(context).width,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: kSpace / 2,
        runSpacing: kSpace / 2,
        children: [
          ClickableButton.icon(
            variant: .secondary,
            onPress: isLoading ? null : windowManager.minimize,
            child: Transform.translate(
              offset: const Offset(0, 5),
              child: Icon(
                FIcons.minus,
                size: context.theme.typography.sm.fontSize,
              ),
            ),
          ),
          if (isMaximized == true)
            ClickableButton.icon(
              variant: .secondary,
              onPress: isLoading ? null : () => doFuture(windowManager.unmaximize),
              child: Transform.flip(
                flipX: true,
                child: Icon(
                  FIcons.copy,
                  size: context.theme.typography.sm.fontSize,
                ),
              ),
            )
          else
            ClickableButton.icon(
              variant: .secondary,
              onPress: isLoading || isMaximized == null ? null : () => doFuture(windowManager.maximize),
              child: Icon(
                FIcons.square,
                size: context.theme.typography.sm.fontSize,
              ),
            ),
          ClickableButton.icon(
            variant: .destructive,
            onPress: isLoading ? null : () => doFuture(windowManager.close),
            child: Icon(
              FIcons.x,
              size: context.theme.typography.sm.fontSize,
            ),
          ),
        ],
      ),
    ),
  );

  /// Executes the given future and sets the loading state accordingly.
  void doFuture<T>(Future<T> Function() future) async {
    setState(() => isLoading = true);
    await future();
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  @override
  void onWindowMaximize() {
    super.onWindowMaximize();
    if (mounted) {
      setState(() => isMaximized = true);
    }
  }

  @override
  void onWindowUnmaximize() {
    super.onWindowUnmaximize();
    if (mounted) {
      setState(() => isMaximized = false);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }
}
