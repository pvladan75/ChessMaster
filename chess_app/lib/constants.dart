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

const String googleWebClientId =
    '425483567970-jgkipp2dfqmc40kvacn2aginpjnph28s.apps.googleusercontent.com';
const int kDefaultEngineTargetDepth = 18;
