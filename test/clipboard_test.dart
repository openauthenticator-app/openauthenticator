import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/themes.dart';
import 'package:open_authenticator/utils/clipboard.dart';

/// Checks feedback when the clipboard is temporarily or persistently locked.
void main() {
  for (final persistent in [false, true]) {
    testWidgets('a locked clipboard is retried once (persistent: $persistent)', (tester) async {
      int writes = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          writes++;
          if (persistent || writes == 1) {
            throw PlatformException(code: 'Clipboard error', message: 'Fixture clipboard is busy');
          }
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => FTheme(data: greenTheme.light.touch, child: child!),
          home: FToaster(
            child: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final Future<void> copying = copyText(context, 'fixture', confirmation: 'Copied fixture');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await copying;
      await tester.pump();
      expect(writes, 2);
      if (persistent) {
        expect(find.textContaining('Fixture clipboard is busy'), findsOneWidget);
        expect(find.text('Copied fixture'), findsNothing);
      } else {
        expect(find.text('Copied fixture'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
