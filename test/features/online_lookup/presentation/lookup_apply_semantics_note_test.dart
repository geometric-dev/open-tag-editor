import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/lookup_state.dart';
import 'package:open_tag_editor/features/online_lookup/presentation/widgets/lookup_apply_panel.dart';

void main() {
  testWidgets('the apply panel states what it does to empty fields', (
    tester,
  ) async {
    // The other two tag-writing surfaces say what they do: the panel says
    // clearing a field removes it everywhere, the extractor offers an
    // explicit mode. This panel used to say nothing and simply skipped
    // fields the release page had no data for -- correct behaviour, but it
    // read as the apply having failed.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LookupApplyPanel(
            matches: const [],
            coverArt: null,
            status: LookupStatus.idle,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('left unchanged'), findsOneWidget);
    expect(find.textContaining('Clear Fields'), findsOneWidget);
  });
}
