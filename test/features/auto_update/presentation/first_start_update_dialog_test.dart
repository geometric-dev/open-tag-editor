import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/auto_update/presentation/widgets/first_start_update_dialog.dart';

void main() {
  group('FirstStartUpdateDialog', () {
    testWidgets(
      'renders Auto-update as filled button and pops true when clicked',
      (tester) async {
        bool? result;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await FirstStartUpdateDialog.show(context);
                  },
                  child: const Text('Launch Prompt'),
                );
              },
            ),
          ),
        );

        // Open dialog
        await tester.tap(find.text('Launch Prompt'));
        await tester.pumpAndSettle();

        expect(find.text('Enable Auto-Updates?'), findsOneWidget);
        final autoUpdateBtn = find.widgetWithText(FilledButton, 'Auto-update');
        expect(autoUpdateBtn, findsOneWidget);
        expect(
          find.widgetWithText(TextButton, "Don't auto-update"),
          findsOneWidget,
        );

        await tester.tap(autoUpdateBtn);
        await tester.pumpAndSettle();

        expect(result, isTrue);
      },
    );

    testWidgets('pops false when Don\'t auto-update is clicked', (
      tester,
    ) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await FirstStartUpdateDialog.show(context);
                },
                child: const Text('Launch Prompt'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Launch Prompt'));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Don't auto-update"));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });
}
