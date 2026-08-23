import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/folder_panel/data/bookmark_entry.dart';
import 'package:open_tag_editor/features/folder_panel/data/bookmarks_notifier.dart';
import 'package:open_tag_editor/features/folder_panel/presentation/quick_switcher_overlay.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/recent_folders_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final testBookmarks = [
    const BookmarkEntry(path: r'C:\Users\Music\Rock', name: 'Rock'),
    const BookmarkEntry(path: r'C:\Users\Music\Jazz', name: 'Jazz'),
    const BookmarkEntry(path: r'C:\Users\Music\Pop', name: 'Pop'),
  ];

  final testRecentFolders = [
    r'C:\Users\Music\Classical',
    r'C:\Users\Music\Electronic',
  ];

  Widget buildTestWidget({
    required void Function(String) onFolderSelected,
    required VoidCallback onDismiss,
    List<BookmarkEntry> bookmarks = const [],
    List<String> recentFolders = const [],
  }) {
    SharedPreferences.setMockInitialValues({});
    return ProviderScope(
      overrides: [
        bookmarksProvider.overrideWith((ref) {
          final notifier = BookmarksNotifier();
          for (final b in bookmarks) {
            notifier.addBookmark(b.path);
          }
          return notifier;
        }),
        recentFoldersProvider.overrideWith((ref) {
          final notifier = RecentFoldersNotifier();
          for (final path in recentFolders.reversed) {
            notifier.addFolder(path);
          }
          return notifier;
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: QuickSwitcherOverlay(
            onFolderSelected: onFolderSelected,
            onDismiss: onDismiss,
          ),
        ),
      ),
    );
  }

  group('QuickSwitcherOverlay', () {
    group('5.2 Filters on keystroke', () {
      testWidgets('shows all entries when query is empty', (tester) async {
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        // All 5 entries should be visible
        expect(find.text('Rock'), findsOneWidget);
        expect(find.text('Jazz'), findsOneWidget);
        expect(find.text('Pop'), findsOneWidget);
        expect(find.text('Classical'), findsOneWidget);
        expect(find.text('Electronic'), findsOneWidget);
      });

      testWidgets('filters entries by typed text', (tester) async {
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        // Type 'rock' to filter
        await tester.enterText(find.byType(TextField), 'rock');
        await tester.pump();

        // Only Rock should be visible
        expect(find.text('Rock'), findsOneWidget);
        expect(find.text('Jazz'), findsNothing);
        expect(find.text('Pop'), findsNothing);
        expect(find.text('Classical'), findsNothing);
        expect(find.text('Electronic'), findsNothing);
      });

      testWidgets('filter is case-insensitive', (tester) async {
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'JAZZ');
        await tester.pump();

        expect(find.text('Jazz'), findsOneWidget);
        expect(find.text('Rock'), findsNothing);
      });

      testWidgets('filter matches path substring', (tester) async {
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        // 'Music' is in all paths, so all should match
        await tester.enterText(find.byType(TextField), 'Music');
        await tester.pump();

        expect(find.text('Rock'), findsOneWidget);
        expect(find.text('Jazz'), findsOneWidget);
        expect(find.text('Pop'), findsOneWidget);
        expect(find.text('Classical'), findsOneWidget);
        expect(find.text('Electronic'), findsOneWidget);
      });
    });

    group('5.3 No matching folders message', () {
      testWidgets('shows "No matching folders" when filter returns empty',
          (tester) async {
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'zzzznonexistent');
        await tester.pump();

        expect(find.text('No matching folders'), findsOneWidget);
      });

      testWidgets('does not show message when query is empty',
          (tester) async {
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        // Empty query should show all entries, not the empty message
        expect(find.text('No matching folders'), findsNothing);
      });
    });

    group('5.4 Arrow key navigation', () {
      testWidgets('arrow down moves highlight to next entry', (tester) async {
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        // First entry should be highlighted initially (index 0)
        // Press arrow down to move to index 1
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        // Verify the second entry (Jazz) is now highlighted by checking
        // its ListTile has the highlighted color
        final listTiles = tester.widgetList<ListTile>(find.byType(ListTile));
        final secondTile = listTiles.elementAt(1);
        expect(secondTile.tileColor, isNotNull);
      });

      testWidgets('arrow up moves highlight to previous entry',
          (tester) async {
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        // Move down first, then up
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        // First entry should be highlighted again
        final listTiles = tester.widgetList<ListTile>(find.byType(ListTile));
        final firstTile = listTiles.elementAt(0);
        expect(firstTile.tileColor, isNotNull);
      });

      testWidgets('arrow down wraps from last to first', (tester) async {
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        // 5 entries total, press down 5 times to wrap around
        for (var i = 0; i < 5; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pump();
        }

        // Should be back at index 0 (first entry highlighted)
        final listTiles = tester.widgetList<ListTile>(find.byType(ListTile));
        final firstTile = listTiles.elementAt(0);
        expect(firstTile.tileColor, isNotNull);
      });

      testWidgets('arrow up wraps from first to last', (tester) async {
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        // Press up from index 0 should wrap to last entry
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        // Last entry (Electronic) should be highlighted
        final listTiles = tester.widgetList<ListTile>(find.byType(ListTile));
        final lastTile = listTiles.elementAt(4);
        expect(lastTile.tileColor, isNotNull);
      });
    });

    group('5.5 Enter selects and loads', () {
      testWidgets('Enter selects the highlighted entry', (tester) async {
        String? selectedPath;
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (path) => selectedPath = path,
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        // First entry is highlighted by default (Rock)
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(selectedPath, r'C:\Users\Music\Rock');
      });

      testWidgets('Enter selects after navigating with arrow keys',
          (tester) async {
        String? selectedPath;
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (path) => selectedPath = path,
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        // Navigate to the third entry (Pop)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(selectedPath, r'C:\Users\Music\Pop');
      });

      testWidgets('Enter selects filtered result', (tester) async {
        String? selectedPath;
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (path) => selectedPath = path,
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        // Filter to 'Jazz'
        await tester.enterText(find.byType(TextField), 'Jazz');
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(selectedPath, r'C:\Users\Music\Jazz');
      });
    });

    group('5.6 Escape dismisses', () {
      testWidgets('Escape calls onDismiss', (tester) async {
        var dismissed = false;
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () => dismissed = true,
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(dismissed, isTrue);
      });

      testWidgets('Escape does not trigger folder selection', (tester) async {
        String? selectedPath;
        var dismissed = false;
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (path) => selectedPath = path,
          onDismiss: () => dismissed = true,
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(dismissed, isTrue);
        expect(selectedPath, isNull);
      });
    });

    group('5.1 Display', () {
      testWidgets('shows a search TextField', (tester) async {
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('shows search hint text', (tester) async {
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Search folders...'), findsOneWidget);
      });

      testWidgets('shows bookmark icon for bookmark entries', (tester) async {
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () {},
          bookmarks: testBookmarks,
          recentFolders: [],
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.bookmark), findsNWidgets(3));
      });

      testWidgets('shows clock icon for recent entries', (tester) async {
        await tester.pumpWidget(buildTestWidget(
          onFolderSelected: (_) {},
          onDismiss: () {},
          bookmarks: [],
          recentFolders: testRecentFolders,
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.access_time), findsNWidgets(2));
      });
    });
  });
}
