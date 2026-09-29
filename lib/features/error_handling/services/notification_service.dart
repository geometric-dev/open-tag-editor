import 'package:flutter/material.dart';

/// Provides snackbar notifications for batch operation results.
///
/// Centralizes snackbar display logic with error/success variants.
/// Error snackbars persist until dismissed; success snackbars auto-hide.
class NotificationService {
  /// Creates a [NotificationService] that uses the given [scaffoldKey]
  /// to show snackbars via [ScaffoldMessenger].
  const NotificationService(this._scaffoldKey);

  final GlobalKey<ScaffoldMessengerState> _scaffoldKey;

  /// Shows an error snackbar with failure count and "View Details" action.
  ///
  /// The snackbar persists until the user explicitly dismisses it or
  /// activates the "View Details" button. Tapping "View Details" calls
  /// [onViewDetails] and closes the snackbar.
  void showBatchError({
    required int failureCount,
    required int successCount,
    required VoidCallback onViewDetails,
  }) {
    final messenger = _scaffoldKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$failureCount file(s) failed'),
        duration: const Duration(seconds: 30),
        showCloseIcon: true,
        action: SnackBarAction(label: 'View Details', onPressed: onViewDetails),
      ),
    );
  }

  /// Shows a success snackbar that auto-hides after 3 seconds.
  void showBatchSuccess({required int successCount}) {
    final messenger = _scaffoldKey.currentState;
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text('$successCount file(s) saved successfully'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
