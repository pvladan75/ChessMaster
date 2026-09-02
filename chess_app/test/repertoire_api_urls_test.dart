import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every request this service makes must name the host.
///
/// A batch added four endpoints written as `Uri.parse('/repertoire/...')` with
/// no `$backendUrl` in front of them. All four would have failed on the first
/// tap on a real device, and every test stayed green the whole time — the
/// repertoire tests drive the service through `MockClient`, which answers
/// whatever it is handed and never looks at the URL. There is no widget test
/// that can see this, which is why it is read out of the source instead.
///
/// Read by matching the quoted string that starts the call, not by slicing a
/// fixed window: a guard that reads a fixed number of characters runs into the
/// next call and matches something it was not looking at, which is how an
/// earlier source-reading test in this project passed over the defect it was
/// written for.
void main() {
  test('every repertoire URL is absolute', () {
    final src = File(
      'lib/features/repertoire/services/repertoire_api_service.dart',
    ).readAsStringSync();

    // The first argument of _get/_post/_put/_delete/Uri.parse, whenever it is
    // a string literal that mentions a route.
    final calls = RegExp(
      r"""(?:Uri\.parse|_get|_post|_put|_delete)\(\s*(?:Uri\.parse\(\s*)?'([^']*)'""",
    );

    final relative = <String>[];
    for (final m in calls.allMatches(src)) {
      final url = m.group(1)!;
      if (!url.contains('/repertoire')) continue;
      if (url.startsWith(r'$backendUrl')) continue;
      relative.add(url);
    }

    expect(
      relative,
      isEmpty,
      reason: 'these would be requested against no host, and MockClient '
          'would not notice: $relative',
    );
  });
}
