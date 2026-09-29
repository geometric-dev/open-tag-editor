import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/folder_panel/presentation/breadcrumb_bar.dart';
import 'package:open_tag_editor/features/tag_editor/presentation/widgets/address_bar.dart';

void main() {
  group('BreadcrumbBar', () {
    Widget buildTestWidget({
      String? folderPath,
      void Function(String)? onFolderSelected,
    }) {
      return ProviderScope(
        overrides: [loadedFolderPathProvider.overrideWith((ref) => folderPath)],
        child: MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(onFolderSelected: onFolderSelected),
          ),
        ),
      );
    }

    testWidgets('shows placeholder when no folder is loaded', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('No folder loaded'), findsOneWidget);
    });

    testWidgets('displays path segments for a loaded folder', (tester) async {
      await tester.pumpWidget(buildTestWidget(folderPath: r'C:\Users\Music'));

      // On Windows, path splits to ['C:\', 'Users', 'Music']
      expect(find.text(r'C:\'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
    });

    testWidgets('last segment is bold and not clickable', (tester) async {
      await tester.pumpWidget(buildTestWidget(folderPath: r'C:\Users\Music'));

      final musicText = tester.widget<Text>(find.text('Music'));
      expect(musicText.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('ancestor segments are clickable and trigger callback', (
      tester,
    ) async {
      String? selectedPath;
      await tester.pumpWidget(
        buildTestWidget(
          folderPath: r'C:\Users\Music',
          onFolderSelected: (path) => selectedPath = path,
        ),
      );

      // Tap the 'Users' segment (ancestor)
      await tester.tap(find.text('Users'));
      await tester.pump();

      expect(selectedPath, r'C:\Users');
    });

    testWidgets('tapping root segment navigates to root', (tester) async {
      String? selectedPath;
      await tester.pumpWidget(
        buildTestWidget(
          folderPath: r'C:\Users\Music',
          onFolderSelected: (path) => selectedPath = path,
        ),
      );

      // Tap the 'C:\' segment (root)
      await tester.tap(find.text(r'C:\'));
      await tester.pump();

      expect(selectedPath, r'C:\');
    });

    testWidgets('shows recursive toggle', (tester) async {
      await tester.pumpWidget(buildTestWidget(folderPath: r'C:\Users\Music'));

      expect(find.text('Recursive'), findsOneWidget);
    });

    testWidgets('shows chevron dividers between segments', (tester) async {
      await tester.pumpWidget(buildTestWidget(folderPath: r'C:\Users\Music'));

      // There should be chevron icons between segments (2 for 3 segments)
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    });

    testWidgets('shows folder icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    group('edit mode', () {
      testWidgets('double-click enters edit mode showing TextField', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(folderPath: r'C:\Users\Music'));

        // Simulate double-tap on the last segment (non-clickable, no navigation)
        await tester.tap(find.text('Music'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Music'));
        await tester.pumpAndSettle();

        // TextField should now be visible with the full path
        expect(find.byType(TextField), findsOneWidget);
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, r'C:\Users\Music');
      });

      testWidgets('Enter in edit mode submits path and exits edit mode', (
        tester,
      ) async {
        String? selectedPath;
        await tester.pumpWidget(
          buildTestWidget(
            folderPath: r'C:\Users\Music',
            onFolderSelected: (path) => selectedPath = path,
          ),
        );

        // Enter edit mode via double-tap on the last segment
        await tester.tap(find.text('Music'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Music'));
        await tester.pumpAndSettle();

        // Clear and type a new path
        final textField = find.byType(TextField);
        await tester.enterText(textField, r'C:\Users\Documents');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Should have called onFolderSelected with the typed path
        expect(selectedPath, r'C:\Users\Documents');
        // Should exit edit mode (no TextField visible)
        expect(find.byType(TextField), findsNothing);
      });

      testWidgets('Escape in edit mode cancels and returns to breadcrumbs', (
        tester,
      ) async {
        String? selectedPath;
        await tester.pumpWidget(
          buildTestWidget(
            folderPath: r'C:\Users\Music',
            onFolderSelected: (path) => selectedPath = path,
          ),
        );

        // Enter edit mode via double-tap on the last segment (non-clickable)
        await tester.tap(find.text('Music'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Music'));
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);

        // Reset selectedPath to ensure Escape doesn't trigger it
        selectedPath = null;

        // Press Escape
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        // Should exit edit mode without calling onFolderSelected
        expect(find.byType(TextField), findsNothing);
        expect(selectedPath, isNull);
        // Breadcrumb segments should be visible again
        expect(find.text('Music'), findsOneWidget);
      });

      testWidgets('focus loss exits edit mode without submitting', (
        tester,
      ) async {
        String? selectedPath;
        await tester.pumpWidget(
          buildTestWidget(
            folderPath: r'C:\Users\Music',
            onFolderSelected: (path) => selectedPath = path,
          ),
        );

        // Enter edit mode via double-tap on the last segment (non-clickable)
        await tester.tap(find.text('Music'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Music'));
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);

        // Reset selectedPath to ensure focus loss doesn't trigger it
        selectedPath = null;

        // Remove focus by unfocusing
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        // Should exit edit mode without calling onFolderSelected
        expect(find.byType(TextField), findsNothing);
        expect(selectedPath, isNull);
      });
    });
  });
}
