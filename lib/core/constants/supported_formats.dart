/// Audio file formats supported by Open Tag Editor.
class SupportedFormats {
  SupportedFormats._();

  static const mp3 = '.mp3';
  static const flac = '.flac';
  static const ogg = '.ogg';
  static const m4a = '.m4a';
  static const mp4 = '.mp4';
  static const wma = '.wma';
  static const wav = '.wav';
  static const ape = '.ape';
  static const opus = '.opus';
  static const aac = '.aac';

  static const all = [
    mp3,
    flac,
    ogg,
    m4a,
    mp4,
    wma,
    wav,
    ape,
    opus,
    aac,
  ];

  /// Returns true if the given file extension is a supported audio format.
  static bool isSupported(String extension) {
    return all.contains(extension.toLowerCase());
  }
}
