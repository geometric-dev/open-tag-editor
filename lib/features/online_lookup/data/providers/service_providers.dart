import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../tag_editor/data/providers/file_list_provider.dart';
import '../../../tag_editor/data/providers/service_providers.dart';
import '../acoustid_service.dart';
import '../cover_art_service.dart';
import '../discogs_service.dart';
import '../fingerprint_generator.dart';
import '../lookup_cache.dart';
import '../metadata_applicator.dart';
import '../musicbrainz_service.dart';
import '../partial_match_applicator.dart';
import '../rate_limiter.dart';
import 'lookup_settings_provider.dart';

/// Rate limiter for MusicBrainz (1 request per second).
final musicBrainzRateLimiterProvider = Provider<RateLimiter>((ref) {
  return RateLimiter(
    maxRequests: 1,
    perDuration: const Duration(seconds: 1),
    innerClient: http.Client(),
  );
});

/// Rate limiter for Discogs (60 requests per minute).
final discogsRateLimiterProvider = Provider<RateLimiter>((ref) {
  return RateLimiter(
    maxRequests: 60,
    perDuration: const Duration(minutes: 1),
    innerClient: http.Client(),
  );
});

/// Rate limiter for Cover Art Archive and AcoustID (shared, generous limit).
final generalRateLimiterProvider = Provider<RateLimiter>((ref) {
  return RateLimiter(
    maxRequests: 5,
    perDuration: const Duration(seconds: 1),
    innerClient: http.Client(),
  );
});

/// MusicBrainz service provider.
final musicBrainzServiceProvider = Provider<MusicBrainzService>((ref) {
  return MusicBrainzService(
    rateLimiter: ref.read(musicBrainzRateLimiterProvider),
  );
});

/// Discogs service provider (null if token not configured).
final discogsServiceProvider = Provider<DiscogsService?>((ref) {
  final settings = ref.watch(lookupSettingsProvider);
  if (!settings.isDiscogsConfigured) return null;
  return DiscogsService(
    rateLimiter: ref.read(discogsRateLimiterProvider),
    personalAccessToken: settings.discogsToken,
  );
});

/// AcoustID service provider.
final acoustIdServiceProvider = Provider<AcoustIDService>((ref) {
  return AcoustIDService(
    rateLimiter: ref.read(generalRateLimiterProvider),
  );
});

/// Fingerprint generator provider (null if fpcalc path not configured).
final fingerprintGeneratorProvider = Provider<FingerprintGenerator?>((ref) {
  final settings = ref.watch(lookupSettingsProvider);
  if (settings.fpcalcPath.isEmpty) return null;
  return FingerprintGenerator(fpcalcPath: settings.fpcalcPath);
});

/// Cover Art Archive service provider.
final coverArtServiceProvider = Provider<CoverArtService>((ref) {
  return CoverArtService(
    rateLimiter: ref.read(generalRateLimiterProvider),
  );
});

/// Lookup cache provider (session-scoped).
final lookupCacheProvider = Provider<LookupCache>((ref) {
  return LookupCache();
});

/// Metadata applicator provider.
final metadataApplicatorProvider = Provider<MetadataApplicator>((ref) {
  return MetadataApplicator(
    tagWriter: ref.read(tagWriterProvider),
    fileListNotifier: ref.read(fileListProvider.notifier),
  );
});

/// Partial match applicator provider.
final partialMatchApplicatorProvider = Provider<PartialMatchApplicator>((ref) {
  return PartialMatchApplicator(
    tagWriter: ref.read(tagWriterProvider),
    fileListNotifier: ref.read(fileListProvider.notifier),
  );
});
