import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/themes.dart';
import 'package:open_authenticator/utils/clipboard.dart';

/// Checks feedback and toast placement when the clipboard is locked.
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
      await tester.pump(const Duration(milliseconds: 400));
      expect(writes, 2);
      if (persistent) {
        expect(find.textContaining('Fixture clipboard is busy'), findsOneWidget);
        expect(find.text('Copied fixture'), findsNothing);
      } else {
        expect(find.text('Copied fixture'), findsOneWidget);
      }
      final Offset toastCenter = tester.getCenter(find.byType(FToast));
      final Offset screenCenter = tester.getCenter(find.byType(FToaster));
      expect(toastCenter.dx, closeTo(screenCenter.dx, 1));
      expect(toastCenter.dy, greaterThan(screenCenter.dy));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
