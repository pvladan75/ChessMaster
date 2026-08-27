const String backendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://192.168.0.19:3000',
);

/// Turns a stored media reference into something that can be fetched.
///
/// The server now stores paths (`/uploads/x.aac`) rather than whole URLs, so a
/// recording keeps working when the backend moves, the domain changes, or the
/// scheme becomes HTTPS. Rows written before that carry an absolute URL — most
/// of them pointing at a LAN address — and are passed through unchanged rather
/// than mangled by prefixing: they still resolve while the backend is that same
/// machine, and they die with the recordings they belong to.
String resolveMediaUrl(String pathOrUrl) {
  final value = pathOrUrl.trim();
  if (value.isEmpty) return value;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  final base = backendUrl.endsWith('/')
      ? backendUrl.substring(0, backendUrl.length - 1)
      : backendUrl;
  return value.startsWith('/') ? '$base$value' : '$base/$value';
}

/// The OAuth client for the desktop sign-in flow (Windows, Linux).
///
/// From `--dart-define`, never from this file: the repository is public, and a
/// desktop client ships with a `client_secret` that is not confidential but is
/// still nobody's business to read here. An empty value means this build has
/// no desktop sign-in, and the button is hidden rather than offered.
///
///     flutter build windows ///       --dart-define=GOOGLE_DESKTOP_CLIENT_ID=... ///       --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...
///
/// The same client id must be in the server's `GOOGLE_CLIENT_IDS`, which is a
/// comma-separated list precisely so the phone and the desktop can each have
/// their own.
const String googleDesktopClientId =
    String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
const String googleDesktopClientSecret =
    String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');

const String googleWebClientId =
    '425483567970-jgkipp2dfqmc40kvacn2aginpjnph28s.apps.googleusercontent.com';
const int kDefaultEngineTargetDepth = 18;
