part of '../page.dart';

/// Shows a full screen search page and returns the search result selected by
/// the user when the page is closed.
/// Adapted from the Flutter library.
Future<Totp?> _showTotpSearch(
  BuildContext context, {
  bool useRootNavigator = false,
  bool maintainState = false,
}) =>
    Navigator.of(
      context,
      rootNavigator: useRootNavigator,
    ).push(
      _SearchPageRoute(maintainState: maintainState),
    );

/// The search page route.
class _SearchPageRoute extends PageRoute<Totp> {
  @override
  final bool maintainState;

  /// Creates a new search page route instance.
  _SearchPageRoute({
    required this.maintainState,
  });

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _SearchPage(
    animation: animation,
  );
}

/// The search page.
class _SearchPage extends ConsumerStatefulWidget {
  /// The animation.
  final Animation<double> animation;

  /// Creates a new search page instance.
  const _SearchPage({
    required this.animation,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SearchPageState();
}

/// The search page state.
class _SearchPageState extends ConsumerState<_SearchPage> {
  /// The focus node.
  late final FocusNode focusNode = FocusNode(
    onKeyEvent: (FocusNode node, KeyEvent event) {
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.pop(context);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );

  /// The query focus node.
  final FocusNode queryFocusNode = FocusNode();

  /// The query controller.
  late final TextEditingController queryController = TextEditingController()
    ..addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => queryFocusNode.requestFocus());
    widget.animation.addStatusListener(onAnimationStatusChanged);
  }

  @override
  Widget build(BuildContext context) {
    AsyncValue<List<Totp>> totps = ref.watch(totpRepositoryProvider);
    return AppScaffold.asyncValue(
      header: FHeader.nested(
        prefixes: [
          ClickableHeaderAction.x(
            onPress: () => Navigator.pop(context),
          ),
        ],
        title: FTextField(
          suffixBuilder: (_, _, _) => ClickableButton.icon(
            variant: .ghost,
            onPress: null,
            child: const Icon(FIcons.search),
          ),
          style: .delta(
            color: .delta(
              [
                .base(context.theme.tileStyles.base.decoration.base.color),
              ],
            ),
          ),
          control: .managed(controller: queryController),
          focusNode: queryFocusNode,
          hint: MaterialLocalizations.of(context).searchFieldLabel,
          onSubmit: (_) => queryFocusNode.unfocus(),
        ),
      ),
      asyncValue: totps,
      builder: buildResults,
      onRetryPressed: () => ref.invalidate(totpRepositoryProvider),
    );
  }

  @override
  void dispose() {
    super.dispose();
    widget.animation.removeStatusListener(onAnimationStatusChanged);
    focusNode.dispose();
    queryFocusNode.dispose();
    queryController.dispose();
  }

  /// Builds the results.
  List<Widget> buildResults(List<Totp> totps) {
    List<Totp> searchResults = totps.search(queryController.text);
    return [
      for (Totp totp in searchResults)
        Padding(
          padding: const EdgeInsets.only(bottom: kBigSpace),
          child: TotpTile(
            key: ValueKey(totp.uuid),
            totp: totp,
            onTap: (context) => Navigator.pop(context, totp),
          ),
        ),
    ];
  }

  /// Triggered when the animation status changes.
  void onAnimationStatusChanged(AnimationStatus status) {
    if (!status.isCompleted) {
      return;
    }
    widget.animation.removeStatusListener(onAnimationStatusChanged);
    queryFocusNode.requestFocus();
  }
}
