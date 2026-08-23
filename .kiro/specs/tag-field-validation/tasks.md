# Implementation Plan: Tag Field Validation

## Overview

Implement a pure-function validation layer that checks tag field values against format constraints and write settings, surfacing warnings/errors inline in both the cell editor and side panel via a shared `ValidationIndicator` widget.

## Tasks

- [x] 1. Create validation models and pure logic
  - [x] 1.1 Create TagFieldValidator and models
    - Create `lib/shared/services/tag_field_validator.dart`
    - Define `TagFieldIssue` class (severity, message, field)
    - Define `TagFieldSeverity` enum (warning, error)
    - Implement `TagFieldValidator.validate(field, value, options, tagFormat)` pure function
    - Rules: ID3v1 truncation warning (>30 chars), Latin-1 encoding error (non-Latin-1 chars), max length error (>10,000), numeric field warning (non-numeric in year/trackNumber/discNumber/bpm)
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 3.1, 3.3_
    - _Subagent: delegate_

  - [x] 1.2 Create Riverpod provider for validation
    - Create `lib/shared/providers/tag_field_validation_provider.dart`
    - Define `tagWriteOptionsProvider` deriving from `tagWritingSettingsProvider`
    - Define `tagFieldValidationProvider` exposing a callable function bound to current options
    - Reactively rebuild when write settings change
    - _Requirements: 3.2, 4.3_
    - _Subagent: delegate_

- [x] 2. Create shared ValidationIndicator widget
  - [x] 2.1 Create ValidationIndicator widget
    - Create `lib/shared/widgets/validation_indicator.dart`
    - Accept `List<TagFieldIssue> issues` parameter
    - Render `SizedBox.shrink()` when issues is empty
    - Show highest-severity icon (error > warning) with theme-aware colours
    - Tooltip lists all issue messages joined with newlines
    - Use `Theme.of(context).colorScheme.error` for error colour, `Colors.orange` for warning
    - _Requirements: 2.1, 2.2_
    - _Subagent: delegate_

- [x] 3. Integrate into inline cell editor
  - [x] 3.1 Add `field` and `tagFormat` parameters to InlineTextField
    - Add `required String field` and `TagFormat? tagFormat` constructor params
    - Update `EditableCell` to pass `coordinate.columnId` and the file's `tagFormat` when constructing `InlineTextField`
    - _Requirements: 3.1, 4.1_
    - _Subagent: main thread (cross-file wiring)_

  - [x] 3.2 Add ValidationIndicator to InlineTextField
    - Call `tagFieldValidationProvider` with `widget.field`, `_controller.text`, and `widget.tagFormat`
    - Render `ValidationIndicator` as `suffixIcon` in `InputDecoration`
    - Trigger rebuild on `onChanged` for immediate feedback
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 4.1_
    - _Subagent: main thread (cross-file wiring)_

- [x] 4. Integrate into side panel tag editor
  - [x] 4.1 Add ValidationIndicator to TagEditPanel fields
    - Modify `_buildField` in `_TagFieldsTabState` to call `tagFieldValidationProvider`
    - Pass `widget.selectedFiles.firstOrNull?.tagFormat` as the tag format
    - Render `ValidationIndicator(issues: issues)` as `suffixIcon`
    - Trigger rebuild via `onChanged` + `setState`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 4.2_
    - _Subagent: main thread (cross-file wiring)_

- [x] 5. Write unit tests for TagFieldValidator
  - [x] 5.1 Example-based unit tests
    - File: `test/shared/services/tag_field_validator_test.dart`
    - Test all validation rules with edge cases (29 tests)
    - _Requirements: 1.1, 1.2, 1.3, 1.4_
    - _Subagent: delegate_

- [x] 6. Write property-based tests for TagFieldValidator
  - [x] 6.1 Property 1: ID3v1 truncation warning
    - For any non-empty value and text field, when writeId3v1 is true: length > limit → warning present; length ≤ limit → no truncation warning
    - _Requirements: 1.1_
    - _Subagent: delegate_

  - [x] 6.2 Property 2: Latin-1 encoding error
    - For any non-empty value, when encoding is Latin-1: any char > 0xFF → error present; all chars ≤ 0xFF → no Latin-1 error
    - _Requirements: 1.2_
    - _Subagent: delegate_

  - [x] 6.3 Property 3: Maximum length enforcement
    - For any value: length > 10,000 → error present; length ≤ 10,000 → no max-length error
    - _Requirements: 1.3_
    - _Subagent: delegate_

  - [x] 6.4 Property 4: Numeric field validation
    - For any numeric field name and non-empty value: non-numeric → warning present; valid numeric → no warning
    - _Requirements: 1.4_
    - _Subagent: delegate_

- [x] 7. Write widget tests
  - [x] 7.1 ValidationIndicator widget tests
    - Renders nothing for empty issues list
    - Renders warning icon for warning-only issues
    - Renders error icon when any error-severity issue exists
    - Tooltip contains all issue messages
    - _Requirements: 2.1, 2.2_
    - _Subagent: delegate_

  - [ ]* 7.2 InlineTextField validation widget tests
    - Renders indicator when value triggers a rule
    - Updates indicator on text change
    - _Requirements: 2.3, 4.1_
    - _Subagent: delegate_

  - [ ]* 7.3 TagEditPanel validation widget tests
    - Renders suffix icon on fields with issues
    - Updates when settings change
    - _Requirements: 2.3, 4.2_
    - _Subagent: delegate_

- [x] 8. Final checkpoint
  - Run `flutter analyze` and `flutter test` to confirm no regressions.
  - Verify build with `flutter build windows`.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- The pre-existing test failure in `SelectionNotifier moveUp selects last row` is unrelated
- Property tests use `package:fast_check` with minimum 100 iterations per property
- The `tagFormat` parameter is reserved for future format-specific rules but must be plumbed through now for correctness

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "5.1"] },
    { "id": 2, "tasks": ["2.1", "6.1", "6.2", "6.3", "6.4"] },
    { "id": 3, "tasks": ["3.1", "4.1"] },
    { "id": 4, "tasks": ["3.2", "7.1"] },
    { "id": 5, "tasks": ["7.2", "7.3"] },
    { "id": 6, "tasks": ["8"] }
  ]
}
```
