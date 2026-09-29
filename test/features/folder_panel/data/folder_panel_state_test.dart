import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/folder_panel/data/folder_panel_state_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Feature: folder-selection-ux, Property 1: Folder panel visibility persistence round-trip
  // **Validates: Requirements 1.4**

  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 1: Folder panel visibility persistence round-trip', () {
    test(
      'persisting a boolean visibility state and loading it back produces the same value',
      () async {
        final rng = Random(42);

        for (var i = 0; i < 100; i++) {
          final value = rng.nextBool();

          // Start with empty prefs
          SharedPreferences.setMockInitialValues({});

          // Create notifier, set visibility, which persists to prefs
          final notifier = FolderPanelStateNotifier();
          notifier.setVisible(value);

          // Allow async persist to complete
          await Future<void>.delayed(Duration.zero);

          // Create a fresh notifier and load from prefs
          final reloaded = FolderPanelStateNotifier();
          await reloaded.loadFromPrefs();

          expect(
            reloaded.state,
            equals(value),
            reason:
                'Round-trip failed for value=$value (iteration $i): '
                'persisted $value but loaded ${reloaded.state}',
          );

          // Clean up
          notifier.dispose();
          reloaded.dispose();
        }
      },
    );
  });
}
