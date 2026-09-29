import 'package:flutter_riverpod/legacy.dart';

/// A command that can be executed and undone.
abstract class UndoableCommand {
  /// Human-readable description of this command.
  String get description;

  /// Execute the command (apply the change).
  void execute();

  /// Undo the command (revert the change).
  void undo();
}

/// Manages undo/redo history for tag editing operations.
class UndoRedoManager extends StateNotifier<UndoRedoState> {
  UndoRedoManager() : super(const UndoRedoState());

  static const _maxHistory = 100;

  /// Execute a command and add it to the undo stack.
  void execute(UndoableCommand command) {
    command.execute();

    final newUndoStack = [...state.undoStack, command];
    // Trim if exceeding max history
    if (newUndoStack.length > _maxHistory) {
      newUndoStack.removeAt(0);
    }

    state = UndoRedoState(
      undoStack: newUndoStack,
      redoStack: const [], // Clear redo stack on new action
    );
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
