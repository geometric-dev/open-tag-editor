import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/tag_field_validation_provider.dart';
import '../../../../shared/services/taglib/taglib_types.dart';
import '../../../../shared/widgets/validation_indicator.dart';
import '../../data/providers/filtered_sorted_file_list_provider.dart';
import '../../data/providers/selection_provider.dart';
import '../providers/inline_cell_edit_provider.dart';

/// Inline text field for cell editing.
///
/// Handles Escape (cancel), Tab/Shift+Tab (navigate), Enter (confirm+down),
/// Ctrl+Enter (batch apply), and arrow up/down (confirm+move selection).
/// Confirms on focus loss.
class InlineTextField extends ConsumerStatefulWidget {
  const InlineTextField({
    super.key,
    required this.initialValue,
    required this.selectAll,
    required this.width,
    required this.field,
    this.tagFormat,
  });

  final String initialValue;
  final bool selectAll;
  final double width;
  final String field;
  final TagFormat? tagFormat;

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
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    _focusNode.addListener(_onFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        if (widget.selectAll) {
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        } else {
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && mounted) {
      final editState = ref.read(inlineCellEditProvider);
      if (editState.isEditing) {
        ref.read(inlineCellEditProvider.notifier).confirmEdit(clearFocus: true);
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final notifier = ref.read(inlineCellEditProvider.notifier);

    final isShift = HardwareKeyboard.instance.logicalKeysPressed.any(
      (k) =>
          k == LogicalKeyboardKey.shiftLeft ||
          k == LogicalKeyboardKey.shiftRight,
    );

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      notifier.cancelEdit();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (isShift) {
        notifier.navigatePrevious();
      } else {
        notifier.navigateNext();
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      notifier.confirmEdit();

      final files = ref.read(filteredSortedFileListProvider);
      final orderedPaths = files.map((f) => f.path).toList();
      final selNotifier = ref.read(selectionProvider.notifier);

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (isShift) {
          selNotifier.extendUp(orderedPaths);
        } else {
          selNotifier.moveUp(orderedPaths);
        }
      } else {
        if (isShift) {
          selNotifier.extendDown(orderedPaths);
        } else {
          selNotifier.moveDown(orderedPaths);
        }
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final currentValue = _controller.text;
    final validate = ref.watch(tagFieldValidationProvider);
    final issues = validate(
      field: widget.field,
      value: currentValue,
      tagFormat: widget.tagFormat,
    );

    final indicator = ValidationIndicator(issues: issues, iconSize: 14);
    final hasIssues = issues.isNotEmpty;

    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 4,
          ),
          border: InputBorder.none,
          suffixIcon: hasIssues ? indicator : null,
          suffixIconConstraints: hasIssues
              ? const BoxConstraints(maxWidth: 20, maxHeight: 16)
              : null,
        ),
        onChanged: (value) {
          ref.read(inlineCellEditProvider.notifier).updateValue(value);
          setState(() {});
        },
        onSubmitted: (_) {
          ref.read(inlineCellEditProvider.notifier).confirmEdit();
          ref.read(inlineCellEditProvider.notifier).navigateDown();
        },
      ),
    );
  }
}
