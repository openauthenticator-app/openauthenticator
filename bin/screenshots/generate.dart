import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
// The headless worker is a development-only Flutter test entry point.
// ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:jovial_svg/jovial_svg.dart';

import 'campaign.dart';
import 'capture.dart';
import 'render.dart';

/// Headless Flutter worker. Normal test discovery never invokes the campaign.
void main() {
  final String arguments = Platform.environment['OA_SCREENSHOTS'] ?? (throw StateError('Run dart run open_authenticator:screenshots.'));
  final options = jsonDecode(arguments) as Map<String, dynamic>;
  final campaign = Campaign.read(options);
  final Directory output = Directory(options['output'] as String).absolute;
  final Set<Capture> captures = {for (final Poster poster in campaign.posters) ?poster.screen};
  final captureOnly = options['capture-only'] == true;
  final composeOnly = options['compose-only'] == true;
  final generated = <Capture>{};
  late final DemoAccounts demo;
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadFonts();
    if (!composeOnly && captures.isNotEmpty) {
      final Directory scratch = Directory.systemTemp.createTempSync('open-authenticator-screenshots-');
      addTearDown(() => scratch.deleteSync(recursive: true));
      demo = await DemoAccounts.create(scratch);
    }
  });

  if (!composeOnly) {
    for (final capture in captures) {
      final String path = capturePath(capture);
      testWidgets(path, (tester) async {
        await withClock(tester.binding.clock, () => captureScreen(tester, capture, demo, campaign.pixelRatio, File('${output.path}/$path')));
        generated.add(capture);
      });
    }
  }
  test('Finish selected campaign', () async {
    if (!composeOnly) {
      expect(generated, containsAll(captures), reason: 'Some required screens failed to render.');
    }
    if (!captureOnly) {
      await loadPosterFonts();
      final ScalableImage logo = ScalableImage.fromSvgString(File('bin/screenshots/assets/key.svg').readAsStringSync());
      for (final Poster poster in campaign.posters) {
        await compose(output, poster, campaign.pixelRatio, logo);
      }
    }
    final Iterable<String> paths = captureOnly ? captures.map(capturePath) : campaign.posters.map((poster) => poster.path);
    final String gallery =
        '''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Open Authenticator screenshots</title><style>
body{margin:2rem;background:#10261e;color:#eff7ef;font:1rem system-ui}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:1.5rem}
figure{margin:0}img{width:100%;height:280px;object-fit:contain;background:#091a14}figcaption{overflow-wrap:anywhere;margin-top:.4rem}a{color:inherit}
</style><h1>Open Authenticator screenshots</h1><main>
${paths.map((path) => '<figure><a href="$path"><img loading="lazy" alt="$path" src="$path"></a><figcaption>$path</figcaption></figure>').join('\n')}
</main></html>''';
    writeOutput(File('${output.path}/index.html'), utf8.encode(gallery));
    stdout.writeln('${captures.length} raw screens, ${captureOnly ? 0 : campaign.posters.length} store images. Gallery: ${output.path}/index.html');
  });
}
