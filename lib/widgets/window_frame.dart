import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart' hide ErrorWidget;
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/utils/window.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:window_manager/window_manager.dart';

/// Allows to display a window frame.
class DesktopWindowFrame extends StatelessWidget {
  /// The window controlled by this frame. Defaults to the primary app window.
  final Window? window;

  /// The child widget.
  final Widget child;

  /// Creates a new window frame widget instance.
  const DesktopWindowFrame({
    super.key,
    this.window,
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
              child: _DragArea(window ?? currentWindow),
            ),
            Expanded(child: child),
          ],
        )
      : child;
}

/// Drag area for the app.
class _DragArea extends StatefulWidget {
  final Window? window;

  _DragArea(this.window) : super(key: ObjectKey(window));

  @override
  State<StatefulWidget> createState() => _DragAreaState();
}

/// The drag area widget state.
class _DragAreaState extends State<_DragArea> {
  /// The current window.
  Window? get window => widget.window;

  /// The window listener ID.
  ListenerId? listenerId;

  /// Whether the window is maximized.
  bool? isMaximized;

  @override
  void initState() {
    super.initState();
    isMaximized = window?.isMaximized;
    listenerId = window?.addListener(onWindowEvent);
  }

  @override
  Widget build(BuildContext context) => DragToMoveArea(
    window: window,
    child: SizedBox(
      width: MediaQuery.sizeOf(context).width,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: kSpace / 2,
        runSpacing: kSpace / 2,
        children: [
          ClickableButton.icon(
            variant: .secondary,
            onPress: window?.minimize,
            child: Transform.translate(
              offset: const Offset(0, 5),
              child: Icon(
                FLucideIcons.minus,
                size: context.theme.typography.body.sm.fontSize,
              ),
            ),
          ),
          if (isMaximized == true)
            ClickableButton.icon(
              variant: .secondary,
              onPress: window?.unmaximize,
              child: Transform.flip(
                flipX: true,
                child: Icon(
                  FLucideIcons.copy,
                  size: context.theme.typography.body.sm.fontSize,
                ),
              ),
            )
          else
            ClickableButton.icon(
              variant: .secondary,
              onPress: isMaximized == null ? null : window?.maximize,
              child: Icon(
                FLucideIcons.square,
                size: context.theme.typography.body.sm.fontSize,
              ),
            ),
          ClickableButton.icon(
            variant: .destructive,
            onPress: window?.close,
            child: Icon(
              FLucideIcons.x,
              size: context.theme.typography.body.sm.fontSize,
            ),
          ),
        ],
      ),
    ),
  );

  /// Triggered when a window event occurs.
  void onWindowEvent(WindowEvent event) {
    if (mounted && (event is WindowMaximizedEvent || event is WindowRestoredEvent || event is WindowResizedEvent)) {
      setState(() => isMaximized = window?.isMaximized);
    }
  }

  @override
  void dispose() {
    final ListenerId? listenerId = this.listenerId;
    if (listenerId != null) {
      window?.removeListener(listenerId);
    }
    super.dispose();
  }
}
