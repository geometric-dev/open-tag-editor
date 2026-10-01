import 'package:flutter_riverpod/legacy.dart';

/// A command that can be executed and undone.
abstract class UndoableCommand {
  /// Human-readable description of this command.
  String get description;

  /// Applies the change.
  ///
  /// Returns whether anything actually changed. A command that decides it has
  /// nothing to do should return false rather than reporting success: the undo
  /// manager uses this to avoid pushing a dead entry onto the stack, where it
  /// would silently consume the user's next Ctrl+Z.
  bool execute();

  /// Undo the command (revert the change).
  void undo();
}

/// Manages undo/redo history for tag editing operations.
class UndoRedoManager extends StateNotifier<UndoRedoState> {
  UndoRedoManager() : super(const UndoRedoState());

  static const _maxHistory = 100;

  /// Executes a command and adds it to the undo stack if it changed anything.
  ///
  /// Returns whether the command was recorded. A no-op command still runs
  /// (so callers can keep one code path) but does not occupy a slot on the
  /// stack: without this, pressing Enter in a field without changing it
  /// created an entry that looked like history and made the next Ctrl+Z do
  /// nothing visible.
  bool execute(UndoableCommand command) {
    if (!command.execute()) return false;

    final newUndoStack = [...state.undoStack, command];
    // Trim if exceeding max history
    if (newUndoStack.length > _maxHistory) {
      newUndoStack.removeAt(0);
    }

    state = UndoRedoState(
      undoStack: newUndoStack,
      redoStack: const [], // Clear redo stack on new action
    );
    return true;
  }

  /// Undo the last command.
  void undo() {
    if (!state.canUndo) return;

    final command = state.undoStack.last;
    command.undo();

    state = UndoRedoState(
      undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
      redoStack: [...state.redoStack, command],
    );
  }

  /// Redo the last undone command.
  void redo() {
    if (!state.canRedo) return;

    final command = state.redoStack.last;
    command.execute();

    state = UndoRedoState(
      undoStack: [...state.undoStack, command],
      redoStack: state.redoStack.sublist(0, state.redoStack.length - 1),
    );
  }

  /// Clear all history.
  void clear() {
    state = const UndoRedoState();
  }
}

/// State of the undo/redo manager.
class UndoRedoState {
  const UndoRedoState({this.undoStack = const [], this.redoStack = const []});

  final List<UndoableCommand> undoStack;
  final List<UndoableCommand> redoStack;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  String? get undoDescription => canUndo ? undoStack.last.description : null;
  String? get redoDescription => canRedo ? redoStack.last.description : null;
}

/// Provider for the undo/redo manager.
final undoRedoProvider = StateNotifierProvider<UndoRedoManager, UndoRedoState>((
  ref,
) {
  return UndoRedoManager();
});
