import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_authenticator/app.dart';

/// A logo search source.
mixin Source {
  /// All logo sources.
  static const List<Source> sources = [
    BrandfetchSource(),
    LogoDevSource(),
    UpLeadSource(),
    WikimediaSource(),
  ];

  /// The source name (to display attributions).
  String get name;

  /// Searches using this source.
  FutureOr<Iterable<Uri>> _trySearch(http.Client client, String userKeywords);

  /// Check whether the given [imageUrl] is good to display.
  static Future<bool> check(http.Client client, Uri imageUrl) async {
    try {
      http.Response response = await client.head(imageUrl);
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
      http.Response response = await client.get(buildEndpointUrl(userKeywords));
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
