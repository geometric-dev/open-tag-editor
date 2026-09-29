import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/core/constants/supported_formats.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/recent_folders_provider.dart';
import 'package:open_tag_editor/features/tag_editor/data/services/editor_open_service.dart';
import 'package:open_tag_editor/features/tag_editor/presentation/widgets/data_grid/empty_state_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('formatSummary', () {
    test('summarises the supported formats', () {
      final summary = EditorOpenService.formatSummary();

      expect(summary, contains('MP3'));
      expect(summary, contains('FLAC'));
      expect(summary, contains('more'));
    });

    test('lists everything when the limit is generous', () {
      final summary = EditorOpenService.formatSummary(max: 1000);

      expect(summary.contains('more'), isFalse);
      expect(summary.split(',').length, SupportedFormats.all.length);
    });

    test('never leaks a leading dot', () {
      expect(EditorOpenService.formatSummary(max: 1000), isNot(contains('. ')));
    });
  });

  group('pickableExtensions', () {
    test('every offered extension is a supported format', () {
      for (final ext in EditorOpenService.pickableExtensions) {
        expect(
          SupportedFormats.isSupported('.$ext'),
          isTrue,
          reason: '.$ext is offered in the picker but not supported',
        );
      }
    });
  });

  group('EmptyStateView', () {
    Widget host() => const ProviderScope(
      child: MaterialApp(home: Scaffold(body: EmptyStateView())),
    );

    testWidgets('offers Open Folder and Open Files', (tester) async {
      await tester.pumpWidget(host());

      expect(find.widgetWithText(FilledButton, 'Open Folder'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Open Files'), findsOneWidget);
    });

    testWidgets('mentions drag and drop and the supported formats', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      expect(
        find.textContaining('Drop audio files or folders'),
        findsOneWidget,
      );
      expect(find.textContaining('MP3'), findsOneWidget);
    });

    testWidgets('lists feature highlights', (tester) async {
      await tester.pumpWidget(host());

      expect(find.textContaining('Edit tags'), findsOneWidget);
      expect(find.textContaining('Rename files'), findsOneWidget);
      expect(find.textContaining('Look up metadata'), findsOneWidget);
    });

    testWidgets('links to settings', (tester) async {
      await tester.pumpWidget(host());

      expect(find.widgetWithText(TextButton, 'Settings'), findsOneWidget);
    });

    testWidgets('hides the recent list when there is nothing recent', (
      tester,
    ) async {
      await tester.pumpWidget(host());

      expect(find.text('Recent folders'), findsNothing);
    });

    testWidgets('shows recent folders when present', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(recentFoldersProvider.notifier)
        ..addFolder('/music/rock')
        ..addFolder('/music/jazz');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: EmptyStateView())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent folders'), findsOneWidget);
      expect(find.text('/music/rock'), findsOneWidget);
      expect(find.text('/music/jazz'), findsOneWidget);
    });

    testWidgets('caps the recent list so it cannot grow without bound', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(recentFoldersProvider.notifier);
      for (var i = 0; i < 12; i++) {
        notifier.addFolder('/music/folder$i');
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: EmptyStateView())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.history), findsNWidgets(6));
    });
  });
}
