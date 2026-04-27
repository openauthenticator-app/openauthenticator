import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:http/http.dart' as http;
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/debounce.dart';
import 'package:open_authenticator/utils/form_label.dart';
import 'package:open_authenticator/widgets/centered_circular_progress_indicator.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/logo_search/sources.dart';
import 'package:open_authenticator/widgets/smart_image.dart';

/// Allows to search for logos on various sources.
class LogoSearch extends StatefulWidget {
  /// The initial search keywords to use.
  final String? initialSearchKeywords;

  /// Triggered when a logo has been clicked.
  final ValueChanged<String>? onLogoClicked;

  /// The logos display width.
  final double imageWidth;

  /// Creates a new Wikimedia logo search instance.
  const LogoSearch({
    super.key,
    this.initialSearchKeywords,
    this.onLogoClicked,
    this.imageWidth = 100,
  });

  @override
  State<StatefulWidget> createState() => _LogoSearchState();
}

/// The Wikimedia logo search state.
class _LogoSearchState extends State<LogoSearch> {
  /// The default search term.
  static const String kDefaultSearch = 'microsoft';

  /// The debounce instance.
  final Debounce debounce = Debounce();

  /// The HTTP client.
  final http.Client client = http.Client();

  /// The search keywords.
  late TextEditingController searchKeywordsController = TextEditingController(text: widget.initialSearchKeywords ?? kDefaultSearch)
    ..addListener(() {
      if (mounted) {
        debounce.milliseconds(500, search);
      }
    });

  /// All searches triggered by the user.
  final Map<String, List<String>> searches = {};

  /// The images that failed to render.
  final Set<String> imageErrors = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debounce.milliseconds(100, search);
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: .min,
    children: [
      FTextFormField(
        control: .managed(controller: searchKeywordsController),
        style: .delta(
          color: .delta(
            [
              .base(context.theme.tileStyles.base.decoration.base.color),
            ],
          ),
        ),
        label: FormLabelWithIcon(
          icon: FIcons.search,
          text: translations.logoSearch.keywords.text,
        ),
        hint: translations.logoSearch.keywords.hint,
      ),
      SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.only(top: kSpace, bottom: kBigSpace),
          child: Text(
            translations.logoSearch.credits(
              sources: [
                for (Source source in Source.sources)
                  if (source is! DirectSource) source.name,
              ].join(' / '),
            ),
            style: context.theme.typography.xs.copyWith(
              color: context.theme.colors.foreground.withValues(alpha: 0.75),
            ),
            textAlign: .right,
          ),
        ),
      ),
      if (searches[filteredSearchKeywords]?.isNotEmpty == true)
        Wrap(
          alignment: .center,
          spacing: widget.imageWidth / 10,
          runSpacing: widget.imageWidth / 10,
          children: [
            for (String logo in searches[filteredSearchKeywords]!) //
              buildImageWidget(logo),
          ],
        )
      else if (searches.isNotEmpty)
        const CenteredCircularProgressIndicator()
      else
        Text(
          translations.logoSearch.noLogoFound,
          textAlign: TextAlign.center,
        ),
    ],
  );

  @override
  void dispose() {
    debounce.clear(search);
    client.close();
    searchKeywordsController.dispose();
    super.dispose();
  }

  /// Returns the search keywords, non null and lowercased.
  String get filteredSearchKeywords => searchKeywordsController.text.trim().isEmpty ? kDefaultSearch : searchKeywordsController.text.trim().toLowerCase();

  /// Triggers the search.
  Future<void> search() async {
    String keywords = filteredSearchKeywords;
    if (!mounted || searches.containsKey(keywords)) {
      return;
    }

    setState(searches.clear);
    List<Uri> logos = await Source.sources.search(client, keywords);
    setState(() => searches.putIfAbsent(keywords, () => []));
    for (Uri logo in logos) {
      if (await Source.check(client, logo) && mounted && searches.containsKey(keywords) && !imageErrors.contains(logo.toString())) {
        setState(() => searches[keywords]?.add(logo.toString()));
      }
      if (!searches.containsKey(keywords)) {
        break;
      }
    }
    if (searches[keywords]?.isEmpty == true) {
      setState(() => searches.remove(keywords));
    }
  }

  /// Removes an image from the displayed results after a rendering error.
  void removeImageError(String imageUrl) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !imageErrors.add(imageUrl)) {
        return;
      }
      setState(() {
        searches.updateAll((_, logos) => logos..remove(imageUrl));
        searches.removeWhere((_, logos) => logos.isEmpty);
      });
    });
  }

  /// Builds the image widget that corresponds to the [imageUrl].
  Widget buildImageWidget(String imageUrl) {
    if (imageErrors.contains(imageUrl)) {
      return const SizedBox.shrink();
    }

    Widget image = UnconstrainedBox(
      child: SizedBox(
        width: widget.imageWidth,
        child: ResolvedSmartImage(
          source: imageUrl,
          height: widget.imageWidth,
          width: widget.imageWidth,
          errorBuilder: (context) {
            removeImageError(imageUrl);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    if (kDebugMode) {
      image = Stack(
        children: [
          image,
          Positioned(
            bottom: 0,
            left: 0,
            child: Text(
              imageUrl,
              style: TextStyle(color: context.theme.colors.destructive, fontSize: 6),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      );
    }
    return widget.onLogoClicked == null
        ? image
        : FTappable(
            builder: (context, states, child) => Container(
              decoration: BoxDecoration(
                color: (states.contains(FTappableVariant.hovered) || states.contains(FTappableVariant.pressed)) ? context.theme.colors.secondary : context.theme.colors.background,
                borderRadius: context.theme.style.borderRadius.md,
              ),
              padding: const EdgeInsets.all(kSpace),
              child: child!,
            ),
            child: image,
            onPress: () => widget.onLogoClicked!.call(imageUrl),
          ).clickable();
  }
}
