# Requirements: Tag Field Validation

## Overview

Provide proactive UI-level validation of tag field values based on the target format's constraints and the user's write settings. Users should see warnings/errors before committing writes, not discover truncation or encoding failures after the fact.

## Requirements

### 1. Validation Rules

- 1.1 When "Write ID3v1" is enabled, warn if any text field value exceeds 30 characters (it will be truncated in the legacy tag).
- 1.2 When encoding is set to Latin-1, flag any character outside the ISO 8859-1 range (0x00–0xFF) as an error — it cannot be represented.
- 1.3 Enforce a practical maximum length of 10,000 characters per field to prevent accidental paste-bombs that bloat file size.
- 1.4 When a numeric-only field (year, trackNumber, discNumber, bpm) contains non-numeric characters, flag as a warning.

### 2. Validation Feedback

- 2.1 Validation issues shall be surfaced as inline indicators on the affected text field (warning icon for truncation/lossy, error icon for unrepresentable).
- 2.2 A tooltip on the indicator shall explain the specific issue.
- 2.3 Validation shall run on every keystroke (debounced if needed) so feedback is immediate.
- 2.4 Validation shall not block input — users can still type and save; the indicators are advisory.

### 3. Validation Context

- 3.1 The validator must consider the current `TagWriteOptions` (encoding, ID3v2 version, writeId3v1 flag) and the file's detected `TagFormat`.
- 3.2 Validation results must update reactively when the user changes write settings.
- 3.3 The validator shall be a pure function (no side effects) for testability.

### 4. Integration Points

- 4.1 Inline cell editor (`InlineTextField`) shall show validation indicators.
- 4.2 Side panel tag editor (`TagEditPanel`) shall show validation indicators.
- 4.3 The validation service shall be accessible via a Riverpod provider.
