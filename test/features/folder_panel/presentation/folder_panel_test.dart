import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/folder_panel/data/bookmark_entry.dart';
import 'package:open_tag_editor/features/folder_panel/data/bookmarks_notifier.dart';
import 'package:open_tag_editor/features/folder_panel/presentation/folder_panel.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/recent_folders_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A test-only bookmarks notifier that can be pre-populated with entries.
class _TestBookmarksNotifier extends BookmarksNotifier {
  _TestBookmarksNotifier(List<BookmarkEntry> initial) : super() {
    state = initial;
  }
}

/// A test-only recent folders notifier that can be pre-populated.
class _TestRecentFoldersNotifier extends RecentFoldersNotifier {
  _TestRecentFoldersNotifier(List<String> initial) : super() {
    state = initial;
  }
}

void main() {
  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('folder_panel_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget buildTestWidget({
    List<BookmarkEntry> bookmarks = const [],
    List<String> recentFolders = const [],
    void Function(String)? onFolderSelected,
  }) {
    return ProviderScope(
      overrides: [
        bookmarksProvider.overrideWith(
          (ref) => _TestBookmarksNotifier(bookmarks),
        ),
        recentFoldersProvider.overrideWith(
          (ref) => _TestRecentFoldersNotifier(recentFolders),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: FolderPanel(
            onFolderSelected: onFolderSelected ?? (_) {},
          ),
        ),
      ),
    );
  }

  group('FolderPanel', () {
    group('section rendering', () {
      testWidgets('renders Bookmarks and Recent Folders section headers',
          (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('Bookmarks'), findsOneWidget);
        expect(find.text('Recent Folders'), findsOneWidget);
      });

      testWidgets('shows empty placeholders when no data', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.text('No bookmarks yet'), findsOneWidget);
        expect(find.text('No recent folders'), findsOneWidget);
      });

      testWidgets('renders bookmark entries with name and path',
          (tester) async {
        final musicDir =
            Directory('${tempDir.path}${Platform.pathSeparator}Music')
              ..createSync();
        final bookmarks = [
          BookmarkEntry(path: musicDir.path, name: 'Music'),
        ];

        await tester.pumpWidget(buildTestWidget(bookmarks: bookmarks));
        await tester.pumpAndSettle();

        expect(find.text('Music'), findsOneWidget);
        expect(find.text(musicDir.path), findsOneWidget);
      });

      testWidgets('renders recent folder entries with basename and path',
          (tester) async {
        final albumDir =
            Directory('${tempDir.path}${Platform.pathSeparator}Album')
              ..createSync();
        final recentFolders = [albumDir.path];

        await tester.pumpWidget(buildTestWidget(recentFolders: recentFolders));
        await tester.pumpAndSettle();

        expect(find.text('Album'), findsOneWidget);
        expect(find.text(albumDir.path), findsOneWidget);
      });
    });

    group('click triggers folder loading', () {
      testWidgets('clicking a bookmark entry calls onFolderSelected',
          (tester) async {
        String? selectedPath;
        final musicDir =
            Directory('${tempDir.path}${Platform.pathSeparator}Music')
              ..createSync();
        final bookmarks = [
          BookmarkEntry(path: musicDir.path, name: 'Music'),
        ];

        await tester.pumpWidget(buildTestWidget(
          bookmarks: bookmarks,
          onFolderSelected: (path) => selectedPath = path,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Music'));
        await tester.pump();

        expect(selectedPath, musicDir.path);
      });

      testWidgets('clicking a recent folder entry calls onFolderSelected',
          (tester) async {
        String? selectedPath;
        final albumDir =
            Directory('${tempDir.path}${Platform.pathSeparator}Album')
              ..createSync();
        final recentFolders = [albumDir.path];

        await tester.pumpWidget(buildTestWidget(
          recentFolders: recentFolders,
          onFolderSelected: (path) => selectedPath = path,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Album'));
        await tester.pump();

        expect(selectedPath, albumDir.path);
      });
    });

    group('context menu', () {
      testWidgets(
          'right-click on bookmark shows Remove Bookmark context menu',
          (tester) async {
        final musicDir =
            Directory('${tempDir.path}${Platform.pathSeparator}Music')
              ..createSync();
        final bookmarks = [
          BookmarkEntry(path: musicDir.path, name: 'Music'),
        ];

        await tester.pumpWidget(buildTestWidget(bookmarks: bookmarks));
        await tester.pumpAndSettle();

        // Perform a secondary (right) click on the bookmark entry name.
        final target = find.text('Music');
        final center = tester.getCenter(target);
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.addPointer(location: center);
        await gesture.down(center);
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('Remove Bookmark'), findsOneWidget);
      });

      testWidgets(
          'right-click on recent folder shows Add to Bookmarks and Remove from History',
          (tester) async {
        final albumDir =
            Directory('${tempDir.path}${Platform.pathSeparator}Album')
              ..createSync();
        final recentFolders = [albumDir.path];

        await tester.pumpWidget(buildTestWidget(recentFolders: recentFolders));
        await tester.pumpAndSettle();

        final target = find.text('Album');
        final center = tester.getCenter(target);
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.addPointer(location: center);
        await gesture.down(center);
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('Add to Bookmarks'), findsOneWidget);
        expect(find.text('Remove from History'), findsOneWidget);
      });
    });

    group('invalid path indicator', () {
      testWidgets('shows warning icon for bookmark with non-existent path',
          (tester) async {
        final invalidPath = r'C:\nonexistent_path_xyz_12345';
        final bookmarks = [
          BookmarkEntry(path: invalidPath, name: 'Missing'),
        ];

        await tester.pumpWidget(buildTestWidget(bookmarks: bookmarks));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      });

      testWidgets('shows warning icon for recent folder with non-existent path',
          (tester) async {
        final invalidPath = r'C:\nonexistent_path_xyz_12345';

        await tester.pumpWidget(
          buildTestWidget(recentFolders: [invalidPath]),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      });

      testWidgets('does not show warning icon for valid path', (tester) async {
        final validDir =
            Directory('${tempDir.path}${Platform.pathSeparator}Valid')
              ..createSync();
        final bookmarks = [
          BookmarkEntry(path: validDir.path, name: 'Valid'),
        ];

        await tester.pumpWidget(buildTestWidget(bookmarks: bookmarks));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      });
    });

    group('drag-and-drop reorder', () {
      testWidgets('bookmarks section uses ReorderableListView with drag handles',
          (tester) async {
        // Create two subdirectories so we have two valid bookmark paths.
        final dir1 = Directory('${tempDir.path}${Platform.pathSeparator}Alpha')
          ..createSync();
        final dir2 = Directory('${tempDir.path}${Platform.pathSeparator}Beta')
          ..createSync();

        final bookmarks = [
          BookmarkEntry(path: dir1.path, name: 'Alpha'),
          BookmarkEntry(path: dir2.path, name: 'Beta'),
        ];

        await tester.pumpWidget(buildTestWidget(bookmarks: bookmarks));
        await tester.pumpAndSettle();

        // Verify drag handles are present (one per bookmark entry).
        expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
      });
    });
  });
}
