import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/shared/services/tag_field_validator.dart';
import 'package:open_tag_editor/shared/widgets/validation_indicator.dart';

void main() {
  group('ValidationIndicator', () {
    testWidgets('renders nothing for empty issues list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ValidationIndicator(issues: []),
          ),
        ),
      );

      expect(find.byType(Icon), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders warning icon for warning-only issues', (tester) async {
      const issues = [
        TagFieldIssue(
          severity: TagFieldSeverity.warning,
          message: 'Will be truncated',
          field: 'title',
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ValidationIndicator(issues: issues),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, equals(Icons.warning_amber));
      expect(icon.color, equals(Colors.orange));
    });

    testWidgets('renders error icon when any error-severity issue exists',
        (tester) async {
      const issues = [
        TagFieldIssue(
          severity: TagFieldSeverity.warning,
          message: 'Will be truncated',
          field: 'title',
        ),
        TagFieldIssue(
          severity: TagFieldSeverity.error,
          message: 'Cannot represent in Latin-1',
          field: 'title',
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ValidationIndicator(issues: issues),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, equals(Icons.error_outline));
    });

    testWidgets('tooltip contains all issue messages', (tester) async {
      const issues = [
        TagFieldIssue(
          severity: TagFieldSeverity.warning,
          message: 'First issue',
          field: 'title',
        ),
        TagFieldIssue(
          severity: TagFieldSeverity.error,
          message: 'Second issue',
          field: 'title',
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ValidationIndicator(issues: issues),
          ),
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, equals('First issue\nSecond issue'));
    });

    testWidgets('uses custom iconSize', (tester) async {
      const issues = [
        TagFieldIssue(
          severity: TagFieldSeverity.warning,
          message: 'Test',
          field: 'title',
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ValidationIndicator(issues: issues, iconSize: 24),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, equals(24));
    });

    testWidgets('uses theme error colour for error severity', (tester) async {
      const issues = [
        TagFieldIssue(
          severity: TagFieldSeverity.error,
          message: 'Error',
          field: 'title',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.light(error: Colors.purple),
          ),
          home: const Scaffold(
            body: ValidationIndicator(issues: issues),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, equals(Colors.purple));
    });
  });
}
