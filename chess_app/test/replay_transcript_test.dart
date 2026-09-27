// The transcript on a recording's player — phase 7 of docs/PLAN-PRIPREMA.md,
// the app's half. The server's half is chess_backend/routes/recordingTranscript.js
// and its gate chess_backend/test/recording_transcript.test.js.
//
// The contract this gate holds, and nothing else of the implementation:
//
//   lib/models/recording_transcript.dart
//     RecordingTranscript.fromJson — language, vendor, model, durationMs,
//       sentences
//     TranscriptSentence — startMs, endMs, text, heard; `corrected` is
//       text != heard
//     sentenceAt(sentences, ms) — the index of the last sentence that has
//       started at [ms], or null before the first
//
//   Keys on the player (ReplayPlayerScreen):
//     replay-transcript-panel     the sentences and their button
//     replay-transcript-open      below 840 wide and upright only: opens the
//                                 panel in a sheet; absent elsewhere
//     transcript-transcribe       „Transcribe…", or „Transcribe again…"
//     transcript-language-<code>  one per language the server offers
//     transcript-start            the dialog's „Transcribe"
//     transcript-replace-confirm  „Replace" before hearing a recording again
//     transcript-replace-cancel
//     transcript-sentence-<i>     a sentence; a tap moves the player to it
//     transcript-current          inside the sentence being said, only there
//     transcript-edit-<i>         opens the sentence's text for correction
//     transcript-field-<i>        the text being corrected
//     transcript-save-<i>, transcript-cancel-<i>
//     transcript-heard-<i>        „Heard: …", under a corrected sentence only
//     transcript-sentence-list    the scrolling list of sentences
//
//   Words the gate reads: „No transcript yet.", „Transcribe…",
//   „Transcribe again…", „Transcribing…"; the language dialog names Groq
//   (D9: the trainer is told the sound leaves the app); the dialog before
//   hearing again says it „replaces" the transcript and its corrections. A
//   sentence's time reads `m:ss` („0:12"), so it is never the player's
//   `mm:ss` clock. The field is a TextField. Upright below 840, the sheet is
//   at most 60% of the screen tall, so the board stays in sight.
//
//   lib/screens/usage_screen.dart
//     countedRows — every `stt_<provider>_seconds` is one row, „Recordings
//     transcribed", in minutes rounded up.
//
// Who is asked: the transcript is the host's, on a recording made in
// Preparation (the server says so too). Nobody else's player asks for it.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/models/recording_transcript.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/replay_player_screen.dart';
import 'package:chess_app/screens/usage_screen.dart';
import 'package:chess_app/services/usage_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';

const _host = 1;
const _student = 3;

