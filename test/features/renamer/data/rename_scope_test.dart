import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/renamer/data/rename_scope.dart';
import 'package:path/path.dart' as p;

void main() {
  group('partitionRenamesByScope', () {
    final root = p.join('C:', 'Music', 'Album');

    test('keeps renames that stay inside the root', () {
      final partition = partitionRenamesByScope({
        p.join(root, 'old.mp3'): p.join(root, 'new.mp3'),
      }, root);

      expect(partition.insideRoot.keys.length, 1);
      expect(partition.outsideRoot, isEmpty);
    });

    test('keeps renames into a subfolder of the root', () {
      final partition = partitionRenamesByScope({
        p.join(root, 'old.mp3'): p.join(root, 'Disc 1', 'new.mp3'),
      }, root);

      expect(partition.insideRoot.keys.length, 1);
      expect(partition.outsideRoot, isEmpty);
    });

    test('separates renames that leave the root', () {
      final partition = partitionRenamesByScope({
        p.join(root, 'a.mp3'): p.join(root, 'a2.mp3'),
        p.join(root, 'b.mp3'): p.join('C:', 'Music', 'Other', 'b.mp3'),
      }, root);

      expect(partition.insideRoot.keys.length, 1);
      expect(partition.outsideRoot.keys.length, 1);
      expect(partition.outsideRoot.keys.first, p.join(root, 'b.mp3'));
    });

    test('treats every rename as inside when there is no root', () {
      final partition = partitionRenamesByScope({
        r'C:\Music\a.mp3': r'C:\Elsewhere\a.mp3',
      }, null);

      expect(partition.insideRoot.keys.length, 1);
      expect(partition.outsideRoot, isEmpty);
    });

    test('does not treat a sibling with a shared prefix as inside', () {
      // "Album2" shares a prefix with "Album" but is not inside it.
      final partition = partitionRenamesByScope({
        p.join(root, 'a.mp3'): p.join('C:', 'Music', 'Album2', 'a.mp3'),
      }, root);

      expect(partition.insideRoot, isEmpty);
      expect(partition.outsideRoot.keys.length, 1);
    });
  });
}
