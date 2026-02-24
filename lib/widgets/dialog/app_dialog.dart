import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/platform.dart';
import 'package:open_authenticator/widgets/clickable.dart';

/// A scrollable full-width app-styled and adaptive alert dialog.
class AppDialog extends StatelessWidget {
  /// The classic content padding.
  static const EdgeInsets kDefaultContentPadding = EdgeInsets.symmetric(
    vertical: kSpace,
    horizontal: kBigSpace,
  );

  /// The dialog animation.
  final Animation<double>? animation;

  /// The dialog title.
  final Widget? title;

  /// The dialog children.
  final List<Widget> children;

  /// The dialog actions.
  final List<Widget>? actions;

  /// Whether to display a close button.
  final bool? displayCloseButton;

  /// The content padding.
  final EdgeInsets? contentPadding;

  /// Whether to put the content in a [ListView] instead of a [Column].
  final bool scrollable;

  /// Creates a new app dialog instance.
  const AppDialog({
    super.key,
    this.animation,
    this.title,
    this.children = const [],
    this.actions,
    this.displayCloseButton,
    this.contentPadding,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    EdgeInsets? listViewPadding = contentPadding;
    if (listViewPadding == null) {
      listViewPadding = kDefaultContentPadding;
      if (title != null && currentPlatform.isMobile) {
        listViewPadding = listViewPadding.copyWith(top: 0);
      }
    }
    List<Widget> children = [
      for (int i = 0; i < this.children.length; i++)
        Padding(
          padding: listViewPadding.copyWith(
            top: i == 0 ? null : kSpace / 2,
            bottom: i == this.children.length - 1 ? null : kSpace / 2,
          ),
          child: this.children[i],
        ),
    ];
    return FDialog.adaptive(
      title: title == null
          ? null
          : Transform.translate(
              offset: const Offset(0, -1),
              child: _AppDialogTitle(
                title: title!,
                displayCloseButton: displayCloseButton,
              ),
            ),
      body: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        child: scrollable
            ? ListView(
                shrinkWrap: true,
                children: children,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
      ),
      style: .delta(
        contentStyle: .delta(
          [
            .all(
              const .delta(
                padding: .value(EdgeInsets.zero),
                titleSpacing: 0,
                bodySpacing: 0,
                contentSpacing: 0,
                actionSpacing: 0,
              ),
            ),
          ],
        ),
      ),
      animation: animation,
      actions: [
        for (int i = 0; i < (actions?.length ?? 0); i++)
          _AdaptiveActionPadding(
            actionIndex: i,
            actionsCount: actions!.length,
            action: actions![i],
          ),
      ],
    );
  }
}

/// An adaptive action padding widget.
class _AdaptiveActionPadding extends StatelessWidget {
  /// The index of the action.
  final int actionIndex;

  /// The number of actions.
  final int actionsCount;

  /// The action widget.
  final Widget action;

  /// The gap between two actions.
  final double gap;

  /// The gap between the action and the edge of the dialog.
  final double bigGap;

  /// Creates a new adaptive action padding instance.
  const _AdaptiveActionPadding({
    super.key,
    required this.actionIndex,
    required this.actionsCount,
    required this.action,
    this.gap = kSpace / 2,
    this.bigGap = kBigSpace,
  });

  @override
  Widget build(BuildContext context) => MediaQuery.sizeOf(context).width < context.theme.breakpoints.sm
      ? Padding(
          padding: EdgeInsets.only(
            top: actionIndex == 0 ? bigGap : gap,
            right: bigGap,
            bottom: actionIndex == actionsCount - 1 ? bigGap : gap,
            left: bigGap,
          ),
          child: action,
        )
      : Padding(
          padding: EdgeInsets.only(
            top: bigGap,
            right: actionIndex == 0 ? bigGap : gap,
            bottom: bigGap,
            left: actionIndex == actionsCount - 1 ? bigGap : gap,
          ),
          child: action,
        );
}

/// The app dialog title widget.
class _AppDialogTitle extends StatelessWidget {
  /// The dialog title.
  final Widget title;

  /// Whether to display a close button.
  final bool? displayCloseButton;

  /// Creates a new app dialog title instance.
  const _AppDialogTitle({
    required this.title,
    this.displayCloseButton,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: .min,
    children: [
      FHeader(
        title: Align(
          alignment: Alignment.centerLeft,
          child: title,
        ),
        style: .delta(
          titleTextStyle: .delta(
            fontSize: context.theme.typography.xl.fontSize,
            fontWeight: FontWeight.normal,
            height: 1,
          ),
          padding: .value(AppDialog.kDefaultContentPadding.copyWith(top: kBigSpace, bottom: kBigSpace)),
        ),
        suffixes: [
          if (currentPlatform.isDesktop && displayCloseButton != false)
            Tooltip(
              message: MaterialLocalizations.of(context).closeButtonLabel,
              child: ClickableButton.icon(
                variant: .destructive,
                child: const Icon(FIcons.x),
                onPress: () => Navigator.pop(context),
              ),
            ),
        ],
      ),
      const FDivider(
        style: .delta(
          padding: .value(EdgeInsets.zero),
        ),
      ),
    ],
  );
}
