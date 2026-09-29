import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/tools/data/replay_gain.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:open_tag_editor/shared/services/taglib/tag_property_mapper.dart';

AudioFile file(Map<String, String> tags) => AudioFile(
  path: '/a.mp3',
  filename: 'a.mp3',
  extension: '.mp3',
  fileSize: 1,
  tags: tags,
);

void main() {
  group('mapper wiring', () {
    test('every ReplayGain field maps to a TagLib key', () {
      for (final field in ReplayGainField.values) {
        expect(
          TagPropertyMapper.toTagLibKey(field.appField),
          field.tagLibKey,
          reason: '${field.appField} must be writable',
        );
      }
    });

    test('every ReplayGain TagLib key maps back to a field', () {
      for (final field in ReplayGainField.values) {
        expect(
          TagPropertyMapper.toAppField(field.tagLibKey),
          field.appField,
          reason: '${field.tagLibKey} must be readable',
        );
      }
    });

    test('the four documented ReplayGain keys are covered', () {
      expect(ReplayGainField.values.map((f) => f.tagLibKey).toSet(), {
        'REPLAYGAIN_TRACK_GAIN',
        'REPLAYGAIN_TRACK_PEAK',
        'REPLAYGAIN_ALBUM_GAIN',
        'REPLAYGAIN_ALBUM_PEAK',
      });
    });
  });

  group('summariseReplayGain', () {
    test('no files reads as not set', () {
      final summary = summariseReplayGain(ReplayGainField.trackGain, const []);

      expect(summary.state, ReplayGainDisplay.notSet);
      expect(summary.display, 'Not set');
    });

    test('a single file with no value reads as not set', () {
      final summary = summariseReplayGain(ReplayGainField.trackGain, [
        file(const {}),
      ]);

      expect(summary.state, ReplayGainDisplay.notSet);
    });

    test('a single file shows its value verbatim', () {
      final summary = summariseReplayGain(ReplayGainField.trackGain, [
        file(const {'replayGainTrackGain': '-6.5 dB'}),
      ]);

      expect(summary.state, ReplayGainDisplay.value);
      expect(summary.display, '-6.5 dB');
    });

    test('identical values across files show the common value', () {
      final summary = summariseReplayGain(ReplayGainField.trackGain, [
        file(const {'replayGainTrackGain': '-6.5 dB'}),
        file(const {'replayGainTrackGain': '-6.5 dB'}),
      ]);

      expect(summary.state, ReplayGainDisplay.value);
      expect(summary.display, '-6.5 dB');
    });

    test('differing values read as varies', () {
      final summary = summariseReplayGain(ReplayGainField.trackGain, [
        file(const {'replayGainTrackGain': '-6.5 dB'}),
        file(const {'replayGainTrackGain': '-9.1 dB'}),
      ]);

      expect(summary.state, ReplayGainDisplay.varies);
      expect(summary.display, 'varies');
    });

    test('a value on only some files reads as varies, not as that value', () {
      final summary = summariseReplayGain(ReplayGainField.trackGain, [
        file(const {'replayGainTrackGain': '-6.5 dB'}),
        file(const {}),
      ]);

      expect(summary.state, ReplayGainDisplay.varies);
      expect(summary.display, 'varies');
    });

    test('whitespace-only values count as absent', () {
      final summary = summariseReplayGain(ReplayGainField.trackPeak, [
        file(const {'replayGainTrackPeak': '   '}),
      ]);

      expect(summary.state, ReplayGainDisplay.notSet);
    });

    test('each field is summarised independently', () {
      final files = [
        file(const {'replayGainTrackGain': '-6.5 dB'}),
      ];

      expect(
        summariseReplayGain(ReplayGainField.trackGain, files).display,
        '-6.5 dB',
      );
      expect(
        summariseReplayGain(ReplayGainField.albumGain, files).state,
        ReplayGainDisplay.notSet,
      );
    });
  });

  group('presence helpers', () {
    test('hasAnyReplayGain is false for an untagged file', () {
      expect(hasAnyReplayGain(file(const {})), isFalse);
    });

    test('hasAnyReplayGain is true when any one field is present', () {
      expect(
        hasAnyReplayGain(file(const {'replayGainAlbumPeak': '1.000'})),
        isTrue,
      );
    });

    test('hasAnyReplayGain ignores blank values', () {
      expect(
        hasAnyReplayGain(file(const {'replayGainAlbumPeak': ''})),
        isFalse,
      );
    });

    test('presentReplayGainFields lists only populated fields', () {
      final present = presentReplayGainFields(
        file(const {
          'replayGainTrackGain': '-6.5 dB',
          'replayGainTrackPeak': '0.988',
          'replayGainAlbumGain': '',
        }),
      );

      expect(present, {'replayGainTrackGain', 'replayGainTrackPeak'});
    });

    test('countWithReplayGain counts only covered files', () {
      final count = countWithReplayGain([
        file(const {'replayGainTrackGain': '-6.5 dB'}),
        file(const {}),
        file(const {'replayGainAlbumGain': '-8.2 dB'}),
      ]);

      expect(count, 2);
    });
  });
}
