/// A builder for [Uri].
class UriBuilder {
  /// The underlying URI.
  Uri _uri;

  /// Creates a new [UriBuilder] from a [Uri].
  UriBuilder._({
    required Uri uri,
  }) : _uri = uri;

  /// Creates a new [UriBuilder].
  UriBuilder({
    String? scheme,
    String? host,
    int? port,
    String? path,
    Iterable<String>? pathSegments,
    String? query,
    Map<String, dynamic>? queryParameters,
    String? fragment,
  }) : _uri = Uri(
         scheme: scheme,
         host: host,
         port: port,
         path: path,
         pathSegments: pathSegments,
         query: query,
         queryParameters: queryParameters,
         fragment: fragment,
       );

  /// Creates a new [UriBuilder] from a [prefix].
  factory UriBuilder.prefix({
    required String prefix,
    String? path,
    Iterable<String>? pathSegments,
    String? query,
    Map<String, dynamic>? queryParameters,
    String? fragment,
  }) {
    UriBuilder builder = UriBuilder._(
      uri: Uri.parse(
        '$prefix$path',
      ),
    );
    if (pathSegments != null) {
      builder.appendPathSegments(pathSegments);
    }
    if (queryParameters != null) {
      builder.appendQueryParameters(queryParameters);
    }
    return builder;
  }

  /// Creates a new [UriBuilder] from an HTTPS authority.
  UriBuilder.https({
    required String authority,
    String unencodedPath = '/',
    Map<String, dynamic>? queryParameters,
  }) : _uri = Uri.https(
         authority,
         unencodedPath,
         queryParameters,
       );

  /// Creates a new [UriBuilder] from an HTTP authority.
  UriBuilder.http({
    required String authority,
    String unencodedPath = '/',
    Map<String, dynamic>? queryParameters,
  }) : _uri = Uri.http(
         authority,
         unencodedPath,
         queryParameters,
       );

  /// Appends a path segment to the URI.
  void appendPathSegment(String pathSegment) => appendPathSegments([pathSegment]);

  /// Appends path segments to the URI.
  void appendPathSegments(Iterable<String> pathSegments) => _uri = _uri.replace(pathSegments: [..._uri.pathSegments, ...pathSegments]);

  /// Appends a query parameter to the URI.
  void appendQueryParameter(String key, dynamic value) => appendQueryParameters({key: value});

  /// Appends query parameters to the URI.
  void appendQueryParameters(Map<String, dynamic> queryParameters) => _uri = _uri.replace(queryParameters: {..._uri.queryParameters, ...queryParameters});

  /// Builds the URI.
  Uri build() => _uri;
}
