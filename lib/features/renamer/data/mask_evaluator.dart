import '../../../shared/models/audio_file.dart';
import 'models/mask_token.dart';
import 'models/tag_variable.dart';

/// Evaluates parsed mask tokens against audio file metadata.
class MaskEvaluator {
  /// Resolves all tokens using the audio file's tags and returns the
  /// resulting path string.
  String evaluate(List<MaskToken> tokens, AudioFile file) {
    final n = tokens.length;
    final resolved = [for (final token in tokens) _resolve(token, file)];
    final out = StringBuffer();

    // A literal is held back as [pending] until we know whether it is a real
    // separator (keep) or a delimiter left dangling by an empty variable
    // (drop). This is what stops `%album\%disc%track` with an empty disc from
    // collapsing to `Album01`: the backslash has a value on its left and a
    // value on its right, so it must survive.
    String? pending;
    // Whether [pending] sits between two variable slots (so it is a
    // delimiter rather than free-standing leading content).
    var pendingAfterSlot = false;
    // Whether [pending] directly follows an *empty* slot, which makes it a
    // candidate trailing delimiter.
    var pendingAfterEmptySlot = false;
    var prevWasEmptySlot = false;

    for (var i = 0; i < n; i++) {
      final token = tokens[i];

      if (token is LiteralToken) {
        // Two literals in a row: the earlier one is genuine content.
        if (pending != null) out.write(pending);
        pending = token.text;
        pendingAfterSlot = i > 0 && tokens[i - 1] is! LiteralToken;
        pendingAfterEmptySlot = prevWasEmptySlot;
        prevWasEmptySlot = false;
        continue;
      }

      final value = resolved[i];

      if (value.isEmpty) {
        // Empty slot. Decide the fate of the delimiter before it.
        if (pending != null) {
          final hasValueAfter = _hasNonEmptyAfter(resolved, tokens, i);
          final nextIsLiteral = i + 1 < n && tokens[i + 1] is LiteralToken;
          if (!hasValueAfter || nextIsLiteral) {
            // Nothing follows, or a literal still separates the neighbours:
            // the pending delimiter is a trailing/leading one — drop it.
            pending = null;
          }
          // Otherwise keep it: dropping it would merge the previous value
          // with the next one.
        }
        prevWasEmptySlot = true;
        continue;
      }

      // Non-empty value: flush the pending delimiter unless it is a leading
      // delimiter sitting before any real content.
      if (pending != null) {
        final isLeadingDelimiter = out.isEmpty && pendingAfterSlot;
        if (!isLeadingDelimiter) out.write(pending);
        pending = null;
      }
      out.write(value);
      prevWasEmptySlot = false;
    }

    // A trailing literal is content only if it did not directly follow an
    // empty variable (which would make it a dangling delimiter).
    if (pending != null && !pendingAfterEmptySlot) out.write(pending);

    return out.toString();
  }

  /// Whether any variable slot after [index] resolves to a non-empty value.
  bool _hasNonEmptyAfter(
    List<String> resolved,
    List<MaskToken> tokens,
    int index,
  ) {
    for (var j = index + 1; j < tokens.length; j++) {
      if (tokens[j] is LiteralToken) continue;
      if (resolved[j].isNotEmpty) return true;
    }
    return false;
  }

  String _resolve(MaskToken token, AudioFile file) {
    return switch (token) {
      LiteralToken(:final text) => text,
      VariableToken(:final variable) => _resolveVariable(variable, file).trim(),
      IgnoreToken() => '',
    };
  }

  String _resolveVariable(TagVariable variable, AudioFile file) {
    final tags = file.tags;

    return switch (variable) {
      TagVariable.artist => tags['artist'] ?? '',
      TagVariable.title => tags['title'] ?? '',
      TagVariable.album => tags['album'] ?? '',
      TagVariable.year => _resolveYear(tags['year'] ?? ''),
      TagVariable.genre => tags['genre'] ?? '',
      TagVariable.track => _resolveTrack(tags['trackNumber'] ?? ''),
      TagVariable.totalTracks => _resolveTotal(tags['trackNumber'] ?? ''),
      TagVariable.disc => _resolveDisc(tags['discNumber'] ?? ''),
      TagVariable.totalDiscs => _resolveTotal(tags['discNumber'] ?? ''),
      TagVariable.albumArtist => _resolveAlbumArtist(tags),
      TagVariable.comment => _resolveComment(tags['comment'] ?? ''),
      TagVariable.bpm => tags['bpm'] ?? '',
      TagVariable.composer => tags['composer'] ?? '',
      TagVariable.conductor => tags['conductor'] ?? '',
      TagVariable.filename => _resolveFilename(file.filename),
      TagVariable.ext => _resolveExtension(file.extension),
    };
  }

  String _resolveTrack(String value) {
    if (value.isEmpty) return '';
    if (value.contains('/')) {
      final part = value.split('/').first.trim();
      return _zeroPad(part);
    }
    return _zeroPad(value);
  }

  String _resolveDisc(String value) {
    if (value.isEmpty) return '';
    if (value.contains('/')) {
      return value.split('/').first.trim();
    }
    return value;
  }

  String _resolveTotal(String value) {
    if (value.isEmpty) return '';
    if (!value.contains('/')) return '';
    return value.split('/').last.trim();
  }

  String _resolveYear(String value) {
    if (value.isEmpty) return '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)) {
      return value.substring(0, 4);
    }
    return value;
  }

  String _resolveAlbumArtist(Map<String, String> tags) {
    final albumArtist = tags['albumArtist'] ?? '';
    if (albumArtist.isNotEmpty) return albumArtist;
    return tags['artist'] ?? '';
  }

  String _resolveComment(String value) {
    if (value.length > 64) return value.substring(0, 64);
    return value;
  }

  String _resolveFilename(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot <= 0) return filename;
    return filename.substring(0, lastDot);
  }

  String _resolveExtension(String extension) {
    if (extension.startsWith('.')) return extension.substring(1);
    return extension;
  }

  String _zeroPad(String value) {
    final number = int.tryParse(value.trim());
    if (number == null) return value;
    return number.toString().padLeft(2, '0');
  }
}
