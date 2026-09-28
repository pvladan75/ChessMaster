// A study written into the move tree — docs/PLAN-STUDIJA-POZICIJE.md, §1
// and §4: the lines under the node the study started from, the words on the
// moves they are about, and a mark only where a sentence names it.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_import.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_facts.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_tree.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_words.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/section_split.dart';

import 'support/recorded_engine.dart';

Future<PositionStudy> _study(String name) async {
  final engine = RecordedEngine.read(name);
  final study = await PositionStudyBuilder(
    analyzer: engine.analyzer,
    depth: engine.depth,
    tablebase: engine.tablebase,
  ).build(engine.fen);
  expect(engine.unanswered, isEmpty);
  return study;
}

/// A sentence for every slot [study] offers, each naming its slot.
Map<String, String> _words(PositionStudy study) => {
      for (final slot in studyWordsRequest(study).slots)
        slot.id: 'Words for ${slot.id}.',
    };

/// The movetext of [root]'s export, headers off.
String _moves(AnalysisNode root) =>
    PgnExporterService.exportToPgn(root).split('\n\n').last.trim();

AnalysisNode _child(AnalysisNode node, String san) =>
    node.children.firstWhere((c) => c.moveSan == san);

Iterable<AnalysisNode> _all(AnalysisNode node) sync* {
  yield node;
  for (final c in node.children) {
    yield* _all(c);
  }
}

