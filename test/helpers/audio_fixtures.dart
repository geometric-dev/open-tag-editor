import 'dart:io';
import 'dart:typed_data';

/// Shared synthetic audio fixtures for tests that need real files.
///
/// These are hand-built minimal containers: valid enough for tag parsing
/// and structural integrity checks, tiny enough to build instantly.

/// Creates a bare-bones MPEG audio stream so that tag writers have a valid
/// audio file to work with. The frames are MPEG1 Layer 3, 128kbps,
/// 44100Hz, stereo filled with zeros (silence).
Uint8List generateMinimalMp3() {
  // MPEG1 Layer 3, 128kbps, 44100Hz, stereo frame header: 0xFFFB9004
  // Frame size = 144 * 128000 / 44100 + 0 = 417 bytes
  const frameSize = 417;
  final frame = Uint8List(frameSize);
  frame[0] = 0xFF;
  frame[1] = 0xFB; // MPEG1, Layer 3, no CRC
  frame[2] = 0x90; // 128kbps, 44100Hz
  frame[3] = 0x04; // Stereo, no padding

  // Repeat a few frames to make it more realistic
  final output = BytesBuilder();
  for (var i = 0; i < 5; i++) {
    output.add(frame);
  }
  return Uint8List.fromList(output.toBytes());
}

/// Generates a minimal valid FLAC file with an empty STREAMINFO block.
Uint8List generateMinimalFlac() {
  final output = BytesBuilder();

  // fLaC marker
  output.add([0x66, 0x4C, 0x61, 0x43]);

  // STREAMINFO block (type=0, is_last=true, size=34)
  output.addByte(0x80); // last-metadata-block flag + type 0
  output.add([0x00, 0x00, 0x22]); // size = 34 bytes

  // STREAMINFO data (34 bytes)
  // min block size (2), max block size (2), min frame size (3),
  // max frame size (3), sample rate/channels/bps/samples (8),
  // MD5 (16)
  final streamInfo = Uint8List(34);
  // min/max block size = 4096
  streamInfo[0] = 0x10;
  streamInfo[1] = 0x00;
  streamInfo[2] = 0x10;
  streamInfo[3] = 0x00;
  // sample rate 44100 = 0xAC44, channels=2 (stored as 1), bps=16 (stored as 15)
  // Byte 10: top 4 bits of sample rate
  streamInfo[10] = 0x0A; // 44100 >> 12
  streamInfo[11] = 0xC4; // (44100 >> 4) & 0xFF
  // Byte 12: bottom 4 bits of sample rate + channels (1=stereo) + top bit of bps
  streamInfo[12] = 0x42; // (44100 & 0xF)<<4 | (1<<1) | (15>>4)
  // Byte 13: bottom 4 bits of bps + top 4 bits of total samples
  streamInfo[13] = 0xF0;
  output.add(streamInfo);

  return Uint8List.fromList(output.toBytes());
}
