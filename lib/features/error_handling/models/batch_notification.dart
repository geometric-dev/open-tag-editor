/// Describes a batch operation notification to display.
class BatchNotification {
  const BatchNotification({
    required this.level,
    required this.successCount,
    required this.failureCount,
  });

  /// The severity level of this notification.
  final NotificationLevel level;

  /// Number of files that succeeded in the batch operation.
  final int successCount;

  /// Number of files that failed in the batch operation.
  final int failureCount;

  /// Error notifications persist until dismissed.
  /// Success notifications auto-hide after 3 seconds.
  Duration? get autoDismissDuration =>
      level == NotificationLevel.success ? const Duration(seconds: 3) : null;

  /// Human-readable summary message for the notification.
  String get message => level == NotificationLevel.success
      ? '$successCount file(s) saved successfully'
      : '$failureCount file(s) failed, $successCount succeeded';
}

/// The severity level of a batch notification.
enum NotificationLevel { success, error }
