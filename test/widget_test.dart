import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:open_tag_editor/app.dart';

void main() {
  testWidgets('App renders without crashing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OpenTagEditorApp()));

    // Verify the app renders with status bar showing initial state
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('0 files'), findsOneWidget);
  });
}
