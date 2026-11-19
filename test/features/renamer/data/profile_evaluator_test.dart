import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/renamer/data/models/rename_profile.dart';
import 'package:open_tag_editor/features/renamer/data/profile_evaluator.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

AudioFile _file(Map<String, String> tags) => AudioFile(
  path: r'C:\Music\Album\01.mp3',
  filename: '01.mp3',
  extension: '.mp3',
  fileSize: 1,
  tags: tags,
);

RenameProfile _singleGroup({
  required String name,
  required String pattern,
  required List<ProfileCondition> conditions,
}) => RenameProfile(
  name: name,
  pattern: pattern,
  conditionGroups: conditions.isEmpty ? const [] : [conditions],
);

void main() {
  const evaluator = ProfileEvaluator();

  group('ProfileEvaluator condition operators', () {
    test('equals is case-insensitive', () {
      final profile = _singleGroup(
        name: 'VA',
        pattern: '%title',
        conditions: const [
          ProfileCondition(
            field: 'albumArtist',
            operator: ProfileOperator.equals,
            value: 'various artists',
          ),
        ],
      );
      expect(
        evaluator.matches(profile, _file({'albumArtist': 'Various Artists'})),
        isTrue,
      );
    });

    test('notEquals', () {
      final profile = _singleGroup(
        name: 'not VA',
        pattern: '%title',
        conditions: const [
          ProfileCondition(
            field: 'albumArtist',
            operator: ProfileOperator.notEquals,
            value: 'Various Artists',
          ),
        ],
      );
      expect(
        evaluator.matches(profile, _file({'albumArtist': 'Some Band'})),
        isTrue,
      );
      expect(
        evaluator.matches(profile, _file({'albumArtist': 'Various Artists'})),
        isFalse,
      );
    });

    test('contains / notContains', () {
      final contains = _singleGroup(
        name: 'ost',
        pattern: '%title',
        conditions: const [
          ProfileCondition(
            field: 'genre',
            operator: ProfileOperator.contains,
            value: 'soundtrack',
          ),
        ],
      );
      expect(
        evaluator.matches(contains, _file({'genre': 'Soundtrack / OST'})),
        isTrue,
      );
      expect(evaluator.matches(contains, _file({'genre': 'Rock'})), isFalse);
    });

    test('isSet / isNotSet', () {
      final isSet = _singleGroup(
        name: 'has disc',
        pattern: '%title',
        conditions: const [
          ProfileCondition(
            field: 'discNumber',
            operator: ProfileOperator.isSet,
          ),
        ],
      );
      expect(evaluator.matches(isSet, _file({'discNumber': '1'})), isTrue);
      expect(evaluator.matches(isSet, _file({})), isFalse);

      final isNotSet = _singleGroup(
        name: 'no disc',
        pattern: '%title',
        conditions: const [
          ProfileCondition(
            field: 'discNumber',
            operator: ProfileOperator.isNotSet,
          ),
        ],
      );
      expect(evaluator.matches(isNotSet, _file({})), isTrue);
      expect(evaluator.matches(isNotSet, _file({'discNumber': '1'})), isFalse);
    });

    test('greaterThan on a numeric pseudo-field', () {
      final multiDisc = _singleGroup(
        name: 'multi-disc',
        pattern: '%title',
        conditions: const [
          ProfileCondition(
            field: 'discCount',
            operator: ProfileOperator.greaterThan,
            value: '1',
          ),
        ],
      );
      // discNumber "2/2" → discCount "2" → 2 > 1 → match.
      expect(
        evaluator.matches(multiDisc, _file({'discNumber': '2/2'})),
        isTrue,
      );
      // "1/1" → discCount "1" → not > 1.
      expect(
        evaluator.matches(multiDisc, _file({'discNumber': '1/1'})),
        isFalse,
      );
      // No slash → discCount empty → no match.
      expect(evaluator.matches(multiDisc, _file({'discNumber': '1'})), isFalse);
    });
  });

  group('ProfileEvaluator condition groups (OR of AND)', () {
    test('matches when any single-condition group matches', () {
      const profile = RenameProfile(
        name: 'VA / OST / Soundtrack',
        pattern: '%album/%track',
        conditionGroups: [
          [
            ProfileCondition(
              field: 'albumArtist',
              operator: ProfileOperator.equals,
              value: 'Various Artists',
            ),
          ],
          [
            ProfileCondition(
              field: 'albumArtist',
              operator: ProfileOperator.equals,
              value: 'OST',
            ),
          ],
          [
            ProfileCondition(
              field: 'albumArtist',
              operator: ProfileOperator.equals,
              value: 'Soundtrack',
            ),
          ],
        ],
      );

      expect(
        evaluator.matches(profile, _file({'albumArtist': 'Various Artists'})),
        isTrue,
      );
      expect(evaluator.matches(profile, _file({'albumArtist': 'OST'})), isTrue);
      expect(
        evaluator.matches(profile, _file({'albumArtist': 'Soundtrack'})),
        isTrue,
      );
      expect(
        evaluator.matches(profile, _file({'albumArtist': 'Some Band'})),
        isFalse,
      );
    });

    test('every condition within a group must match (AND)', () {
      const profile = RenameProfile(
        name: 'VA + Rock',
        pattern: '%title',
        conditionGroups: [
          [
            ProfileCondition(
              field: 'albumArtist',
              operator: ProfileOperator.equals,
              value: 'Various Artists',
            ),
            ProfileCondition(
              field: 'genre',
              operator: ProfileOperator.equals,
              value: 'Rock',
            ),
          ],
        ],
      );
      expect(
        evaluator.matches(
          profile,
          _file({'albumArtist': 'Various Artists', 'genre': 'Rock'}),
        ),
        isTrue,
      );
      // One of the two fails → group fails → profile fails.
      expect(
        evaluator.matches(
          profile,
          _file({'albumArtist': 'Various Artists', 'genre': 'Pop'}),
        ),
        isFalse,
      );
    });
  });

  group('ProfileEvaluator resolveField', () {
    test('resolves discCount from "current/total"', () {
      expect(
        evaluator.resolveField('discCount', _file({'discNumber': '1/3'})),
        '3',
      );
    });

    test('resolves trackCount from "current/total"', () {
      expect(
        evaluator.resolveField('trackCount', _file({'trackNumber': '5/12'})),
        '12',
      );
    });

    test('resolves a case-insensitive tag field', () {
      expect(
        evaluator.resolveField('ALBUMARTIST', _file({'albumArtist': 'X'})),
        'X',
      );
    });

    test('folderDepth returns the passed depth', () {
      expect(
        evaluator.resolveField('folderDepth', _file({}), folderDepth: 2),
        '2',
      );
    });

    test('unknown field resolves to empty', () {
      expect(evaluator.resolveField('nope', _file({})), '');
    });
  });

  group('ProfileEvaluator.firstMatch', () {
    test('returns the first matching profile in order', () {
      final profiles = [
        _singleGroup(
          name: 'VA',
          pattern: '%album/%track - %title',
          conditions: const [
            ProfileCondition(
              field: 'albumArtist',
              operator: ProfileOperator.equals,
              value: 'Various Artists',
            ),
          ],
        ),
        const RenameProfile(name: 'Standard', pattern: '%artist - %title'),
      ];

      final match = evaluator.firstMatch(
        profiles,
        _file({'albumArtist': 'Various Artists', 'artist': 'A', 'title': 'T'}),
      );
      expect(match?.name, 'VA');
    });

    test('falls through to a catch-all', () {
      final profiles = [
        _singleGroup(
          name: 'VA',
          pattern: '%album/%track',
          conditions: const [
            ProfileCondition(
              field: 'albumArtist',
              operator: ProfileOperator.equals,
              value: 'Various Artists',
            ),
          ],
        ),
        const RenameProfile(name: 'Standard', pattern: '%artist - %title'),
      ];
      final match = evaluator.firstMatch(profiles, _file({'artist': 'A'}));
      expect(match?.name, 'Standard');
    });

    test('returns null when nothing matches', () {
      final profiles = [
        _singleGroup(
          name: 'VA',
          pattern: '%x',
          conditions: const [
            ProfileCondition(
              field: 'albumArtist',
              operator: ProfileOperator.equals,
              value: 'Various Artists',
            ),
          ],
        ),
      ];
      expect(evaluator.firstMatch(profiles, _file({'artist': 'A'})), isNull);
    });

    test('a profile with no groups matches everything', () {
      const profiles = [RenameProfile(name: 'Catch all', pattern: '%title')];
      final match = evaluator.firstMatch(profiles, _file({}));
      expect(match?.name, 'Catch all');
    });

    test('legacy flat conditions load as a single group', () {
      final profile = RenameProfile.fromJson({
        'name': 'Legacy',
        'pattern': '%title',
        'conditions': [
          {
            'field': 'albumArtist',
            'operator': 'equals',
            'value': 'Various Artists',
          },
        ],
      });
      expect(profile.conditionGroups.length, 1);
      expect(
        evaluator.matches(profile, _file({'albumArtist': 'Various Artists'})),
        isTrue,
      );
    });
  });
}
