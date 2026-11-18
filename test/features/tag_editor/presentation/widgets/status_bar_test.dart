import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/core/utils/cancellation_token.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/editor_state_provider.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/folder_loading_provider.dart';
import 'package:open_tag_editor/features/tag_editor/presentation/widgets/status_bar.dart';

void main() {
  group('EnhancedStatusBar', () {
    testWidgets('renders idle status message', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            statusMessageProvider.overrideWith((ref) => 'Ready'),
            folderLoadProgressProvider.overrideWith(
              (ref) => FolderLoadProgress.idle,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(bottomNavigationBar: EnhancedStatusBar()),
          ),
        ),
      );

      expect(find.text('Ready'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cancel_folder_load_button')),
        findsNothing,
      );
    });

    testWidgets('renders scanning progress and triggers cancel on button tap', (
      tester,
    ) async {
      final token = CancellationToken();
      final progress = FolderLoadProgress(
        stage: FolderLoadStage.scanning,
        total: 125,
        completed: 0,
        cancellationToken: token,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            folderLoadProgressProvider.overrideWith((ref) => progress),
          ],
          child: const MaterialApp(
            home: Scaffold(bottomNavigationBar: EnhancedStatusBar()),
          ),
        ),
      );

      expect(find.text('Scanning... 125 audio file(s) found'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final cancelButton = find.byKey(
        const ValueKey('cancel_folder_load_button'),
      );
      expect(cancelButton, findsOneWidget);

      expect(token.isCancelled, isFalse);
      await tester.tap(cancelButton);
      await tester.pump();
      expect(token.isCancelled, isTrue);
    });

    testWidgets(
      'renders readingTags progress with percentage and cancel button',
      (tester) async {
        final token = CancellationToken();
        final progress = FolderLoadProgress(
          stage: FolderLoadStage.readingTags,
          total: 200,
          completed: 50,
          cancellationToken: token,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              folderLoadProgressProvider.overrideWith((ref) => progress),
            ],
            child: const MaterialApp(
              home: Scaffold(bottomNavigationBar: EnhancedStatusBar()),
            ),
          ),
        );

        expect(find.text('Loading 50 of 200 (25%)'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          find.byKey(const ValueKey('cancel_folder_load_button')),
          findsOneWidget,
        );
      },
    );
  });
}
