import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:open_authenticator/app.dart';

/// A logo search source.
mixin Source {
  /// All logo sources.
  static const List<Source> sources = [
    DirectSource(),
    BrandfetchSource(),
    LogoDevSource(),
    UpLeadSource(),
    WikimediaSource(),
  ];

  /// Headers to use when querying third-party services.
  static const Map<String, String> defaultHeaders = {
    HttpHeaders.userAgentHeader: 'OpenAuthenticator logo search (${App.githubRepositoryUrl})',
  };

  /// The source name (to display attributions).
  String get name;

  /// Searches using this source.
  FutureOr<Iterable<Uri>> _trySearch(http.Client client, String userKeywords);

  /// Check whether the given [imageUrl] is good to display.
  static Future<bool> check(http.Client client, Uri imageUrl) async {
    try {
      http.Response response = await client.head(imageUrl, headers: defaultHeaders);
      return response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    }
  }
}

/// Used on sources that provide a direct download link.
mixin DirectApiSource on Source {
  /// The API host.
  String get apiHost;

  /// The query parameters.
  Map<String, dynamic>? get queryParameters => null;

  @override
  Iterable<Uri> _trySearch(http.Client client, String userKeywords) => {
    Uri.https(apiHost, userKeywords, queryParameters),
    Uri.https(apiHost, userKeywords.replaceAll(' ', ''), queryParameters),
    Uri.https(apiHost, '${userKeywords.replaceAll(' ', '')}.com', queryParameters),
  };
}

/// Search directly on the target website.
class DirectSource with Source {
  /// Creates a new direct source instance.
  const DirectSource();

  /// The meta image attributes to look for.
  static const List<String> _kMetaImageAttributes = [
    'og:logo',
    'og:image:secure_url',
    'og:image:url',
    'og:image',
    'twitter:image:src',
    'twitter:image',
    'image',
    'thumbnail',
    'msapplication-tileimage',
  ];

  /// The link image relations to look for.
  static const List<String> _kLinkImageRelations = [
    'apple-touch-icon',
    'apple-touch-icon-precomposed',
    'icon',
    'shortcut icon',
    'mask-icon',
  ];

  @override
  String get name => 'Direct';

  @override
  Future<List<Uri>> _trySearch(http.Client client, String userKeywords) async {
    Set<Uri> result = {};
    for (Uri websiteUrl in _buildWebsiteUrls(userKeywords)) {
      try {
        http.Response response = await client.get(websiteUrl, headers: Source.defaultHeaders);
        if (response.statusCode != HttpStatus.ok || !_isHtml(response)) {
          continue;
        }
        result.addAll(_parseImageUrls(response.body, response.request?.url ?? websiteUrl));
        if (result.isNotEmpty) {
          break;
        }
      } catch (_) {}
    }
    return result.toList();
  }

  /// Builds the website URLs to try.
  Iterable<Uri> _buildWebsiteUrls(String keywords) sync* {
    String trimmed = keywords.trim();
    if (trimmed.isEmpty) {
      return;
    }

    Uri? directUri = Uri.tryParse(trimmed);
    if (directUri?.hasScheme == true && directUri?.hasAuthority == true) {
      yield directUri!;
      return;
    }

    String hostLikeKeywords = trimmed.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
    if (!hostLikeKeywords.contains(' ') && hostLikeKeywords.contains('.')) {
      yield Uri.https(hostLikeKeywords, '');
      yield Uri.https('www.$hostLikeKeywords', '');
      return;
    }

    String compactKeywords = trimmed.replaceAll(RegExp(r'\s+'), '');
    if (compactKeywords.isNotEmpty) {
      yield Uri.https('$compactKeywords.com', '');
      yield Uri.https('www.$compactKeywords.com', '');
    }
  }

  /// Extracts image URLs from the HTML meta and link tags.
  Iterable<Uri> _parseImageUrls(String responseBody, Uri websiteUrl) {
    Map<String, Uri> metaImages = {};
    Map<String, Uri> linkImages = {};
    html.Document document = html_parser.parse(responseBody);

    List<html.Element> elements = document.querySelectorAll('meta, link');
    for (html.Element element in elements) {
      String? content = element.attributes['content'];
      String? href = element.attributes['href'];

      for (String key in [
        element.attributes['property'],
        element.attributes['name'],
        element.attributes['itemprop'],
      ].nonNulls) {
        if (content == null) {
          continue;
        }
        Uri? imageUrl = _buildImageUrl(content, websiteUrl);
        if (imageUrl != null) {
          metaImages.putIfAbsent(key.toLowerCase(), () => imageUrl);
        }
      }

      if (href != null) {
        Set<String> relations = (element.attributes['rel'] ?? '').toLowerCase().split(RegExp(r'\s+')).where((relation) => relation.isNotEmpty).toSet();
        for (String relation in _kLinkImageRelations) {
          if (relations.containsAll(relation.split(' '))) {
            Uri? imageUrl = _buildImageUrl(href, websiteUrl);
            if (imageUrl != null) {
              linkImages.putIfAbsent(relation, () => imageUrl);
            }
          }
        }
      }
    }

    return [
      for (String attribute in _kMetaImageAttributes)
        if (metaImages[attribute] != null) metaImages[attribute]!,
      for (String relation in _kLinkImageRelations)
        if (linkImages[relation] != null) linkImages[relation]!,
    ];
  }

