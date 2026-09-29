import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/settings/data/models/general_settings.dart';
import 'package:open_tag_editor/features/settings/data/notifiers/general_settings_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('confirmBeforeSave', () {
    test('defaults to off so saves are not interrupted', () {
      expect(const GeneralSettings().confirmBeforeSave, isFalse);
    });

    test('round-trips through SharedPreferences', () async {
      final notifier = GeneralSettingsNotifier();
      await notifier.loadFromPrefs();
      expect(notifier.state.confirmBeforeSave, isFalse);

      notifier.setConfirmBeforeSave(true);
      // Persistence is fire-and-forget; read the written value directly.
      await Future<void>.delayed(Duration.zero);

      final reloaded = GeneralSettingsNotifier();
      await reloaded.loadFromPrefs();
      expect(reloaded.state.confirmBeforeSave, isTrue);
    });

    test('is reset by resetToDefaults', () async {
      final notifier = GeneralSettingsNotifier();
      await notifier.loadFromPrefs();
      notifier.setConfirmBeforeSave(true);
      await Future<void>.delayed(Duration.zero);

      notifier.resetToDefaults();
      await Future<void>.delayed(Duration.zero);

      final reloaded = GeneralSettingsNotifier();
      await reloaded.loadFromPrefs();
      expect(reloaded.state.confirmBeforeSave, isFalse);
    });
  });

  group('persistence of the other general settings', () {
    test('all fields round-trip', () async {
      final notifier = GeneralSettingsNotifier();
      await notifier.loadFromPrefs();
      notifier
        ..setReopenLastFolder(true)
        ..setFileCountThreshold(1234)
        ..setBackupEnabled(false)
        ..setPreserveTimestamp(true)
        ..setConfirmBeforeSave(true)
        ..setThemeMode(AppThemeMode.dark);
      await Future<void>.delayed(Duration.zero);

      final reloaded = GeneralSettingsNotifier();
      await reloaded.loadFromPrefs();

      expect(reloaded.state.reopenLastFolder, isTrue);
      expect(reloaded.state.fileCountThreshold, 1234);
      expect(reloaded.state.backupEnabled, isFalse);
      expect(reloaded.state.preserveTimestamp, isTrue);
      expect(reloaded.state.confirmBeforeSave, isTrue);
      expect(reloaded.state.themeMode, AppThemeMode.dark);
    });

    test('fileCountThreshold is clamped to a sane range', () async {
      final notifier = GeneralSettingsNotifier();
      await notifier.loadFromPrefs();

      notifier.setFileCountThreshold(1);
      expect(notifier.state.fileCountThreshold, 50);

      notifier.setFileCountThreshold(999999);
      expect(notifier.state.fileCountThreshold, 10000);
    });
  });
}
