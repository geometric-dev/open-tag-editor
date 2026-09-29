/// Provides bidirectional mapping between the app's internal field names
/// and TagLib property keys used by the Properties API.
class TagPropertyMapper {
  TagPropertyMapper._();

  /// Maps app field names to TagLib property keys.
  static const Map<String, String> _appToTagLib = {
    'title': 'TITLE',
    'artist': 'ARTIST',
    'albumArtist': 'ALBUMARTIST',
    'album': 'ALBUM',
    'year': 'DATE',
    'trackNumber': 'TRACKNUMBER',
    'trackTotal': 'TRACKTOTAL',
    'discNumber': 'DISCNUMBER',
    'discTotal': 'DISCTOTAL',
    'genre': 'GENRE',
    'comment': 'COMMENT',
    'composer': 'COMPOSER',
    'conductor': 'CONDUCTOR',
    'lyricist': 'LYRICIST',
    'publisher': 'PUBLISHER',
    'copyright': 'COPYRIGHT',
    'bpm': 'BPM',
    'compilation': 'COMPILATION',
    'lyrics': 'LYRICS',
    'rating': 'RATING',
    'mood': 'MOOD',
    'grouping': 'GROUPING',
    'subtitle': 'SUBTITLE',
    'language': 'LANGUAGE',
    'originalArtist': 'ORIGINALARTIST',
    'remixer': 'REMIXEDBY',
    'label': 'LABEL',
    'catalogNumber': 'CATALOGNUMBER',
    'isrc': 'ISRC',
    'url': 'URL',

    // ReplayGain is calculated data, not authored metadata, but it has to
    // be addressable for two reasons: the panel shows it read-only, and
    // "Clear ReplayGain" needs a real write. TagLib surfaces these as
    // TXXX frames on ID3v2 and as plain keys on Vorbis Comment / APEv2,
    // using this same spelling in both cases.
    'replayGainTrackGain': 'REPLAYGAIN_TRACK_GAIN',
    'replayGainTrackPeak': 'REPLAYGAIN_TRACK_PEAK',
    'replayGainAlbumGain': 'REPLAYGAIN_ALBUM_GAIN',
    'replayGainAlbumPeak': 'REPLAYGAIN_ALBUM_PEAK',
  };

  /// Maps TagLib property keys to app field names.
  static const Map<String, String> _tagLibToApp = {
    'TITLE': 'title',
    'ARTIST': 'artist',
    'ALBUMARTIST': 'albumArtist',
    'ALBUM': 'album',
    'DATE': 'year',
    'TRACKNUMBER': 'trackNumber',
    'TRACKTOTAL': 'trackTotal',
    'DISCNUMBER': 'discNumber',
    'DISCTOTAL': 'discTotal',
    'GENRE': 'genre',
    'COMMENT': 'comment',
    'COMPOSER': 'composer',
    'CONDUCTOR': 'conductor',
    'LYRICIST': 'lyricist',
    'PUBLISHER': 'publisher',
    'COPYRIGHT': 'copyright',
    'BPM': 'bpm',
    'COMPILATION': 'compilation',
    'LYRICS': 'lyrics',
    'RATING': 'rating',
    'MOOD': 'mood',
    'GROUPING': 'grouping',
    'SUBTITLE': 'subtitle',
    'LANGUAGE': 'language',
    'ORIGINALARTIST': 'originalArtist',
    'REMIXEDBY': 'remixer',
    'LABEL': 'label',
    'CATALOGNUMBER': 'catalogNumber',
    'ISRC': 'isrc',
    'URL': 'url',
    'REPLAYGAIN_TRACK_GAIN': 'replayGainTrackGain',
    'REPLAYGAIN_TRACK_PEAK': 'replayGainTrackPeak',
    'REPLAYGAIN_ALBUM_GAIN': 'replayGainAlbumGain',
    'REPLAYGAIN_ALBUM_PEAK': 'replayGainAlbumPeak',
  };

  /// Converts an app field name to the corresponding TagLib property key.
  ///
  /// Returns `null` if the field name is not recognized.
  static String? toTagLibKey(String appField) {
    return _appToTagLib[appField];
  }

  /// Converts a TagLib property key to the corresponding app field name.
  ///
  /// Returns `null` if the property key is not recognized.
  static String? toAppField(String tagLibKey) {
    return _tagLibToApp[tagLibKey];
  }

  /// Parses a track or disc number string that may contain a total.
  ///
  /// Values like `"3/12"` are split into `("3", "12")`.
  /// Values without a slash return `(value, null)`.
  static (String number, String? total) parseTrackNumber(String value) {
    final parts = value.split('/');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return (parts[0], parts[1]);
    }
    return (value, null);
  }

  /// Formats a track or disc number with an optional total.
  ///
  /// If [total] is non-null and non-empty, returns `"number/total"`.
  /// Otherwise returns just the [number].
  static String formatTrackNumber(String number, String? total) {
    if (total != null && total.isNotEmpty) {
      return '$number/$total';
    }
    return number;
  }
}
