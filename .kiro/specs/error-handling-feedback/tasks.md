# Implementation Plan: Error Handling & User Feedback

## Overview

Implement structured error handling and user feedback for batch operations. The approach starts with domain models and the error log state layer (pure logic), then builds the notification and retry services, followed by the presentation layer (error panel, status bar integration, snackbar, corrupt file indicators), and finally wires everything into existing batch operation flows. Each step builds incrementally on the previous, ensuring no orphaned code.

## Tasks

- [x] 1. Define domain models and error log state management
  - [x] 1.1 Create ErrorEntry, OperationContext, and ErrorLogState models
    - Create `lib/features/error_handling/models/error_entry.dart` with `ErrorEntry` class (id, filePath, fileName, operationType, errorMessage, timestamp, operationContext)
    - Create `lib/features/error_handling/models/operation_context.dart` with sealed `OperationContext` class and subclasses: `ReadOperationContext`, `WriteOperationContext`, `RenameOperationContext`
    - Create `lib/features/error_handling/models/error_log_state.dart` with `ErrorLogState` class (entries list, count, isEmpty, isNotEmpty getters)
    - Create `lib/features/error_handling/models/operation_type.dart` with `OperationType` enum (read, write, rename)
    - _Requirements: 2.1_

  - [x] 1.2 Implement ErrorLogNotifier with bounded buffer logic
    - Create `lib/features/error_handling/notifiers/error_log_notifier.dart`
    - Implement `addEntries(List<ErrorEntry> entries)` — appends entries, evicts oldest when at 500 capacity
    - Implement `removeEntry(String entryId)` — removes entry by ID (used after successful retry)
    - Implement `updateEntry(String entryId, {required String newMessage, required DateTime newTimestamp})` — updates in-place (used after failed retry)
    - Implement `clear()` — removes all entries (called on folder change)
    - _Requirements: 2.2, 2.3, 2.4, 2.5_

  - [x] 1.3 Create ErrorEntryFactory for batch result conversion
    - Create `lib/features/error_handling/utils/error_entry_factory.dart`
    - Implement `fromWriteResults(List<TagWriteResult> results, Map<String, Map<String, String>> originalTags)` — creates ErrorEntry per failed write with WriteOperationContext
    - Implement `fromRenameResults(List<RenameResult> results)` — creates ErrorEntry per failed rename with RenameOperationContext
    - Implement `fromReadFailures(List<String> failedPaths, Map<String, String> errorMessages)` — creates ErrorEntry per failed read with ReadOperationContext
    - _Requirements: 2.1_

  - [x] 1.4 Create Riverpod providers for error state
    - Create `lib/features/error_handling/providers/error_providers.dart`
    - Define `errorLogProvider` as `StateNotifierProvider<ErrorLogNotifier, ErrorLogState>`
    - Define `errorPanelVisibleProvider` as `StateProvider<bool>` (default false)
    - Define `errorCountProvider` as derived `Provider<int>` watching `errorLogProvider.count`
    - Define `isRetryingProvider` as `StateProvider<bool>` (default false)
    - _Requirements: 6.1, 6.4_

  - [ ]* 1.5 Write property test: Error log bounded buffer invariant (Property 3)
    - **Property 3: Error log bounded buffer invariant**
    - **Validates: Requirements 2.2, 2.3, 2.5**
    - Create `test/features/error_handling/data/error_log_notifier_test.dart`
    - Generate random sequences of `addEntries` calls with varying entry counts
    - Assert: entries.length never exceeds 500, insertion order maintained (newest last), oldest evicted first

  - [ ]* 1.6 Write property test: ErrorEntry creation completeness (Property 2)
    - **Property 2: ErrorEntry creation completeness**
    - **Validates: Requirements 2.1**
    - Create `test/features/error_handling/data/error_entry_factory_test.dart`
    - Generate random batch results with failures
    - Assert: exactly one ErrorEntry per failure, each has non-empty filePath, valid operationType, non-empty errorMessage, non-null timestamp, non-null operationContext preserving original parameters

  - [ ]* 1.7 Write property test: Error count reflects log size (Property 8)
    - **Property 8: Error count reflects log size**
    - **Validates: Requirements 6.1, 6.4**
    - Assert: after any sequence of add/remove/clear operations, errorCountProvider returns entries.length

  - [ ]* 1.8 Write unit tests for ErrorLogNotifier and ErrorEntryFactory
    - Test: empty initial state, single add, single remove, clear
    - Test: capacity eviction at exactly 500
    - Test: updateEntry changes message and timestamp but preserves id and operationContext
    - Test: fromWriteResults with mixed success/failure, fromRenameResults, fromReadFailures
    - Test: fromWriteResults with all-success batch produces empty list
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [x] 2. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Implement notification and retry services
  - [x] 3.1 Create BatchNotification model and NotificationService
    - Create `lib/features/error_handling/models/batch_notification.dart` with `BatchNotification` class (level, successCount, failureCount, autoDismissDuration, message getter) and `NotificationLevel` enum
    - Create `lib/features/error_handling/services/notification_service.dart` with `NotificationService` class
    - Implement `showBatchError({required int failureCount, required int successCount, required VoidCallback onViewDetails})` — persistent snackbar with "View Details" action
    - Implement `showBatchSuccess({required int successCount})` — auto-hide after 3 seconds
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [x] 3.2 Implement RetryService
    - Create `lib/features/error_handling/services/retry_service.dart`
    - Implement `retryAll()` — iterates all error entries, replays each operation via stored OperationContext, removes on success, updates on failure, returns success count
    - Implement `retrySingle(String entryId)` — replays single operation, returns bool
    - Handle read/write/rename context types by dispatching to appropriate existing services
    - Set `isRetryingProvider` during operation to disable UI buttons
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [x] 3.3 Create RetryService Riverpod provider
    - Create `lib/features/error_handling/providers/retry_provider.dart`
    - Define `retryServiceProvider` wired to `errorLogProvider`, tag reader, tag writer, and file list notifier
    - _Requirements: 4.1_

  - [ ]* 3.4 Write property test: Batch notification correctness (Property 1)
    - **Property 1: Batch notification correctness**
    - **Validates: Requirements 1.1, 1.2, 1.3**
    - Create `test/features/error_handling/data/notification_model_test.dart`
    - Generate random batch results with varying success/failure counts
    - Assert: failures > 0 → level is error, autoDismissDuration is null; failures == 0 → level is success, autoDismissDuration is 3 seconds

  - [ ]* 3.5 Write property test: Retry parameter preservation (Property 4)
    - **Property 4: Retry parameter preservation**
    - **Validates: Requirements 4.1**
    - Create `test/features/error_handling/data/retry_service_test.dart`
    - Generate random ErrorEntries with various OperationContext types
    - Assert: retry calls the corresponding service with parameters identical to those in OperationContext

  - [ ]* 3.6 Write property test: Successful retry removes entry (Property 5)
    - **Property 5: Successful retry removes entry**
    - **Validates: Requirements 4.3**
    - Generate random error log states, mock successful retry
    - Assert: entry is removed from log, count decreases by one

  - [ ]* 3.7 Write property test: Failed retry updates entry in-place (Property 6)
    - **Property 6: Failed retry updates entry in-place**
    - **Validates: Requirements 4.4**
    - Generate random error log states, mock failed retry
    - Assert: entry's errorMessage and timestamp updated, id and operationContext unchanged, no duplicate entry added

  - [ ]* 3.8 Write unit tests for NotificationService and RetryService
    - Test: showBatchError creates persistent snackbar with correct message
    - Test: showBatchSuccess creates auto-dismissing snackbar
    - Test: retrySingle success removes entry
    - Test: retrySingle failure updates entry
    - Test: retryAll with mixed results returns correct success count
    - Test: retry buttons disabled while isRetryingProvider is true
    - _Requirements: 1.1, 1.2, 1.3, 4.1, 4.3, 4.4, 4.5_

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement error panel and status bar UI
  - [x] 5.1 Implement VerticalResizableSplitter widget
    - Create `lib/shared/widgets/vertical_resizable_splitter.dart`
    - Implement draggable horizontal divider between top and bottom children
    - Support configurable `bottomHeight`, `minBottomHeight`, `maxBottomHeightFraction`
    - Follow existing `ResizableSplitter` drag-handle pattern
    - _Requirements: 3.3_

  - [x] 5.2 Implement ErrorPanel widget
    - Create `lib/features/error_handling/widgets/error_panel.dart`
    - Render scrollable list of ErrorEntry rows (file path, operation type, error message, timestamp)
    - Use `ListView.builder` for virtualization when entries exceed 50
    - Show empty state message when log is empty
    - Include "Retry All Failed" button in header, disabled while `isRetryingProvider` is true
    - Include per-row retry button, disabled while retrying
    - _Requirements: 3.1, 3.2, 3.4, 3.5, 4.1, 4.2, 4.5_

  - [x] 5.3 Integrate error count into EnhancedStatusBar
    - Modify existing `EnhancedStatusBar` widget to watch `errorCountProvider`
    - Show warning icon and error count when count > 0, hide when count == 0
    - Make error count clickable to toggle `errorPanelVisibleProvider`
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 5.4 Wire VerticalResizableSplitter into main layout
    - Modify the main layout to wrap the file list area with `VerticalResizableSplitter`
    - Show `ErrorPanel` as bottom child when `errorPanelVisibleProvider` is true
    - Collapse bottom panel (height 0) when hidden
    - _Requirements: 3.1, 3.3_

  - [ ]* 5.5 Write widget tests for ErrorPanel and status bar integration
    - Test: error panel renders entry rows with all fields
    - Test: empty state message shown when log is empty
    - Test: "Retry All Failed" button disabled during retry
    - Test: status bar shows/hides error count based on log state
    - Test: clicking status bar error count toggles panel visibility
    - _Requirements: 3.2, 3.5, 4.5, 6.1, 6.2, 6.3_

