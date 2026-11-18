import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/core/utils/cancellation_token.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/folder_loading_provider.dart';
import 'package:open_tag_editor/features/tag_editor/presentation/widgets/folder_load_indicator.dart';

void main() {
  group('FolderLoadProgress', () {
    test('is idle by default', () {
      expect(FolderLoadProgress.idle.isActive, isFalse);
      expect(FolderLoadProgress.idle.fraction, isNull);
    });

    test('is active part-way through a load', () {
      const progress = FolderLoadProgress(total: 100, completed: 25);

      expect(progress.isActive, isTrue);
      expect(progress.fraction, 0.25);
    });

    test('is not active once every file has been read', () {
      const progress = FolderLoadProgress(total: 100, completed: 100);

      expect(progress.isActive, isFalse);
      expect(progress.fraction, 1.0);
    });

    test('reports no fraction for a zero-file load', () {
      const progress = FolderLoadProgress(total: 0, completed: 0);

      expect(progress.isActive, isFalse);
      expect(progress.fraction, isNull);
    });

    test('is inactive for an empty folder listing', () {
      // A folder with no supported audio files returns before any progress is
      // published, so the indicator must not appear at all.
      const progress = FolderLoadProgress(total: 0, completed: 0);
      expect(progress.isActive, isFalse);
    });

    test('scanning stage is active with indeterminate fraction', () {
      final token = CancellationToken();
      final progress = FolderLoadProgress(
        stage: FolderLoadStage.scanning,
        total: 42,
        completed: 0,
        cancellationToken: token,
      );

      expect(progress.isActive, isTrue);
      expect(progress.isScanning, isTrue);
      expect(progress.isReadingTags, isFalse);
      expect(progress.fraction, isNull);
      expect(progress.cancellationToken, equals(token));
      expect(token.isCancelled, isFalse);
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('readingTags stage is active with determinate fraction', () {
      const progress = FolderLoadProgress(
        stage: FolderLoadStage.readingTags,
        total: 200,
        completed: 100,
      );

      expect(progress.isActive, isTrue);
      expect(progress.isScanning, isFalse);
      expect(progress.isReadingTags, isTrue);
      expect(progress.fraction, 0.5);
    });
  });

  group('indicator widget', () {
    Future<void> pump(WidgetTester tester, FolderLoadProgress progress) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            folderLoadProgressProvider.overrideWith((ref) => progress),
          ],
          child: const MaterialApp(home: Scaffold(body: FolderLoadIndicator())),
        ),
      );
    }

    testWidgets('renders nothing when idle', (tester) async {
      await pump(tester, FolderLoadProgress.idle);

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byType(FractionallySizedBox), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('renders nothing when the load has completed', (tester) async {
      await pump(tester, const FolderLoadProgress(total: 50, completed: 50));

      expect(find.byType(FractionallySizedBox), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('renders indeterminate progress bar during scanning', (
      tester,
    ) async {
      await pump(
        tester,
        const FolderLoadProgress(
          stage: FolderLoadStage.scanning,
          total: 10,
          completed: 0,
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(FractionallySizedBox), findsNothing);
    });

    testWidgets('renders a bar mid-load', (tester) async {
      await pump(tester, const FolderLoadProgress(total: 50, completed: 10));

      expect(find.byType(FractionallySizedBox), findsOneWidget);
      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, 0.2);
    });

    testWidgets('does not overflow when completed exceeds total', (
      tester,
    ) async {
      await pump(tester, const FolderLoadProgress(total: 5, completed: 7));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
