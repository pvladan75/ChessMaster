import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_drill_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// The Smith-Morra accepted, Black to move.
const smithMorra = 'rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq - 0 4';

/// A drill server with no server: it hands back one question and grades the
/// answer against a fixed decision.
class _FakeApi extends RepertoireApiService {
  _FakeApi({
    this.outcomeFor,
    this.reply = 'g1f3',
    this.replyCovered = true,
    this.item = smithMorra,
    this.stats = const DrillStats(positions: 6, due: 2, known: 1, fresh: 3),
  }) : super(client: MockClient((_) async => http.Response('{}', 500)));

  /// What this student decided to play here: 4...Nc6 in the Smith-Morra.
  static const primaryUci = 'b8c6';
  static const primarySan = 'Nc6';

  final String? outcomeFor;
  final String? reply;
  final bool replyCovered;
  final String? item;
  final DrillStats stats;

  int loads = 0;
  int reveals = 0;
  bool? lastRevealedFlag;

  /// The line handed back, and null for a server that did not answer — which
  /// the screen must tell apart from a line with no question in it.
  DrillLine? line;

  /// What comes back when the caller asks to practise ahead of schedule. Null
  /// means the same line as always.
  DrillLine? aheadLine;
  int lineCalls = 0;
  String? lastFromFen;
  bool? lastAhead;

  /// Which fork the last request asked to be walked through, and what it had
  /// already refused. Both are the point of the buttons that send them.
  String? lastViaFen;
  String? lastViaUci;
  List<String> lastExclude = const [];

  /// A line per chosen road, so a test can watch the drill actually change
  /// direction rather than only asserting on what went up the wire.
  final Map<String?, DrillLine?> linesByVia = {};

  /// How many answers were graded. The rehearsal must add nothing to this: a
  /// prefix is replayed many times a day, and grading it would push those
  /// positions out on repetitions nobody had to remember cold.
  int graded = 0;
  bool? lastPractice;

  /// Whether the last answer asked the server to write only if the position
  /// was really due — what a line walked on past its question sends.
  bool? lastOnlyIfDue;

  /// Every position that was graded, and whether it was written down. A run
  /// through a branch must score the positions that were due and leave the
  /// rest alone, so this is the thing worth asserting on.
  final List<({String fen, bool practice, bool onlyIfDue})> answers = [];

  /// The branches the picker is offered.
  List<DrillBranch> branches = const [];
  int branchCalls = 0;

  @override
  Future<List<DrillBranch>> drillBranches({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? gateUci,
  }) async {
    branchCalls += 1;
    return branches;
  }

  @override
  Future<DrillLine?> drillLine({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? fromFen,
    String? viaFen,
    String? viaUci,
    List<String> exclude = const [],
    bool ahead = false,
    String? gateUci,
  }) async {
    lineCalls += 1;
    lastFromFen = fromFen;
    lastAhead = ahead;
    lastViaFen = viaFen;
    lastViaUci = viaUci;
    lastExclude = exclude;
    if (linesByVia.containsKey(viaUci)) return linesByVia[viaUci];
    return aheadLine != null && ahead ? aheadLine : line;
  }

  @override
  Future<({DrillItem? item, DrillStats stats})> nextDrill(
      {required String color}) async {
    loads += 1;
    return (
      item: item == null
          ? null
          : DrillItem(fen: item!, fresh: false, repetitions: 3, moves: 2),
      stats: stats,
    );
  }

  @override
  Future<RepertoireMove?> revealDrill({
    required String color,
    required String fen,
  }) async {
    reveals += 1;
    return RepertoireMove(uci: primaryUci, san: primarySan, role: 'primary');
  }

