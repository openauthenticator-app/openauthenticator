import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

/// An available update for a build distributed through GitHub Releases.
typedef ReleaseUpdate = ({String version, Uri downloadsPage});

/// Checks for a newer stable release with a downloadable asset for this build.
Future<ReleaseUpdate?> findReleaseUpdate({
  required http.Client client,
  required Uri repository,
  required String installedVersion,
  required String assetName,
}) async {
  final List<String> repositoryPath = repository.pathSegments.where((segment) => segment.isNotEmpty).toList();
  if (repository.host != 'github.com' || repositoryPath.length != 2 || assetName.isEmpty) {
    return null;
  }

  try {
    final Version installed = _parseVersion(installedVersion);
    final http.Response response = await client
        .get(
          Uri.https('api.github.com', '/repos/${repositoryPath.join('/')}/releases/latest'),
          headers: const {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      return null;
    }
    if (jsonDecode(response.body) case {'tag_name': final String tag, 'draft': false, 'prerelease': false, 'assets': final List<dynamic> assets}) {
      final Version latest = _parseVersion(tag);
      final bool hasAsset = assets.any((asset) => asset is Map<String, dynamic> && asset['name'] == assetName && asset['state'] == 'uploaded');
      if (!latest.isPreRelease && latest > installed && hasAsset) {
        return (
          version: latest.toString(),
          downloadsPage: Uri(scheme: 'https', host: 'github.com', pathSegments: [...repositoryPath, 'releases', 'tag', tag]),
        );
      }
    }
    return null;
  } on FormatException {
    return null;
  } on http.ClientException {
    return null;
  } on TimeoutException {
    return null;
  }
}

/// Parses a release tag or installed version without its build metadata.
Version _parseVersion(String value) {
  final Version version = Version.parse(value.replaceFirst(RegExp(r'^v'), ''));
  return Version(version.major, version.minor, version.patch, pre: version.isPreRelease ? version.preRelease.join('.') : null);
}
