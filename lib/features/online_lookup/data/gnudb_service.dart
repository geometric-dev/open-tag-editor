import 'dart:convert';

import '../../../shared/models/audio_file.dart';
import 'lookup_service_exception.dart';
import 'models/search_result.dart';
import 'rate_limiter.dart';

/// Service for the GNUdb database (freedb successor at gnudb.org).
///
/// Tag&Rename queried freedb by computing a virtual CD table-of-contents
/// from file durations; this reproduces that flow against gnudb's JSON API:
///
/// 1. Sort files (track number tag when present, else filename).
/// 2. Build a CDDB TOC string: firstTrack+numTracks+offset1..offsetN+leadout
///    where offsets are 75fps frame positions and track 1 starts at 150
///    (2-second lead-in).
/// 3. `cdlookup?toc=...` returns candidate discs with full track lists.
class GnuDbService {
  /// Creates a [GnuDbService] with the given [rateLimiter].
  GnuDbService({required this.rateLimiter});

  /// Rate limiter for GNUdb requests.
  final RateLimiter rateLimiter;

  static const _baseUrl = 'https://gnudb.org';

  static const _userAgent =
      'OpenTagEditor/0.2.0 (https://github.com/open-tag-editor)';

  Map<String, String> get _headers => {'User-Agent': _userAgent};

  /// Builds a CDDB TOC string from [durationsSeconds], in play order.
  ///
  /// Track 1 starts at frame 150 (the 2-second lead-in); each subsequent
  /// offset accumulates the preceding durations; lead-out adds a 2-second
  /// gap after the last track, per Red Book convention.
  static String buildToc(List<double> durationsSeconds) {
    if (durationsSeconds.isEmpty) {
      throw ArgumentError('Need at least one duration to build a TOC');
    }
    const framesPerSecond = 75;
    const leadInFrames = 150;

    final offsets = <int>[leadInFrames];
    var cursor = leadInFrames.toDouble();
    for (final d in durationsSeconds) {
      cursor += d * framesPerSecond;
      offsets.add(cursor.round());
    }

    return [
      '1',
      '${durationsSeconds.length}',
      ...offsets.map((o) => '$o'),
    ].join('+');
  }

  /// Orders files for TOC purposes: by numeric track-number tag when every
  /// file has one, else by filename (case-insensitive).
  static List<AudioFile> orderForToc(List<AudioFile> files) {
    final allHaveTrackNumbers =
        files.isNotEmpty &&
        files.every((f) => int.tryParse(f.tags['trackNumber'] ?? '') != null);
    final sorted = List<AudioFile>.from(files);
    if (allHaveTrackNumbers) {
      sorted.sort(
        (a, b) => int.parse(
          a.tags['trackNumber']!,
        ).compareTo(int.parse(b.tags['trackNumber']!)),
      );
    } else {
      sorted.sort(
        (a, b) => a.filename.toLowerCase().compareTo(b.filename.toLowerCase()),
      );
    }
    return sorted;
  }

  /// Looks up candidate discs matching the virtual TOC of [files].
  ///
  /// Track lists are embedded in the cdlookup response; they are returned
  /// alongside results so callers can pre-seed their cache and avoid a
  /// second round trip.
  Future<GnuDbLookupResult> lookupByFiles(List<AudioFile> files) async {
    final ordered = orderForToc(files);
    final durations = ordered
        .map((f) => f.duration ?? 0.0)
        .toList(growable: false);
    final hasAllDurations = ordered.every((f) => f.duration != null);
    if (!hasAllDurations || durations.length < 2) {
      throw LookupServiceException(
        'GNUdb needs track lengths: select sequential album tracks '
        '(at least 2, all with known duration).',
      );
    }

    final toc = buildToc(durations);
    final url = Uri.parse(
      '$_baseUrl/cdlookup',
    ).replace(queryParameters: {'toc': toc, 'client': 'opentageditor+0.2.0'});

    final response = await rateLimiter.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw LookupServiceException(
        'GNUdb request failed',
        statusCode: response.statusCode,
      );
    }

    return parseCdLookupResponse(response.body);
  }

  /// Parses a `cdlookup` JSON array into results + per-disc track lists.
  ///
  /// Tolerant of missing fields; entries without a discid/genre pair are
  /// skipped because they cannot be addressed later.
  static GnuDbLookupResult parseCdLookupResponse(String body) {
    late final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (e) {
      throw LookupServiceException('GNUdb returned malformed JSON: $e');
    }
    if (decoded is! List) {
      throw LookupServiceException('Unexpected GNUdb response shape');
    }

    final results = <SearchResult>[];
    final tracksByDiscId = <String, List<TrackInfo>>{};

    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      final discId = entry['discid'] as String?;
      final genre = entry['genre'] as String?;
      if (discId == null || discId.isEmpty || genre == null || genre.isEmpty) {
        continue;
      }

      final artist = entry['artist'] as String? ?? '';
      final title = entry['title'] as String? ?? '';
      final yearRaw = entry['year'];
      final year = yearRaw is int ? '$yearRaw' : yearRaw as String?;

      final tracks = <TrackInfo>[];
      final rawTracks = entry['tracks'];
      if (rawTracks is List) {
        var position = 1;
        for (final t in rawTracks) {
          final tTitle = t is String
              ? t
              : (t as Map<String, dynamic>?)?['title'] as String?;
          if (tTitle == null || tTitle.isEmpty) {
            position++;
            continue;
          }
          tracks.add(TrackInfo(title: tTitle, position: position));
          position++;
        }
      }

      // Composite id keeps genre addressable without a second request.
      final compositeId = 'gnudb:$genre:$discId';
      results.add(
        SearchResult(
          id: compositeId,
          title: title,
          artist: artist,
          year: year,
          trackCount: tracks.length,
          source: SearchSource.gnudb,
        ),
      );
      tracksByDiscId[compositeId] = tracks;
    }

    return GnuDbLookupResult(results: results, tracksByDiscId: tracksByDiscId);
  }
}

/// Result of a `cdlookup`: candidate discs plus their embedded track lists.
class GnuDbLookupResult {
  const GnuDbLookupResult({
    required this.results,
    required this.tracksByDiscId,
  });

  /// Candidate discs, best match first (server-ordered).
  final List<SearchResult> results;

  /// Tracks keyed by composite result id, ready to seed a LookupCache.
  final Map<String, List<TrackInfo>> tracksByDiscId;
}
