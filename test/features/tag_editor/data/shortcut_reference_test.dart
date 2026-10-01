import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tag_editor/data/models/shortcut_reference.dart';
import 'package:open_tag_editor/features/tag_editor/presentation/widgets/shortcut_help_dialog.dart';

void main() {
  group('ShortcutReference', () {
    test('has groups with content', () {
      expect(ShortcutReference.groups, isNotEmpty);
      for (final group in ShortcutReference.groups) {
        expect(group.title, isNotEmpty);
        expect(group.shortcuts, isNotEmpty);
      }
    });

    test('no shortcut is listed twice', () {
      final seen = <String>{};
      for (final group in ShortcutReference.groups) {
        for (final (keys, _) in group.shortcuts) {
          expect(
            seen.add(keys),
            isTrue,
            reason: '"$keys" is listed more than once',
          );
        }
      }
    });

    test('every entry names both keys and a description', () {
      for (final group in ShortcutReference.groups) {
        for (final (keys, description) in group.shortcuts) {
          expect(keys.trim(), isNotEmpty);
          expect(description.trim(), isNotEmpty);
        }
      }
    });

    test('total matches the sum of the groups', () {
      final sum = ShortcutReference.groups.fold<int>(
        0,
        (total, group) => total + group.shortcuts.length,
      );
      expect(ShortcutReference.total, sum);
    });

    test('covers the bindings that were previously undiscoverable', () {
      // These are the ones that existed with no way to find out about them
      // before this dialog.
      final all = <String>{
        for (final group in ShortcutReference.groups)
          for (final (keys, _) in group.shortcuts) keys,
      };

      for (final expected in [
        'Ctrl + ↑ / ↓',
        'Ctrl + Space',
        'F5',
        'Ctrl + Shift + Home / End',
        'F2 or double-click',
        'Alt + ← / →',
        'Ctrl + G',
        'Page Up / Page Down',
        'Delete',
      ]) {
        expect(all, contains(expected));
      }
    });
  });

  group('ShortcutHelpDialog', () {
    testWidgets('renders every group and entry', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShortcutHelpDialog())),
      );
      await tester.pumpAndSettle();

      for (final group in ShortcutReference.groups) {
        expect(find.text(group.title.toUpperCase()), findsOneWidget);
      }
      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
      expect(find.text('${ShortcutReference.total}'), findsOneWidget);
    });

    testWidgets('shows the keys and what they do', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShortcutHelpDialog())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ctrl + S'), findsOneWidget);
      expect(find.text('Save tags to disk'), findsOneWidget);
    });

    testWidgets('closes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShortcutHelpDialog())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsNothing);
    });
  });
}
