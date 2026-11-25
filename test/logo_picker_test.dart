import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/i18n/translations.g.dart';
import 'package:open_authenticator/themes.dart';
import 'package:open_authenticator/widgets/centered_circular_progress_indicator.dart';
import 'package:open_authenticator/widgets/dialog/logo_search/dialog.dart';
import 'package:open_authenticator/widgets/smart_image.dart';

/// Checks the initial lookup through the dialog route.
void main() {
  for (final (String issuer, String keywords) in [(' Acme ', 'acme'), ('', 'microsoft')]) {
    testWidgets('the logo picker starts searching for $keywords when it opens', (tester) async {
      final slowSource = Completer<http.Response>();
      final imageCheck = Completer<http.Response>();
      final requests = <http.Request>[];
      String? selectedLogo;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => FTheme(data: greenTheme.light.touch, child: child!),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async => selectedLogo = await LogoPickerDialog.openDialog(context, initialSearchKeywords: issuer),
                    child: const Text('Open logo picker'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open logo picker'));
          await tester.pump();
          expect(find.byType(CenteredCircularProgressIndicator), findsOneWidget);
          expect(find.text(translations.logoSearch.noLogoFound), findsNothing);

          await tester.pump(const Duration(milliseconds: 200));
          final Finder field = find.byType(EditableText);
          expect(tester.widget<EditableText>(field).controller.text.toLowerCase(), keywords);
          expect(requests.any((request) => request.url.queryParameters['srsearch'] == keywords), isTrue);
          expect(requests.any((request) => request.method == 'HEAD' && request.url.host == 'commons.wikimedia.org'), isTrue);

          if (issuer.isNotEmpty) {
            imageCheck.complete(http.Response('', 200));
            await tester.pump();
            final Finder logo = find.byType(ResolvedSmartImage);
            expect(logo, findsOneWidget);
            expect(slowSource.isCompleted, isFalse);
            await tester.tapAt(tester.getCenter(logo));
            slowSource.complete(http.Response('', 404));
            await tester.pumpAndSettle();
            expect(selectedLogo, 'https://commons.wikimedia.org/wiki/Special:FilePath/File:Example.svg');
          } else {
            imageCheck.complete(http.Response('', 404));
            await tester.pump(const Duration(seconds: 8));
            await tester.pumpAndSettle();
            expect(find.text(translations.logoSearch.noLogoFound), findsOneWidget);
            slowSource.complete(http.Response('', 404));
            await tester.pump();

            await tester.enterText(field, 'Contoso');
            await tester.pump(const Duration(milliseconds: 500));
            expect(requests.any((request) => request.url.queryParameters['srsearch'] == 'contoso'), isTrue);
            await tester.pumpAndSettle();
          }
        },
        () => MockClient((request) async {
          requests.add(request);
          if (request.url.host == '$keywords.com') {
            return slowSource.future;
          }
          if (request.url.host == 'commons.wikimedia.org') {
            if (request.method == 'HEAD') {
              return imageCheck.future;
            }
            if (request.url.path == '/w/api.php') {
              return http.Response('{"query":{"search":[{"title":"File:Example.svg"}]}}', 200);
            }
            return http.Response('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10"/></svg>', 200);
          }
          return http.Response('', 404);
        }),
      );
    });
  }
}
