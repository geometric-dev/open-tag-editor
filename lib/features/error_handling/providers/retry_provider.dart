import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tag_editor/data/providers/service_providers.dart';
import '../services/retry_service.dart';
import 'error_providers.dart';

/// Provides a fully-wired [RetryService] instance.
///
/// Reads the error log notifier, tag reader, tag writer, and retrying
/// state controller from their respective providers so the service can
/// replay failed operations and update UI state.
final retryServiceProvider = Provider<RetryService>((ref) {
  final errorLogNotifier = ref.read(errorLogProvider.notifier);
  final tagReader = ref.read(tagReaderProvider);
  final tagWriter = ref.read(tagWriterProvider);
  final isRetryingController = ref.read(isRetryingProvider.notifier);

  return RetryService(
    errorLogNotifier: errorLogNotifier,
    tagReader: tagReader,
    tagWriter: tagWriter,
    isRetryingController: isRetryingController,
  );
});
