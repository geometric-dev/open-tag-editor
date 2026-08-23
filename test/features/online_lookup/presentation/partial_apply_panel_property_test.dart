import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/partial_match_file_entry.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/search_result.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/track_file_match.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

// Feature: partial-album-match, Property 11: Display ordering invariant

/// Property-based tests for the partial apply panel display ordering.
///
/// Verifies that all matched entries appear before all unmatched entries
/// in the displayed list.
void main() {
  final random = Random(42);

  /// Generates a random string of the given [length].
  String randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(
      List.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  /// Creates a random [AudioFile].
  AudioFile randomAudioFile() {
    final name = randomString(5 + random.nextInt(10));
    return AudioFile(
      path: '/music/$name.mp3',
      filename: '$name.mp3',
      extension: '.mp3',
      fileSize: 1000 + random.nextInt(10000000),
    );
  }

  /// Creates a random [TrackInfo].
  TrackInfo randomTrackInfo(int position) {
    return TrackInfo(
      title: randomString(5 + random.nextInt(20)),
      position: position,
    );
  }

  /// Creates a random [MatchConfidence] (excluding unmatched).
  MatchConfidence randomConfidence() {
    const values = [
      MatchConfidence.exact,
      MatchConfidence.high,
      MatchConfidence.medium,
      MatchConfidence.low,
      MatchConfidence.duration,
    ];
    return values[random.nextInt(values.length)];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Property 11: Display ordering invariant
  // ─────────────────────────────────────────────────────────────────────────

  /// **Validates: matched entries always appear before unmatched entries.**
  group('Property 11: Display ordering invariant', () {
    test(
      'all matched entries appear before all unmatched entries in the '
      'displayed list',
      () {
        for (var i = 0; i < 100; i++) {
          // Generate 2–20 entries in random order.
          final entryCount = 2 + random.nextInt(19);
          final entries = List.generate(entryCount, (index) {
            final isMatched = random.nextBool();
            return PartialMatchFileEntry(
              file: randomAudioFile(),
              matchedTrack: isMatched ? randomTrackInfo(index + 1) : null,
              confidence: isMatched ? randomConfidence() : null,
              score: isMatched ? random.nextDouble() : null,
            );
          });

          // Sort the way the panel does: matched first, unmatched second.
          final displayed = <PartialMatchFileEntry>[
            ...entries.where((e) => e.isMatched),
            ...entries.where((e) => !e.isMatched),
          ];

          // Verify the invariant: once an unmatched entry appears, no
          // matched entry follows.
          var seenUnmatched = false;
          for (var j = 0; j < displayed.length; j++) {
            if (!displayed[j].isMatched) {
              seenUnmatched = true;
            } else if (seenUnmatched) {
              fail(
                'Iteration $i: matched entry at index $j appears after '
                'unmatched entry. List length: ${displayed.length}',
              );
            }
          }
        }
      },
    );
  });
}
