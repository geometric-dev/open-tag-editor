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
// Mock TagWriterService
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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

AudioFile makeFile(int index) => AudioFile(
  path: 'C:\\Music\\file$index.mp3',
  filename: 'file$index.mp3',
  extension: '.mp3',
  fileSize: 1024,
  duration: 240.0,
);

void main() {
  late MockTagWriterService tagWriter;
  late FileListNotifier fileListNotifier;
  late PartialMatchApplicator applicator;

  /// 5 files, 3 matched to tracks (files 0, 1, 2), 2 unmatched (files 3, 4).
  late List<AudioFile> allFiles;
  late List<TrackFileMatch> matches;

  setUp(() {
    tagWriter = MockTagWriterService();
    fileListNotifier = FileListNotifier();

    allFiles = List.generate(5, makeFile);
    fileListNotifier.addFiles(allFiles);

    applicator = PartialMatchApplicator(
      tagWriter: tagWriter,
      fileListNotifier: fileListNotifier,
    );

    matches = [
      TrackFileMatch(
        track: const TrackInfo(
          title: 'Track One',
          position: 1,
          artist: 'Solo Artist',
          discNumber: 1,
        ),
        file: allFiles[0],
        confidence: MatchConfidence.high,
        score: 0.85,
      ),
      TrackFileMatch(
        track: const TrackInfo(
          title: 'Track Two',
          position: 2,
          artist: 'Feat Artist',
          discNumber: 1,
        ),
        file: allFiles[1],
        confidence: MatchConfidence.high,
        score: 0.78,
      ),
      TrackFileMatch(
        track: const TrackInfo(
          title: 'Track Three',
          position: 3,
          discNumber: 2,
        ),
        file: allFiles[2],
        confidence: MatchConfidence.medium,
        score: 0.55,
      ),
    ];
  });

  group('PartialMatchApplicator', () {
    // ─────────────────────────────────────────────────────────────────────
    // Test 1: Album fields written to unmatched files
    // Validates: Requirements 3.1, 3.4
    // ─────────────────────────────────────────────────────────────────────

    test('album fields are written to all files including unmatched', () async {
      await applicator.apply(
        matches: matches,
        allFiles: allFiles,
        selectedFields: {'album', 'albumArtist', 'year'},
        optedOutPaths: <String>{},
        totalFileCount: 5,
        albumTitle: 'Test Album',
        albumArtist: 'Test Artist',
        year: '2024',
      );

      // All 5 files should receive album metadata.
      for (final file in allFiles) {
        final tags = tagWriter.writtenTags[file.path];
        expect(tags, isNotNull, reason: '${file.path} should have tags');
        expect(tags!['album'], 'Test Album');
        expect(tags['albumArtist'], 'Test Artist');
        expect(tags['year'], '2024');
      }
    });

    // ─────────────────────────────────────────────────────────────────────
    // Test 2: Track fields NOT written to unmatched files
    // Validates: Requirements 4.3
    // ─────────────────────────────────────────────────────────────────────

    test('track fields are NOT written to unmatched files', () async {
      await applicator.apply(
        matches: matches,
        allFiles: allFiles,
        selectedFields: {
          'album',
          'albumArtist',
          'year',
          'title',
          'artist',
          'discNumber',
          'trackNumber',
        },
        optedOutPaths: <String>{},
        totalFileCount: 5,
        albumTitle: 'Test Album',
        albumArtist: 'Test Artist',
        year: '2024',
      );

      // Unmatched files (index 3, 4) should NOT have track-only fields
      // (title, trackNumber) but SHOULD have album-level fields
      // (artist = albumArtist, discNumber, trackTotal).
      for (final file in [allFiles[3], allFiles[4]]) {
        final tags = tagWriter.writtenTags[file.path]!;
        expect(
          tags.containsKey('title'),
          isFalse,
          reason: '${file.path} should not have title',
        );
        expect(
          tags.containsKey('trackNumber'),
          isFalse,
          reason: '${file.path} should not have trackNumber',
        );
        // Artist is album-level (defaults to album artist).
        expect(
          tags['artist'],
          'Test Artist',
          reason: '${file.path} should have artist = albumArtist',
        );
        // Disc number is album-level.
        expect(
          tags.containsKey('discNumber'),
          isTrue,
          reason: '${file.path} should have discNumber',
        );
        // Track total is written to all files.
        expect(
          tags['trackTotal'],
          '5',
          reason: '${file.path} should have trackTotal',
        );
      }

      // Matched files (index 0, 1, 2) SHOULD have track-level fields.
      for (final file in [allFiles[0], allFiles[1], allFiles[2]]) {
        final tags = tagWriter.writtenTags[file.path]!;
        expect(
          tags.containsKey('title'),
          isTrue,
          reason: '${file.path} should have title',
        );
        expect(
          tags.containsKey('trackNumber'),
          isTrue,
          reason: '${file.path} should have trackNumber',
        );
      }
    });

    // ─────────────────────────────────────────────────────────────────────
    // Test 3: Opted-out files receive nothing
    // Validates: Requirements 5.2
    // ─────────────────────────────────────────────────────────────────────

    test('opted-out files receive no tags or cover art', () async {
      final optedOut = {allFiles[1].path, allFiles[3].path};
      final coverArt = CoverArtResult(
        imageBytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
        mimeType: 'image/jpeg',
      );

      await applicator.apply(
        matches: matches,
        allFiles: allFiles,
        selectedFields: {
          'album',
          'albumArtist',
          'year',
          'title',
          'artist',
          'trackNumber',
        },
        optedOutPaths: optedOut,
        totalFileCount: 5,
        albumTitle: 'Test Album',
        albumArtist: 'Test Artist',
        year: '2024',
        coverArt: coverArt,
        applyCoverArt: true,
      );

      // Opted-out files should have no tag writes.
      for (final path in optedOut) {
        expect(
          tagWriter.writtenTags.containsKey(path),
          isFalse,
          reason: '$path should have no tag writes',
        );
      }

      // Opted-out files should have no cover art writes.
      for (final path in optedOut) {
        expect(
          tagWriter.writtenArt.contains(path),
          isFalse,
          reason: '$path should have no cover art writes',
        );
      }

      // Non-opted-out files should still receive writes.
      final nonOptedOut = allFiles
          .where((f) => !optedOut.contains(f.path))
          .toList();
      for (final file in nonOptedOut) {
        expect(
          tagWriter.writtenTags.containsKey(file.path),
          isTrue,
          reason: '${file.path} should have tag writes',
        );
        expect(
          tagWriter.writtenArt.contains(file.path),
          isTrue,
          reason: '${file.path} should have cover art writes',
        );
      }
    });

    // ─────────────────────────────────────────────────────────────────────
    // Test 4: Track number format "3/16" in partial mode
    // Validates: Requirements 9.1, 9.3
    // ─────────────────────────────────────────────────────────────────────

    test(
      'track number uses total file count as denominator in partial mode',
      () async {
        // 16 total files, track at position 3.
        final files16 = List.generate(16, makeFile);
        final notifier16 = FileListNotifier();
        notifier16.addFiles(files16);

        final applicator16 = PartialMatchApplicator(
          tagWriter: tagWriter,
          fileListNotifier: notifier16,
        );

        final partialMatches = [
          TrackFileMatch(
            track: const TrackInfo(
              title: 'Third Track',
              position: 3,
              discNumber: 1,
            ),
            file: files16[2],
            confidence: MatchConfidence.high,
            score: 0.9,
          ),
        ];

        // Partial mode: totalFileCount = 16 (all files in selection).
        await applicator16.apply(
          matches: partialMatches,
          allFiles: files16,
          selectedFields: {'trackNumber', 'album'},
          optedOutPaths: <String>{},
          totalFileCount: 16,
          albumTitle: 'Partial Album',
        );

        // Track at position 3 with 16 total files → "3/16".
        final tags = tagWriter.writtenTags[files16[2].path]!;
        expect(tags['trackNumber'], '3/16');
      },
    );

    test(
      'track number uses matched track count as denominator in full mode',
      () async {
        // Full mode: 11 tracks, 11 files → totalFileCount = 11.
        final files11 = List.generate(11, makeFile);
        final notifier11 = FileListNotifier();
        notifier11.addFiles(files11);

        // Reset tag writer for clean state.
        final freshTagWriter = MockTagWriterService();
        final applicator11 = PartialMatchApplicator(
          tagWriter: freshTagWriter,
          fileListNotifier: notifier11,
        );

        final fullMatches = [
          TrackFileMatch(
            track: const TrackInfo(
              title: 'Third Track',
              position: 3,
              discNumber: 1,
            ),
            file: files11[2],
            confidence: MatchConfidence.exact,
            score: 1.0,
          ),
        ];

        // Full mode: totalFileCount = 11 (matched track count).
        await applicator11.apply(
          matches: fullMatches,
          allFiles: files11,
          selectedFields: {'trackNumber', 'album'},
          optedOutPaths: <String>{},
          totalFileCount: 11,
          albumTitle: 'Full Album',
        );

        // Track at position 3 with 11 total → "3/11".
        final tags = freshTagWriter.writtenTags[files11[2].path]!;
        expect(tags['trackNumber'], '3/11');
      },
    );
  });
}