Map<String, Object?> _row({String source = 'preparation'}) => {
      'id': 5,
      'room_id': null,
      'source': source,
      'host_id': _host,
      'host_name': 'Vladan',
      'title': 'Italijanska',
      'audio_url': null,
      'video_download_url': null,
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

/// The measured shape: sentence 2 starts before sentence 1 has ended.
List<Map<String, Object?>> _sentences() => [
      {
        'startMs': 480,
        'endMs': 6300,
        'text': 'Ovo ćemo sada da vidimo kako izgleda najčešća italijanska '
            'partija posle uvodnih poteza, i koji su planovi za obe strane.',
        'heard': 'Ovo ćemo sada da vidimo kako izgleda najčešća italijanska '
            'partija posle uvodnih poteza, i koji su planovi za obe strane.',
      },
      {
        'startMs': 12000,
        'endMs': 15740,
        'text': 'Ona počinje potezom lovac c4.',
        'heard': 'Ona počinje potezom lovac c4.',
      },
      {
        'startMs': 15500,
        'endMs': 21780,
        'text': 'Najčešći odgovor crnog je lovac c5.',
        'heard': 'Najčešći odgovor crnog je lovac c5.',
      },
      {
        'startMs': 50280,
        'endMs': 52120,
        'text': 'Dakle, lovat c5.',
        'heard': 'Dakle, lovat c5.',
      },
    ];

Map<String, Object?> _transcript({List<Map<String, Object?>>? sentences}) => {
      'language': 'sr-Latn',
      'vendor': 'groq',
      'model': 'whisper-large-v3',
      'durationMs': 95000,
      'sentences': sentences ?? _sentences(),
      'updatedAt': '2026-09-27T12:10:00.000Z',
    };

const _languages = ['en', 'sr-Latn', 'de', 'es', 'it', 'fr'];

/// A canned answer as Express sends one: JSON **in utf-8**. `package:http`
/// encodes a string body as latin1 unless a charset is named, and the
/// fixtures' Serbian letters (ć, č, š) are not latin1 — the gate's first
/// draft threw inside its own fake (found by the implementer, 27.9.2026).
http.Response _json(String body, int status) => http.Response(
      body,
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

class _Server {
  _Server({
    Map<String, Object?>? row,
    this.available = true,
    this.transcript,
    this.transcriptStatus = 200,
  }) : row = row ?? _row();

  final Map<String, Object?> row;
  final bool available;
  final int transcriptStatus;
  Map<String, Object?>? transcript;

  final gets = <http.Request>[];
  final posts = <http.Request>[];
  final puts = <http.Request>[];

  /// When set, the next POST waits for it; the test answers.
  Completer<http.Response>? holdPost;

  /// When set, POST and PUT answer this instead.
  http.Response? failWith;

  late final client = MockClient((req) async {
    final path = req.url.path;
    if (path == '/recordings/5' && req.method == 'GET') {
      return _json(jsonEncode(row), 200);
    }
    if (path == '/recordings/5/transcript') {
      if (req.method == 'GET') {
        gets.add(req);
        if (transcriptStatus != 200) {
          return _json('{"error":"no"}', transcriptStatus);
        }
        return _json(
          jsonEncode({
            'available': available,
            'languages': available ? _languages : const [],
            'transcript': transcript,
          }),
          200,
        );
      }
      if (req.method == 'POST') {
        posts.add(req);
        final hold = holdPost;
        if (hold != null) return hold.future;
        if (failWith != null) return failWith!;
        transcript = _transcript();
        return _json(jsonEncode({'transcript': transcript}), 201);
      }
      if (req.method == 'PUT') {
        puts.add(req);
        if (failWith != null) return failWith!;
        final texts = (jsonDecode(req.body)['texts'] as List).cast<String>();
        final sentences = [
          for (var i = 0; i < texts.length; i++)
            {
              ...(transcript!['sentences'] as List)[i] as Map<String, Object?>,
              'text': texts[i],
            },
        ];
        transcript = _transcript(sentences: sentences);
        return _json(jsonEncode({'transcript': transcript}), 200);
      }
    }
    return _json('[]', 200);
  });
}

Future<void> _player(
  WidgetTester tester,
  _Server server, {
  int me = _host,
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData().copyWith(extensions: const [AppColorTokens.light]),
      home: ReplayPlayerScreen(
        key: UniqueKey(),
        recordingId: 5,
        userSession: UserSession(
          id: me,
          token: 'tok',
          email: 'e',
          name: 'N',
          role: 'x',
        ),
        client: server.client,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

final _panel = find.byKey(const Key('replay-transcript-panel'));
final _transcribe = find.byKey(const Key('transcript-transcribe'));
final _current = find.byKey(const Key('transcript-current'));
Finder _sentence(int i) => find.byKey(Key('transcript-sentence-$i'));

/// The clock under the board, which reads `mm:ss` of where the player is.
Finder _clock(String mmss) => find.text(mmss);

void main() {
  group('the model', () {
    test('reads the wire and says which sentence has started', () {
      final t = RecordingTranscript.fromJson(_transcript());
      expect(t.language, 'sr-Latn');
      expect(t.vendor, 'groq');
      expect(t.model, 'whisper-large-v3');
      expect(t.durationMs, 95000);
      expect(t.sentences, hasLength(4));
      expect(t.sentences[1].startMs, 12000);
      expect(t.sentences[1].endMs, 15740);
      expect(t.sentences[0].corrected, isFalse);

      final corrected = TranscriptSentence.fromJson(const {
        'startMs': 0,
        'endMs': 10,
        'text': 'lovac',
        'heard': 'lovat',
      });
      expect(corrected.corrected, isTrue);

      final s = t.sentences;
      expect(sentenceAt(s, 0), isNull, reason: 'before the first sentence');
      expect(sentenceAt(s, 479), isNull);
      expect(sentenceAt(s, 480), 0, reason: 'on its first millisecond');
      expect(
        sentenceAt(s, 11999),
        0,
        reason: 'the last one said, through a pause',
      );
      expect(sentenceAt(s, 12000), 1);
      expect(sentenceAt(s, 15499), 1);
      expect(
        sentenceAt(s, 15500),
        2,
        reason:
            'the later sentence once it starts, though the earlier has not ended',
      );
      expect(sentenceAt(s, 94000), 3);
      expect(sentenceAt(const [], 1000), isNull);
    });
  });

  group('who is asked', () {
    testWidgets(
      'the host of a Preparation recording is offered „Transcribe…"',
      (tester) async {
        final server = _Server();
        await _player(tester, server);
        expect(server.gets, hasLength(1));
        expect(_panel, findsOneWidget);
        expect(find.text('No transcript yet.'), findsOneWidget);
        expect(
          find.descendant(of: _panel, matching: _transcribe),
          findsOneWidget,
        );
        expect(find.text('Transcribe…'), findsOneWidget);
        await _close(tester);
      },
    );

    testWidgets('a student it is shared with is never asked for it', (
      tester,
    ) async {
      final server = _Server(transcript: _transcript());
      await _player(tester, server, me: _student);
      expect(server.gets, isEmpty);
      expect(_panel, findsNothing);
      await _close(tester);
    });

    testWidgets('a room recording is never asked for it', (tester) async {
      final server = _Server(row: _row(source: 'room'));
      await _player(tester, server);
      expect(server.gets, isEmpty);
      expect(_panel, findsNothing);
      await _close(tester);
    });

    testWidgets('a server that cannot say leaves the player as it was', (
      tester,
    ) async {
      final server = _Server(transcriptStatus: 500);
      await _player(tester, server);
      expect(server.gets, hasLength(1));
      expect(_panel, findsNothing);
      expect(find.byType(SkinnedChessBoard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _close(tester);
    });

    testWidgets('no provider and nothing heard: nothing is drawn', (
      tester,
    ) async {
      final server = _Server(available: false);
      await _player(tester, server);
      expect(_panel, findsNothing);
      await _close(tester);
    });

    testWidgets(
        'no provider, but heard before: the sentences stay, the button '
        'goes', (tester) async {
      final server = _Server(available: false, transcript: _transcript());
      await _player(tester, server);
      expect(_panel, findsOneWidget);
      expect(_sentence(3), findsOneWidget);
      expect(_transcribe, findsNothing);
      await _close(tester);
    });
  });

  group('transcribing', () {
    testWidgets(
        'the dialog offers the server\'s languages by name, Serbian '
        '(Latin) first chosen, and says where the sound goes', (tester) async {
      final server = _Server();
      await _player(tester, server);
      await tester.tap(_transcribe);
      await _settle(tester);

      for (final code in _languages) {
        expect(
          find.byKey(Key('transcript-language-$code')),
          findsOneWidget,
          reason: code,
        );
      }
      expect(
        find.byKey(const Key('transcript-language-sr-Cyrl')),
        findsNothing,
      );
      expect(find.text('Serbian (Latin)'), findsOneWidget);
      expect(find.text('German'), findsOneWidget);
      expect(
        find.textContaining('Groq'),
        findsWidgets,
        reason: 'the trainer is told the sound leaves the app (D9)',
      );

      await tester.tap(find.byKey(const Key('transcript-start')));
      await _settle(tester);
      expect(server.posts, hasLength(1));
      expect(jsonDecode(server.posts.single.body), {'language': 'sr-Latn'});
      await _close(tester);
    });

    testWidgets('the language chosen is the one sent', (tester) async {
      final server = _Server();
      await _player(tester, server);
      await tester.tap(_transcribe);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('transcript-language-de')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('transcript-start')));
      await _settle(tester);
      expect(jsonDecode(server.posts.single.body), {'language': 'de'});
      await _close(tester);
    });

    testWidgets(
        'while it is heard the button says so and a second tap sends '
        'nothing; then the sentences are drawn', (tester) async {
      final server = _Server()..holdPost = Completer<http.Response>();
      await _player(tester, server);
      await tester.tap(_transcribe);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('transcript-start')));
      await _settle(tester);

      expect(find.text('Transcribing…'), findsOneWidget);
      await tester.tap(find.text('Transcribing…'), warnIfMissed: false);
      await _settle(tester);
      expect(
        find.byKey(const Key('transcript-start')),
        findsNothing,
        reason: 'no second dialog',
      );
      expect(server.posts, hasLength(1));

      server.transcript = _transcript();
      server.holdPost!.complete(
        _json(jsonEncode({'transcript': server.transcript}), 201),
      );
      server.holdPost = null;
      await _settle(tester);

      expect(find.text('Transcribing…'), findsNothing);
      for (var i = 0; i < 4; i++) {
        expect(_sentence(i), findsOneWidget, reason: 'sentence $i');
      }
      expect(find.text('Ona počinje potezom lovac c4.'), findsOneWidget);
      expect(find.text('Transcribe again…'), findsOneWidget);
      await _close(tester);
    });

    testWidgets(
        'a vendor that fails is the server\'s sentence, and the panel '
        'is as it was', (tester) async {
      final server = _Server()
        ..failWith = _json(
          jsonEncode({
            'error': 'The speech service is busy. Try again in a minute.',
            'reason': 'busy',
          }),
          503,
        );
      await _player(tester, server);
      await tester.tap(_transcribe);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('transcript-start')));
      await _settle(tester);

      expect(
        find.text('The speech service is busy. Try again in a minute.'),
        findsOneWidget,
      );
      expect(find.text('No transcript yet.'), findsOneWidget);
      expect(find.text('Transcribe…'), findsOneWidget);
      expect(find.text('Transcribing…'), findsNothing);
      await _close(tester);
    });

    testWidgets('hearing it again asks first, and a no sends nothing', (
      tester,
    ) async {
      final server = _Server(transcript: _transcript());
      await _player(tester, server);
      expect(find.text('Transcribe again…'), findsOneWidget);

      await tester.tap(_transcribe);
      await _settle(tester);
      expect(find.textContaining('replaces'), findsOneWidget);
      await tester.tap(find.byKey(const Key('transcript-replace-cancel')));
      await _settle(tester);
      expect(find.byKey(const Key('transcript-start')), findsNothing);
      expect(server.posts, isEmpty);

      await tester.tap(_transcribe);
      await _settle(tester);
      await tester.tap(find.byKey(const Key('transcript-replace-confirm')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('transcript-start')));
      await _settle(tester);
      expect(server.posts, hasLength(1));
      await _close(tester);
    });
  });

  group('reading along', () {
    testWidgets('a tap on a sentence moves the player to it and marks it', (
      tester,
    ) async {
      final server = _Server(transcript: _transcript());
      await _player(tester, server);
      expect(_current, findsNothing, reason: 'nothing said at 00:00');

      await tester.tap(_sentence(1));
      await _settle(tester);
      expect(_clock('00:12'), findsOneWidget);
      expect(
        find.descendant(of: _sentence(1), matching: _current),
        findsOneWidget,
      );
      expect(_current, findsOneWidget, reason: 'one sentence at a time');

      await tester.tap(_sentence(3));
      await _settle(tester);
      expect(_clock('00:50'), findsOneWidget);
      expect(
        find.descendant(of: _sentence(3), matching: _current),
        findsOneWidget,
      );
      await _close(tester);
    });

    testWidgets('while it plays the mark follows the voice', (tester) async {
      final server = _Server(transcript: _transcript());
      await _player(tester, server);
      await tester.tap(_sentence(1));
      await _settle(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(
        find.descendant(of: _sentence(2), matching: _current),
        findsOneWidget,
        reason: '12 s + 4 s of playing is past sentence 2\'s start at 15.5',
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await _close(tester);
    });

    testWidgets('a long sentence is read whole, not cut to a line', (
      tester,
    ) async {
      final server = _Server(transcript: _transcript());
      await _player(tester, server);
      final text = find.descendant(
        of: _sentence(0),
        matching: find.textContaining('obe strane.'),
      );
      expect(text, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(paragraph.didExceedMaxLines, isFalse);
      await _close(tester);
    });
  });

  group('correcting', () {
    testWidgets(
        'a correction sends every text, no time, and shows what was '
        'heard', (tester) async {
      final server = _Server(transcript: _transcript());
      await _player(tester, server);
      expect(find.byKey(const Key('transcript-heard-3')), findsNothing);

      await tester.tap(find.byKey(const Key('transcript-edit-3')));
      await _settle(tester);
      await tester.enterText(
        find.byKey(const Key('transcript-field-3')),
        'Dakle, lovac c5.',
      );
      await tester.tap(find.byKey(const Key('transcript-save-3')));
      await _settle(tester);

      expect(server.puts, hasLength(1));
      final body = jsonDecode(server.puts.single.body) as Map<String, dynamic>;
      expect(body.keys, ['texts'], reason: 'a correction carries no time');
      expect(body['texts'], [
        for (final s in _sentences().take(3)) s['text'],
        'Dakle, lovac c5.',
      ]);
      expect(find.byKey(const Key('transcript-field-3')), findsNothing);
      expect(
        find.descendant(
          of: _sentence(3),
          matching: find.text('Dakle, lovac c5.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('transcript-heard-3')),
          matching: find.textContaining('lovat c5'),
        ),
        findsOneWidget,
      );
      await _close(tester);
    });

    testWidgets('cancel keeps the sentence and sends nothing', (tester) async {
      final server = _Server(transcript: _transcript());
      await _player(tester, server);
      await tester.tap(find.byKey(const Key('transcript-edit-1')));
      await _settle(tester);
      await tester.enterText(
        find.byKey(const Key('transcript-field-1')),
        'Nešto drugo.',
      );
      await tester.tap(find.byKey(const Key('transcript-cancel-1')));
      await _settle(tester);
      expect(server.puts, isEmpty);
      expect(find.text('Ona počinje potezom lovac c4.'), findsOneWidget);
      expect(find.text('Nešto drugo.'), findsNothing);
      await _close(tester);
    });

    testWidgets('a correction the server refuses stays open with its text', (
      tester,
    ) async {
      final server = _Server(transcript: _transcript())
        ..failWith = _json(
          jsonEncode({'error': 'Server error while saving the correction.'}),
          500,
        );
      await _player(tester, server);
      await tester.tap(find.byKey(const Key('transcript-edit-1')));
      await _settle(tester);
      await tester.enterText(
        find.byKey(const Key('transcript-field-1')),
        'Ispravljeno.',
      );
      await tester.tap(find.byKey(const Key('transcript-save-1')));
      await _settle(tester);
      expect(
        find.text('Server error while saving the correction.'),
        findsOneWidget,
      );
      final field = tester.widget<TextField>(
        find.byKey(const Key('transcript-field-1')),
      );
      expect(field.controller!.text, 'Ispravljeno.');
      await _close(tester);
    });
  });

  group('where it stands', () {
    for (final size in const [
      Size(1200, 900),
      Size(1536, 792),
      Size(900, 700),
    ]) {
      testWidgets(
        'at ${size.width.toInt()} x ${size.height.toInt()} beside the '
        'board, and the board no smaller for it',
        (tester) async {
          final student = _Server(transcript: _transcript());
          await _player(tester, student, me: _student, size: size);
          final alone = tester.getRect(find.byType(SkinnedChessBoard));
          await _close(tester);

          final host = _Server(transcript: _transcript());
          await _player(tester, host, size: size);
          final board = tester.getRect(find.byType(SkinnedChessBoard));
          final panel = tester.getRect(_panel);
          expect(board.width, board.height, reason: 'a board is square');
          expect(
            board.width,
            alone.width,
            reason: 'the panel costs the board nothing',
          );
          expect(panel.left, greaterThanOrEqualTo(board.right));
          expect(panel.right, lessThanOrEqualTo(size.width));
          expect(find.byKey(const Key('replay-transcript-open')), findsNothing);
          expect(tester.takeException(), isNull);
          await _close(tester);
        },
      );
    }

    // Added on grading, 27.9.2026: the gate's four sentences fit anywhere,
    // and a rendered look at 900 x 700 with twelve found the panel
    // overflowing by 31 px — the list asked for a fixed 420 rather than
    // taking the column's height, which also left 1536 x 792 showing half its
    // sentences over empty space. A real take has dozens (rule 6).
    for (final size in const [Size(900, 700), Size(1536, 792)]) {
      testWidgets(
        'at ${size.width.toInt()} x ${size.height.toInt()} a long '
        'transcript takes the height of the column and its button stays in reach',
        (tester) async {
          final many = [
            for (var i = 0; i < 40; i++)
              {
                'startMs': 1000 + i * 2000,
                'endMs': 2500 + i * 2000,
                'text': 'Rečenica broj $i, dovoljno duga da zauzme dva reda u '
                    'koloni pored table.',
                'heard': 'Rečenica broj $i, dovoljno duga da zauzme dva reda u '
                    'koloni pored table.',
              },
          ];
          final server = _Server(transcript: _transcript(sentences: many));
          await _player(tester, server, size: size);
          expect(tester.takeException(), isNull);
          final panel = tester.getRect(_panel);
          final button = tester.getRect(_transcribe);
          expect(panel.bottom, lessThanOrEqualTo(size.height));
          expect(button.bottom, lessThanOrEqualTo(panel.bottom));
          expect(_transcribe.hitTestable(), findsOneWidget);
          expect(
            panel.bottom - button.bottom,
            lessThan(48),
            reason: 'the list fills the column; no empty band under the '
                'button while sentences are hidden above it',
          );
          await _close(tester);
        },
      );
    }

    testWidgets(
        'on a phone upright the sentences open over the player, and a '
        'tap still moves it', (tester) async {
      final server = _Server(transcript: _transcript());
      await _player(tester, server, size: const Size(360, 640));
      expect(_panel, findsNothing);
      expect(tester.takeException(), isNull);

      final open = find.byKey(const Key('replay-transcript-open'));
      expect(open, findsOneWidget);
      expect(tester.getRect(open).right, lessThanOrEqualTo(360));
      await tester.tap(open);
      await _settle(tester);
      expect(_panel, findsOneWidget);
      // Measured, not hit-tested: the marks' CustomPaint lies over the
      // board and takes every hit, so `hitTestable()` finds the board on no
      // screen at all (the gate's first draft; the implementer, 27.9.2026).
      expect(
        tester.getRect(find.byType(SkinnedChessBoard)).center.dy,
        lessThan(tester.getRect(_panel).top),
        reason: 'the board is still in sight above the sheet',
      );
      // Added on grading, 27.9.2026: the first build laid the sheet over the
      // control deck, which holds the only button that closes it — a rendered
      // phone had no play button and no way out — and ran its list past the
      // screen with „Transcribe again…" below the edge.
      expect(
        open.hitTestable(),
        findsOneWidget,
        reason: 'the sheet can be closed while it is open',
      );
      expect(
        find.byType(FloatingActionButton).hitTestable(),
        findsOneWidget,
        reason: 'play is in reach while reading',
      );
      expect(_transcribe.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(_panel).bottom,
        lessThanOrEqualTo(tester.getRect(open).top),
        reason: 'the sheet stands above the controls, not over them',
      );

      // The sheet shows a few sentences; the reader scrolls to the rest.
      await tester.scrollUntilVisible(
        _sentence(1),
        60,
        scrollable: find.descendant(
          of: find.byKey(const Key('transcript-sentence-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pump();
      await tester.tap(_sentence(1));
      await _settle(tester);
      expect(_clock('00:12'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _close(tester);
    });

    // Case 3 of the phase 8 brief: the player's door
    // (`transcript-make-tutorial`), measured in the sheet a phone upright
    // opens the panel into — the corner this codebase has clipped a button
    // in before (`CLAUDE.md`, 20.8.2026).
    testWidgets(
        'on a phone upright, in the sheet: „Make a tutorial" is on screen '
        'whole and its words are not clipped, and the list above it keeps '
        'its room', (tester) async {
      final server = _Server(transcript: _transcript());
      await _player(tester, server, size: const Size(360, 640));
      final open = find.byKey(const Key('replay-transcript-open'));
      await tester.tap(open);
      await _settle(tester);
      expect(_panel, findsOneWidget);

      final list = find.byKey(const Key('transcript-sentence-list'));
      expect(list, findsOneWidget);
      final listRect = tester.getRect(list);
      expect(listRect.height, greaterThan(0),
          reason: 'the list above the door keeps its room');

      final door = find.byKey(const Key('transcript-make-tutorial'));
      expect(door, findsOneWidget);
      final doorRect = tester.getRect(door);
      expect(doorRect.right, lessThanOrEqualTo(360),
          reason: 'the button is on screen whole');
      expect(doorRect.bottom, lessThanOrEqualTo(640),
          reason: 'the button is on screen whole');

      final label =
          find.descendant(of: door, matching: find.text('Make a tutorial'));
      expect(label, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(paragraph.didExceedMaxLines, isFalse,
          reason: '„fits" is not „can be read" (CLAUDE.md, 27.9.2026)');
      await _close(tester);
    });

    testWidgets('on a phone on its side the sentences stand beside the board', (
      tester,
    ) async {
      final server = _Server(transcript: _transcript());
      await _player(tester, server, size: const Size(800, 360));
      expect(_panel, findsOneWidget);
      final board = tester.getRect(find.byType(SkinnedChessBoard));
      final panel = tester.getRect(_panel);
      expect(board.width, board.height);
      expect(panel.left, greaterThanOrEqualTo(board.right));
      expect(find.byKey(const Key('replay-transcript-open')), findsNothing);
      expect(tester.takeException(), isNull);
      await _close(tester);
    });
  });

  group('Usage this month', () {
    test('every provider\'s seconds are one row, in minutes rounded up', () {
      final rows = countedRows(
        MonthlyUsage(
          tier: 'free',
          periodStart: DateTime.utc(2026, 9, 1),
          quotas: const {},
          metrics: const {'stt_groq_seconds': 121, 'mp4_render_seconds': 60},
          voiceMinutes: 0,
        ),
      );
      expect(rows.map((r) => '${r.label}: ${r.value}').toList(), [
        'Video rendered: 1 min',
        'Recordings transcribed: 3 min',
      ]);
    });
  });
}
