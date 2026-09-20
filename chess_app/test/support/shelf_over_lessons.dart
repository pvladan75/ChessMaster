import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';

/// The Library's shelf, answered from the same rows a test's fake
/// `GET /lessons` already serves.
///
/// Since 17.9.2026 the Tutorials card's „Saved tutorials" opens the Library
/// screen, which lists what it shows through `GET /library/positions` and
/// acts on a tutorial with the row `GET /lessons` returns. A dozen tests were
/// written against the dialog that read only the second; this lets each of
/// them keep its one fake and still tell one story on both reads.
///
/// **A fake of the server, at the wire.** The mapping is
/// `chess_backend/services/positionLibrary.js`'s — a row with parts is a
/// tutorial, one without is a saved position, the trainer's rows say so —
/// and the backend's own `library_kinds.test.js` holds the server to it.
PositionLibraryService shelfOver(LessonApiService lessons) =>
    PositionLibraryService(
      authToken: 'tok',
      client: MockClient((req) async {
        if (req.url.path != '/library/positions') {
          return http.Response('{"error":"Not found"}', 404);
        }
        final rows = await lessons.fetchAll();
        if (lessons.lastFetchFailed) {
          return http.Response('{"error":"Server error"}', 500);
        }
        return http.Response(
          jsonEncode({
            'items': [
              for (final raw in rows)
                if (raw is Map) _item(Map<String, dynamic>.from(raw)),
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

Map<String, dynamic> _item(Map<String, dynamic> row) {
  final parts = row['position_list'];
  final isTutorial = parts is List;
  return {
    'kind': isTutorial ? 'tutorial' : 'position',
    'id': '${row['id']}',
    'title': row['title'] ?? 'Untitled',
    'fen': row['fen'] ?? '',
    if (isTutorial) 'partsCount': parts.length,
    'hasVideo': row['has_video'] == true,
    'rendering': row['render_job_id'] != null,
    'fromTrainer': row['is_trainer_lesson'] == true,
    'themes': row['tags'] ?? const [],
    'assignable': false,
  };
}

/// One card of the Library's list, whatever it holds: its tile and the line
/// of actions under it. The dialog these tests were written against kept its
/// actions inside the `ListTile`; since phase 3b of `docs/PLAN-LISTE.md` a row
/// is a `Card` in an `AdaptiveCardGrid` and the actions are under the tile at
/// every width, so the key is what finds one and nothing else is.
final Finder libraryRow = find.byWidgetPredicate((w) =>
    w is KeyedSubtree &&
    w.key is ValueKey<String> &&
    (w.key! as ValueKey<String>).value.startsWith('library-row-'));
