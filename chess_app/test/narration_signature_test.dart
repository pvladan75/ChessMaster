// The signature that binds a recording to the beats it was made over — phase 5
// of `docs/PLAN-SNIMANJE.md`.
//
// A recording is markers into a beat list, and a marker names a beat by its
// index. Edit a sentence, add a part, reorder two, and every marker after the
// edit names a beat it was never recorded against — the film is right at the
// start and wrong in the middle, which is the half nobody re-checks. Phase 1
// could only count beats, and a count sees none of those.
//
// What this file pins is therefore two-sided, and both sides matter:
//
//   1. every edit that moves a beat changes the signature;
//   2. every edit that does not, does not — because the cost of a false alarm
//      is a trainer told to record an hour again for a highlight they added.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_take.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';
import 'package:chess_app/move_tree.dart' show ChessArrow, SquareMark;

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _after1e4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';

/// The same tutorial set up on a board with no queens: 1. e4 e5 is legal on it
/// and the sentences are the same, so nothing but the fen differs.
const _noQueens = 'rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNB1KBNR w KQkq - 0 1';

TutorialSection sectionOf({
  String fen = _start,
  String pgn = '{ White takes the centre. } 1. e4 { Black answers. } e5',
  String title = 'Part',
  LessonStepKind kind = LessonStepKind.show,
  String? instruction,
}) =>
    TutorialSection(
      root: readStepTree(fen: fen, pgn: pgn).root,
      title: title,
      kind: kind,
      instruction: instruction,
    );

TutorialDraft draftOf(
        {String title = 'Centre', List<TutorialSection>? parts}) =>
    TutorialDraft(
      lessonId: 12,
      title: title,
      sections: parts ?? [sectionOf()],
    );

String signatureOf(TutorialDraft draft) => filmSignatureOf(filmBeatsOf(draft));

NarrationTake takeOf({
  int eventCount = 3,
  double peakDbfs = -12,
  String? signature,
}) =>
    NarrationTake(
      markersMs: [for (var i = 0; i < eventCount; i++) i * 100],
      durationMs: eventCount * 100 + 100,
      eventCount: eventCount,
      peakDbfs: peakDbfs,
      recordedAt: DateTime(2026, 9, 10),
      signature: signature,
    );

