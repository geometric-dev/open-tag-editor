import 'package:equatable/equatable.dart';

/// Immutable data class holding all persisted window layout state.
///
/// Includes window geometry (size and position), tag panel state
/// (open/closed and width), and the last loaded folder path.
class WindowState extends Equatable {
  const WindowState({
    required this.windowWidth,
    required this.windowHeight,
    required this.windowX,
    required this.windowY,
    required this.isTagPanelOpen,
    required this.tagPanelWidth,
    this.errorPanelHeight = defaultErrorPanelHeight,
    this.lastFolderPath,
  });

  /// Default window state: 1280×800, position 0,0 (will be centered at
  /// startup if no persisted position), tag panel closed at 380px.
  factory WindowState.defaults() {
    return const WindowState(
      windowWidth: 1280,
      windowHeight: 800,
      windowX: 0,
      windowY: 0,
      isTagPanelOpen: false,
      tagPanelWidth: 380.0,
    );
  }

  /// Window width in logical pixels.
  final int windowWidth;

  /// Window height in logical pixels.
  final int windowHeight;

  /// Window x-position (top-left corner) in logical pixels.
  final int windowX;

  /// Window y-position (top-left corner) in logical pixels.
  final int windowY;

  /// Whether the tag editor side panel is open.
  final bool isTagPanelOpen;

  /// Tag panel width in logical pixels.
  final double tagPanelWidth;

  /// Error panel height in logical pixels.
  final double errorPanelHeight;

  /// The last successfully loaded folder path, or null if none.
  final String? lastFolderPath;

  /// Default error panel height.
  static const double defaultErrorPanelHeight = 200.0;

  /// Minimum allowed error panel height.
  static const double minErrorPanelHeight = 100.0;

  /// Minimum allowed tag panel width.
  static const double minTagPanelWidth = 280.0;

  /// Maximum tag panel width as a fraction of window width.
  static const double maxTagPanelWidthFraction = 0.5;

  /// Creates a copy with updated fields.
  WindowState copyWith({
    int? windowWidth,
    int? windowHeight,
    int? windowX,
    int? windowY,
    bool? isTagPanelOpen,
    double? tagPanelWidth,
    double? errorPanelHeight,
    String? Function()? lastFolderPath,
  }) {
    return WindowState(
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
      windowX: windowX ?? this.windowX,
      windowY: windowY ?? this.windowY,
      isTagPanelOpen: isTagPanelOpen ?? this.isTagPanelOpen,
      tagPanelWidth: tagPanelWidth ?? this.tagPanelWidth,
      errorPanelHeight: errorPanelHeight ?? this.errorPanelHeight,
      lastFolderPath:
          lastFolderPath != null ? lastFolderPath() : this.lastFolderPath,
    );
  }

  @override
  List<Object?> get props => [
        windowWidth,
        windowHeight,
        windowX,
        windowY,
        isTagPanelOpen,
        tagPanelWidth,
        errorPanelHeight,
        lastFolderPath,
      ];
}
