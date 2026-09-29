import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/lookup_settings.dart';
import 'package:open_tag_editor/features/online_lookup/data/providers/lookup_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('defaults', () {
    test('ReplayGain is preserved out of the box', () {
      const settings = LookupSettings();

      expect(settings.preserves('replayGainTrackGain'), isTrue);
      expect(settings.preserves('replayGainAlbumPeak'), isTrue);
    });

    test('ordinary metadata is not preserved by default', () {
      const settings = LookupSettings();

      for (final field in ['title', 'artist', 'album', 'year', 'rating']) {
        expect(
          settings.preserves(field),
          isFalse,
          reason: '$field must stay appliable by default',
        );
      }
    });
  });

  group('presets', () {
    test('every preset field is a real tag field name', () {
      // A typo in a preset would silently preserve nothing, which looks
      // exactly like the feature working.
      for (final preset in PreservedFieldPreset.values) {
        for (final field in preset.fields) {
          expect(
            field,
            isNotEmpty,
            reason: '${preset.label} has a blank field',
          );
          expect(
            field,
            matches(RegExp(r'^[a-zA-Z][a-zA-Z0-9]*$')),
            reason: '$field does not look like an app field name',
          );
        }
      }
    });

    test('the ReplayGain preset covers all four ReplayGain fields', () {
      expect(
        PreservedFieldPreset.replayGain.fields,
        LookupSettings.defaultPreservedFields,
      );
    });

    test('presets do not overlap', () {
      final seen = <String>{};
      for (final preset in PreservedFieldPreset.values) {
        expect(
          seen.intersection(preset.fields),
          isEmpty,
          reason: '${preset.label} overlaps another preset',
        );
        seen.addAll(preset.fields);
      }
    });
  });

  group('notifier', () {
    test('toggling a single field adds and removes it', () async {
      final notifier = LookupSettingsNotifier();
      await notifier.loadFromPrefs();

      notifier.togglePreservedField('rating', true);
      expect(notifier.state.preserves('rating'), isTrue);

      notifier.togglePreservedField('rating', false);
      expect(notifier.state.preserves('rating'), isFalse);
    });

    test('toggling a preset adds the whole group', () async {
      final notifier = LookupSettingsNotifier();
      await notifier.loadFromPrefs();

      notifier.togglePreset(PreservedFieldPreset.ratings, true);
      expect(notifier.state.preserves('rating'), isTrue);
      expect(notifier.state.preserves('mood'), isTrue);
    });

    test('disabling a preset removes only its own fields', () async {
      final notifier = LookupSettingsNotifier();
      await notifier.loadFromPrefs();
      notifier
        ..togglePreservedField('title', true)
        ..togglePreset(PreservedFieldPreset.ratings, true)
        ..togglePreset(PreservedFieldPreset.ratings, false);

      expect(notifier.state.preserves('rating'), isFalse);
      expect(notifier.state.preserves('title'), isTrue);
      expect(notifier.state.preserves('mood'), isFalse);
    });

    test('preserved fields persist across a reload', () async {
      final notifier = LookupSettingsNotifier();
      await notifier.loadFromPrefs();
      notifier
        ..togglePreset(PreservedFieldPreset.ratings, true)
        ..togglePreservedField('isrc', true);
      // Persistence is fire-and-forget.
      await Future<void>.delayed(Duration.zero);

      final reloaded = LookupSettingsNotifier();
      await reloaded.loadFromPrefs();

      expect(reloaded.state.preserves('rating'), isTrue);
      expect(reloaded.state.preserves('isrc'), isTrue);
    });

    test('resetToDefaults restores the default preserved set', () async {
      final notifier = LookupSettingsNotifier();
      await notifier.loadFromPrefs();
      notifier.togglePreset(PreservedFieldPreset.ratings, true);
      notifier.resetToDefaults();
      await Future<void>.delayed(Duration.zero);

      final reloaded = LookupSettingsNotifier();
      await reloaded.loadFromPrefs();

      expect(
        reloaded.state.preservedFields,
        LookupSettings.defaultPreservedFields,
      );
    });

    test('a field may be preserved individually and via its preset', () async {
      final notifier = LookupSettingsNotifier();
      await notifier.loadFromPrefs();

      notifier
        ..togglePreservedField('rating', true)
        ..togglePreset(PreservedFieldPreset.ratings, false);

      // 'rating' is in the ratings preset, so disabling the preset must
      // clear it even though it was set individually.
      expect(notifier.state.preserves('rating'), isFalse);
    });
  });

  group('equality', () {
    test('set order does not affect equality', () {
      const a = LookupSettings(preservedFields: {'a', 'b'});
      const b = LookupSettings(preservedFields: {'b', 'a'});

      expect(a, equals(b));
    });

    test('a different set is not equal', () {
      const a = LookupSettings(preservedFields: {'a'});
      const b = LookupSettings(preservedFields: {'a', 'b'});

      expect(a, isNot(equals(b)));
    });
  });
}
