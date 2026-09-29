import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/online_lookup/data/metadata_applicator.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/search_result.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/track_file_match.dart';
import 'package:open_tag_editor/features/tag_editor/data/providers/file_list_provider.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';
import 'package:open_tag_editor/shared/services/tag_reader_service.dart';

class RecordingTagWriter implements TagWriterService {
  final written = <String, Map<String, String>>{};

  @override
  Future<void> writeTags(String path, Map<String, String> tags) async {
    written[path] = {...(written[path] ?? {}), ...tags};
  }

  @override
  Future<void> writeAlbumArt(String path, AlbumArtData art) async {}

  @override
  Future<void> removeAlbumArt(String path) async {}

  @override
  Future<List<TagWriteResult>> writeTagsBatch(
    Map<String, Map<String, String>> fileTagsMap,
  ) async => const [];
}

void main() {
  late RecordingTagWriter tagWriter;
  late FileListNotifier fileList;
  late AudioFile file;

  setUp(() {
    tagWriter = RecordingTagWriter();
    fileList = FileListNotifier();
    file = const AudioFile(
      path: '/music/a.mp3',
      filename: 'a.mp3',
      extension: '.mp3',
      fileSize: 1024,
      duration: 240,
      tags: {'replayGainTrackGain': '-6.5 dB', 'rating': '5'},
    );
    fileList.addFiles([file]);
  });

  Future<Map<String, String>> applyWith(
    Set<String> preserved,
    Set<String> selectedFields,
  ) async {
    final applicator = MetadataApplicator(
      tagWriter: tagWriter,
      fileListNotifier: fileList,
      preservedFields: preserved,
    );
    await applicator.apply(
      matches: [
        TrackFileMatch(
          track: const TrackInfo(title: 'Fetched Title', position: 1),
          file: file,
          confidence: MatchConfidence.high,
          score: 0.9,
        ),
      ],
      selectedFields: selectedFields,
      albumTitle: 'Fetched Album',
      albumArtist: 'Fetched Artist',
      year: '2026',
    );
    return tagWriter.written[file.path] ?? const {};
  }

  test('preserved fields are not written', () async {
    final written = await applyWith(
      const {'rating'},
      const {'title', 'album', 'rating', 'year'},
    );

    expect(written.containsKey('rating'), isFalse);
    expect(written['title'], 'Fetched Title');
  });

  test('non-preserved fields are still written', () async {
    final written = await applyWith(
      const {'rating'},
      const {'title', 'album', 'year'},
    );

    expect(written['album'], 'Fetched Album');
    expect(written['year'], '2026');
  });

  test('an empty preserved list writes everything selected', () async {
    final written = await applyWith(const {}, const {'title'});

    expect(written['title'], 'Fetched Title');
  });

  test('preserving a field that was not selected is a no-op', () async {
    final written = await applyWith(
      const {'replayGainTrackGain'},
      const {'title'},
    );

    expect(written.keys, containsAll(['title']));
    expect(written.containsKey('replayGainTrackGain'), isFalse);
  });

  test('the on-disk ReplayGain is left alone after an apply', () async {
    await applyWith(const {'replayGainTrackGain'}, const {'title', 'artist'});

    // The file list is updated with what was actually written, so the
    // original loudness value must still be there.
    final updated = fileList.currentFiles.first;
    expect(updated.tags['replayGainTrackGain'], '-6.5 dB');
    expect(updated.isModified, isFalse);
  });
}
