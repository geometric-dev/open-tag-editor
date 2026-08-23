import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/online_lookup/data/track_matcher.dart';
import 'package:open_tag_editor/features/online_lookup/data/filename_parser.dart';
import 'package:open_tag_editor/features/online_lookup/data/fuzzy_matcher.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/search_result.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

/// Property-based tests for TrackMatcher.
///
/// Each property is tested with 100+ random inputs (Property 6 uses 50
/// iterations due to brute-force verification cost).
void main() {
  final random = Random(42); // Fixed seed for reproducibility

  // ─────────────────────────────────────────────────────────────────────────
  // Generators
  // ─────────────────────────────────────────────────────────────────────────

  /// Common audio file extensions.
  const extensions = ['.mp3', '.flac', '.ogg', '.wav', '.m4a', '.aac'];

  /// Separator characters used between track number and title.
  const separators = [' ', '_', '-', '.'];

  /// Pool of word fragments for generating titles.
  const words = [
    'Take',
    'Me',
    'Away',
    'Song',
    'Name',
    'The',
    'Great',
    'Escape',
    'Love',
    'Fire',
    'Night',
    'Dream',
    'Blue',
    'Sky',
    'Run',
    'Wild',
    'Heart',
    'Gold',
    'Rise',
    'Fall',
  ];

  /// Short titles (≤ 3 characters) for Property 4 testing.
  const shortTitles = ['Intro', 'End', 'III', 'IV', 'Run', 'Go', 'Hi', 'A'];

  /// Generates a random title composed of 1–4 words joined by spaces.
  String randomTitle() {
    final wordCount = 1 + random.nextInt(4);
    return List.generate(
      wordCount,
      (_) => words[random.nextInt(words.length)],
    ).join(' ');
  }

  /// Generates a short title (≤ 3 characters).
  String randomShortTitle() {
    return shortTitles.where((t) => t.length <= 3).toList()[
        random.nextInt(shortTitles.where((t) => t.length <= 3).length)];
  }

  /// Generates a random AudioFile with optional track number in filename.
  AudioFile randomAudioFile({bool withTrackNumber = true, int? trackNum}) {
    final ext = extensions[random.nextInt(extensions.length)];
    final sep = separators[random.nextInt(separators.length)];
    final titleSep = separators[random.nextInt(separators.length)];
    final title = randomTitle().replaceAll(' ', titleSep);
    final tn = trackNum ?? (1 + random.nextInt(20));

    String filename;
    if (withTrackNumber) {
      final padded =
          random.nextBool() ? tn.toString().padLeft(2, '0') : tn.toString();
      filename = '$padded$sep$title$ext';
    } else {
      filename = '$title$ext';
    }

    // Random duration between 60 and 600 seconds.
    final duration = 60.0 + random.nextDouble() * 540.0;

    return AudioFile(
      path: 'C:\\Music\\$filename',
      filename: filename,
      extension: ext,
      fileSize: 1024 * (100 + random.nextInt(9000)),
      duration: duration,
    );
  }

  /// Generates a random TrackInfo.
  TrackInfo randomTrackInfo({String? title, int? position, int? durationMs}) {
    return TrackInfo(
      title: title ?? randomTitle(),
      position: position ?? (1 + random.nextInt(20)),
      durationMs: durationMs ?? (60000 + random.nextInt(540000)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Property 4: Title signal attenuation
  // Feature: partial-album-match, Property 4: Title signal attenuation
  // ─────────────────────────────────────────────────────────────────────────

  /// **Validates: Requirements 2.3, 2.4**
  group('Property 4: Title signal attenuation', () {
    test(
      'short titles (≤3 chars) use half the normal title weight',
      () {
        for (var i = 0; i < 100; i++) {
          final shortTitle = randomShortTitle();
          final track = randomTrackInfo(title: shortTitle, position: 99);

          // Create a file with no track number match and no duration match
          // so we can isolate the title signal.
          final file = AudioFile(
            path: 'C:\\Music\\$shortTitle.mp3',
            filename: '$shortTitle.mp3',
            extension: '.mp3',
            fileSize: 1024,
            duration: null, // No duration → duration signal = 0
          );

          final score = TrackMatcher.computeScore(file: file, track: track);

          // Compute expected: trackNumber signal = 0 (no leading digits),
          // title signal = similarity between extracted title and track title,
          // duration signal = 0 (null duration).
          final extractedTitle = FilenameParser.extractTitle(file.filename);
          final rawSimilarity =
              FuzzyMatcher.similarity(extractedTitle, track.title);
          final titleSignal = rawSimilarity < TrackMatcher.minTitleSimilarity
              ? 0.0
              : rawSimilarity;

          // Effective title weight is halved for short titles.
          final effectiveTitleWeight = TrackMatcher.titleWeight * 0.5;
          final expectedScore = effectiveTitleWeight * titleSignal;

          expect(
            score,
            closeTo(expectedScore, 1e-10),
            reason: 'Short title "$shortTitle" should use half title weight '
                '(iteration $i)',
          );
        }
      },
    );

    test(
      'title similarity below minTitleSimilarity contributes zero',
      () {
        for (var i = 0; i < 100; i++) {
          // Create a file and track with very different titles to ensure
          // similarity < 0.4.
          final fileTitle = 'ZZZZQQQQ${random.nextInt(9999)}';
          final trackTitle =
              'Completely Different Title ${random.nextInt(9999)}';

          final file = AudioFile(
            path: 'C:\\Music\\$fileTitle.mp3',
            filename: '$fileTitle.mp3',
            extension: '.mp3',
            fileSize: 1024,
            duration: null, // No duration → duration signal = 0
          );

          final track = randomTrackInfo(title: trackTitle, position: 99);

          // Verify the similarity is indeed below threshold.
          final extractedTitle = FilenameParser.extractTitle(file.filename);
          final rawSimilarity =
              FuzzyMatcher.similarity(extractedTitle, track.title);

          if (rawSimilarity >= TrackMatcher.minTitleSimilarity) {
            // Skip this iteration if by chance similarity is above threshold.
            continue;
          }

          final score = TrackMatcher.computeScore(file: file, track: track);

          // With no track number match, no duration, and title below threshold,
          // the score should be 0.0.
          expect(
            score,
            equals(0.0),
            reason:
                'Title similarity $rawSimilarity < ${TrackMatcher.minTitleSimilarity} '
                'should contribute zero to score (iteration $i)',
          );
        }
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Property 5: Score validity and weighted composition
  // Feature: partial-album-match, Property 5: Score validity and weighted composition
  // ─────────────────────────────────────────────────────────────────────────

  /// **Validates: Requirements 1.2, 1.3, 1.4**
  group('Property 5: Score validity and weighted composition', () {
    test(
      'computeScore returns value in [0.0, 1.0]',
      () {
        for (var i = 0; i < 150; i++) {
          final file = randomAudioFile(
            withTrackNumber: random.nextBool(),
          );
          final track = randomTrackInfo();

          final score = TrackMatcher.computeScore(file: file, track: track);

          expect(
            score,
            greaterThanOrEqualTo(0.0),
            reason: 'Score should be >= 0.0 (iteration $i, score=$score)',
          );
          expect(
            score,
            lessThanOrEqualTo(1.0),
            reason: 'Score should be <= 1.0 (iteration $i, score=$score)',
          );
        }
      },
    );

    test(
      'computeScore equals the weighted formula',
      () {
        for (var i = 0; i < 150; i++) {
          final file = randomAudioFile(
            withTrackNumber: random.nextBool(),
          );
          final track = randomTrackInfo();

          final score = TrackMatcher.computeScore(file: file, track: track);

          // Recompute each signal independently.
          final extractedTrackNumber =
              FilenameParser.extractTrackNumber(file.filename);
          final trackNumberSignal = (extractedTrackNumber != null &&
                  extractedTrackNumber == track.position)
              ? 1.0
              : 0.0;

          final extractedTitle = FilenameParser.extractTitle(file.filename);
          final rawTitleSimilarity =
              FuzzyMatcher.similarity(extractedTitle, track.title);
          final titleSignal =
              rawTitleSimilarity < TrackMatcher.minTitleSimilarity
                  ? 0.0
                  : rawTitleSimilarity;

          final double durationSignal;
          final fileDurationMs = ((file.duration ?? 0) * 1000).round();
          if (file.duration == null || track.durationMs == null) {
            durationSignal = 0.0;
          } else {
            final diffMs = (fileDurationMs - track.durationMs!).abs();
            durationSignal = (1.0 - (diffMs / TrackMatcher.durationToleranceMs))
                .clamp(0.0, 1.0);
          }

          final effectiveTitleWeight =
              track.title.length <= TrackMatcher.shortTitleLength
                  ? TrackMatcher.titleWeight * 0.5
                  : TrackMatcher.titleWeight;

          final expectedScore =
              (TrackMatcher.trackNumberWeight * trackNumberSignal) +
                  (effectiveTitleWeight * titleSignal) +
                  (TrackMatcher.durationWeight * durationSignal);

          expect(
            score,
            closeTo(expectedScore, 1e-10),
            reason: 'Score $score should equal weighted formula '
                '$expectedScore (iteration $i)\n'
                '  trackNumberSignal=$trackNumberSignal, '
                'titleSignal=$titleSignal, '
                'durationSignal=$durationSignal, '
                'effectiveTitleWeight=$effectiveTitleWeight',
          );
        }
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Property 6: Optimal assignment maximises total score
  // Feature: partial-album-match, Property 6: Optimal assignment maximises total score
  // ─────────────────────────────────────────────────────────────────────────

  /// **Validates: Requirements 1.5, 1.7, 1.8**
  group('Property 6: Optimal assignment maximises total score', () {
    /// Generates all permutations of [count] items chosen from [total] items.
    /// Returns lists of indices of length [count].
    List<List<int>> permutations(int total, int count) {
      final results = <List<int>>[];

      void generate(List<int> current, List<bool> used) {
        if (current.length == count) {
          results.add(List.from(current));
          return;
        }
        for (var i = 0; i < total; i++) {
          if (used[i]) continue;
          used[i] = true;
          current.add(i);
          generate(current, used);
          current.removeLast();
          used[i] = false;
        }
      }

      generate([], List.filled(total, false));
      return results;
    }

    test(
      'autoMatch total score >= all other valid assignments (small inputs)',
      () {
        for (var i = 0; i < 50; i++) {
          // Generate small inputs: 1–3 tracks, tracks+1 to tracks+3 files.
          final numTracks = 1 + random.nextInt(3); // 1–3
          final numFiles =
              numTracks + 1 + random.nextInt(3); // tracks+1 to tracks+3

          final tracks = List.generate(
            numTracks,
            (t) => randomTrackInfo(position: t + 1),
          );
          final files = List.generate(
            numFiles,
            (_) => randomAudioFile(withTrackNumber: random.nextBool()),
          );

          // Get the autoMatch result (score-based since files > tracks).
          final result = TrackMatcher.autoMatch(
            tracks: tracks,
            files: files,
          );

          // Compute total score from autoMatch.
          final autoMatchTotalScore = result.fold<double>(
            0.0,
            (sum, match) => sum + (match.score ?? 0.0),
          );

          // Enumerate all valid assignments and compute their total scores.
          final allAssignments = permutations(numFiles, numTracks);

          for (final assignment in allAssignments) {
            var assignmentScore = 0.0;
            for (var t = 0; t < numTracks; t++) {
              assignmentScore += TrackMatcher.computeScore(
                file: files[assignment[t]],
                track: tracks[t],
              );
            }

            expect(
              autoMatchTotalScore,
              greaterThanOrEqualTo(assignmentScore - 1e-9),
              reason: 'autoMatch total score ($autoMatchTotalScore) should be '
                  '>= alternative assignment score ($assignmentScore) '
                  '(iteration $i, assignment=$assignment)',
            );
          }
        }
      },
    );
  });
}
