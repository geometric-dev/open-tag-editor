import '../../../../shared/models/audio_file.dart';

/// A ReplayGain field the app recognises.
///
/// These are calculated values produced by a scanner such as `loudgain` or
/// foobar2000. The app never invents or edits them: it displays what is on
/// disk, preserves it through unrelated edits, and offers an explicit way
/// to clear it so an external tool can recalculate.
enum ReplayGainField {
  trackGain('replayGainTrackGain', 'Track Gain', 'REPLAYGAIN_TRACK_GAIN'),
  trackPeak('replayGainTrackPeak', 'Track Peak', 'REPLAYGAIN_TRACK_PEAK'),
  albumGain('replayGainAlbumGain', 'Album Gain', 'REPLAYGAIN_ALBUM_GAIN'),
  albumGainPeak('replayGainAlbumPeak', 'Album Peak', 'REPLAYGAIN_ALBUM_PEAK');

  const ReplayGainField(this.appField, this.label, this.tagLibKey);

  /// Field name in `AudioFile.tags`.
  final String appField;

  /// Human-readable label for the panel.
  final String label;

  /// Underlying TagLib property key.
  final String tagLibKey;
}

/// Aggregated display state for one ReplayGain field across a selection.
enum ReplayGainDisplay {
  /// No selected file carries a value.
  notSet,

  /// Every selected file carries the same value.
  value,

  /// Selected files disagree, or only some carry a value.
  varies;

  /// Label to render for a single file's raw value.
  static const notSetLabel = 'Not set';
  static const variesLabel = 'varies';
}

/// Resolves what to show for [field] across [files].
///
/// Single-file selections show the value as-is. Multi-file selections show
/// the value only when every file agrees, and `varies` otherwise, so the
/// user is never shown a number that is true of only part of the selection.
({String display, ReplayGainDisplay state}) summariseReplayGain(
  ReplayGainField field,
  Iterable<AudioFile> files,
) {
  final list = files.toList();
  if (list.isEmpty) {
    return (
      display: ReplayGainDisplay.notSetLabel,
      state: ReplayGainDisplay.notSet,
    );
  }

  final values = <String>{};
  var withValue = 0;
  for (final file in list) {
    final raw = file.tags[field.appField]?.trim();
    if (raw != null && raw.isNotEmpty) {
      values.add(raw);
      withValue++;
    }
  }

  if (values.isEmpty) {
    return (
      display: ReplayGainDisplay.notSetLabel,
      state: ReplayGainDisplay.notSet,
    );
  }
  // Disagreement, or only some files carrying it, both read as "varies":
  // showing one file's number for a mixed selection would be a lie.
  if (values.length > 1 || withValue < list.length) {
    return (
      display: ReplayGainDisplay.variesLabel,
      state: ReplayGainDisplay.varies,
    );
  }

  return (display: values.single, state: ReplayGainDisplay.value);
}

/// Files in [files] that actually carry at least one ReplayGain value.
int countWithReplayGain(Iterable<AudioFile> files) =>
    files.where(hasAnyReplayGain).length;

/// Whether [file] carries any ReplayGain value at all.
bool hasAnyReplayGain(AudioFile file) => ReplayGainField.values.any((f) {
  final value = file.tags[f.appField]?.trim();
  return value != null && value.isNotEmpty;
});

/// The set of ReplayGain fields present on [file].
Set<String> presentReplayGainFields(AudioFile file) => {
  for (final field in ReplayGainField.values)
    if ((file.tags[field.appField]?.trim() ?? '').isNotEmpty) field.appField,
};
