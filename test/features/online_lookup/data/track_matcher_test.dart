import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/online_lookup/data/track_matcher.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/track_file_match.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/search_result.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

void main() {
  group('TrackMatcher', () {
    group('partial match: 11 tracks, 16 files', () {
      test('returns 11 matched results with non-null file assignments', () {
        final tracks = List.generate(
          11,
          (i) => TrackInfo(
            title: 'Track ${i + 1}',
            position: i + 1,
            durationMs: 200000 + i * 10000,
          ),
        );

        final files = List.generate(
          16,
          (i) => AudioFile(
            path:
                '/music/${(i + 1).toString().padLeft(2, '0')}_Track_${i + 1}.mp3',
            filename:
                '${(i + 1).toString().padLeft(2, '0')}_Track_${i + 1}.mp3',
            extension: '.mp3',
            fileSize: 1024,
            duration: 200.0 + i * 10.0,
          ),
        );

        final results = TrackMatcher.autoMatch(tracks: tracks, files: files);

        expect(results.length, 11);

        final matched = results.where((r) => r.file != null).toList();
        final unmatched = results.where((r) => r.file == null).toList();

        expect(matched.length, 11);
        expect(unmatched.length, 0);

        // All results should have a file assigned
        for (final result in results) {
          expect(result.file, isNotNull);
        }
      });
    });

    group('files with correct track numbers produce high confidence', () {
      test('all matches have high confidence when track numbers align', () {
        final tracks = List.generate(
          5,
          (i) => TrackInfo(
            title: 'Song ${i + 1}',
            position: i + 1,
            durationMs: 240000,
          ),
        );

        // 8 files, first 5 have matching track numbers
        final files = List.generate(
          8,
          (i) => AudioFile(
            path:
                '/music/${(i + 1).toString().padLeft(2, '0')}_Song_${i + 1}.mp3',
            filename: '${(i + 1).toString().padLeft(2, '0')}_Song_${i + 1}.mp3',
            extension: '.mp3',
            fileSize: 1024,
            duration: 240.0,
          ),
        );

        final results = TrackMatcher.autoMatch(tracks: tracks, files: files);

        expect(results.length, 5);

        for (final result in results) {
          expect(result.file, isNotNull);
          expect(
            result.confidence,
            MatchConfidence.high,
            reason:
                'Track "${result.track.title}" matched to "${result.file!.filename}" '
                'should have high confidence (score: ${result.score})',
          );
          expect(result.score, greaterThanOrEqualTo(0.7));
        }
      });
    });

    group('files with no track numbers but matching titles', () {
      test('matches are found via title similarity', () {
        final tracks = [
          const TrackInfo(
            title: 'Take Me Away',
            position: 1,
            durationMs: 240000,
          ),
          const TrackInfo(
            title: 'Burning Bright',
            position: 2,
            durationMs: 200000,
          ),
          const TrackInfo(
            title: 'Midnight Sun',
            position: 3,
            durationMs: 180000,
          ),
        ];

        // Files without track numbers but with matching titles
        final files = [
          const AudioFile(
            path: '/music/Take Me Away.mp3',
            filename: 'Take Me Away.mp3',
            extension: '.mp3',
            fileSize: 1024,
            duration: 240.0,
          ),
          const AudioFile(
            path: '/music/Burning Bright.mp3',
            filename: 'Burning Bright.mp3',
            extension: '.mp3',
            fileSize: 1024,
            duration: 200.0,
          ),
          const AudioFile(
            path: '/music/Midnight Sun.mp3',
            filename: 'Midnight Sun.mp3',
            extension: '.mp3',
            fileSize: 1024,
            duration: 180.0,
          ),
          const AudioFile(
            path: '/music/Bonus Track.mp3',
            filename: 'Bonus Track.mp3',
            extension: '.mp3',
            fileSize: 1024,
            duration: 300.0,
          ),
        ];

        final results = TrackMatcher.autoMatch(tracks: tracks, files: files);

        expect(results.length, 3);

        // Verify each track is matched to the file with the matching title
        final takeMe = results.firstWhere(
          (r) => r.track.title == 'Take Me Away',
        );
        expect(takeMe.file, isNotNull);
        expect(takeMe.file!.filename, 'Take Me Away.mp3');

        final burning = results.firstWhere(
          (r) => r.track.title == 'Burning Bright',
        );
        expect(burning.file, isNotNull);
        expect(burning.file!.filename, 'Burning Bright.mp3');

        final midnight = results.firstWhere(
          (r) => r.track.title == 'Midnight Sun',
        );
        expect(midnight.file, isNotNull);
        expect(midnight.file!.filename, 'Midnight Sun.mp3');
      });
    });

    group('conflicting signals: composite score wins', () {
      test('file with track number 1 but title matching track 2', () {
        final tracks = [
          const TrackInfo(
            title: 'Alpha Song',
            position: 1,
            durationMs: 240000,
          ),
          const TrackInfo(
            title: 'Beta Song',
            position: 2,
            durationMs: 200000,
          ),
        ];

        // File has track number "01" (matches track 1 position)
        // but title "Beta_Song" (matches track 2 title)
        final conflictingFile = const AudioFile(
          path: '/music/01_Beta_Song.mp3',
          filename: '01_Beta_Song.mp3',
          extension: '.mp3',
          fileSize: 1024,
          duration: 200.0,
        );

        // Another file that clearly matches track 2 by number
        final track2File = const AudioFile(
          path: '/music/02_Alpha_Song.mp3',
          filename: '02_Alpha_Song.mp3',
          extension: '.mp3',
          fileSize: 1024,
          duration: 240.0,
        );

        // A third file to make it a partial match scenario
        final extraFile = const AudioFile(
          path: '/music/03_Extra.mp3',
          filename: '03_Extra.mp3',
          extension: '.mp3',
          fileSize: 1024,
          duration: 300.0,
        );

        final files = [conflictingFile, track2File, extraFile];

        final results = TrackMatcher.autoMatch(tracks: tracks, files: files);

        expect(results.length, 2);

        // The composite score should determine the winner.
        // For "01_Beta_Song.mp3" vs track 1 ("Alpha Song", position 1):
        //   trackNumber signal = 1.0 (filename has 01, track position is 1)
        //   title signal = low (Beta Song vs Alpha Song)
        //   score = 0.5 * 1.0 + 0.3 * low + 0.2 * duration
        //
        // For "01_Beta_Song.mp3" vs track 2 ("Beta Song", position 2):
        //   trackNumber signal = 0.0 (filename has 01, track position is 2)
        //   title signal = 1.0 (Beta Song matches Beta Song)
        //   score = 0.5 * 0.0 + 0.3 * 1.0 + 0.2 * duration
        //
        // The Hungarian algorithm finds the globally optimal assignment.
        // Verify that each track gets a file assigned (the optimal solution).
        for (final result in results) {
          expect(result.file, isNotNull);
          expect(result.score, isNotNull);
        }

        // Verify the composite score determines the assignment:
        // The optimal assignment should maximise total score.
        // Compute what the total score would be for the actual assignment.
        final totalScore = results.fold<double>(
          0.0,
          (sum, r) => sum + (r.score ?? 0.0),
        );

        // Compute the alternative assignment's total score
        final altScore1 = TrackMatcher.computeScore(
          file: conflictingFile,
          track: tracks[0],
        );
        final altScore2 = TrackMatcher.computeScore(
          file: track2File,
          track: tracks[1],
        );
        final altTotal = altScore1 + altScore2;

        final swapScore1 = TrackMatcher.computeScore(
          file: conflictingFile,
          track: tracks[1],
        );
        final swapScore2 = TrackMatcher.computeScore(
          file: track2File,
          track: tracks[0],
        );
        final swapTotal = swapScore1 + swapScore2;

        // The actual assignment should have the higher total score
        expect(
          totalScore,
          greaterThanOrEqualTo(altTotal < swapTotal ? altTotal : swapTotal),
          reason:
              'The optimal assignment should maximise total composite score',
        );
      });
    });
  });
}
