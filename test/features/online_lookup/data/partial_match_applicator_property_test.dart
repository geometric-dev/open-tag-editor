import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/cover_art_result.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/search_result.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/track_file_match.dart';
import 'package:open_tag_editor/features/online_lookup/data/partial_match_applicator.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:open_tag_editor/shared/services/tag_reader_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock TagWriterService that records all write calls.
// ─────────────────────────────────────────────────────────────────────────────

class MockTagWriterService implements TagWriterService {
  final writtenTags = <String, Map<String, String>>{};
  final writtenArt = <String>[];

  @override
  Future<void> writeTags(String path, Map<String, String> tags) async {
    writtenTags[path] = {...(writtenTags[path] ?? {}), ...tags};
  }

  @override
  Future<void> writeAlbumArt(String path, AlbumArtData art) async {
    writtenArt.add(path);
  }

  @override
  Future<void> removeAlbumArt(String path) async {}

  @override
  Future<List<TagWriteResult>> writeTagsBatch(
    Map<String, Map<String, String>> fileTagsMap,
  ) async => [];
}

/// Property-based tests for PartialMatchApplicator.
///
/// Each property is tested with 100+ random inputs using a fixed seed
/// for reproducibility.
void main() {
  final random = Random(42);

  // ─────────────────────────────────────────────────────────────────────────
  // Generators
  // ─────────────────────────────────────────────────────────────────────────

  /// Common audio file extensions.
  const extensions = ['.mp3', '.flac', '.ogg', '.wav', '.m4a'];

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
  ];

  /// Generates a random string of 3–8 word fragments.
  String randomString() {
    final wordCount = 1 + random.nextInt(4);
    return List.generate(
      wordCount,
      (_) => words[random.nextInt(words.length)],
    ).join(' ');
  }

  /// Generates a random AudioFile with a unique path.
  AudioFile randomAudioFile(int index) {
    final ext = extensions[random.nextInt(extensions.length)];
    final title = randomString().replaceAll(' ', '_');
    final filename = '${index.toString().padLeft(2, '0')}_$title$ext';
    final path = 'C:\\Music\\Album\\$filename';

    return AudioFile(
      path: path,
      filename: filename,
      extension: ext,
      fileSize: 1024 * (100 + random.nextInt(9000)),
      duration: 60.0 + random.nextDouble() * 540.0,
    );
  }

  /// Generates a list of unique AudioFiles.
  List<AudioFile> randomFileList(int count) {
    return List.generate(count, (i) => randomAudioFile(i));
  }

  /// Generates a random TrackInfo.
  TrackInfo randomTrackInfo(int position) {
    return TrackInfo(
      title: randomString(),
      position: position,
      durationMs: 60000 + random.nextInt(540000),
      artist: random.nextBool() ? randomString() : null,
      discNumber: random.nextBool() ? 1 + random.nextInt(2) : 1,
    );
  }

  /// Generates a random subset of paths from a file list.
  Set<String> randomOptedOutPaths(List<AudioFile> files) {
    final count = random.nextInt(files.length); // 0 to files.length-1
    final shuffled = List<AudioFile>.from(files)..shuffle(random);
    return shuffled.take(count).map((f) => f.path).toSet();
  }

  /// Generates TrackFileMatch entries: some files matched, some unmatched.
  /// Returns matches where each track is assigned to a file from [files].
  List<TrackFileMatch> randomMatches(List<AudioFile> files, int trackCount) {
    // Assign first trackCount files to tracks (or fewer if files < trackCount).
    final assignable = min(trackCount, files.length);
    final shuffled = List<AudioFile>.from(files)..shuffle(random);

    return List.generate(assignable, (i) {
      return TrackFileMatch(
        track: randomTrackInfo(i + 1),
        file: shuffled[i],
        confidence: MatchConfidence.high,
        score: 0.7 + random.nextDouble() * 0.3,
      );
    });
  }

  /// Creates a fresh MockTagWriterService and FileListNotifier for each test
  /// iteration.
  ({
    MockTagWriterService tagWriter,
    FileListNotifier fileListNotifier,
    PartialMatchApplicator applicator,
  })
  createApplicator(List<AudioFile> files) {
    final tagWriter = MockTagWriterService();
    final fileListNotifier = FileListNotifier();
    fileListNotifier.addFiles(files);
    final applicator = PartialMatchApplicator(
      tagWriter: tagWriter,
      fileListNotifier: fileListNotifier,
    );
    return (
      tagWriter: tagWriter,
      fileListNotifier: fileListNotifier,
      applicator: applicator,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Property 7: Album metadata applied to exactly non-opted-out files
  // Feature: partial-album-match, Property 7: Album metadata applied to
  // exactly non-opted-out files
  // ─────────────────────────────────────────────────────────────────────────

  /// **Validates: Requirements 3.1, 3.3, 3.4, 5.2**
  group('Property 7: Album metadata applied to exactly non-opted-out files', () {
    test(
      'album-level metadata written to all non-opted-out files, not to opted-out',
      () async {
        for (var i = 0; i < 100; i++) {
          final fileCount = 3 + random.nextInt(10); // 3–12 files
          final trackCount = 1 + random.nextInt(fileCount - 1); // fewer tracks
          final files = randomFileList(fileCount);
          final matches = randomMatches(files, trackCount);
          final optedOut = randomOptedOutPaths(files);

          // Always include album fields in selected fields for this property.
          final selectedFields = {'album', 'albumArtist', 'year'};
          final albumTitle = 'Album ${random.nextInt(999)}';
          final albumArtist = 'Artist ${random.nextInt(999)}';
          final year = '${1970 + random.nextInt(55)}';

          final setup = createApplicator(files);

          await setup.applicator.apply(
            matches: matches,
            allFiles: files,
            selectedFields: selectedFields,
            optedOutPaths: optedOut,
            totalFileCount: fileCount,
            albumTitle: albumTitle,
            albumArtist: albumArtist,
            year: year,
          );

          final nonOptedOutPaths = files
              .where((f) => !optedOut.contains(f.path))
              .map((f) => f.path);
          final optedOutPathsList = files
              .where((f) => optedOut.contains(f.path))
              .map((f) => f.path);

          // Every non-opted-out file should have received album metadata.
          for (final path in nonOptedOutPaths) {
            final tags = setup.tagWriter.writtenTags[path];
            expect(
              tags,
              isNotNull,
              reason:
                  'Non-opted-out file "$path" should have received writes '
                  '(iteration $i)',
            );
            expect(
              tags!['album'],
              equals(albumTitle),
              reason:
                  'Album title should be written to "$path" '
                  '(iteration $i)',
            );
            expect(
              tags['albumArtist'],
              equals(albumArtist),
              reason:
                  'Album artist should be written to "$path" '
                  '(iteration $i)',
            );
            expect(
              tags['year'],
              equals(year),
              reason: 'Year should be written to "$path" (iteration $i)',
            );
          }

          // Opted-out files should NOT have received any writes.
          for (final path in optedOutPathsList) {
            expect(
              setup.tagWriter.writtenTags.containsKey(path),
              isFalse,
              reason:
                  'Opted-out file "$path" should NOT have received writes '
                  '(iteration $i)',
            );
          }
        }
      },
    );

    test(
      'cover art written to all non-opted-out files, not to opted-out',
      () async {
        for (var i = 0; i < 100; i++) {
          final fileCount = 3 + random.nextInt(8); // 3–10 files
          final trackCount = 1 + random.nextInt(fileCount - 1);
          final files = randomFileList(fileCount);
          final matches = randomMatches(files, trackCount);
          final optedOut = randomOptedOutPaths(files);

          final coverArt = CoverArtResult(
            imageBytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
            mimeType: 'image/jpeg',
          );

          final setup = createApplicator(files);

          await setup.applicator.apply(
            matches: matches,
            allFiles: files,
            selectedFields: {'album'}, // Need at least one field or cover art
            optedOutPaths: optedOut,
            totalFileCount: fileCount,
            coverArt: coverArt,
            applyCoverArt: true,
            albumTitle: 'Test Album',
          );

          final nonOptedOutPaths = files
              .where((f) => !optedOut.contains(f.path))
              .map((f) => f.path);
          final optedOutPathsList = files
              .where((f) => optedOut.contains(f.path))
              .map((f) => f.path);

          // Every non-opted-out file should have received cover art.
          for (final path in nonOptedOutPaths) {
            expect(
              setup.tagWriter.writtenArt.contains(path),
              isTrue,
              reason:
                  'Non-opted-out file "$path" should have received '
                  'cover art (iteration $i)',
            );
          }

          // Opted-out files should NOT have received cover art.
          for (final path in optedOutPathsList) {
            expect(
              setup.tagWriter.writtenArt.contains(path),
              isFalse,
              reason:
                  'Opted-out file "$path" should NOT have received '
                  'cover art (iteration $i)',
            );
          }
        }
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Property 8: Track metadata applied only to matched non-opted-out files
  // Feature: partial-album-match, Property 8: Track metadata applied only to
  // matched non-opted-out files
  // ─────────────────────────────────────────────────────────────────────────

  /// **Validates: Requirements 4.1, 4.3**
  group(
    'Property 8: Track metadata applied only to matched non-opted-out files',
    () {
      test(
        'track-level metadata written only to files with assignment and not opted out',
        () async {
          for (var i = 0; i < 100; i++) {
            final fileCount = 4 + random.nextInt(8); // 4–11 files
            final trackCount =
                1 + random.nextInt(fileCount - 2); // fewer tracks
            final files = randomFileList(fileCount);
            final matches = randomMatches(files, trackCount);
            final optedOut = randomOptedOutPaths(files);

            // Include track fields in selected fields.
            final selectedFields = {
              'album',
              'albumArtist',
              'title',
              'artist',
              'discNumber',
              'trackNumber',
            };

            final setup = createApplicator(files);

            await setup.applicator.apply(
              matches: matches,
              allFiles: files,
              selectedFields: selectedFields,
              optedOutPaths: optedOut,
              totalFileCount: fileCount,
              albumTitle: 'Test Album',
              albumArtist: 'Test Artist',
            );

            // Determine which files are matched.
            final matchedPaths = <String>{};
            for (final match in matches) {
              if (match.file != null) {
                matchedPaths.add(match.file!.path);
              }
            }

            // Check each file.
            for (final file in files) {
              final tags = setup.tagWriter.writtenTags[file.path];
              final isOptedOut = optedOut.contains(file.path);
              final isMatched = matchedPaths.contains(file.path);

              if (isOptedOut) {
                // Opted-out files should have no writes at all.
                expect(
                  tags,
                  isNull,
                  reason:
                      'Opted-out file "${file.path}" should have no writes '
                      '(iteration $i)',
                );
              } else if (isMatched) {
                // Matched non-opted-out files should have track metadata.
                expect(
                  tags,
                  isNotNull,
                  reason:
                      'Matched file "${file.path}" should have writes '
                      '(iteration $i)',
                );
                // Should have title (if track has non-empty title).
                final match = matches.firstWhere(
                  (m) => m.file?.path == file.path,
                );
                if (match.track.title.isNotEmpty) {
                  expect(
                    tags!.containsKey('title'),
                    isTrue,
                    reason:
                        'Matched file should have title written '
                        '(iteration $i)',
                  );
                }
              } else {
                // Unmatched non-opted-out files should NOT have track metadata
                // (title, trackNumber). Album-level fields (artist, discNumber,
                // trackTotal) are expected to be present.
                if (tags != null) {
                  expect(
                    tags.containsKey('title'),
                    isFalse,
                    reason:
                        'Unmatched file "${file.path}" should NOT have '
                        'title written (iteration $i)',
                  );
                  expect(
                    tags.containsKey('trackNumber'),
                    isFalse,
                    reason:
                        'Unmatched file "${file.path}" should NOT have '
                        'trackNumber written (iteration $i)',
                  );
                }
              }
            }
          }
        },
      );
    },
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Property 9: Track number formatting
  // Feature: partial-album-match, Property 9: Track number formatting
  // ─────────────────────────────────────────────────────────────────────────

  /// **Validates: Requirements 9.1, 9.2, 10.1, 10.2**
  group('Property 9: Track number formatting', () {
    test(
      'matched files get "P/N" format; unmatched files have no trackNumber write',
      () async {
        for (var i = 0; i < 100; i++) {
          final fileCount = 4 + random.nextInt(12); // 4–15 files
          final trackCount = 1 + random.nextInt(fileCount - 2);
          final files = randomFileList(fileCount);
          final matches = randomMatches(files, trackCount);

          // No opt-outs for this property test — focus on formatting.
          final selectedFields = {'trackNumber', 'album'};

          final setup = createApplicator(files);

          await setup.applicator.apply(
            matches: matches,
            allFiles: files,
            selectedFields: selectedFields,
            optedOutPaths: <String>{},
            totalFileCount: fileCount,
            albumTitle: 'Test Album',
          );

          // Determine matched file paths and their track positions.
          final matchedFilePositions = <String, int>{};
          for (final match in matches) {
            if (match.file != null) {
              matchedFilePositions[match.file!.path] = match.track.position;
            }
          }

          for (final file in files) {
            final tags = setup.tagWriter.writtenTags[file.path];
            final isMatched = matchedFilePositions.containsKey(file.path);

            if (isMatched) {
              final position = matchedFilePositions[file.path]!;
              final expectedTrackNumber = '$position/$fileCount';
              expect(
                tags,
                isNotNull,
                reason:
                    'Matched file "${file.path}" should have writes '
                    '(iteration $i)',
              );
              expect(
                tags!['trackNumber'],
                equals(expectedTrackNumber),
                reason:
                    'Track number should be "$expectedTrackNumber" for '
                    'matched file (iteration $i)',
              );
            } else {
              // Unmatched files should not have trackNumber written.
              if (tags != null) {
                expect(
                  tags.containsKey('trackNumber'),
                  isFalse,
                  reason:
                      'Unmatched file "${file.path}" should NOT have '
                      'trackNumber written (iteration $i)',
                );
              }
            }
          }
        }
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Property 10: Summary count reflects opt-out state
  // Feature: partial-album-match, Property 10: Summary count reflects opt-out
  // state
  // ─────────────────────────────────────────────────────────────────────────

  /// **Validates: Requirements 5.4, 8.1**
  group('Property 10: Summary count reflects opt-out state', () {
    test(
      'success count equals number of non-opted-out files that received writes',
      () async {
        for (var i = 0; i < 100; i++) {
          final fileCount = 3 + random.nextInt(10); // 3–12 files
          final trackCount = 1 + random.nextInt(fileCount - 1);
          final files = randomFileList(fileCount);
          final matches = randomMatches(files, trackCount);
          final optedOut = randomOptedOutPaths(files);

          // Use fields that ensure all non-opted-out files get writes.
          final selectedFields = {'album', 'title', 'trackNumber'};

          final setup = createApplicator(files);

          final result = await setup.applicator.apply(
            matches: matches,
            allFiles: files,
            selectedFields: selectedFields,
            optedOutPaths: optedOut,
            totalFileCount: fileCount,
            albumTitle: 'Test Album',
          );

          // Count files that actually received writes.
          final filesWithWrites =
              setup.tagWriter.writtenTags.keys.length +
              setup.tagWriter.writtenArt
                  .where((p) => !setup.tagWriter.writtenTags.containsKey(p))
                  .length;

          // The success count should equal the number of files that received
          // writes (non-opted-out files that had something to write).
          expect(
            result.successCount,
            equals(filesWithWrites),
            reason:
                'Success count (${result.successCount}) should equal '
                'files with writes ($filesWithWrites) (iteration $i)\n'
                '  fileCount=$fileCount, trackCount=$trackCount, '
                'optedOut=${optedOut.length}',
          );

          // Also verify: successCount + failureCount + skipped = total files
          // where skipped = opted-out + files with nothing to write.
          final totalProcessed = result.successCount + result.failureCount;
          final nonOptedOutCount = files
              .where((f) => !optedOut.contains(f.path))
              .length;

          // All non-opted-out files should be processed (success or failure)
          // since we always have album title selected.
          expect(
            totalProcessed,
            equals(nonOptedOutCount),
            reason:
                'Total processed ($totalProcessed) should equal '
                'non-opted-out count ($nonOptedOutCount) (iteration $i)',
          );
        }
      },
    );
  });
}
