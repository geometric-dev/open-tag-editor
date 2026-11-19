import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/auto_update/data/services/update_service.dart';

void main() {
  group('buildWindowsUpdateScript', () {
    final script = buildWindowsUpdateScript(
      targetPid: 1234,
      srcDir:
          r'C:\Users\Matt\AppData\Local\Temp\open_tag_editor_updates\staged',
      destDir: r'C:\Program Files\OpenTagEditor',
      exeName: 'open_tag_editor.exe',
    );

    test('waits on the process by PID rather than polling tasklist', () {
      // The original .bat polled with `tasklist | find`, which needed a real
      // console and opened a visible window that spun forever. Wait-Process
      // waits on the PID directly and works without a console.
      expect(script, contains(r'Wait-Process -Id $targetPid'));
      expect(script, isNot(contains('tasklist')));
      expect(script, isNot(contains('find ')));
    });

    test('launches hidden (no console window)', () {
      // The caller passes -WindowStyle Hidden; assert the builder does not
      // itself require a console (no `cmd /c`).
      expect(script, isNot(contains('cmd')));
    });

    test('copies the payload over the install dir and relaunches', () {
      expect(script, contains('Copy-Item'));
      expect(script, contains('Start-Process'));
      expect(script, contains('open_tag_editor.exe'));
    });

    test('escapes single quotes in paths', () {
      final quoted = buildWindowsUpdateScript(
        targetPid: 1,
        srcDir: r"C:\It's\Here",
        destDir: r'C:\Dest',
        exeName: "app's.exe",
      );
      // A single quote inside a single-quoted PS string is doubled.
      expect(quoted, contains(r"C:\It''s\Here"));
      expect(quoted, contains("app''s.exe"));
    });

    test('embeds the target PID as a bare integer', () {
      expect(script, contains('\$targetPid = 1234'));
    });
  });
}