void main() {
  test('the owner\'s line is in the tree, marked as a player would mark it',
      () async {
    final study = await _study('owner1');
    final root = AnalysisNode(fen: study.fen);
    writeStudy(root, study);
    // Superseded on 28.9.2026 in one place: this began `Bxb1 (7... Be4?!`.
    // The first move of the text is Black's and now carries its number, as
    // the PGN standard has it (`pgn_black_move_number_test.dart`). The
    // lines, their order and their marks are what they were.
    expect(
      _moves(root),
      '7... Bxb1 (7... Be4?! 8. dxc6! Bxh1? (8... Nxc6 9. f3) 9. Rxa7! Rxa7 '
      '(9... Nxc6 10. Rxa8+) 10. c7 e6 11. cxb8=Q+) '
      '(7... Nd7? 8. Nxd7 Bxd7 9. Bg2) 8. Rxb1 cxd5 9. e4 *',
    );
  });

  test('a trap stands beside the move of the main line it is an answer to',
      () async {
    final study = await _study('owner2');
    final root = AnalysisNode(fen: study.fen);
    writeStudy(root, study);
    // Superseded on 28.9.2026 in two places: `… Be6) Nxc6` and
    // `… b6) Nxe5`. A Black move that follows a closed variation now
    // carries its number (`pgn_black_move_number_test.dart`). Where each
    // trap stands is what it was.
    expect(
      _moves(root),
      '8. dxc6 (8. f3 Bxd5 9. d4 Nf6 10. Nd2 Nfd7 11. e4 Be6) 8... Nxc6 '
      '(8... Bxh1? 9. Rxa7! Rxa7 (9... Nxc6 10. Rxa8+) 10. c7 e6 '
      '11. cxb8=Q+) 9. f3 (9. Nxc6? Bxh1! 10. Na5 b6) 9... Nxe5 '
      '10. fxe4 Nc6 *',
    );
  });

  test('without words there is no comment and no mark anywhere', () async {
    final study = await _study('owner2');
    final root = AnalysisNode(fen: study.fen);
    final written = writeStudy(root, study);
    expect(written.sentences, 0);
    expect(written.moves, greaterThan(20));
    for (final node in _all(root)) {
      expect(node.beats, hasLength(1), reason: node.moveSan);
      expect(node.beats.single.isEmpty, isTrue, reason: node.moveSan);
    }
  });

  test('the words go on the moves they are about', () async {
    final study = await _study('owner1');
    final root = AnalysisNode(fen: study.fen);
    final written = writeStudy(root, study, words: _words(study));

    expect(root.comment, 'Words for s.position.');
    expect(_child(root, 'Bxb1').comment, 'Words for m1.move.');
    final be4 = _child(root, 'Be4');
    expect(be4.comment, 'Words for t1.move.');
    final dxc6 = _child(be4, 'dxc6');
    expect(dxc6.comment, 'Words for t1.reply.');
    expect(dxc6.children.first.moveSan, 'Bxh1',
        reason: 'the trap first: a tutorial\'s part walks first children');
    expect(dxc6.children.first.comment, 'Words for t1.greedy.');
    expect(_child(dxc6.children.first, 'Rxa7').comment, 'Words for t1.punish.');
    expect(written.lastMove.lastBeat.comment, 'Words for e.outcome.');
    expect(written.sentences, studyWordsRequest(study).slots.length);
  });

  test('a mark stands only in a beat whose sentence names it', () async {
    final study = await _study('owner2');
    final words = _words(study);

    final marked = AnalysisNode(fen: study.fen);
    writeStudy(marked, study, words: words);
    expect(marked.beats, hasLength(2), reason: 'the position, then the threat');
    expect({for (final s in marked.beats[0].squares) s.colorCode}, {'Y'});
    expect(marked.beats[1].comment, 'Words for s.threat.');
    expect([for (final a in marked.beats[1].arrows) '$a'], ['Re4h1']);
    expect([for (final s in marked.beats[1].squares) '$s'], ['Rh1']);

    // The threat's sentence was refused: its arrow goes with it.
    final unsaid = AnalysisNode(fen: study.fen);
    writeStudy(unsaid, study, words: {...words}..remove('s.threat'));
    expect(unsaid.beats, hasLength(1));
    expect(_all(unsaid).expand((n) => n.beats).expand((b) => b.arrows),
        isNot(contains(predicate((a) => '$a' == 'Re4h1'))));
  });

  test(
      'what the reader wrote on the position is kept, and the study '
      'follows it', () async {
    final study = await _study('owner1');
    final root = AnalysisNode(fen: study.fen, comment: 'My own note.');
    writeStudy(root, study, words: _words(study));
    expect(root.beats.first.comment, 'My own note.');
    expect(root.beats[1].comment, 'Words for s.position.');
  });

  test('a move already in the tree is not added again', () async {
    final study = await _study('owner1');
    final root = AnalysisNode(fen: study.fen);
    final first = writeStudy(root, study);
    final again = writeStudy(root, study);
    expect(first.moves, greaterThan(0));
    expect(again.moves, 0);
    expect(root.children.map((c) => c.moveSan), ['Bxb1', 'Be4', 'Nd7']);
  });

  test('a mark of judgement the reader gave a move is not overwritten',
      () async {
    final study = await _study('owner1');
    final root = AnalysisNode(fen: study.fen);
    final be4 = root.addChild(
      childFen: study.tempting.first.move.fenAfter,
      san: 'Be4',
      uci: study.tempting.first.move.uci,
    )..nag = '!?';
    writeStudy(root, study);
    expect(be4.nag, '!?');
  });

  test('the study is of the position its node stands on, or it is refused',
      () async {
    final study = await _study('owner1');
    final other = AnalysisNode(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    expect(() => writeStudy(other, study), throwsArgumentError);
    expect(other.children, isEmpty);
  });

  test('what was written is read back by the app\'s one reader, whole',
      () async {
    final study = await _study('owner2');
    final root = AnalysisNode(fen: study.fen);
    writeStudy(root, study, words: _words(study));
    final pgn = PgnExporterService.exportToPgn(root);
    final read = readAnalysisPgn(pgn);
    expect(read, isNotNull);
    expect(read!.rejectedMoves, 0);
    expect(_moves(read.root), _moves(root));
    expect(read.root.beats.map((b) => b.comment),
        ['Words for s.position.', 'Words for s.threat.']);
    expect([for (final a in read.root.beats[1].arrows) '$a'], ['Re4h1']);
  });

  test(
      'as a tutorial it is parts, one line each, and the owner\'s line is '
      'told in order', () async {
    final study = await _study('owner1');
    final root = AnalysisNode(fen: study.fen);
    writeStudy(root, study, words: _words(study));
    final parts = splitAtForks(TutorialSection(root: root));
    for (final part in parts) {
      expect(_all(part.root).every((n) => n.children.length <= 1), isTrue,
          reason: 'a part is one line');
    }
    // The tutorial's own order (docs/PLAN-MAPA-DELOVA.md): a part runs to a
    // fork, the side lines follow it, then the line goes on — a book's
    // order, in which what fails is shown before what is played.
    expect(
      [
        for (final part in parts)
          [
            for (AnalysisNode? n = part.root.children.isEmpty
                    ? null
                    : part.root.children.first;
                n != null;
                n = n.children.isEmpty ? null : n.children.first)
              n.moveSan,
          ].join(' '),
      ],
      [
        'Be4 dxc6',
        'Nxc6 f3',
        'Bxh1 Rxa7',
        'Nxc6 Rxa8+',
        'Rxa7 c7 e6 cxb8=Q+',
        'Nd7 Nxd7 Bxd7 Bg2',
        'Bxb1 Rxb1 cxd5 e4',
      ],
    );
  });
}
