import '../../../shared/models/audio_file.dart';
import 'models/mask_token.dart';
import 'models/tag_variable.dart';

/// Evaluates parsed mask tokens against audio file metadata.
class MaskEvaluator {
  /// Resolves all tokens using the audio file's tags and returns the
  /// resulting path string.
  String evaluate(List<MaskToken> tokens, AudioFile file) {
    final pairs = tokens.map((token) {
      return _TokenPair(token, _resolve(token, file));
    }).toList();

    _collapseDelimiters(pairs);

    return pairs
        .where((p) => p.resolved.isNotEmpty)
        .map((p) => p.resolved)
        .join();
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

  void _collapseDelimiters(List<_TokenPair> pairs) {
    for (var i = 0; i < pairs.length; i++) {
      final token = pairs[i].token;
      final isEmpty = pairs[i].resolved.isEmpty;

      if (!isEmpty) continue;
      if (token is! VariableToken && token is! IgnoreToken) continue;

      // Remove adjacent literal delimiter before this empty variable.
      if (i > 0 && pairs[i - 1].token is LiteralToken) {
        final hasNextVariable = i + 1 < pairs.length &&
            (pairs[i + 1].token is VariableToken ||
                pairs[i + 1].token is IgnoreToken);
        if (hasNextVariable) {
          pairs[i - 1].resolved = '';
          continue;
        }
      }

      // Remove adjacent literal delimiter after this empty variable.
      if (i + 1 < pairs.length && pairs[i + 1].token is LiteralToken) {
        final hasPrevVariable = i > 0 &&
            (pairs[i - 1].token is VariableToken ||
                pairs[i - 1].token is IgnoreToken);
        if (hasPrevVariable) {
          pairs[i + 1].resolved = '';
        }
      }
    }
  }
}

class _TokenPair {
  _TokenPair(this.token, this.resolved);

  final MaskToken token;
  String resolved;
}
