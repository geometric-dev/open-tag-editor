import 'package:flutter_riverpod/legacy.dart';

import '../models/inline_cell_edit_state.dart';
import '../notifiers/inline_cell_edit_notifier.dart';

/// Provider for inline cell edit state.
final inlineCellEditProvider =
    StateNotifierProvider<InlineCellEditNotifier, InlineCellEditState>((ref) {
      return InlineCellEditNotifier(ref: ref);
    });
