# Test Fixtures

Minimal audio files for testing the TagLib FFI integration.

## Required Files

| File | Format | Purpose |
|------|--------|---------|
| `test.mp3` | MPEG Audio | MP3 with ID3v2 tags |
| `test.flac` | FLAC | FLAC with Vorbis Comment |
| `test.ogg` | Ogg Vorbis | OGG with Vorbis Comment |
| `test.m4a` | MPEG-4 Audio | M4A with iTunes atoms |
| `test.mp4` | MPEG-4 | MP4 with audio track |
| `test.wma` | Windows Media | WMA with ASF metadata |
| `test.wav` | Waveform Audio | WAV with ID3v2 or INFO chunk |
| `test.ape` | Monkey's Audio | APE with APE tags |
| `test.opus` | Opus | Opus with Vorbis Comment |
| `test.aac` | AAC | AAC with ID3v2 tags |
| `no_tags.mp3` | MPEG Audio | Valid MP3 with no metadata |
| `corrupt.bin` | N/A | Random bytes for corruption testing |

## Generating Fixtures

Use FFmpeg to create minimal test files (1 second of silence):

```bash
# MP3
ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -metadata title="Test" -metadata artist="Artist" test.mp3

# FLAC
ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -metadata title="Test" -metadata artist="Artist" test.flac

# OGG
ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -metadata title="Test" -metadata artist="Artist" test.ogg

# M4A
ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -metadata title="Test" -metadata artist="Artist" test.m4a

# MP4
ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -metadata title="Test" -metadata artist="Artist" test.mp4

# WAV
ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 1 test.wav

# Opus
ffmpeg -f lavfi -i anullsrc=r=48000:cl=mono -t 1 -metadata title="Test" -metadata artist="Artist" test.opus

# AAC
ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -metadata title="Test" -metadata artist="Artist" -c:a aac test.aac

# No tags MP3
ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -map_metadata -1 no_tags.mp3

# Corrupt file
dd if=/dev/urandom of=corrupt.bin bs=1024 count=4
```

Note: WMA and APE require specific encoders not always available in FFmpeg.
For WMA, use Windows Media Encoder or a tool that produces ASF files.
For APE, use Monkey's Audio encoder.

## Size Target

All files should be < 10KB for fast test execution.
