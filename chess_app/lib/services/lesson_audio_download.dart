import 'dart:io';

import 'package:http/http.dart' as http;

/// A recording's sound, fetched through the app's own HTTP client into
/// [target] — the file the player then plays. Null when it could not be had.
///
/// Why the app fetches it rather than handing the URL to the player: on
/// Android the platform player opens an `http://` URL through the system's
/// network stack, which refuses unencrypted traffic unless the manifest allows
/// it, while the app's own requests go through Dart and are not asked. So on
/// the local backend every lesson played silent on a phone while Windows heard
/// it (the owner's live pass of 22.9.2026, read off the phone's log:
/// `NuCachedSource2: source returned error -1`, ten retries, then
/// `MEDIA_ERROR_UNKNOWN`). Fetching it here also means one source is set once,
/// so pressing Play can no longer abort a load still under way.
Future<File?> downloadLessonAudio(
    http.Client client, Uri url, File target) async {
  try {
    final res = await client.get(url);
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
    await target.writeAsBytes(res.bodyBytes, flush: true);
    return target;
  } catch (_) {
    return null;
  }
}
