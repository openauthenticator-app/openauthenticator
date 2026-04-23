import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/widgets/clickable.dart';

/// A list tile that allows to expand its content by tapping on it.
class ExpandableTile extends ConsumerStatefulWidget with FTileMixin {
  /// The tile title.
  final Widget title;

  /// The expanded children.
  final List<Widget> children;

  /// The children padding.
  final EdgeInsets childrenPadding;

  /// The children cross axis alignment.
  final CrossAxisAlignment childrenCrossAxisAlignment;

  /// Whether the tile is enabled.
  final bool enabled;

  /// The icon color.
  final Color? iconColor;

  /// Called when the tile is long pressed.
  final VoidCallback? onLongPress;

  /// Creates a new expand list tile instance.
  const ExpandableTile({
    super.key,
    required this.title,
    this.children = const [],
    this.childrenPadding = const EdgeInsets.only(top: kBigSpace),
    this.childrenCrossAxisAlignment = CrossAxisAlignment.start,
    this.enabled = true,
    this.iconColor,
    this.onLongPress,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ExpandableTileState();
}

/// The expand list tile instance.
class _ExpandableTileState extends ConsumerState<ExpandableTile> with SingleTickerProviderStateMixin {
  /// The expand controller.
  late AnimationController expandController;

  /// The expand animation.
  late Animation<double> expandAnimation;

  /// Whether the content is expanded.
  bool expand = false;

  @override
  void initState() {
    super.initState();
    expandController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    expandAnimation = CurvedAnimation(
      parent: expandController,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) => ClickableTile.raw(
    onLongPress: widget.onLongPress,
    // onPress: _toggle,
    enabled: widget.enabled,
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: widget.title,
            ),
            ClickableButton.icon(
              variant: .secondary,
              onPress: _toggle,
              child: AnimatedRotation(
                turns: expand ? 0.25 : 0,
                duration: const Duration(milliseconds: 100),
                child: Icon(
                  FIcons.chevronRight,
                  color: widget.iconColor,
                ),
              ),
            ),
          ],
        ),
        SizeTransition(
          axisAlignment: 1.0,
          sizeFactor: expandAnimation,
          child: Padding(
            padding: widget.childrenPadding,
            child: Column(
              spacing: kSpace,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: widget.childrenCrossAxisAlignment,
              children: widget.children,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    expandController.dispose();
    super.dispose();
  }

  void _toggle() {
    bool willExpand = !expand;
    setState(() => expand = willExpand);
    if (willExpand) {
      expandController.forward();
    } else {
      expandController.reverse();
    }
  }
}