  @override
  Future<DrillAnswer?> answerDrill({
    required String color,
    required String fen,
    required String uci,
    bool revealed = false,
    int? minRating,
    bool practice = false,
    bool onlyIfDue = false,
  }) async {
    graded += 1;
    lastPractice = practice;
    lastRevealedFlag = revealed;
    lastOnlyIfDue = onlyIfDue;
    answers.add((fen: fen, practice: practice, onlyIfDue: onlyIfDue));
    final outcome = outcomeFor ?? (uci == primaryUci ? 'primary' : 'unknown');
    return DrillAnswer(
      outcome: outcome,
      primary: outcome == 'unprepared'
          ? null
          : RepertoireMove(uci: primaryUci, san: primarySan, role: 'primary'),
      intervalDays: practice ? null : (outcome == 'primary' ? 6 : 0),
      reply: outcome == 'unprepared' ? null : reply,
      replyCovered: replyCovered,
      practice: practice,
    );
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    _FakeApi api, {
    void Function(String fen)? onBuildHere,
    Size size = const Size(500, 1000),
    Key? key,
    String? rootFen,
    List<String> rootPath = const [],
    String? fromFen,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: RepertoireDrillScreen(
        key: key,
        name: 'Smit-Mora, crni',
        color: 'b',
        rootFen: rootFen,
        rootPath: rootPath,
        fromFen: fromFen,
        api: api,
        onBuildHere: onBuildHere,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> play(WidgetTester tester, String from, String to) async {
    final finder = find.byType(ChessBoardWithOverlay);
    final widget = tester.widget<ChessBoardWithOverlay>(finder);
    final rect = tester.getRect(finder);
    final square = widget.boardSize / 8;
    Offset at(String name) {
      final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
      final col =
          widget.boardOrientation == PlayerColor.black ? 7 - file : file;
      final row =
          widget.boardOrientation == PlayerColor.black ? rank : 7 - rank;
      return rect.topLeft + Offset((col + 0.5) * square, (row + 0.5) * square);
    }

    await tester.tapAt(at(from));
    await tester.pumpAndSettle();
    await tester.tapAt(at(to));
    await tester.pumpAndSettle();
    // The rehearsal shows the line's move alone for a beat before the
    // opponent's answer lands on top of it, so a test that plays two moves in a
    // row has to let that beat run out or the second tap arrives on a locked
    // board.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  /// Lets the walk-on run out.
  ///
  /// A right answer with a reply carries on down the line by itself, so a test
  /// that only looks at the graded panel still leaves a timer behind. This is
  /// how it says "and then it moved on", which is also worth asserting after.
  Future<void> walkOn(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
  }

  testWidgets('the question comes without its answer', (tester) async {
    final api = _FakeApi();
    await pump(tester, api);

    expect(find.text('Šta igrate crnim?'), findsOneWidget);
    // The move the student decided on is nowhere on the screen until they ask
    // for it or play something.
    expect(find.textContaining('Nc6'), findsNothing);
    expect(find.textContaining('na redu: 2'), findsOneWidget);
  });

  testWidgets('the move they decided on is a pass, and says when it returns',
      (tester) async {
    final api = _FakeApi();
    await pump(tester, api);

    await play(tester, 'b8', 'c6');

    expect(find.textContaining('Tačno'), findsOneWidget);
    expect(find.textContaining('Vraća se za 6 dana'), findsOneWidget);
    expect(api.lastRevealedFlag, false);

    // And then it walks on by itself, carrying the verdict with it: the panel
    // that named the schedule is gone, and the sentence it was named in is not.
    await walkOn(tester);
    expect(find.text('Šta igrate crnim?'), findsOneWidget);
    expect(find.textContaining('vraća se za 6 dana'), findsOneWidget);
  });

  testWidgets('good chess that is not their decision is still a miss',
      (tester) async {
    // The drill asks about a decision. Accepting anything sound would make the
    // schedule meaningless, because everything would always be a pass.
    final api = _FakeApi();
    await pump(tester, api);

    await play(tester, 'g8', 'f6');

    expect(find.textContaining('Nije to'), findsOneWidget);
    expect(find.textContaining('Vaš potez je Nc6'), findsOneWidget);
  });

  testWidgets('asking to be shown marks the answer as recognised',
      (tester) async {
    final api = _FakeApi();
    await pump(tester, api);

    await tester.tap(find.text('Pokaži'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vaš potez je Nc6'), findsOneWidget);
    expect(api.reveals, 1);

    await play(tester, 'b8', 'c6');
    expect(api.lastRevealedFlag, true,
        reason: 'prepoznato nije isto što i zapamćeno');
    await walkOn(tester);
  });

  testWidgets('the opponent answers, and an unprepared reply is named as such',
      (tester) async {
    final api = _FakeApi(reply: 'a2a3', replyCovered: false);
    await pump(tester, api);

    await play(tester, 'b8', 'c6');

    expect(find.textContaining('Protivnik je odgovorio a3'), findsOneWidget);
    expect(find.textContaining('to niste pokrili'), findsOneWidget);

    // And it stops there. Being surprised is the door back into building, and
    // walking past that sentence into a position with no answer to give would
    // be the worst moment to hurry.
    await walkOn(tester);
    expect(find.textContaining('to niste pokrili'), findsOneWidget);
    expect(find.text('Nastavi liniju'), findsOneWidget);
  });

  testWidgets('a right answer walks on down the line by itself',
      (tester) async {
    // The drill was agreed as a line walk, and a line walked one button press
    // at a time is a quiz with an extra step. "Nastavi liniju" was that press.
    final api = _FakeApi();
    await pump(tester, api);

    await play(tester, 'b8', 'c6');
    expect(find.text('Nastavi liniju'), findsNothing,
        reason: 'ništa se ne traži od korisnika — šetnja ide sama');

    await walkOn(tester);
    expect(find.text('Šta igrate crnim?'), findsOneWidget);

    // And what it asks next was not what the schedule asked for, so it goes up
    // saying "write this down only if it really was due".
    await play(tester, 'd7', 'd6');
    expect(api.answers.last.onlyIfDue, true);
    expect(api.answers.first.onlyIfDue, false,
        reason: 'pitanje jeste bilo dospelo');
  });

  testWidgets('a mistake stops the walk where it happened', (tester) async {
    // That position is the whole reason the line was worth playing, and
    // hurrying past it is the one moment the screen must not hurry.
    final api = _FakeApi(outcomeFor: 'unknown');
    await pump(tester, api);

    await play(tester, 'g8', 'f6');
    await walkOn(tester);

    expect(find.textContaining('Nije to'), findsOneWidget);
    expect(find.text('Nastavi liniju'), findsOneWidget,
        reason: 'dalje se ide kad korisnik kaže, ne sam');
  });

  testWidgets('the end of the book is not walked into', (tester) async {
    // With no reply there is nothing to walk on into: the position after your
    // own move is the opponent's to answer, and asking you for it was a bug of
    // its own.
    final api = _FakeApi(reply: null);
    await pump(tester, api);

    await play(tester, 'b8', 'c6');
    await walkOn(tester);

    expect(find.textContaining('Tačno'), findsOneWidget);
    expect(find.text('Nastavi liniju'), findsNothing);
  });

  testWidgets('a position that was never built offers to build it',
      (tester) async {
    String? asked;
    final api = _FakeApi(outcomeFor: 'unprepared');
    await pump(tester, api, onBuildHere: (fen) => asked = fen);

    await play(tester, 'b8', 'c6');
    expect(find.textContaining('niste pokrili'), findsOneWidget);

    await tester.tap(find.text('Izgradi ovu poziciju'));
    await tester.pumpAndSettle();
    expect(asked, smithMorra,
        reason: 'gradi se pozicija u kojoj je stao, ne neka druga');
  });

  testWidgets('an empty schedule is told apart from an empty repertoire',
      (tester) async {
    final nothingBuilt = _FakeApi(
      item: null,
      stats: const DrillStats(positions: 0, due: 0, known: 0, fresh: 0),
    );
    // A key per case: without one Flutter reuses the same State across the two
    // pumps, initState never runs again, and the second case quietly asserts
    // against the first one's data.
    await pump(tester, nothingBuilt, key: const ValueKey('nista-izgradjeno'));
    expect(find.text('Još nema šta da se vežba.'), findsOneWidget);

    final nothingDue = _FakeApi(
      item: null,
      stats: const DrillStats(positions: 20, due: 0, known: 9, fresh: 0),
    );
    await pump(tester, nothingDue, key: const ValueKey('nista-na-redu'));
    expect(find.text('Ništa nije na redu.'), findsOneWidget);
    expect(find.textContaining('znate 9 od 20'), findsOneWidget);
  });

  testWidgets('the drill fits a 360 dp phone', (tester) async {
    final api = _FakeApi();
    await pump(tester, api, size: const Size(360, 640));
    expect(tester.takeException(), isNull);

    await play(tester, 'b8', 'c6');
    expect(tester.takeException(), isNull);

    // And the line the walk-on leaves behind it, which is the longest sentence
    // on the screen and the one most likely to be clipped by a release build.
    await walkOn(tester);
    expect(tester.takeException(), isNull);
  });

  /// The position after a line of SAN moves from the start of a game.
  ///
  /// Computed rather than pasted, like the frontier's tests: a hand-written FEN
  /// is a chance to assert against a position that does not exist, and the
  /// screen would then be right while the test was wrong.
  String fenAfter(List<String> sans) {
    final board = chess.Chess();
    for (final san in sans) {
      board.move(san);
    }
    return board.fen;
  }

  /// 1.e4 c5 2.d4 cxd4 3.c3 — the Smith-Morra, with Black to move at every
  /// point the student is asked anything. The question is what to do about
  /// 3.c3, and everything before it is rehearsal.
  DrillLine morraLine({bool startKnown = false, List<String>? startPath}) =>
      DrillLine(
        rootPath: const ['e4'],
        startFen: fenAfter(['e4']),
        startPath: startPath ?? const [],
        startKnown: startKnown,
        prefix: const [
          LineMove(uci: 'c7c5', san: 'c5', mine: true),
          LineMove(uci: 'd2d4', san: 'd4', mine: false),
          LineMove(uci: 'c5d4', san: 'cxd4', mine: true),
          LineMove(uci: 'c2c3', san: 'c3', mine: false),
        ],
        question: DrillItem(
          fen: fenAfter(['e4', 'c5', 'd4', 'cxd4', 'c3']),
          fresh: true,
          repetitions: 0,
          moves: 1,
          path: const ['c5', 'd4', 'cxd4', 'c3'],
        ),
        stats: const DrillStats(positions: 6, due: 1, known: 2, fresh: 3),
      );

  testWidgets('the question arrives at the end of the line that leads to it',
      (tester) async {
    // The drill used to put up a bare board four moves into something with no
    // way to tell how it arose. A repertoire is played forwards, and this is
    // the difference between remembering a line and recognising a photograph
    // of its end.
    final api = _FakeApi()..line = morraLine();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    expect(api.lineCalls, 1);
    expect(find.text('Ponovite liniju'), findsOneWidget);
    expect(find.text('1.e4'), findsOneWidget);
    expect(find.textContaining('potez 1 od 2'), findsOneWidget);

    await play(tester, 'c7', 'c5');

    // The student's move and the opponent's answer, both on the board and both
    // in the line above it.
    expect(find.text('1.e4 c5 2.d4'), findsOneWidget);
    expect(find.textContaining('potez 2 od 2'), findsOneWidget);

    await play(tester, 'c5', 'd4');

    // And now the question, at the end of the line rather than on its own.
    expect(find.text('Šta igrate crnim?'), findsOneWidget);
    expect(find.text('1.e4 c5 2.d4 cxd4 3.c3'), findsOneWidget);
    // Nothing along the way was graded.
    expect(api.graded, 0, reason: 'ponavljanje je ocenjeno');
  });

  testWidgets('a wrong move in the rehearsal is named, not marked',
      (tester) async {
    // The rule the whole line drill rests on. A prefix is replayed many times a
    // day on the way to whatever is due below it, so grading it would push
    // those positions' intervals out on rehearsals nobody had to remember cold.
    final api = _FakeApi()..line = morraLine();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    await play(tester, 'e7', 'e5');

    expect(find.textContaining('U ovoj liniji ide c5'), findsOneWidget);
    expect(api.graded, 0, reason: 'ponavljanje je ocenjeno');
    // The line's own move went on the board anyway: carrying on from a move
    // that is not in the line would be rehearsing a different line.
    expect(find.text('1.e4 c5 2.d4'), findsOneWidget);
  });

  /// The same line, but the student kept two moves in the position it opens
  /// in: 1...c5 is what this line walks and 1...e5 is theirs as well.
  DrillLine forkedLine() => DrillLine(
        rootPath: const ['e4'],
        startFen: fenAfter(['e4']),
        prefix: const [
          LineMove(
            uci: 'c7c5',
            san: 'c5',
            mine: true,
            role: 'alternate',
            alts: [LineAlternative(uci: 'e7e5', san: 'e5')],
          ),
          LineMove(uci: 'd2d4', san: 'd4', mine: false),
        ],
        question: DrillItem(
          fen: fenAfter(['e4', 'c5', 'd4']),
          fresh: true,
          repetitions: 0,
          moves: 1,
          path: const ['c5', 'd4'],
        ),
        stats: const DrillStats(positions: 6, due: 1, known: 2, fresh: 3),
      );

  testWidgets('a line through an alternate says so before it asks',
      (tester) async {
    // Otherwise the rehearsal is a guess. A position where two of the
    // student's own moves are right and only one continues this line asks
    // "play the move you chose" and means one of them.
    final api = _FakeApi()..line = forkedLine();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    expect(find.textContaining('ide kroz alternativu'), findsOneWidget);
  });

  testWidgets('and a line through the main move says nothing', (tester) async {
    final api = _FakeApi()..line = morraLine();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    expect(find.textContaining('ide kroz alternativu'), findsNothing);
  });

  testWidgets('another move of their own is named as theirs, not as a miss',
      (tester) async {
    // Right chess in the wrong line. Reported in the same orange as a blunder,
    // it teaches a student to distrust a move they themselves chose — and
    // nothing in the repertoire is worth that.
    final api = _FakeApi()..line = forkedLine();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    await play(tester, 'e7', 'e5');

    expect(find.textContaining('I e5 je vaš potez'), findsOneWidget);
    expect(find.textContaining('ova linija vežba c5'), findsOneWidget);
    expect(find.textContaining('U ovoj liniji ide'), findsNothing);
    expect(api.graded, 0, reason: 'ponavljanje je ocenjeno');
    // And the line went on through the move it walks, as it always did.
    expect(find.text('1.e4 c5 2.d4'), findsOneWidget);
  });

  testWidgets("a move that is nobody's is still just wrong", (tester) async {
    final api = _FakeApi()..line = forkedLine();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    await play(tester, 'd7', 'd6');

    expect(find.textContaining('U ovoj liniji ide c5'), findsOneWidget);
    expect(find.textContaining('je vaš potez'), findsNothing);
  });

  testWidgets("the line's move is drawn while it is alone on the board",
      (tester) async {
    // The correction used to be invisible: both plies landed in one frame, so
    // a piece appeared on a square nothing had been seen going to. This is the
    // beat in which it is visible.
    final api = _FakeApi()..line = morraLine();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    final finder = find.byType(ChessBoardWithOverlay);
    final widget = tester.widget<ChessBoardWithOverlay>(finder);
    final rect = tester.getRect(finder);
    final square = widget.boardSize / 8;
    Offset at(String name) {
      final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
      final col =
          widget.boardOrientation == PlayerColor.black ? 7 - file : file;
      final row =
          widget.boardOrientation == PlayerColor.black ? rank : 7 - rank;
      return rect.topLeft + Offset((col + 0.5) * square, (row + 0.5) * square);
    }

    await tester.tapAt(at('e7'));
    await tester.pumpAndSettle();
    await tester.tapAt(at('e5'));
    await tester.pumpAndSettle();

    final arrows = tester.widget<ChessBoardWithOverlay>(finder).arrows;
    expect(arrows, hasLength(1));
    expect(arrows.single.from, 'c7');
    expect(arrows.single.to, 'c5');

    // And it is gone once the opponent's answer has landed on top of it.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(tester.widget<ChessBoardWithOverlay>(finder).arrows, isEmpty);
  });

  testWidgets('a fork offers the other road, and only a fork does',
      (tester) async {
    // Standing in front of your own main move, being drilled down the
    // alternative, with no way to say "the other one" — the queue decided and
    // the other road came round when its positions fell due.
    final plain = _FakeApi()..line = morraLine();
    await pump(tester, plain,
        rootFen: fenAfter(['e4']), rootPath: const ['e4']);
    expect(find.text('Druga odluka'), findsNothing);

    final api = _FakeApi()..line = forkedLine();
    await pump(tester, api,
        key: const ValueKey('racva'),
        rootFen: fenAfter(['e4']),
        rootPath: const ['e4']);
    expect(find.text('Druga odluka'), findsOneWidget);
  });

  testWidgets('choosing the other road asks for the line through it',
      (tester) async {
    final api = _FakeApi()..line = forkedLine();
    api.linesByVia['e7e5'] = DrillLine(
      rootPath: const ['e4'],
      startFen: fenAfter(['e4', 'e5']),
      prefix: const [],
      question: DrillItem(
        fen: fenAfter(['e4', 'e5']),
        fresh: true,
        repetitions: 0,
        moves: 1,
        path: const ['e5'],
      ),
      stats: const DrillStats(positions: 2, due: 0, known: 0, fresh: 2),
    );
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    // The move is named nowhere until it is asked for — the rehearsal is not
    // graded, but with two decisions kept, naming one gives away the other.
    expect(find.textContaining('Vežbaj e5'), findsNothing);

    await tester.tap(find.text('Druga odluka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vežbaj e5'));
    await tester.pumpAndSettle();

    expect(api.lastViaFen, fenAfter(['e4']));
    expect(api.lastViaUci, 'e7e5');
    // Nothing under that move need be due: asking for a road is reason enough
    // to walk it, and practising early writes nothing down.
    expect(api.lastAhead, true);
    // And the screen says which road it is on, with the way back.
    expect(find.textContaining('Vežbate liniju kroz e5'), findsOneWidget);
    expect(find.text('Nazad na red'), findsOneWidget);

    await tester.tap(find.text('Nazad na red'));
    await tester.pumpAndSettle();
    expect(api.lastViaUci, isNull);
    expect(api.lastAhead, false);
  });

  testWidgets('the chosen road names its move at the fork', (tester) async {
    // The bug this exists for: above a fork both roads read exactly the same —
    // the board, the breadcrumb, the move count. A student who asked for the d4
    // line was handed it, shown the position they were already looking at, and
    // asked to play "the move you chose". It worked and could not be seen
    // working, which is the same thing as not working.
    final api = _FakeApi()..line = forkedLine();
    api.linesByVia['e7e5'] = DrillLine(
      rootPath: const ['e4'],
      startFen: fenAfter(['e4']),
      // The same prefix shape as the road not taken: one move of theirs out of
      // the same position, and nothing on screen to tell the two apart.
      prefix: const [
        LineMove(
          uci: 'e7e5',
          san: 'e5',
          mine: true,
          role: 'primary',
          alts: [LineAlternative(uci: 'c7c5', san: 'c5')],
        ),
        LineMove(uci: 'g1f3', san: 'Nf3', mine: false),
      ],
      question: DrillItem(
        fen: fenAfter(['e4', 'e5', 'Nf3']),
        fresh: true,
        repetitions: 0,
        moves: 1,
        path: const ['e5', 'Nf3'],
      ),
      stats: const DrillStats(positions: 2, due: 1, known: 0, fresh: 1),
    );
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    await tester.tap(find.text('Druga odluka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vežbaj e5'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ide kroz e5 — odigrajte ga'), findsOneWidget);
    // And the "one of your moves is not this one" warning is gone: they named
    // the move a moment ago, so hedging about it says less than nothing.
    expect(find.textContaining('ide kroz alternativu'), findsNothing);
  });

  testWidgets('a road with nothing behind it says so, and lets you off it',
      (tester) async {
    // The empty screen is drawn instead of the panel that carries the road and
    // the way back off it, so this used to strand the student on a road they
    // could neither see nor leave — under a sentence about the whole
    // repertoire that was a fact about one move.
    final api = _FakeApi()..line = forkedLine();
    api.linesByVia['e7e5'] = const DrillLine(
      reason: 'nothing-due',
      stats: DrillStats(positions: 6, due: 0, known: 2, fresh: 0),
    );
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    await tester.tap(find.text('Druga odluka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vežbaj e5'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Iza poteza e5 ništa nije na redu'),
        findsOneWidget);
    expect(find.text('Ništa nije na redu.'), findsNothing);
    expect(find.text('Nazad na red'), findsOneWidget);

    await tester.tap(find.text('Nazad na red'));
    await tester.pumpAndSettle();
    expect(api.lastViaUci, isNull);
  });

  testWidgets('another line is a different line', (tester) async {
    // `nextItem` is a deterministic `ORDER BY due_at LIMIT 1` and skipping
    // writes nothing down, so this button used to hand back exactly what it
    // was asked to take away.
    final api = _FakeApi()..line = morraLine();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    await tester.tap(find.text('Druga linija'));
    await tester.pumpAndSettle();

    expect(api.lastExclude, [fenKeyOf(morraLine().question!.fen)]);
  });

  testWidgets('and the pile is turned over rather than declared empty',
      (tester) async {
    // Skipping is a shuffle, not a deletion. "Ništa nije na redu" after
    // refusing everything is a lie told by the skip button.
    final api = _FakeApi()..line = morraLine();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    // With the only question refused the server has nothing left to give.
    api.line = const DrillLine(
      reason: 'nothing-due',
      stats: DrillStats(positions: 6, due: 0, known: 2, fresh: 3),
    );
    final before = api.lineCalls;

    await tester.tap(find.text('Druga linija'));
    await tester.pumpAndSettle();

    // Two calls, not one: the empty answer was asked again with a clean pile,
    // and that second ask carried no refusals.
    expect(api.lineCalls, before + 2);
    expect(api.lastExclude, isEmpty);
  });

  testWidgets('the rehearsal can be skipped', (tester) async {
    // Worth having and not a toll gate.
    final api = _FakeApi()..line = morraLine();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    await tester.tap(find.text('Preskoči ponavljanje'));
    await tester.pumpAndSettle();

    expect(find.text('Šta igrate crnim?'), findsOneWidget);
    expect(find.text('1.e4 c5 2.d4 cxd4 3.c3'), findsOneWidget);
  });

  testWidgets('a rehearsal that starts where the student knows says so',
      (tester) async {
    // Twelve plies of rehearsal to reach one question is how a drill stops
    // being opened — and a short one is something the student earned, so it is
    // a different sentence from "we start at the beginning".
    final api = _FakeApi()
      ..line = morraLine(startKnown: true, startPath: const ['c5', 'd4']);
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    expect(find.textContaining('dokle znate napamet'), findsOneWidget);
  });

  testWidgets('a line that could not be read falls back, and says so',
      (tester) async {
    // "We could not work out the line" must not be shown as "here is your
    // question, cold" with nothing said. The drill still works; the sentence is
    // there so a broken walk is noticed rather than lived with.
    final api = _FakeApi();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    expect(api.lineCalls, 1);
    expect(api.loads, 1);
    expect(find.text('Šta igrate crnim?'), findsOneWidget);
    expect(find.textContaining('bez ponavljanja'), findsOneWidget);
  });

  testWidgets('an empty branch says it is the branch that is empty',
      (tester) async {
    // The block. "Nothing here" about one branch and "nothing at all" are
    // different sentences, and the student asked about a branch.
    final api = _FakeApi()
      ..line = const DrillLine(
        reason: 'nothing-built',
        stats: DrillStats(positions: 0, due: 0, known: 0, fresh: 0),
      );
    await pump(tester, api,
        rootFen: fenAfter(['e4']),
        rootPath: const ['e4'],
        fromFen: fenAfter(['e4', 'c5', 'd4']));

    expect(api.lastFromFen, fenAfter(['e4', 'c5', 'd4']));
    expect(find.text('U ovoj grani nema šta da se vežba.'), findsOneWidget);
  });

  testWidgets('the rehearsal fits a 360 dp phone', (tester) async {
    // A release build paints no overflow stripes; in a test build it throws.
    final api = _FakeApi()..line = morraLine();
    await pump(tester, api,
        size: const Size(360, 640),
        rootFen: fenAfter(['e4']),
        rootPath: const ['e4']);
    expect(tester.takeException(), isNull);

    await play(tester, 'c7', 'c5');
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing due in a branch says when it comes back',
      (tester) async {
    // One position, drilled once, scheduled for tomorrow. The screen used to
    // say only that nothing was due, which reads as "this branch cannot be
    // practised" — and that is exactly how it was read the first time.
    final api = _FakeApi()
      ..line = DrillLine(
        reason: 'nothing-due',
        stats: DrillStats(
          positions: 1,
          due: 0,
          known: 0,
          fresh: 0,
          nextDueAt: DateTime.now().add(const Duration(days: 1)),
        ),
      );
    await pump(tester, api, rootFen: smithMorra, fromFen: smithMorra);

    expect(find.text('U ovoj grani ništa nije na redu.'), findsOneWidget);
    expect(find.textContaining('Sledeća se vraća sutra'), findsOneWidget);
    expect(find.text('Vežbaj ipak'), findsOneWidget);
  });

  testWidgets('an empty branch is not offered a practice run', (tester) async {
    // Nothing was ever built there, so there is nothing to run early either.
    final api = _FakeApi()
      ..line = const DrillLine(
        reason: 'nothing-built',
        stats: DrillStats(positions: 0, due: 0, known: 0, fresh: 0),
      );
    await pump(tester, api, rootFen: smithMorra, fromFen: smithMorra);

    expect(find.text('Vežbaj ipak'), findsNothing);
  });

  testWidgets('practising ahead is judged and not written down',
      (tester) async {
    // What makes the button safe to offer. A position run through five times in
    // one evening must not come back in a month on the strength of it.
    final api = _FakeApi()
      ..line = const DrillLine(
        reason: 'nothing-due',
        stats: DrillStats(positions: 1, due: 0, known: 0, fresh: 0),
      )
      ..aheadLine = DrillLine(
        question: const DrillItem(
            fen: smithMorra, fresh: false, repetitions: 2, moves: 1),
        ahead: true,
        stats: const DrillStats(positions: 1, due: 0, known: 0, fresh: 0),
      );
    await pump(tester, api, rootFen: smithMorra, fromFen: smithMorra);

    await tester.tap(find.text('Vežbaj ipak'));
    await tester.pumpAndSettle();
    expect(api.lastAhead, true);
    expect(find.text('Šta igrate crnim?'), findsOneWidget);

    await play(tester, 'b8', 'c6');

    expect(api.lastPractice, true);
    expect(find.textContaining('ocena se ne upisuje'), findsOneWidget);
    // And no promise of a return date, because nothing was stored.
    expect(find.textContaining('Vraća se za'), findsNothing);

    await walkOn(tester);
    expect(api.lastPractice, true,
        reason: 'ostaje van rasporeda i posle šetnje');
  });

  group('branches and sparring', () {
    /// The branch opens on the position this drill actually asks about: the
    /// Smith-Morra accepted, Black to move. A branch whose first position is
    /// the *opponent's* turn would be a run the student cannot play.
    const branchFen = smithMorra;
    final branchKey = smithMorra.split(' ').take(4).join(' ');

    _FakeApi withBranch({List<String> dueKeys = const []}) => _FakeApi()
      ..branches = [
        DrillBranch(
          fen: branchFen,
          san: 'e4 c5',
          path: const ['e4', 'c5'],
          positions: 4,
          due: dueKeys.length,
          known: 1,
          dueKeys: dueKeys,
        ),
      ];

    Future<void> openPicker(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Izaberi granu'));
      await tester.pumpAndSettle();
    }

    Future<void> startRun(WidgetTester tester) async {
      await openPicker(tester);
      await tester.tap(find.byTooltip('Odigraj granu do kraja'));
      await tester.pumpAndSettle();
    }

    testWidgets('the drill can be pointed at one branch from inside it',
        (tester) async {
      // `fromFen` worked from the day it was written, but only somebody coming
      // through the build screen or the radar could reach it: opening the drill
      // gave you the whole colour and no way to say otherwise.
      final api = withBranch();
      await pump(tester, api, rootFen: smithMorra);

      await openPicker(tester);
      expect(find.text('Ceo repertoar'), findsOneWidget);
      expect(find.text('e4 c5'), findsOneWidget);
      expect(find.textContaining('dospelo 0 od 4'), findsOneWidget);

      await tester.tap(find.text('e4 c5'));
      await tester.pumpAndSettle();

      expect(api.lastFromFen, branchFen);
    });

    testWidgets('and pointed back at the whole repertoire', (tester) async {
      final api = withBranch();
      await pump(tester, api, rootFen: smithMorra, fromFen: branchFen);

      await openPicker(tester);
      await tester.tap(find.text('Ceo repertoar'));
      await tester.pumpAndSettle();

      expect(api.lastFromFen, isNull);
    });

    testWidgets('a run opens on the branch and says so', (tester) async {
      final api = withBranch();
      await pump(tester, api, rootFen: smithMorra);
      await startRun(tester);

      // The board opens on the branch rather than on whatever was due
      // elsewhere, and the row says a run is happening — a board that simply
      // keeps answering looks the same as the ordinary drill, and the two are
      // graded differently.
      expect(find.textContaining('Sparing: e4 c5'), findsOneWidget);
    });

    testWidgets('a position that was due is written down', (tester) async {
      final api = withBranch(dueKeys: [branchKey]);
      await pump(tester, api, rootFen: smithMorra);
      await startRun(tester);

      await play(tester, 'b8', 'c6');
      await tester.pumpAndSettle();
      // The run waits before playing on, so the reply can be seen. A bare
      // delay schedules no frame, which is why it has to be pumped out by hand
      // or the binding reports a timer outliving the tree.
      await tester.pump(const Duration(seconds: 1));

      expect(api.answers.single.fen, branchFen);
      expect(api.answers.single.practice, false,
          reason: 'pozicija koja je dospela ide u raspored');
    });

    testWidgets('and one that was not is only practised', (tester) async {
      // The rule the whole run rests on. A branch replayed with every position
      // scored would push the schedule out on the strength of moves nobody had
      // to remember cold — the same reason the rehearsal's prefix is not
      // graded, and the reason a run is safe to play twice in an evening.
      final api = withBranch();
      await pump(tester, api, rootFen: smithMorra);
      await startRun(tester);

      await play(tester, 'b8', 'c6');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(api.answers.single.practice, true);
    });

    testWidgets('a branch that runs out says so and ends the run',
        (tester) async {
      // A wrong or unprepared position stops the run where it happened: that
      // position is the whole reason the run was worth playing, and hurrying
      // past it at the same speed as the rest is the one moment the screen
      // should not.
      final api = _FakeApi(outcomeFor: 'unprepared')
        ..branches = [
          const DrillBranch(
            fen: branchFen,
            san: 'e4 c5',
            path: ['e4', 'c5'],
            positions: 4,
            due: 0,
          ),
        ];
      await pump(tester, api, rootFen: smithMorra);
      await startRun(tester);

      await play(tester, 'b8', 'c6');
      await tester.pumpAndSettle();

      expect(find.textContaining('Dovde ide grana'), findsOneWidget);
      expect(find.text('Druga grana'), findsOneWidget);
    });
  });
}
