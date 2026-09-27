// Phase 6 of docs/PLAN-PRIPREMA.md — one case for
// `chess_app/test/preparation_recording_test.dart`, pasted at the end of its
// group('the timeline', …) when the phase is briefed. It uses that file's own
// harness (_Server, _open, _startRecording, _speak, _play, _press, _mark,
// _saveAs, _eventsOf) rather than a second copy of it.
//
// The rule it holds is the file's own invariant — what the player replays is
// what the trainer saw — for the one new way the marks on the board can
// change: **opening another sentence of the same position**. It is an
// `arrow_drawn`, as any other change of the marks; adding a sentence that
// keeps the marks (D16 B) changes nothing on the board and writes nothing.

    testWidgets('another sentence opened is a change of the marks',
        (tester) async {
      final server = _Server();
      final (mic, _) = await _open(tester, server);
      await _startRecording(tester);
      await _speak(tester, mic, 500);
      await _play(tester, 'e2', 'e4');
      await _speak(tester, mic, 500);
      await _press(tester, const Key('annotate-arrow'));
      await _mark(tester, 'g1');
      await _mark(tester, 'f3');
      await _speak(tester, mic, 500);
      // A second sentence: it keeps the arrow, so the board does not change.
      await _press(tester, const Key('prep-add-sentence'));
      await _speak(tester, mic, 500);
      await _press(tester, const Key('annotate-clear'));
      await _speak(tester, mic, 500);
      // Back to the first sentence: its arrow is on the board again.
      await _press(tester, const Key('prep-sentence-prev'));
      await _speak(tester, mic, 500);
      await _saveAs(tester, 'Two sentences');

      final events = _eventsOf(server.uploads.single);
      expect([for (final e in events) e['eventType']], [
        'init', // Record
        'move', // e4
        'arrow_drawn', // g1–f3
        'arrow_drawn', // the second sentence cleared
        'arrow_drawn', // the first sentence opened again
      ]);
      expect([for (final e in events) e['timestampMs']],
          [0, 500, 1000, 2000, 2500],
          reason: 'adding a sentence that keeps the marks wrote nothing');
      Map<String, dynamic> data(int i) =>
          Map<String, dynamic>.from(events[i]['data'] as Map);
      expect(data(3), {'arrows': <Object>[], 'squares': <Object>[]});
      expect(data(4), {
        'arrows': [
          {'from': 'g1', 'to': 'f3', 'color': 'G'},
        ],
        'squares': <Object>[],
      });
    });
