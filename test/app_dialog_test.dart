import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_authenticator/themes.dart';
import 'package:open_authenticator/widgets/dialog/app_dialog.dart';

/// Checks the outer margins and scrolling of a tall dialog on a phone.
void main() {
  testWidgets('a tall dialog keeps margins on all sides of an Android screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final FThemeData theme = greenTheme.light.touch;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: .android),
        builder: (context, child) => FTheme(data: theme, child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFDialog<void>(
                context: context,
                builder: (context, style, animation) => AppDialog(
                  animation: animation,
                  title: const Text('Licenses'),
                  children: [for (int index = 1; index <= 50; index++) Text('Package $index')],
                ),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    final Finder surface = find.descendant(
      of: find.byType(FDialog),
      matching: find.byWidgetPredicate((widget) => widget is DecoratedBox && widget.decoration == theme.dialogStyle.decoration),
    );
    expect(tester.getRect(surface), const Rect.fromLTRB(40, 24, 320, 776));

    await tester.scrollUntilVisible(find.text('Package 50'), 300);
    expect(find.text('Licenses'), findsOneWidget);
  });
}
