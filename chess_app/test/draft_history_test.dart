// The studio's undo and redo, without a screen — phase 1 of
// docs/PLAN-STUDIO-ISTORIJA.md.
//
// The history is a list of whole-draft snapshots, and every rule about what
// becomes a step is here: a change that changes nothing is not one, typing is
// merged per pause, a new change after an undo drops what could be redone, and
// the hundredth change pushes the oldest out. The clock is injected, so the
// pause is tested rather than waited for. The second group pins the content
// signature those rules compare, on the model itself.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/draft_history.dart';
import 'package:chess_app/move_tree.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';

void main() {
  group('the history', () {
    late DateTime clock;
    late DraftHistory history;

    setUp(() {
      clock = DateTime(2026, 9, 11, 12);
      history = DraftHistory(now: () => clock);
      history.start('s0', 'c0');
    });

    void later(int ms) => clock = clock.add(Duration(milliseconds: ms));

    test('starts with nothing to undo or redo', () {
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
      expect(history.undo(), isNull);
      expect(history.redo(), isNull);
    });

    test('undoes a change and redoes it', () {
      history.record('s1', 'c1');
      expect(history.canUndo, isTrue);

      expect(history.undo(), 's0');
      expect(history.canRedo, isTrue);
      expect(history.redo(), 's1');
      expect(history.canRedo, isFalse);
    });

    test(
        'a change that changes nothing is not a step, but keeps where the '
        'trainer stands', () {
      history.record('s1', 'c1');
      // Walking the line after the change: same content, new cursor.
      history.record('s1-cursor-moved', 'c1');
      history.record('s2', 'c2');

      expect(history.undo(), 's1-cursor-moved',
          reason:
              'the undo puts the trainer back where the next change was made');
      expect(history.undo(), 's0');
      expect(history.canUndo, isFalse, reason: 'two changes, two steps');
    });

    test('typing in one field without a pause is one step', () {
      history.record('t1', 'B', typingIn: 'comment:1');
      later(200);
      history.record('t2', 'Be', typingIn: 'comment:1');
      later(200);
      history.record('t3', 'Bel', typingIn: 'comment:1');

      expect(history.undo(), 's0', reason: 'the whole word goes in one undo');
    });

    test('a pause starts a new step', () {
      history.record('t1', 'Beli', typingIn: 'comment:1');
      later(1500);
      history.record('t2', 'Beli preti', typingIn: 'comment:1');

      expect(history.undo(), 't1');
      expect(history.undo(), 's0');
    });

    test('another field starts a new step', () {
      history.record('t1', 'title', typingIn: 'title');
      later(100);
      history.record('t2', 'title+labels', typingIn: 'labels');

      expect(history.undo(), 't1');
    });

    test('a change that is not typing ends the typing step', () {
      history.record('t1', 'Beli', typingIn: 'comment:1');
      later(100);
      history.record('m1', 'Beli+e4');
      later(100);
      history.record('t2', 'Beli+e4 preti', typingIn: 'comment:1');

      expect(history.undo(), 'm1');
    });

    test('typing after an undo does not rewrite the step it landed on', () {
      history.record('t1', 'Beli', typingIn: 'comment:1');
      history.record('m1', 'Beli+e4');
      history.undo();
      later(100);
      history.record('t2', 'Beli preti', typingIn: 'comment:1');

      expect(history.undo(), 't1',
          reason:
              'the state the undo returned to is still there to go back to');
    });

    test('typing is merged again once a new step has begun after an undo', () {
      history.record('m1', 'e4');
      history.undo();
      later(100);
      history.record('t1', 'B', typingIn: 'comment:1');
      later(100);
      history.record('t2', 'Be', typingIn: 'comment:1');

      expect(history.undo(), 's0',
          reason:
              'one undo does not turn the rest of the session into letters');
    });

    test('typing after a redo does not rewrite the step it landed on', () {
      history.record('t1', 'Beli', typingIn: 'comment:1');
      later(100);
      history.undo();
      history.redo();
      later(100);
      history.record('t2', 'Beli preti', typingIn: 'comment:1');

      expect(history.undo(), 't1',
          reason: 'the redone step is a place to come back to, like any other');
    });

    test('a new change after an undo drops what could be redone', () {
      history.record('s1', 'c1');
      history.record('s2', 'c2');
      history.undo();
      history.record('s3', 'c3');

      expect(history.canRedo, isFalse);
      expect(history.undo(), 's1');
    });

    test('keeps a hundred changes, and the oldest goes first', () {
      for (var i = 1; i <= 101; i++) {
        history.record('s$i', 'c$i');
      }

      var undone = 0;
      String? last;
      while (history.canUndo) {
        last = history.undo();
        undone++;
      }
      expect(undone, 100);
      expect(last, 's1',
          reason:
              'the start and the first change fell out of a history of 100');
    });
  });

  group('the content signature', () {
    TutorialDraft draft({String comment = 'Beli počinje.', String title = ''}) {
      final root = AnalysisNode(fen: _start);
      root.addChild(childFen: _afterE4, san: 'e4', uci: 'e2e4').comment =
          comment;
      return TutorialDraft(
        lessonId: 5,
        title: 'Opozicija',
        sections: [TutorialSection(root: root, title: title)],
      );
    }

    test('does not see the cursor, the selected part or the ids', () {
      final a = draft();
      final b = draft();
      b.section.cursorNode = b.section.root.children.first;
      b.sections.first.stepId = 'abc';
      b.lessonId = 99;

      expect(b.contentSignature(), a.contentSignature());
    });

    test('sees a sentence, an arrow and a starting position', () {
      final base = draft().contentSignature();

      expect(draft(comment: 'Crni odgovara.').contentSignature(), isNot(base));

      final arrow = draft();
      arrow.section.root.arrows
          .add(ChessArrow(from: 'e2', to: 'e4', colorCode: 'G'));
      expect(arrow.contentSignature(), isNot(base));

      // No moves at all, only another board: [treeSignature] leaves the
      // position out on purpose, and the content must not.
      final a = TutorialDraft(sections: [
        TutorialSection.blank(fen: _start),
      ]);
      final b = TutorialDraft(sections: [
        TutorialSection.blank(fen: _afterE4),
      ]);
      expect(a.contentSignature(), isNot(b.contentSignature()));
    });

    test('reads a part named by its first sentence as that sentence', () {
      // The server stores a part the trainer did not name under its first
      // sentence; the same part here has no name of its own. Phase 2 compares
      // the two, and they are one tutorial.
      final local = TutorialDraft(sections: [
        TutorialSection(
            root: AnalysisNode(fen: _start, comment: 'Beli počinje.')),
      ]);
      final fromServer = TutorialDraft(sections: [
        TutorialSection(
            root: AnalysisNode(fen: _start, comment: 'Beli počinje.'),
            title: 'Beli počinje.'),
      ]);
      expect(fromServer.contentSignature(), local.contentSignature());
    });

    test('a part keeps its key through the on-device slot, and a copy does not',
        () {
      final original = draft();
      final key = original.sections.first.localKey;

      final read = TutorialDraft.fromJson(original.toJson());
      expect(read.sections.first.localKey, key);
      expect(original.sections.first.copy().localKey, isNot(key));
    });
  });
}
