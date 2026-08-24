/// Audio file formats supported by Open Tag Editor.
class SupportedFormats {
  SupportedFormats._();

  static const mp3 = '.mp3';
  static const flac = '.flac';
  static const ogg = '.ogg';
  static const m4a = '.m4a';
  static const mp4 = '.mp4';
  static const m4b = '.m4b';
  static const m4r = '.m4r';
  static const m4v = '.m4v';
  static const wma = '.wma';
  static const wav = '.wav';
  static const aiff = '.aiff';
  static const aif = '.aif';
  static const ape = '.ape';
  static const mpc = '.mpc';
  static const wv = '.wv';
  static const tta = '.tta';
  static const ofr = '.ofr';
  static const opus = '.opus';
  static const spx = '.spx';
  static const dsf = '.dsf';
  static const aac = '.aac';

  static const all = [
    mp3,
    flac,
    ogg,
    m4a,
    mp4,
    m4b,
    m4r,
    m4v,
    wma,
    wav,
    aiff,
    aif,
    ape,
    mpc,
    wv,
    tta,
    ofr,
    opus,
    spx,
    dsf,
    aac,
  ];

  /// Returns true if the given file extension is a supported audio format.
  static bool isSupported(String extension) {
    return all.contains(extension.toLowerCase());
  }
}
