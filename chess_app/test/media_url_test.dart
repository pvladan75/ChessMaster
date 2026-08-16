// Pins how a stored media reference becomes something fetchable.
//
// The server used to write `http://<whatever host answered>/uploads/x.aac` into
// the database, so every recording made at home points at a LAN address and
// would have died the moment the backend moved. Paths are stored now, but the
// old rows are still there and must keep working — which is the case a
// prefixing bug would silently mangle into `http://server/http://192.168...`.

import 'package:chess_app/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a stored path is joined with the backend', () {
    expect(resolveMediaUrl('/uploads/audio_1.aac'),
        '$backendUrl/uploads/audio_1.aac');
  });

  test('a path without a leading slash still joins cleanly', () {
    expect(resolveMediaUrl('uploads/audio_1.aac'),
        '$backendUrl/uploads/audio_1.aac');
  });

  test('an absolute URL from an old row is left alone', () {
    const old = 'http://192.168.0.19:3000/uploads/audio_1.aac';
    expect(resolveMediaUrl(old), old);
  });

  test('https is left alone too', () {
    const url = 'https://api.example.app/uploads/audio_1.aac';
    expect(resolveMediaUrl(url), url);
  });

  test('a query string survives the join', () {
    // The MP4 download carries a signed token; losing it would turn every
    // export link into a 401 that looks like the file is missing.
    expect(
      resolveMediaUrl('/recordings/export-download/x.mp4?token=abc'),
      '$backendUrl/recordings/export-download/x.mp4?token=abc',
    );
  });

  test('an empty reference stays empty rather than becoming the backend root',
      () {
    expect(resolveMediaUrl(''), '');
    expect(resolveMediaUrl('   '), '');
  });
}
