/// Third-party API keys bundled with the application.
///
/// These are application-identifying client keys, not secrets: both
/// services issue per-application client IDs designed for public
/// distribution (rate limits are keyed to them, not secrecy).
library;

/// AcoustID application client key.
///
/// Registered for Open Tag Editor at https://acoustid.org/.
/// Users may supply a personal key in Settings > Online Lookup for higher
/// rate limits; this default identifies the app itself.
const String acoustidClientKey = 'C4iBH37ugg';
