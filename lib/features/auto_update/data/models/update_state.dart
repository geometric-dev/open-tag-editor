import 'app_version.dart';
import 'update_info.dart';

/// Lifecycle statuses of the auto-update process.
enum UpdateStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  readyToInstall,
  failed,
}

/// Immutable state of the auto-update feature.
class UpdateState {
  const UpdateState({
    required this.status,
    required this.currentVersion,
    this.updateInfo,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
    this.releaseUrl,
  });

  /// Initial idle state using the current app version.
  static const initial = UpdateState(
    status: UpdateStatus.idle,
    currentVersion: AppVersion.current,
  );

  final UpdateStatus status;
  final AppVersion currentVersion;
  final UpdateInfo? updateInfo;
  final int downloadedBytes;
  final int totalBytes;
  final String? errorMessage;
  final String? releaseUrl;

  bool get isChecking => status == UpdateStatus.checking;
  bool get isUpToDate => status == UpdateStatus.upToDate;
  bool get isUpdateAvailable => status == UpdateStatus.updateAvailable;
  bool get isDownloading => status == UpdateStatus.downloading;
  bool get isReadyToInstall => status == UpdateStatus.readyToInstall;
  bool get isFailed => status == UpdateStatus.failed;

  /// Whether an action is currently running.
  bool get isBusy => isChecking || isDownloading;

  /// 0..1 download progress fraction, or null if total is unknown.
  double? get downloadFraction {
    if (totalBytes <= 0) return null;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  UpdateState copyWith({
    UpdateStatus? status,
    AppVersion? currentVersion,
    UpdateInfo? updateInfo,
    int? downloadedBytes,
    int? totalBytes,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? releaseUrl,
  }) {
    return UpdateState(
      status: status ?? this.status,
      currentVersion: currentVersion ?? this.currentVersion,
      updateInfo: updateInfo ?? this.updateInfo,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      releaseUrl: releaseUrl ?? this.releaseUrl,
    );
  }
}
