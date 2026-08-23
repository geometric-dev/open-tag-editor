import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_tag_editor/features/online_lookup/data/models/search_result.dart';
import 'package:open_tag_editor/features/online_lookup/presentation/widgets/lookup_match_panel.dart';
import 'package:open_tag_editor/shared/models/audio_file.dart';

List<TrackInfo> makeTracks(int count) => List.generate(
      count,
      (i) => TrackInfo(title: 'Track ${i + 1}', position: i + 1),
    );

List<AudioFile> makeFiles(int count) => List.generate(
      count,
      (i) => AudioFile(
        path: '/file$i.mp3',
        filename: 'file$i.mp3',
        extension: '.mp3',
        fileSize: 1024,
      ),
    );

void main() {
  group('LookupMatchPanel partial match trigger', () {
    testWidgets(
      '"Apply as Partial Match" button appears when trackCount < fileCount',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LookupMatchPanel(
                trackListing: makeTracks(5),
                coverArt: null,
                coverArtLoading: false,
                selectedFiles: makeFiles(8),
                onMatch: () {},
                onBack: () {},
                onPartialMatch: () {},
              ),
            ),
          ),
        );

        expect(find.text('Apply as Partial Match'), findsOneWidget);
      },
    );

    testWidgets(
      '"Apply as Partial Match" button does NOT appear when trackCount == fileCount',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LookupMatchPanel(
                trackListing: makeTracks(5),
                coverArt: null,
                coverArtLoading: false,
                selectedFiles: makeFiles(5),
                onMatch: () {},
                onBack: () {},
                onPartialMatch: () {},
              ),
            ),
          ),
        );

        expect(find.text('Apply as Partial Match'), findsNothing);
      },
    );

    testWidgets(
      '"Apply as Partial Match" button does NOT appear when trackCount > fileCount',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LookupMatchPanel(
                trackListing: makeTracks(5),
                coverArt: null,
                coverArtLoading: false,
                selectedFiles: makeFiles(3),
                onMatch: () {},
                onBack: () {},
                onPartialMatch: () {},
              ),
            ),
          ),
        );

        expect(find.text('Apply as Partial Match'), findsNothing);
      },
    );
  });
}