  /// Checks whether the response is HTML.
  bool _isHtml(http.Response response) {
    String contentType = response.headers[HttpHeaders.contentTypeHeader] ?? '';
    return contentType.isEmpty || contentType.toLowerCase().contains('text/html');
  }

  /// Builds the image URL.
  Uri? _buildImageUrl(String imageUrl, Uri websiteUrl) {
    try {
      Uri uri = websiteUrl.resolve(imageUrl.trim());
      return uri.isScheme('http') || uri.isScheme('https') ? uri : null;
    } catch (_) {
      return null;
    }
  }
}

/// Search using Wikimedia.
class WikimediaSource with Source {
  /// Creates a new Wikimedia source instance.
  const WikimediaSource();

  @override
  String get name => 'Wikimedia';

  @override
  Future<List<Uri>> _trySearch(http.Client client, String userKeywords) async {
    List<String> result = [];
    try {
      http.Response response = await client.get(buildEndpointUrl(userKeywords), headers: Source.defaultHeaders);
      Map<String, dynamic> json = jsonDecode(response.body);
      dynamic query = json['query'];
      if (query is Map<String, dynamic>) {
        dynamic search = query['search'];
        if (search is List) {
          for (dynamic element in search) {
            if (element is Map<String, dynamic>) {
              String logo = element['title'];
              if (logo.endsWith('.png') || logo.endsWith('.jpg') || logo.endsWith('.jpeg') || logo.endsWith('.tiff') || logo.endsWith('.webp') || logo.endsWith('.svg')) {
                result.add(logo);
              }
            }
          }
        }
      }
    } catch (_) {}
    return result.map(buildImageUrl).toList();
  }

  /// The endpoint URL.
  Uri buildEndpointUrl(String keywords) => Uri.https(
    'commons.wikimedia.org',
    '/w/api.php',
    {
      'format': 'json',
      'action': 'query',
      'list': 'search',
      'srsearch': keywords,
      'srnamespace': '6',
      'srlimit': '20',
    },
  );

  /// Builds the image URL.
  Uri buildImageUrl(String imageFile) => Uri.https('commons.wikimedia.org', '/wiki/Special:FilePath/$imageFile');
}

/// Search using Logo.dev.
class LogoDevSource with Source, DirectApiSource {
  /// Creates a new Logo.dev source instance.
  const LogoDevSource();

  @override
  String get name => 'Logo.dev';

  @override
  String get apiHost => 'img.logo.dev';

  @override
  Map<String, dynamic>? get queryParameters => {
    if (AppCredentials.logoDevApiKey.isNotEmpty) 'token': AppCredentials.logoDevApiKey,
    'format': 'webp',
  };
}

/// Search using UpLead.
class UpLeadSource with Source, DirectApiSource {
  /// Creates a new UpLead source instance.
  const UpLeadSource();

  @override
  String get name => 'UpLead';

  @override
  String get apiHost => 'logo.uplead.com';
}

/// Search using Brandfetch.
class BrandfetchSource with Source {
  /// Creates a new Brandfetch source instance.
  const BrandfetchSource();

  @override
  String get name => 'Brandfetch';

  @override
  Future<List<Uri>> _trySearch(http.Client client, String userKeywords) async {
    List<Uri> result = [];
    try {
      http.Response response = await client.get(buildEndpointUrl(userKeywords));
      List jsonList = jsonDecode(response.body);
      for (dynamic jsonBrand in jsonList) {
        if (jsonBrand['qualityScore'] >= 0.75) {
          result.add(Uri.parse(jsonBrand['icon']));
        }
      }
    } catch (_) {}
    return result;
  }

  /// The endpoint URL.
  Uri buildEndpointUrl(String keywords) => Uri.https('api.brandfetch.io', '/v2/search/$keywords');
}

/// Allows to quickly search on a source list.
extension Search on List<Source> {
  /// Searches using these sources, avoiding errors.
  Future<List<Uri>> search(http.Client client, String userKeywords) async => [
    for (Source source in this) //
      ...await source._trySearch(client, userKeywords),
  ];
}
