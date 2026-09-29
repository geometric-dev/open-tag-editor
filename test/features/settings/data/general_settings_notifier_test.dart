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

  group('accessibility settings', () {
    test('high contrast defaults to off and persists', () async {
      final notifier = GeneralSettingsNotifier();
      await notifier.loadFromPrefs();
      expect(notifier.state.highContrast, isFalse);

      notifier.setHighContrast(true);
      await Future<void>.delayed(Duration.zero);

      final reloaded = GeneralSettingsNotifier();
      await reloaded.loadFromPrefs();
      expect(reloaded.state.highContrast, isTrue);
    });

    test('ui scale defaults to 1.0 and persists', () async {
      final notifier = GeneralSettingsNotifier();
      await notifier.loadFromPrefs();
      expect(notifier.state.uiScale, 1.0);

      notifier.setUiScale(1.3);
      await Future<void>.delayed(Duration.zero);

      final reloaded = GeneralSettingsNotifier();
      await reloaded.loadFromPrefs();
      expect(reloaded.state.uiScale, 1.3);
    });

    test('ui scale is clamped to a range the UI can actually render', () async {
      final notifier = GeneralSettingsNotifier();
      await notifier.loadFromPrefs();

      notifier.setUiScale(0.01);
      expect(notifier.state.uiScale, GeneralSettings.minUiScale);

      notifier.setUiScale(99);
      expect(notifier.state.uiScale, GeneralSettings.maxUiScale);
    });

    test('effectiveUiScale clamps even if state was loaded out of range', () {
      const absurd = GeneralSettings(uiScale: 50);
      expect(absurd.effectiveUiScale, GeneralSettings.maxUiScale);
    });

    test('every offered scale option is inside the supported range', () {
      for (final option in GeneralSettings.uiScaleOptions) {
        expect(
          option,
          inInclusiveRange(
            GeneralSettings.minUiScale,
            GeneralSettings.maxUiScale,
          ),
        );
      }
    });

    test('the offered options include 100% and are strictly increasing', () {
      expect(GeneralSettings.uiScaleOptions, contains(1.0));
      for (var i = 1; i < GeneralSettings.uiScaleOptions.length; i++) {
        expect(
          GeneralSettings.uiScaleOptions[i],
          greaterThan(GeneralSettings.uiScaleOptions[i - 1]),
        );
      }
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
