// The gate of phase 7 of docs/PLAN-EKRANI.md: the recording player as the
// owner chose from `docs/skice/ekrani/compare_player.png` — the bar's
// unlabelled icons as words (rule R5, as Analysis and Preparation), the
// transcript's two actions as quiet text buttons (R4), the filler line under
// the board gone, and on a phone the open transcript showing sentences rather
// than buttons (§2.2: at 360 x 640 it showed one sentence).
//
// The host of a Preparation recording with a transcript: the one who sees
// every action. The app's own theme with real Roboto, as phase 1 taught.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/replay_player_screen.dart';
import 'package:chess_app/theme/app_theme.dart';

import 'support/landscape.dart';
import 'support/render_look.dart';

const _host = 1;
const _window = Size(1536, 792);
const _phone = Size(360, 640);

const _texts = [
  'Today we look at the most common way the Italian Game is played.',
  'White starts with pawn e4, Black answers e5.',
  'Knight f3 attacks the pawn, knight c6 defends it.',
  'Now bishop c4, aiming straight at the weak square f7.',
  'Pawn c3 prepares the big centre with d4.',
  'Black counterattacks at once with knight f6, hitting e4.',
  'The break d4 is the point of the whole plan.',
  'Check from the bishop on b4. Block with the knight.',
  'And now Black grabs the pawn on e4.',
  'That is why we call it the Moller attack.',
  'White gives a whole piece for the attack.',
  'Let us see if Black can survive it.',
];

Map<String, Object?> _row() => {
      'id': 5,
      'room_id': null,
      'source': 'preparation',
      'host_id': _host,
      'host_name': 'Marko Ilić',
      'title': 'Italian Game: the Giuoco Piano',
      'audio_url': null,
      'video_download_url': 'https://example.invalid/v.mp4',
      'duration_ms': 95000,
      'timeline_json': [
        {
          'timestampMs': 0,
          'eventType': 'init',
          'data': {
            'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          },
        },
      ],
      'created_at': '2026-09-27T12:00:00.000Z',
    };

Map<String, Object?> _transcript() => {
      'language': 'en',
      'vendor': 'groq',
      'model': 'whisper-large-v3',
      'durationMs': 95000,
      'sentences': [
        for (var i = 0; i < _texts.length; i++)
          {
            'startMs': i * 7000,
            'endMs': i * 7000 + 6000,
            'text': _texts[i],
            'heard': _texts[i],
          }
      ],
      'updatedAt': '2026-09-27T12:10:00.000Z',
    };

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: const {'content-type': 'application/json; charset=utf-8'});

final _client = MockClient((req) async {
  final path = req.url.path;
  if (path == '/recordings/5' && req.method == 'GET') return _json(_row());
  if (path == '/recordings/5/transcript' && req.method == 'GET') {
    return _json({
      'available': true,
      'languages': const ['en', 'sr-Latn'],
      'transcript': _transcript(),
    });
  }
  return _json(const []);
});

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: robotoTheme(AppTheme.dark),
    home: ReplayPlayerScreen(
      key: UniqueKey(),
      recordingId: 5,
      userSession: UserSession(
          id: _host, token: 'tok', email: 'e', name: 'N', role: 'x'),
      client: _client,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

Finder _inBar(Finder f) =>
    find.descendant(of: find.byType(AppBar), matching: f);

Finder _button<T extends Widget>(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is T),
    );

/// How many sentence rows lie wholly inside the window and inside every box
/// that scrolls them — read, not merely built.
int _sentencesSeen(WidgetTester tester, Size size) {
  var seen = 0;
  for (var i = 0; i < _texts.length; i++) {
    final f = find.byKey(Key('transcript-sentence-$i'));
    if (f.evaluate().isEmpty) continue;
    final element = f.evaluate().first;
    final box = element.renderObject! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    var inside = (Offset.zero & size).contains(rect.topLeft) &&
        (Offset.zero & size).contains(rect.bottomRight - const Offset(1, 1));
    element.visitAncestorElements((a) {
      if (a.widget is Scrollable) {
        final s = a.renderObject! as RenderBox;
        final sr = s.localToGlobal(Offset.zero) & s.size;
        if (!sr.contains(rect.topLeft) ||
            !sr.contains(rect.bottomRight - const Offset(1, 1))) {
          inside = false;
        }
      }
      return true;
    });
    if (inside) seen++;
  }
  return seen;
}

void main() {
  setUpAll(loadRoboto);

  group('on a window', () {
    testWidgets('the bar says its actions in words (R5)', (tester) async {
      await _pump(tester, _window);
      expect(tester.takeException(), isNull);
      for (final word in ['Open in Analysis', 'Share…', 'Video']) {
        expect(_inBar(find.text(word)), findsOneWidget, reason: word);
        expectOnScreen(tester, _window, _inBar(find.text(word)));
      }
      for (final tip in [
        'Export to Analysis 🔬',
        'Share with students…',
        'Download video',
        'Export to MP4 Video',
      ]) {
        expect(_inBar(find.byTooltip(tip)), findsNothing,
            reason: 'the unlabelled icon „$tip" is a word now');
      }
      await _close(tester);
    });

    testWidgets('Video opens the two things a video can be: kept and made',
        (tester) async {
      await _pump(tester, _window);
      expect(_inBar(find.text('Video')), findsOneWidget);
      await tester.tap(_inBar(find.text('Video')));
      await tester.pumpAndSettle();
      expect(find.text('Download video'), findsOneWidget);
      expect(find.textContaining('Export to MP4'), findsOneWidget);
      await _close(tester);
    });

    testWidgets(
        'the transcript\'s actions are text buttons, the filler line is '
        'gone, and the sentences have the column', (tester) async {
      await _pump(tester, _window);
      expect(_button<TextButton>('Make a tutorial'), findsOneWidget);
      expect(_button<TextButton>('Transcribe again…'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is ElevatedButton), findsNothing,
          reason: 'no slab (R4)');
      expect(
          find.text('Synchronized playback of moves and arrows'), findsNothing);
      // Six were seen before; the two buttons under the list took the rest.
      expect(_sentencesSeen(tester, _window), greaterThanOrEqualTo(7));
      await _close(tester);
    });
  });

  group('on a phone', () {
    testWidgets('the bar\'s actions are behind ⋮, not crowding the title',
        (tester) async {
      await _pump(tester, _phone);
      expect(tester.takeException(), isNull);
      expect(_inBar(find.text('Open in Analysis')), findsNothing);
      expect(_inBar(find.byIcon(Icons.more_vert)), findsOneWidget);
      await tester.tap(_inBar(find.byIcon(Icons.more_vert)));
      await tester.pumpAndSettle();
      expect(find.text('Open in Analysis'), findsOneWidget);
      expect(find.text('Share…'), findsOneWidget);
      expect(find.text('Download video'), findsOneWidget);
      await _close(tester);
    });

    testWidgets(
        'the open transcript shows sentences, its two actions behind ⋮ '
        '(§2.2: one sentence was seen)', (tester) async {
      await _pump(tester, _phone);
      await tester.tap(find.byKey(const Key('replay-transcript-open')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_sentencesSeen(tester, _phone), greaterThanOrEqualTo(4));
      expect(find.text('Make a tutorial').hitTestable(), findsNothing,
          reason: 'not a row of its own over the sentences');
      final actions = find.byKey(const Key('transcript-actions'));
      expect(actions, findsOneWidget);
      await tester.tap(actions);
      await tester.pumpAndSettle();
      expect(find.text('Make a tutorial'), findsOneWidget);
      expect(find.text('Transcribe again…'), findsOneWidget);
      await _close(tester);
    });
  });
}
