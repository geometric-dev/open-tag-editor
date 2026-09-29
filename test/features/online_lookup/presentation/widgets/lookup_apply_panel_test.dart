import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/lookup_state.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/search_result.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/track_file_match.dart';
import 'package:open_tag_editor/features/online_lookup/presentation/widgets/lookup_apply_panel.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

List<AudioFile> makeFiles(int count) => List.generate(
  count,
  (i) => AudioFile(
    path: '/file$i.mp3',
    filename: 'file$i.mp3',
    extension: '.mp3',
    fileSize: 1024,
  ),
);

List<TrackInfo> makeTracks(int count) => List.generate(
  count,
  (i) => TrackInfo(title: 'Track ${i + 1}', position: i + 1),
);

List<TrackFileMatch> makePartialMatches(
  List<AudioFile> files,
  List<TrackInfo> tracks,
) {
  return tracks.asMap().entries.map((e) {
    return TrackFileMatch(
      track: e.value,
      file: files[e.key],
      confidence: MatchConfidence.high,
      score: 0.85,
    );
  }).toList();
}

void main() {
  /// Widget tests for LookupApplyPanel in partial match mode.
  group('LookupApplyPanel partial mode', () {
    late List<AudioFile> files;
    late List<TrackInfo> tracks;
    late List<TrackFileMatch> matches;

    setUp(() {
      files = makeFiles(5);
      tracks = makeTracks(3);
      matches = makePartialMatches(files, tracks);
    });

    Widget buildWidget({Set<String> optedOutPaths = const {}}) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LookupApplyPanel(
              matches: matches,
              coverArt: null,
              status: LookupStatus.idle,
              onBack: () {},
              isPartialMatch: true,
              allSelectedFiles: files,
              optedOutPaths: optedOutPaths,
              trackListing: tracks,
            ),
          ),
        ),
      );
    }

    testWidgets('displays all files (matched + unmatched)', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        expect(find.text('file$i.mp3'), findsOneWidget);
      }
    });

    testWidgets('shows checkboxes that default to checked', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(5));

      for (final element in checkboxes.evaluate()) {
        final checkbox = element.widget as Checkbox;
        expect(checkbox.value, isTrue);
      }
    });

    testWidgets('shows confidence indicators on matched rows', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('High'), findsNWidgets(3));
    });

    testWidgets('shows "Album info only" badge on unmatched rows', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Album info only'), findsNWidgets(2));
    });

    testWidgets('unmatched rows have reduced opacity', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      final opacityWidgets = find.byType(Opacity);
      final reducedOpacity = opacityWidgets.evaluate().where((element) {
        final opacity = element.widget as Opacity;
        return opacity.opacity == 0.7;
      });

      expect(reducedOpacity.length, greaterThanOrEqualTo(2));
    });

    testWidgets('matched rows grouped before unmatched', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        final finder = find.text('file$i.mp3');
        expect(finder, findsOneWidget);
      }

      // Verify ordering by checking vertical positions
      final matchedPositions = <double>[];
      final unmatchedPositions = <double>[];

      for (var i = 0; i < 3; i++) {
        final box = tester.getRect(find.text('file$i.mp3'));
        matchedPositions.add(box.top);
      }
      for (var i = 3; i < 5; i++) {
        final box = tester.getRect(find.text('file$i.mp3'));
        unmatchedPositions.add(box.top);
      }

      // All matched rows should appear above all unmatched rows
      for (final matchedY in matchedPositions) {
        for (final unmatchedY in unmatchedPositions) {
          expect(matchedY, lessThan(unmatchedY));
        }
      }
    });

    testWidgets('summary text shows correct counts', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('3 of 5 files matched to tracks'),
        findsOneWidget,
      );
    });

    testWidgets('opt-out updates display', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildWidget(optedOutPaths: {'/file0.mp3'}));
      await tester.pumpAndSettle();

      final checkboxes = find.byType(Checkbox);
      final unchecked = checkboxes.evaluate().where((element) {
        final checkbox = element.widget as Checkbox;
        return checkbox.value == false;
      });

      expect(unchecked.length, 1);
    });

    testWidgets('shows reassign menu on matched rows', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_vert), findsNWidgets(3));
    });
  });
}
