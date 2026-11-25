import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forui/forui.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/spacing.dart';
import 'package:open_authenticator/utils/debounce.dart';
import 'package:open_authenticator/widgets/centered_circular_progress_indicator.dart';
import 'package:open_authenticator/widgets/clickable.dart';
import 'package:open_authenticator/widgets/dialog/logo_search/sources.dart';
import 'package:open_authenticator/widgets/form/form_label.dart';
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

  /// The initial text displayed in the search field.
  late final String initialKeywords;

  /// The normalized keywords for the current search.
  late String searchKeywords;

  /// Identifies the current search, even when revisiting the same keywords.
  int searchRevision = 0;

  /// Whether the current search is waiting on any sources or images.
  bool searching = true;

  /// The images found for the current keywords.
  final List<String> imageUrls = [];

  /// The images that failed to render.
  final Set<String> imageErrors = {};

  @override
  void initState() {
    super.initState();
    final String initialText = widget.initialSearchKeywords?.trim() ?? '';
    initialKeywords = initialText.isEmpty ? kDefaultSearch : initialText;
    searchKeywords = initialKeywords.toLowerCase();
    unawaited(search());
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: .min,
    children: [
      FTextFormField(
        control: .managed(
          initial: TextEditingValue(text: initialKeywords),
          onChange: onKeywordsChanged,
        ),
        style: .delta(
          color: .delta(
            [
              .base(context.theme.tileStyles.base.contentDecoration.base.color),
            ],
          ),
        ),
        label: FormLabelWithIcon(
          icon: FLucideIcons.search,
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
                for (final Source source in Source.sources)
                  if (source is! DirectSource) source.name,
              ].join(' / '),
            ),
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.foreground.withValues(alpha: 0.75),
            ),
            textAlign: .right,
          ),
        ),
      ),
      if (imageUrls.isNotEmpty)
        Wrap(
          alignment: .center,
          spacing: widget.imageWidth / 10,
          runSpacing: widget.imageWidth / 10,
          children: [
            for (final String logo in imageUrls) buildImageWidget(logo),
          ],
        )
      else if (searching)
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
    super.dispose();
  }

  /// Queues a new search when the keywords change.
  void onKeywordsChanged(TextEditingValue value) {
    final String text = value.text.trim().toLowerCase();
    final String keywords = text.isEmpty ? kDefaultSearch : text;
    if (keywords == searchKeywords) {
      return;
    }
    setState(() {
      searchKeywords = keywords;
      searchRevision++;
      searching = true;
      imageUrls.clear();
    });
    debounce.milliseconds(500, search);
  }

  /// Looks up each source independently and displays logos as their checks finish.
  Future<void> search() async {
    final String keywords = searchKeywords;
    final int revision = searchRevision;
    final Set<Uri> candidates = {};
    await Future.wait(
      Source.sources.map((source) async {
        final Iterable<Uri> logos = await source.search(client, keywords);
        if (!mounted || revision != searchRevision) {
          return;
        }
        await Future.wait(
          logos.where(candidates.add).map((logo) async {
            final String url = logo.toString();
            if (await Source.check(client, logo) && mounted && revision == searchRevision && !imageErrors.contains(url)) {
              setState(() => imageUrls.add(url));
            }
          }),
        );
      }),
    );
    if (mounted && revision == searchRevision) {
      setState(() => searching = false);
    }
  }

  /// Removes an image from the displayed results after a rendering error.
  void removeImageError(String imageUrl) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !imageErrors.add(imageUrl)) {
        return;
      }
      setState(() => imageUrls.remove(imageUrl));
    });
  }

  /// Builds the image widget that corresponds to the [imageUrl].
  Widget buildImageWidget(String imageUrl) {
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
              child: child,
            ),
            child: image,
            onPress: () => widget.onLogoClicked!.call(imageUrl),
          ).clickable();
  }
}
