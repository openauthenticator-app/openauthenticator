part of '../page.dart';

/// A widget that allows to search for a TOTP.
class _SearchBox extends ConsumerStatefulWidget implements PreferredSizeWidget {
  /// Triggered when a TOTP has been found by the user.
  final Function(Totp totp)? onTotpFound;

  /// The header widget.
  final Widget header;

  /// Creates a new search box instance.
  const _SearchBox({
    super.key,
    this.onTotpFound,
    required this.header,
  });

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SearchBoxWidgetState();
}

/// The search box widget state.
class _SearchBoxWidgetState extends ConsumerState<_SearchBox> {
  /// The current focus node.
  final FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(onFocusChange);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      widget.header,
      Container(
        padding: const EdgeInsets.all(10),
        color: context.theme.colors.secondary,
        child: FTextField(
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
          hint: MaterialLocalizations.of(context).searchFieldLabel,
          focusNode: focusNode,
        ),
      ),
    ],
  );

  /// Triggered when the focus changes.
  void onFocusChange() async {
    if (focusNode.hasFocus) {
      focusNode.unfocus();
      if (mounted) {
        Totp? result = await _showTotpSearch(context);
        if (result != null) {
          widget.onTotpFound?.call(result);
        }
      }
    }
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }
}
