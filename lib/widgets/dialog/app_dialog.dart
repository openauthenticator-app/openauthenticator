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
    EdgeInsets? listViewPadding = contentPadding ?? kDefaultContentPadding;
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
    return FDialog.raw(
      builder: (context, style) => _AppDialogContent(
        style: style.contentStyle.resolve({context.platformVariant}),
        slideableActions: style.slideableActions.resolve({context.platformVariant}),
        title: title == null
            ? null
            : _AppDialogTitle(
                title: title!,
                displayCloseButton: displayCloseButton,
              ),
        body: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          child: scrollable
              ? ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: children,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
        ),
        actions: [
          for (int i = 0; i < (actions?.length ?? 0); i++)
            _AdaptiveActionPadding(
              actionIndex: i,
              actionsCount: actions!.length,
              action: actions![i],
            ),
        ],
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
    );
  }
}

/// Mimics ForUI's dialog content, but allows the text to be aligned at the start by default.
class _AppDialogContent extends StatelessWidget {
  /// The dialog content's style.
  final FDialogContentStyle style;

  /// Whether the dialog's actions support pressing an action and sliding to another.
  final bool slideableActions;

  /// The alignment of the content.
  final CrossAxisAlignment alignment;

  /// The dialog title.
  final Widget? title;

  /// The alignment of the title.
  final TextAlign titleTextAlign;

  /// The dialog body.
  final Widget? body;

  /// The alignment of the body.
  final TextAlign bodyTextAlign;

  /// The dialog actions.
  final List<Widget> actions;

  /// Creates a new app dialog content instance.
  const _AppDialogContent({
    required this.style,
    required this.slideableActions,
    this.alignment = .start,
    required this.title,
    this.titleTextAlign = .start,
    required this.body,
    this.bodyTextAlign = .start,
    required this.actions,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: style.padding,
    child: Column(
      mainAxisSize: .min,
      crossAxisAlignment: alignment,
      children: [
        if (title case final title?)
          Padding(
            padding: .only(bottom: style.titleSpacing),
            child: Semantics(
              container: true,
              child: DefaultTextStyle.merge(textAlign: titleTextAlign, style: style.titleTextStyle, child: title),
            ),
          ),
        if (body case final body?)
          Flexible(
            child: Padding(
              padding: .only(bottom: style.bodySpacing),
              child: Semantics(
                container: true,
                child: DefaultTextStyle.merge(textAlign: bodyTextAlign, style: style.bodyTextStyle, child: body),
              ),
            ),
          ),
        if (title != null && body != null) SizedBox(height: style.contentSpacing),
        if (slideableActions) FTappableGroup(child: _createActions(context, style)) else _createActions(context, style),
      ],
    ),
  );

  /// Creates the dialog actions.
  Widget _createActions(BuildContext context, FDialogContentStyle style) => MediaQuery.sizeOf(context).width < context.theme.breakpoints.sm
      ? Column(
          spacing: style.actionSpacing,
          mainAxisSize: .min,
          children: actions,
        )
      : Row(
          spacing: style.actionSpacing,
          mainAxisAlignment: .end,
          children: actions.reversed.toList(),
        );
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
  final bool displayCloseButton;

  /// Creates a new app dialog title instance.
  _AppDialogTitle({
    required this.title,
    bool? displayCloseButton,
  }) : displayCloseButton = currentPlatform.isDesktop && displayCloseButton != false;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: .min,
    children: [
      MediaQuery.removePadding(
        removeTop: true,
        removeRight: true,
        removeBottom: true,
        removeLeft: true,
        context: context,
        child: FHeader(
          title: Align(
            alignment: .centerLeft,
            child: title,
          ),
          style: .delta(
            titleTextStyle: .delta(
              fontSize: context.theme.typography.xl.fontSize,
              fontWeight: FontWeight.normal,
              height: 1,
            ),
            padding: displayCloseButton
                ? .value(
                    AppDialog.kDefaultContentPadding.copyWith(
                      top: kBigSpace,
                      bottom: kBigSpace - 6,
                    ),
                  )
                : const .value(AppDialog.kDefaultContentPadding),
          ),
          suffixes: [
            if (displayCloseButton)
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
      ),
      const FDivider(
        style: .delta(
          padding: .value(
            EdgeInsets.only(
              bottom: kSpace * 3 / 2,
            ),
          ),
        ),
      ),
    ],
  );
}
