import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inline_cell_edit_provider.dart';

/// The text input field displayed inside a cell during edit mode.
///
/// Matches the font size and padding of the static cell text.
/// Handles Enter, Escape, Tab, Shift+Tab, and Ctrl+Enter key events.
class InlineTextField extends ConsumerStatefulWidget {
  const InlineTextField({
    super.key,
    required this.initialValue,
    required this.selectAll,
    required this.width,
  });

  /// The initial text value to display.
  final String initialValue;

  /// Whether to select all text on mount (F2 entry).
  final bool selectAll;

  /// The width of the text field.
  final double width;

  @override
  ConsumerState<InlineTextField> createState() => _InlineTextFieldState();
}

class _InlineTextFieldState extends ConsumerState<InlineTextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();

    // Auto-focus and optionally select all
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        if (widget.selectAll) {
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        } else {
          // Place cursor at end
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: SizedBox(
        width: widget.width,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            ref.read(inlineCellEditProvider.notifier).updateValue(value);
          },
          onEditingComplete: () {
            // Enter key — confirm and navigate down
            ref.read(inlineCellEditProvider.notifier).confirmEdit();
            ref.read(inlineCellEditProvider.notifier).navigateDown();
          },
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final notifier = ref.read(inlineCellEditProvider.notifier);

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      notifier.cancelEdit();
    } else if (event.logicalKey == LogicalKeyboardKey.tab) {
      final isShift = HardwareKeyboard.instance.logicalKeysPressed.any(
        (k) =>
            k == LogicalKeyboardKey.shiftLeft ||
            k == LogicalKeyboardKey.shiftRight,
      );
      if (isShift) {
        notifier.navigatePrevious();
      } else {
        notifier.navigateNext();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      final isCtrl = HardwareKeyboard.instance.logicalKeysPressed.any(
        (k) =>
            k == LogicalKeyboardKey.controlLeft ||
            k == LogicalKeyboardKey.controlRight,
      );
      if (isCtrl) {
        // Ctrl+Enter: batch apply without prompt
        notifier.confirmEdit(batchMode: true);
      } else {
        notifier.confirmEdit();
        notifier.navigateDown();
      }
    }
  }
}
