import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:open_tag_editor/features/album_art/data/cover_art_resize_service.dart';

Uint8List pngBytes(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(200, 100, 50));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('CoverArtResizeService.transformBytes', () {
    test('downscales a PNG to the bounding box', () {
      final out = CoverArtResizeService.transformBytes(
        pngBytes(800, 600),
        const CoverArtResizeOptions(maxDimension: 300),
      );

      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 300);
      expect(decoded.height, 225); // aspect preserved
    });

    test('never upscales smaller images', () {
      final original = pngBytes(100, 80);
      final out = CoverArtResizeService.transformBytes(
        original,
        const CoverArtResizeOptions(maxDimension: 500),
      );

      // No resize needed; output decodes to same dimensions.
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 100);
      expect(decoded.height, 80);
    });

    test('keep-format re-encodes PNG as PNG', () {
      final out = CoverArtResizeService.transformBytes(
        pngBytes(400, 400),
        const CoverArtResizeOptions(maxDimension: 200),
      );
      // PNG magic bytes.
      expect(out.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('jpeg format conversion emits JPEG magic', () {
      final out = CoverArtResizeService.transformBytes(
        pngBytes(400, 400),
        const CoverArtResizeOptions(
          maxDimension: 200,
          format: CoverArtFormat.jpeg,
          jpegQuality: 85,
        ),
      );

      // JPEG magic (SOI + APP0 marker).
      expect(out.sublist(0, 2), [0xFF, 0xD8]);
    });
  });

  group('AudioFile skip semantics', () {
    test('garbage bytes fail decoding with a clear exception', () {
      // The image package throws RangeError on truncated data; either way
      // it throws, and CoverArtResizeService captures per-file failures.
      expect(
        () => CoverArtResizeService.transformBytes(
          Uint8List.fromList([1, 2, 3]),
          const CoverArtResizeOptions(maxDimension: 100),
        ),
        throwsA(anything),
      );
    });
  });
}
