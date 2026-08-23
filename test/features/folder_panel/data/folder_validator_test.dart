import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/folder_panel/data/folder_validator.dart';

void main() {
  late FolderValidator validator;

  setUp(() {
    validator = FolderValidator();
  });

  group('FolderValidator', () {
    test('returns ok for an existing directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('validator_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final result = await validator.validate(tempDir.path);

      expect(result.isValid, isTrue);
      expect(result.error, isNull);
    });

    test('returns notFound for a non-existent path', () async {
      final result = await validator.validate(
        '${Directory.systemTemp.path}/non_existent_folder_xyz_123',
      );

      expect(result.isValid, isFalse);
      expect(result.error, FolderValidationError.notFound);
    });

    test('returns notADirectory for a file path', () async {
      final tempFile = File(
        '${Directory.systemTemp.path}/validator_test_file.txt',
      );
      tempFile.writeAsStringSync('test');
      addTearDown(() => tempFile.deleteSync());

      final result = await validator.validate(tempFile.path);

      expect(result.isValid, isFalse);
      expect(result.error, FolderValidationError.notADirectory);
    });

    test('returns ok for an empty directory', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'validator_empty_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final result = await validator.validate(tempDir.path);

      expect(result.isValid, isTrue);
      expect(result.error, isNull);
    });
  });

  group('FolderValidationResult', () {
    test('ok result has null error and isValid true', () {
      const result = FolderValidationResult.ok();

      expect(result.error, isNull);
      expect(result.isValid, isTrue);
    });

    test('failed result has error and isValid false', () {
      const result = FolderValidationResult.failed(
        FolderValidationError.notFound,
      );

      expect(result.error, FolderValidationError.notFound);
      expect(result.isValid, isFalse);
    });
  });
}