void main() {
  group('filmSignatureOf', () {
    test('is the same for two readings of the same tutorial', () {
      expect(signatureOf(draftOf()), signatureOf(draftOf()));
      expect(signatureOf(draftOf()), hasLength(64),
          reason: 'the column that stores it is VARCHAR(64)');
    });

    test('a rewritten sentence is a different beat list', () {
      final edited = draftOf(parts: [
        sectionOf(
            pgn: '{ White takes the middle. } 1. e4 { Black answers. } e5'),
      ]);
      expect(signatureOf(edited), isNot(signatureOf(draftOf())));
    });

    // A move replaced is caught by the beat's own fen, and the moves are
    // deliberately not in the signature for that reason — a mutation deleting
    // them from it survived this whole file. See `filmSignatureOf`.
    test('a beat added, and a move replaced', () {
      final longer = draftOf(parts: [
        sectionOf(
            pgn:
                '{ White takes the centre. } 1. e4 { Black answers. } e5 2. Nf3'),
      ]);
      final other = draftOf(parts: [
        sectionOf(
            pgn: '{ White takes the centre. } 1. e4 { Black answers. } c5'),
      ]);
      expect(signatureOf(longer), isNot(signatureOf(draftOf())));
      expect(signatureOf(other), isNot(signatureOf(draftOf())));
    });

    test('a part opening on another position is a different beat list', () {
      // **The one thing no move can say.** A part's own starting position is
      // derived from nothing else, so only the fen carries it — and the fixture
      // has to make that the only difference or the test proves nothing about
      // the fen. Same sentences, same two moves, one board without queens: a
      // signature over the sans and the captions alone cannot tell them apart,
      // and a trainer who set the position up differently is talking about
      // another board from the first word.
      final elsewhere = draftOf(parts: [sectionOf(fen: _noQueens)]);
      expect(signatureOf(elsewhere), isNot(signatureOf(draftOf())));

      // And the ply the part opens on, which is a fen and nothing else.
      final later = draftOf(parts: [
        sectionOf(fen: _after1e4, pgn: '{ White takes the centre. } 1... e5'),
      ]);
      expect(signatureOf(later), isNot(signatureOf(draftOf())));
    });

    test('two parts swapped is a different beat list', () {
      final first = sectionOf(pgn: '{ One. } 1. e4');
      final second = sectionOf(pgn: '{ Two. } 1. d4');
      final forward = signatureOf(draftOf(parts: [first, second]));
      final back = signatureOf(draftOf(parts: [second, first]));
      expect(forward, isNot(back),
          reason: 'the markers would name the other part from the first beat');
    });

    test('the task of a part that asks is in it: the child hears it read', () {
      final asks = draftOf(parts: [
        sectionOf(
            kind: LessonStepKind.askMove, instruction: 'Find the best move.'),
      ]);
      final asksOther = draftOf(parts: [
        sectionOf(kind: LessonStepKind.askMove, instruction: 'Why not Nf3?'),
      ]);
      expect(signatureOf(asks), isNot(signatureOf(asksOther)));
    });

    test('renaming the tutorial costs no narration', () {
      // The plan names this one outright: an hour of a trainer's voice must not
      // be spent on a title.
      expect(signatureOf(draftOf(title: 'The centre, again')),
          signatureOf(draftOf()));
    });

    test('renaming a part costs no narration', () {
      // A part's title is a label in a list and is never on the film.
      expect(signatureOf(draftOf(parts: [sectionOf(title: 'Deo 7')])),
          signatureOf(draftOf()));
    });

    test('an arrow, a ring and a flipped board cost no narration', () {
      // They change what is drawn on a beat, not which beat it is nor how long
      // it is spoken over. A trainer highlighting the square they were already
      // talking about has not made their own voice wrong.
      final drawn = sectionOf();
      drawn.root.arrows.add(ChessArrow(from: 'd2', to: 'd4', colorCode: 'G'));
      drawn.root.squares.add(SquareMark(square: 'd5', colorCode: 'R'));
      drawn.blackOrientation = true;
      expect(signatureOf(draftOf(parts: [drawn])), signatureOf(draftOf()));
    });
  });

  group('takeMismatchOf', () {
    final signature = signatureOf(draftOf());
    final moved = signatureOf(draftOf(parts: [
      sectionOf(pgn: '{ White takes the middle. } 1. e4 { Black answers. } e5'),
    ]));

    test('a take of these beats, signed with them, can make the film', () {
      expect(
          takeMismatchOf(takeOf(signature: signature),
              beats: 3, signature: signature),
          TakeMismatch.none);
    });

    test('the same beats saying something else is what phase 5 is for', () {
      // The count cannot see this, and it is the whole reason for the column:
      // three beats before, three beats now, and one of them is about another
      // sentence.
      expect(
          takeMismatchOf(takeOf(signature: moved),
              beats: 3, signature: signature),
          TakeMismatch.edited);
    });

    test('a take from before phase 5 is judged by its count, as it was', () {
      // Absence is a third answer. Refusing every unsigned take is an hour of a
      // trainer's voice thrown away for a question it was never asked; passing
      // them all is the silent wrong film this phase exists to prevent.
      expect(takeMismatchOf(takeOf(), beats: 3, signature: signature),
          TakeMismatch.none);
      expect(
          takeMismatchOf(takeOf(eventCount: 5), beats: 3, signature: signature),
          TakeMismatch.beatsChanged);
    });

    test('a silent take is said before anything about beats', () {
      // It is wrong whatever the tutorial says now, and it is the one problem
      // that recording the same beats again would not have fixed.
      expect(
          takeMismatchOf(takeOf(peakDbfs: -91, signature: moved),
              beats: 3, signature: signature),
          TakeMismatch.silent);
    });

    test('a count that has moved is named as a count, not as an edit', () {
      // Both are true, and the trainer can act on the first: it says how many
      // beats there were and how many there are.
      expect(
          takeMismatchOf(takeOf(eventCount: 5, signature: moved),
              beats: 3, signature: signature),
          TakeMismatch.beatsChanged);
    });

    test('a take stopped part-way, of the right beats, is incomplete', () {
      final short = NarrationTake(
        markersMs: const [0, 100],
        durationMs: 400,
        eventCount: 3,
        peakDbfs: -12,
        recordedAt: DateTime(2026, 9, 10),
        signature: signature,
      );
      expect(takeMismatchOf(short, beats: 3, signature: signature),
          TakeMismatch.incomplete);
    });
  });

  test('a take carries its signature through the index on disk', () {
    // `take.json` is what a device remembers, and a signature that did not
    // survive the round trip would make every reopened tutorial look edited.
    final signature = signatureOf(draftOf());
    final back = NarrationTake.fromJson(takeOf(signature: signature).toJson());
    expect(back.signature, signature);
    expect(NarrationTake.fromJson(takeOf().toJson()).signature, isNull,
        reason: 'a take with none must not gain one on the way through');
  });
}
