/// Google sign-in for the platforms `google_sign_in` does not cover.
///
/// The plugin supports Android, iOS, macOS and the web. Windows and Linux get
/// nothing at all — `supportsAuthenticate()` answers false and the button was a
/// dead end, which is what was reported on 27.8.2026. The implementation
/// behind this export does the same thing by hand: the system browser, a
/// loopback redirect, and PKCE.
///
/// Conditional export rather than a platform check inside one file: the real
/// implementation needs `dart:io`, and importing that unconditionally breaks
/// the web build. Same shape as `stockfish_service.dart` next door.
library;

export 'desktop_google_sign_in_stub.dart'
    if (dart.library.io) 'desktop_google_sign_in_io.dart';