- [x] 6. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Implement corrupt file handling and snackbar integration
  - [x] 7.1 Add readError field to AudioFile model
    - Modify existing `AudioFile` class to add optional `String? readError` field
    - Update `copyWith` to support `readError`
    - Update equality/hashCode to include `readError`
    - _Requirements: 5.1_

  - [x] 7.2 Implement corrupt file error indicator in file list
    - Modify the tag indicator column rendering to show a red error icon when `audioFile.readError != null`
    - Add tooltip on hover displaying the `readError` message
    - Ensure corrupt files remain selectable for rename operations
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [x] 7.3 Integrate error reporting into FolderLoadingService
    - Modify `FolderLoadingService` to call `errorLogNotifier.clear()` on new folder load
    - Capture tag read failures and create ErrorEntries via `ErrorEntryFactory.fromReadFailures()`
    - Add failed files to file list with `readError` set and empty `tags` map
    - Call `NotificationService.showBatchError()` when failures occur during load
    - _Requirements: 2.1, 2.4, 5.1, 1.1_

  - [x] 7.4 Integrate error reporting into tag write and rename operations
    - Modify tag write batch operation to capture failures and call `errorLogNotifier.addEntries()` via `ErrorEntryFactory.fromWriteResults()`
    - Modify rename batch operation to capture failures and call `errorLogNotifier.addEntries()` via `ErrorEntryFactory.fromRenameResults()`
    - Show appropriate snackbar notification after each batch operation
    - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2_

  - [ ]* 7.5 Write property test: Corrupt file inclusion with error flag (Property 7)
    - **Property 7: Corrupt file inclusion with error flag**
    - **Validates: Requirements 5.1**
    - Create `test/features/error_handling/data/corrupt_file_test.dart`
    - Generate random file paths that fail tag reading
    - Assert: resulting AudioFile has that path, empty tags map, non-null readError, valid filename derived from path

  - [ ]* 7.6 Write widget tests for corrupt file indicator and snackbar
    - Test: red error icon shown in tag indicator column for corrupt files
    - Test: tooltip displays readError message on hover
    - Test: corrupt files can be selected
    - Test: error snackbar "View Details" button opens error panel
    - Test: success snackbar auto-hides after 3 seconds
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 1.1, 1.3, 1.4_

- [x] 8. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate the 8 universal correctness properties defined in the design
- Unit tests validate specific examples and edge cases
- Domain models and state management (task 1) have no widget dependencies and are fully testable in isolation
- The existing `TagWriteResult`, `RenameResult`, and service classes are reused without modification
- The `VerticalResizableSplitter` follows the same pattern as the existing horizontal `ResizableSplitter`

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["1.4", "1.5", "1.6"] },
    { "id": 3, "tasks": ["1.7", "1.8"] },
    { "id": 4, "tasks": ["3.1", "3.2"] },
    { "id": 5, "tasks": ["3.3", "3.4", "3.5"] },
    { "id": 6, "tasks": ["3.6", "3.7", "3.8"] },
    { "id": 7, "tasks": ["5.1", "5.3", "7.1"] },
    { "id": 8, "tasks": ["5.2", "5.4", "7.2"] },
    { "id": 9, "tasks": ["5.5", "7.3", "7.4"] },
    { "id": 10, "tasks": ["7.5", "7.6"] }
  ]
}
```
