import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
// `hide Color`: the board package re-exports the chess package, whose `Color`
// is a piece colour. Without this, `Color` in this file means black-or-white
// instead of a paint colour, and the error it produces names two files that
// look identical.
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;

import 'package:chess_app/features/repertoire/line_text.dart';
import 'package:chess_app/features/repertoire/widgets/opening_banner.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/move_tree.dart' show ChessArrow;
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/speakable_info.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// Being asked what you decided to play, until you no longer have to think.
///
/// The questions come from the same schedule homework uses — SM-2, the one
/// algorithm, in `spacedRepetitionService` — but nobody is asked to grade
/// themselves here. The answer is objective, because it is the student's own
/// decision written down, so remembering it is a pass, needing to look is a
/// weaker pass, and playing something else is a miss even when it is perfectly
/// good chess. The drill asks about a decision, not about chess.
///
/// **It costs nothing.** No Lichess request is made at any point: the
/// opponent's replies come out of the book stored while the position was built.
/// Somebody who has spent their allowance, or never had a token at all, can
/// still practise everything they own.
///
/// **The opponent stays inside what was prepared.** Its move is drawn by how
/// often it is really played, out of the replies the student covered — never
/// out of the tail beyond them. It used to be the other way round, so that
/// meeting an uncovered move showed the student the edge of their preparation;
/// the owner asked for that gone on 1.9.2026, and the line walk had never
/// rehearsed such a move anyway.
///
/// The door back into building survives, and is the honest half of what the
/// surprise was for: a position you covered and never decided about comes back
/// as `unprepared`, with an offer to build it. That is a hole in the
/// repertoire rather than a hole in the book.
///
/// **A line, not a photograph.** With a [rootFen] the question arrives at the
/// end of the line that leads to it: the student plays their own moves from the
/// start and the opponent's answers come back, until the board is standing in
/// the position that is due. The replay begins at the deepest position they
/// already know cold — twelve plies of rehearsal to reach one question is how a
/// drill stops being opened — and **the rehearsed moves are not graded**,
/// because a prefix is played many times a day on the way to whatever is due
/// below it.
class RepertoireDrillScreen extends StatefulWidget {
  const RepertoireDrillScreen({
    super.key,
    required this.name,
    required this.color,
    this.rootFen,
    this.rootPath = const [],
    this.fromFen,
    this.minRating,
    this.gateUci,
    this.api,
    this.onBuildHere,
    this.ids,
    this.breadth,
  });

  final String name;

  /// 'w' or 'b' — the side whose decisions are being asked about.
  final String color;

  /// The repertoire's starting position. Without it the drill still works, one
  /// bare position at a time — which is what it did before lines existed, and
  /// what it falls back to when the walk cannot be read.
  final String? rootFen;

  /// The moves that led to [rootFen], so the line reads from move one.
  final List<String> rootPath;

  /// One branch to practise, rather than the whole repertoire. The ten
  /// positions built yesterday are what somebody sits down to drill, and the
  /// rest of the repertoire is in the way.
  final String? fromFen;

  final int? minRating;

  /// The move this repertoire goes through at its root — its **gate**.
  ///
  /// Two repertoires can start from the same position and mean two different
  /// openings: after 1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5, one plays 4.b4 and the other
  /// 4.0-0. The moves stay in one graph — a position reached both ways is one
  /// position — and this narrows the **view** to one of them, so the tree, the
  /// queue and the drill are about one opening.
  ///
  /// Null is every repertoire with no twin, and behaves exactly as before.
  final String? gateUci;

  final RepertoireApiService? api;

  /// Called with a position the student has not prepared, so the screen above
  /// can offer to build it instead of leaving them stuck.
  final void Function(String fen)? onBuildHere;

  final List<int>? ids;

  /// The repertoire's width, for a session that runs on one. A combined
  /// session leaves it null: the server reads each door's width from its row.
  final String? breadth;

  @override
  State<RepertoireDrillScreen> createState() => _RepertoireDrillScreenState();
}

class _RepertoireDrillScreenState extends State<RepertoireDrillScreen> {
  final ChessBoardController _boardController = ChessBoardController();

  late final RepertoireApiService _api = widget.api ?? RepertoireApiService();

  String? _fen;
  String? _lastMoveFrom;
  String? _lastMoveTo;
  DrillStats _stats =
      const DrillStats(positions: 0, due: 0, known: 0, fresh: 0);
  bool _loading = true;
  int _drafts = 0;
  bool _busy = false;

  /// Set once the student has asked to be shown the answer. The next answer is
  /// then graded as recognised rather than remembered.
  RepertoireMove? _revealed;

  /// The line being rehearsed, null when the drill is asking bare positions.
  DrillLine? _line;

  /// The moves left to replay, and how far through them the student is.
  List<LineMove> _prefix = const [];
  int _prefixAt = 0;

  /// The board during the rehearsal. Null once it is over, and then the board
  /// shows the question itself.
  String? _rehearsalFen;

  /// The moves of the rehearsal already played, for the breadcrumb.
  final List<String> _played = [];

  /// What to say about the last rehearsed move. The rehearsal is not graded, so
  /// this is a reminder rather than a verdict.
  String? _prefixNote;

  /// True when that note is about a move of the student's own — right chess in
  /// the wrong line. It is not a mistake and must not be painted as one.
  bool _prefixNoteMild = false;

  /// The line's own move, drawn on the board for the beat it is alone there.
  ///
  /// Without it the correction was invisible: both plies landed in one frame,
  /// so an enemy piece appeared on a square nothing had been seen going to.
  ChessArrow? _prefixArrow;

  /// Long enough to see the move, short enough that a six-move rehearsal is
  /// still a rehearsal and not a film.
  static const Duration _beat = Duration(milliseconds: 550);

  bool get _rehearsing => _prefixAt < _prefix.length;

  /// The next move the student is asked for, or null when the rehearsal is
  /// over. Found rather than indexed: `_prefixAt` lands on a move of theirs by
  /// construction, and an assumption that quietly holds is one nobody notices
  /// breaking.
  LineMove? get _nextMine {
    for (var i = _prefixAt; i < _prefix.length; i += 1) {
      if (_prefix[i].mine) return _prefix[i];
    }
    return null;
  }

  /// True when the move the rehearsal is about to ask for is one of the
  /// student's alternates and not their main move.
  ///
  /// Only for an alternate. Saying "there is a choice here" at every fork would
  /// name nothing, and naming the move would turn the rehearsal into a cutscene
  /// at exactly the positions worth rehearsing.
  bool get _alternateAhead {
    final next = _nextMine;
    return next != null && next.isFork && next.role != 'primary';
  }

  /// True when the rehearsal is standing at the fork whose road was chosen,
  /// and the move it wants is the one that was asked for.
  ///
  /// This is the moment the choice has to be visible. Above the fork the board
  /// and the breadcrumb read exactly the same down either road — the line
  /// diverges at the next move and not before — so a student who asked for the
  /// d4 line was handed it, shown a position identical to the one they were
  /// looking at, and asked to play "the move you chose" as though nothing had
  /// happened. The feature worked and could not be seen working.
  bool get _viaHere {
    final at = _rehearsalFen;
    final next = _nextMine;
    final viaFen = _viaFen;
    final viaUci = _viaUci;
    if (at == null || next == null || viaFen == null || viaUci == null) {
      return false;
    }
    return fenKeyOf(at) == fenKeyOf(viaFen) && next.uci == viaUci;
  }

  /// Set once the student has asked to practise a branch before it is due.
  ///
  /// Everything answered in this state is judged and then thrown away. That is
  /// what makes the button safe to offer: a position run through five times in
  /// one evening because somebody enjoyed themselves must not come back in a
  /// month on the strength of it.
  bool _ahead = false;

  /// The decision this session is walking through, when the student asked for
  /// one road at a fork rather than the one the schedule offered.
  ///
  /// A repertoire keeps more than one move in plenty of positions, and which of
  /// them a line goes through was the queue's to decide. Standing in front of
  /// your own main move and being drilled down the alternative, with no way to
  /// say "the other one", is the complaint this answers.
  String? _viaFen;
  String? _viaUci;
  String? _viaSan;

  /// The questions refused this session.
  ///
  /// `nextItem` is a deterministic `ORDER BY due_at LIMIT 1` and skipping
  /// writes nothing down, so "Druga linija" and "Preskoči" handed back exactly
  /// what was refused. They were escapes that escaped nowhere.
  final Set<String> _refused = {};

  /// The branch this session is walking, or null for the whole repertoire.
  ///
  /// Chosen here as well as handed in from the build screen: a repertoire is a
  /// handful of branches — what they play against your first move — and a
  /// session is one of them. One queue over the whole colour is right for a
  /// schedule and wrong for sitting down, because the ten positions that hang
  /// together are the ones worth meeting in a row.
  late String? _branchFen = widget.fromFen;
  String? _branchSan;

  /// The sparring run: one branch played from its start, the opponent
  /// answering by itself, to the end of what was prepared.
  ///
  /// **Only the positions that were due are graded.** A whole branch replayed
  /// with every position scored would push the schedule out on the strength of
  /// moves nobody had to remember cold — the same rule that keeps the line
  /// walk's prefix ungraded, and the reason this is safe to press twice.
  /// The verdict on the previous answer, carried into the next question.
  ///
  /// Walking on by itself takes the graded panel off the screen after a beat,
  /// and that panel is where the schedule is reported. A drill that quietly
  /// stops saying when a position comes back has lost the one thing it is
  /// keeping — so the sentence follows the walk instead of being replaced by
  /// it. Cleared as soon as there is a real verdict again.
  String? _lastVerdict;

  /// True once this line has been walked on past the position that was due.
  ///
  /// Everything below the question is a position the schedule did not ask for,
  /// so the answer goes up with `onlyIfDue` and the server writes it only if it
  /// really was due. Same rule as the sparring run's `dueKeys`, and the reason
  /// walking on is safe to do by itself.
  bool _walkedOn = false;

  bool _sparring = false;
  Set<String> _sparDue = const {};
  int _sparPlayed = 0;
  int _sparMissed = 0;

  /// Set when the run is over, and it is the only thing that says so.
  String? _sparNote;

  DrillAnswer? _answer;
  String? _playedSan;

  /// What the opponent replied, once it has been played on the board.
  String? _replySan;

  /// Where the line stands after that reply — the next question, if the
  /// student prepared one. Kept as a field rather than recomputed: the board is
  /// the one place that knows, and asking it twice invites the two to disagree.
  String? _lineFen;
  bool _replyCovered = true;

  bool get _forWhite => widget.color == 'w';
  PlayerColor get _orientation =>
      _forWhite ? PlayerColor.white : PlayerColor.black;

  @override
  void initState() {
    super.initState();
    _loadNext();
    _loadToday();
  }

  /// What has been practised since this reader's day started.
  ///
  /// Null until it answers, and null again if it cannot: „danas niste
  /// odvežbali nijednu poziciju" is a hard enough sentence to be told when it
  /// is true, and a failed request must not be able to say it.
  PracticeToday? _today;

  /// Midnight where the reader is. The server cannot work this out — it would
  /// tell a child in Belgrade at 01:00 that they had already practised
  /// tomorrow — so the client sends it.
  DateTime get _dayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _loadToday() async {
    if (AppSettingsService.instance.dailyTarget == 0) return;
    final today = await _api.practiceToday(
      since: _dayStart,
      color: widget.color,
    );
    if (!mounted || today == null) return;
    setState(() => _today = today);
  }

  /// What this sitting is about, in one line.
  ///
  /// „Vežbate: Benoni · grana e4 c5 · 18 pozicija · danas 4 od 10". The owner's
  /// ask — *„i drill, mora da bude jasno šta pokriva, koje linije"* — and the
  /// answer to a screen that put up a board and a question with nothing saying
  /// which of your openings it had chosen or how much of it was in scope.
  ///
  /// Every number here is already on the screen's own state. Nothing is asked
  /// of the server for it, and a part that is not known is left out rather
  /// than guessed: „18 pozicija" on a combined session whose stats have not
  /// arrived would be a number about nothing.
  Widget _scopeLine(BuildContext context) {
    final target = AppSettingsService.instance.dailyTarget;
    final parts = <String>[
      widget.name,
      if (_branchSan != null) 'grana $_branchSan' else 'ceo repertoar',
      if (_stats.positions > 0) '${_stats.positions} pozicija',
      if (_stats.due > 0) 'na redu ${_stats.due}',
    ];
    final done = _today?.positions;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      // `Wrap`: four fragments and a target do not fit on one line at 360 dp,
      // and a release build clips rather than warning.
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xxs,
        children: [
          Text(
            'Vežbate: ${parts.join(' · ')}',
            style: AppText.micro.copyWith(color: context.colors.textSecondary),
          ),
          if (target > 0 && done != null)
            Text(
              // The day's own line, said in what was done rather than in what
              // is left: a number that goes up is worth finishing, and one
              // that counts down is a debt.
              done >= target
                  ? 'danas $done — cilj ispunjen'
                  : 'danas $done od $target',
              style: AppText.micro.copyWith(
                color: done >= target
                    ? context.colors.success
                    : context.colors.accent,
              ),
            ),
        ],
      ),
    );
  }

  /// The branches still to run in this sitting, after the one on the board.
  ///
  /// Several branches ticked in the sheet are one session, and the server hands
  /// out a line for one branch at a time — so the rest wait here and the queue
  /// moves on when the current branch has nothing left to ask.
  List<DrillBranch> _branchQueue = [];

  /// Leaves the drill at the first position nobody has decided in.
  ///
  /// The drill cannot answer the question — it asks about decisions and a draft
  /// is the absence of one — so it hands the position to the screen that can.
  Future<void> _goBuildDrafts() async {
    final root = widget.rootFen;
    if (root == null || _busy) return;
    setState(() => _busy = true);
    final walk = await _api.unconfirmedPositions(
      color: widget.color,
      rootFen: root,
      rootPath: widget.rootPath,
      gateUci: widget.gateUci,
      breadth: widget.breadth,
      minRating: widget.minRating,
      limit: 1,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (walk == null) {
      AppFeedback.error(context, 'Nacrti nisu mogli da se pročitaju.');
      return;
    }
    if (walk.positions.isEmpty) {
      AppFeedback.info(context, 'Nema više nepotvrđenih poteza.');
      return;
    }
    widget.onBuildHere?.call(walk.positions.first.fen);
  }

  /// The branches, and what to do with one.
  ///
  /// Two actions per row on purpose: the queue and the run are different
  /// things. The queue asks what is due in that branch, in the order the
  /// schedule wants; the run plays the branch from its start, which is what
  /// somebody means by "let me see if I still know this line".
  Future<void> _pickBranch() async {
    final root = widget.rootFen;
    final ids = widget.ids;
    // One door or the other. A combined session has ids and no root, and the
    // sheet is the whole point of it — reading only [rootFen] here is how the
    // feature came back unreachable the first time.
    if ((root == null && ids == null) || _busy) return;
    setState(() => _busy = true);
    final branches = await _api.drillBranches(
      color: widget.color,
      rootFen: ids == null ? root : null,
      rootPath: ids == null ? widget.rootPath : const [],
      minRating: widget.minRating,
      gateUci: ids == null ? widget.gateUci : null,
      breadth: ids == null ? widget.breadth : null,
      ids: ids,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (branches.isEmpty) {
      AppFeedback.info(context,
          'Još nema grana — repertoar ima samo koren ili nijednu odluku.');
      return;
    }

    final picked =
        await showModalBottomSheet<({List<DrillBranch> branches, bool spar})>(
      context: context,
      backgroundColor: context.colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheet) => _BranchPickerSheet(
          branches: branches, isCombined: widget.ids != null),
    );

    if (!mounted || picked == null) return;
    if (picked.spar && picked.branches.isNotEmpty) {
      await _spar(picked.branches.first);
      return;
    }
    setState(() {
      _branchQueue = List.from(picked.branches);
      if (_branchQueue.isNotEmpty) {
        final b = _branchQueue.removeAt(0);
        _branchFen = b.fen;
        _branchSan = b.san;
      } else {
        _branchFen = null;
        _branchSan = null;
      }
      _sparring = false;
      _sparNote = null;
      _viaFen = null;
      _viaUci = null;
      _viaSan = null;
      _refused.clear();
    });
    await _loadNext(keepAhead: false);
  }

  /// Plays one branch from its start, to the end of what was prepared.
  ///
  /// No rehearsal and no queue: the board goes to the position the branch opens
  /// in and stays on the line. The opponent answers by itself out of the stored
  /// book, weighted by how often each reply is actually played — so the same
  /// branch runs differently twice, which is the point of sparring rather than
  /// reciting.
  Future<void> _spar(DrillBranch branch) async {
    setState(() {
      _branchFen = branch.fen;
      _branchSan = branch.san;
      _viaFen = null;
      _viaUci = null;
      _viaSan = null;
      _refused.clear();
      _sparring = true;
      _sparDue = branch.dueKeys.toSet();
      _sparPlayed = 0;
      _sparMissed = 0;
      _sparNote = null;
      _loading = false;
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _ahead = false;
      _line = null;
      _prefix = const [];
      _prefixAt = 0;
      _rehearsalFen = null;
      _prefixNote = null;
      _prefixNoteMild = false;
      _prefixArrow = null;
      _walkedOn = false;
      _lastVerdict = null;
      _answer = null;
      _playedSan = null;
      _replySan = null;
      _replyCovered = true;
      _revealed = null;
      _lineFen = null;
      _fen = branch.fen;
      _played
        ..clear()
        ..addAll(branch.path);
    });
    _boardController.loadFen(branch.fen);
  }

  /// The run is over: what happened, in one sentence.
  ///
  /// Said out loud rather than left to be inferred from a board that stopped
  /// moving — and it names the mistakes, because a run with three of them and a
  /// run with none must not end the same way.
  void _endSpar(String why) {
    setState(() {
      _sparNote = _sparMissed == 0
          ? '$why Odigrano $_sparPlayed, bez greške.'
          : '$why Odigrano $_sparPlayed, greške: $_sparMissed.';
      _sparring = false;
    });
  }

  /// Puts this question at the back of the pile and asks for another.
  ///
  /// Behind both "Druga linija" and "Preskoči", which is what they always
  /// claimed to do: without refusing anything, the next request asked the same
  /// deterministic queue the same question and got the same answer back.
  Future<void> _refuseAndNext() async {
    final fen = _fen;
    if (fen != null) _refused.add(fenKeyOf(fen));
    await _loadNext();
  }

  /// The other roads out of the fork the rehearsal is standing at.
  ///
  /// Behind a press rather than on the board, the way "Pokaži" is. The
  /// rehearsal is not graded, but naming the position's other move would give
  /// away the one it is about to ask for wherever the student kept exactly two
  /// — and looking is then something they did, not something that happened.
  Future<void> _pickFork() async {
    final at = _rehearsalFen;
    final fork = _nextMine;
    if (at == null || fork == null || !fork.isFork || _busy) return;

    final picked = await showModalBottomSheet<LineAlternative>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxs),
              child: Text('Druga odluka u ovoj poziciji',
                  style: AppText.bodyBold
                      .copyWith(color: sheet.colors.textPrimary)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text(
                'Vežbanje ide dalje kroz potez koji izaberete.',
                style: AppText.micro.copyWith(color: sheet.colors.textMuted),
              ),
            ),
            const Divider(height: 1),
            for (final alt in fork.alts)
              ListTile(
                dense: true,
                leading:
                    Icon(Icons.alt_route, size: 18, color: sheet.colors.accent),
                title: Text('Vežbaj ${alt.san}', style: AppText.bodyLarge),
                onTap: () => Navigator.pop(sheet, alt),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    if (!mounted || picked == null) return;
    setState(() {
      _viaFen = at;
      _viaUci = picked.uci;
      _viaSan = picked.san;
      // A different road is a different pile. What was refused on the old one
      // says nothing about this one.
      _refused.clear();
    });
    // Nothing under that move need be due — asking for a road is a reason to
    // walk it now, and practising early writes nothing down.
    _ahead = true;
    await _loadNext();
  }

  /// Back to whatever the schedule wants, from a chosen road.
  Future<void> _clearVia() async {
    setState(() {
      _viaFen = null;
      _viaUci = null;
      _viaSan = null;
      _refused.clear();
    });
    await _loadNext(keepAhead: false);
  }

  /// Practises a branch that is not due yet. Nothing is written down.
  Future<void> _practiseAhead() async {
    _ahead = true;
    await _loadNext();
  }

  Future<void> _loadNext({bool keepAhead = true}) async {
    if (!keepAhead) _ahead = false;
    setState(() {
      _loading = true;
      _answer = null;
      _playedSan = null;
      _replySan = null;
      _replyCovered = true;
      _revealed = null;
      _lineFen = null;
      _line = null;
      _prefix = const [];
      _prefixAt = 0;
      _rehearsalFen = null;
      _prefixNote = null;
      _prefixNoteMild = false;
      _prefixArrow = null;
      _walkedOn = false;
      _lastVerdict = null;
      _played.clear();
    });

    // A line when there is a repertoire to walk, and a bare position when there
    // is not. The fallback says so out loud rather than quietly turning into
    // the old screen: a walk that could not be read is a fault to notice, and
    // the drill is still worth having while somebody notices it.
    final root = widget.rootFen;
    final ids = widget.ids;
    if (root != null || ids != null) {
      var line = await _api.drillLine(
        color: widget.color,
        rootFen: ids == null ? root : null,
        rootPath: ids == null ? widget.rootPath : const [],
        minRating: widget.minRating,
        fromFen: _branchFen,
        viaFen: _viaFen,
        viaUci: _viaUci,
        exclude: _refused.toList(),
        ahead: _ahead,
        gateUci: ids == null ? widget.gateUci : null,
        breadth: ids == null ? widget.breadth : null,
        ids: ids,
      );
      if (!mounted) return;
      // Skipping is a shuffle, not a deletion. Once everything has been
      // refused the pile is turned over rather than the screen saying nothing
      // is due — which would be a lie told by the skip button.
      if (line != null && !line.hasQuestion && _refused.isNotEmpty) {
        _refused.clear();
        line = await _api.drillLine(
          color: widget.color,
          rootFen: ids == null ? root : null,
          rootPath: ids == null ? widget.rootPath : const [],
          minRating: widget.minRating,
          fromFen: _branchFen,
          viaFen: _viaFen,
          viaUci: _viaUci,
          ahead: _ahead,
          gateUci: ids == null ? widget.gateUci : null,
          ids: ids,
        );
        if (!mounted) return;
      }
      if (line != null) {
        // A branch with nothing left to ask ends the branch, not the sitting:
        // the next ticked branch takes the board and the load runs again.
        if (!line.hasQuestion && _branchQueue.isNotEmpty) {
          final next = _branchQueue.removeAt(0);
          _branchFen = next.fen;
          _branchSan = next.san;
          _refused.clear();
          return _loadNext(keepAhead: _ahead);
        }
        _startLine(line);
        return;
      }
    }

    final next = await _api.nextDrill(color: widget.color);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _stats = next.stats;
      _fen = next.item?.fen;
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _prefixNote = root == null && ids == null
          ? null
          : 'Linija nije mogla da se sastavi — pitanje ide bez ponavljanja.';
    });
    final fen = _fen;
    if (fen != null) _boardController.loadFen(fen);

    if (_stats.positions == 0 || _stats.due == 0) {
      final counts = await _api.unconfirmedCounts();
      if (mounted && counts != null) {
        setState(() {
          _drafts =
              widget.color == 'w' ? counts.w.positions : counts.b.positions;
        });
      }
    }
  }

  /// Puts up the line: the board at its start, the question waiting at the end.

  void _startLine(DrillLine line) {
    final question = line.question;
    setState(() {
      _loading = false;
      _line = line;
      _stats = line.stats;
      _fen = question?.fen;
      _prefix = line.prefix;
      _prefixAt = 0;
      _rehearsalFen = line.prefix.isEmpty ? null : line.startFen;
      _prefixNote = null;
      _prefixNoteMild = false;
      _prefixArrow = null;
      _lastMoveFrom = null;
      _lastMoveTo = null;
    });
    final fen = _rehearsalFen ?? _fen;
    if (fen != null) _boardController.loadFen(fen);
  }

  /// One move of the rehearsal — played, never graded.
  ///
  /// This is the rule the whole line drill rests on. The prefix is replayed
  /// many times a day on the way to whatever is due below it, and grading it
  /// would push those positions' intervals out on the strength of rehearsals
  /// the student never had to remember cold. Only the position at the end of
  /// the line is answered.
  ///
  /// A wrong move is not a failure either: the line's own move is played
  /// instead, and named. Carrying on from a move that is not in the line would
  /// be rehearsing a different line.
  ///
  /// **Three outcomes, not two.** The line's own move is right; *another move
  /// the student themselves chose* is right chess in the wrong line; anything
  /// else is a miss. Those first two used to read identically — an orange
  /// warning naming the move you did not play — so a student rehearsing an
  /// alternate line was told their own main move was a mistake. It is not, and
  /// nothing in the repertoire is worth teaching somebody to distrust less.
  ///
  /// **Shown in two beats.** The line's move and the opponent's answer used to
  /// land in a single `loadFen`, so a correction was never visible: the board
  /// simply changed, and a piece appeared on a square nothing had been seen
  /// going to. The move goes up alone first, with an arrow on it.
  Future<void> _rehearse(String from, String to, String promotion) async {
    final at = _rehearsalFen;
    if (at == null || _busy || !_rehearsing) return;

    final want = _prefix[_prefixAt];
    final board = chess.Chess.fromFEN(at);
    final isPromotion = _isPromotion(board, from, to);
    final piece = promotion.isEmpty ? 'q' : promotion;
    final ok = board.move({
      'from': from,
      'to': to,
      if (isPromotion) 'promotion': piece,
    });
    if (ok == false) {
      _boardController.loadFen(at);
      return;
    }
    final uci = isPromotion ? '$from$to$piece' : '$from$to';
    final playedSan = board.getHistory().last.toString();
    final right = uci == want.uci;
    final ownMove = !right && want.alts.any((a) => a.uci == uci);

    // The line's move goes on the board whatever was played, so the board is
    // never one move away from the line it is rehearsing.
    final walker = chess.Chess.fromFEN(at);
    walker.move({
      'from': want.uci.substring(0, 2),
      'to': want.uci.substring(2, 4),
      if (want.uci.length > 4) 'promotion': want.uci.substring(4, 5),
    });
    final afterMine = walker.fen;
    var cursor = _prefixAt + 1;
    final replies = <String>[];

    // And then the opponent's answers, until it is the student's move again.
    while (cursor < _prefix.length && !_prefix[cursor].mine) {
      final reply = _prefix[cursor];
      walker.move({
        'from': reply.uci.substring(0, 2),
        'to': reply.uci.substring(2, 4),
        if (reply.uci.length > 4) 'promotion': reply.uci.substring(4, 5),
      });
      replies.add(reply.san);
      cursor += 1;
    }

    setState(() {
      // The board is locked for the beat: the answers are coming and a move
      // played into the middle of them would be answering a position that is
      // about to stop existing.
      _busy = replies.isNotEmpty;
      _played.add(want.san);
      _prefixArrow = ChessArrow(
        from: want.uci.substring(0, 2),
        to: want.uci.substring(2, 4),
        colorCode: right ? 'G' : 'O',
      );
      _prefixNote = right
          ? null
          : ownMove
              ? 'I $playedSan je vaš potez — ali ova linija vežba '
                  '${want.san}.'
              : 'U ovoj liniji ide ${want.san}. Ponavljanje se ne ocenjuje.';
      _prefixNoteMild = ownMove;
      _lastMoveFrom = null;
      _lastMoveTo = null;
    });
    _boardController.loadFen(afterMine);

    if (replies.isNotEmpty) {
      final line = _line;
      await Future<void>.delayed(_beat);
      // Somebody may have loaded another line while the beat ran. Checked
      // against the line itself rather than a flag, because that is the thing
      // that would have changed.
      if (!mounted || !identical(_line, line) || _rehearsalFen != at) return;
    }

    setState(() {
      _busy = false;
      _played.addAll(replies);
      _prefixAt = cursor;
      _prefixArrow = null;
      _rehearsalFen = cursor < _prefix.length ? walker.fen : null;
    });
    _boardController.loadFen(_rehearsalFen ?? _fen ?? walker.fen);
  }

  /// Straight to the question, for somebody who does not want the rehearsal.
  void _skipRehearsal() {
    if (!_rehearsing) return;
    setState(() {
      _played.addAll(_prefix.skip(_prefixAt).map((m) => m.san));
      _prefixAt = _prefix.length;
      _rehearsalFen = null;
      _prefixNote = null;
      _prefixNoteMild = false;
      _prefixArrow = null;
      _lastMoveFrom = null;
      _lastMoveTo = null;
    });
    final fen = _fen;
    if (fen != null) _boardController.loadFen(fen);
  }

  /// The line up to whatever is on the board, numbered the way a book does it.
  String _lineText() {
    final line = _line;
    if (line == null) return '';
    final moves = [
      ...line.rootPath,
      ...line.startPath,
      ..._played,
    ];
    return numberedLine(
      moves,
      from: line.rootPath.isEmpty ? widget.rootFen : null,
    );
  }

  /// Continues the line from a position the drill walked into, rather than
  /// jumping somewhere else. Landing in an unprepared position is the point of
  /// the uncovered replies, so it stays on the board and offers the way out.
  void _continueAt(String fen, {String? verdict}) {
    // The two moves that got here go into the line, or the breadcrumb would
    // name a position two moves behind the board.
    final mine = _playedSan;
    final reply = _replySan;
    setState(() {
      // Past the position the schedule asked for. Everything answered from
      // here on is written down only if it was due in its own right.
      _walkedOn = true;
      _lastVerdict = verdict;
      if (mine != null) _played.add(mine);
      if (reply != null) _played.add(reply);
      _fen = fen;
      _answer = null;
      _playedSan = null;
      _replySan = null;
      _replyCovered = true;
      _revealed = null;
      _lineFen = null;
    });
    _boardController.loadFen(fen);
  }

  Future<void> _onMove(String from, String to, String promotion) async {
    if (_rehearsing) {
      await _rehearse(from, to, promotion);
      return;
    }
    final fen = _fen;
    if (fen == null || _busy || _answer != null) return;

    final board = chess.Chess.fromFEN(fen);
    final isPromotion = _isPromotion(board, from, to);
    final piece = promotion.isEmpty ? 'q' : promotion;
    final ok = board.move({
      'from': from,
      'to': to,
      if (isPromotion) 'promotion': piece,
    });
    if (ok == false) {
      _boardController.loadFen(fen);
      return;
    }

    final played = ChessBoardWithOverlay.lastMoveSquares(_boardController.game);
    setState(() {
      _lastMoveFrom = played?.from;
      _lastMoveTo = played?.to;
    });

    final san = board.getHistory().last.toString();
    final uci = isPromotion ? '$from$to$piece' : '$from$to';

    setState(() {
      _busy = true;
      _playedSan = san;
    });

    final graded = await _api.answerDrill(
      color: widget.color,
      fen: fen,
      uci: uci,
      revealed: _revealed != null,
      minRating: widget.minRating,
      // Judged and not stored, in two cases that are the same rule twice:
      // ahead of schedule, and a position met on the way through a branch that
      // was not itself due. A run scored at every position would push the
      // schedule out on the strength of moves nobody had to remember cold.
      practice: _ahead || (_sparring && !_sparDue.contains(fenKeyOf(fen))),
      // Below the question the schedule asked for nothing, so the server
      // writes this one only if it really was due. Same rule as the run's
      // `dueKeys`, kept where `due_at` is — the client cannot know.
      onlyIfDue: _walkedOn && !_sparring,
    );
    if (!mounted) return;

    if (graded == null) {
      setState(() {
        _busy = false;
        _playedSan = null;
      });
      _boardController.loadFen(fen);
      return;
    }

    // One more position practised, whether or not the schedule was told. Not
    // awaited: the verdict goes on screen now and the count catches up.
    _loadToday();

    // The board shows the line as it should have gone: the student's own move
    // when it was one of theirs, and their primary when it was not — carrying
    // on from a move they were just told is wrong would rehearse the mistake.
    final shown = graded.outcome == 'unknown' && graded.primary != null
        ? graded.primary!.uci
        : uci;
    final afterOwn = _fenAfter(fen, shown) ?? fen;
    var boardFen = afterOwn;
    String? replySan;
    if (graded.reply != null) {
      final replyBoard = chess.Chess.fromFEN(afterOwn);
      final played = replyBoard.move({
        'from': graded.reply!.substring(0, 2),
        'to': graded.reply!.substring(2, 4),
        if (graded.reply!.length > 4)
          'promotion': graded.reply!.substring(4, 5),
      });
      if (played != false) {
        replySan = replyBoard.getHistory().last.toString();
        boardFen = replyBoard.fen;
      }
    }

    setState(() {
      _busy = false;
      _answer = graded;
      _lastVerdict = null;
      _replySan = replySan;
      _replyCovered = graded.replyCovered;
      _lineFen = boardFen;
    });
    _boardController.loadFen(boardFen);

    if (_sparring) {
      await _sparStep(graded, boardFen);
      return;
    }
    await _walkOn(graded, boardFen);
  }

  /// On down the line by itself, after a right answer.
  ///
  /// The drill was agreed as a line walk, and a line walked one button press at
  /// a time is a quiz with an extra step. The sparring run already did this;
  /// the queue did not, and "Nastavi liniju" was the whole difference between
  /// them. Now the button is what is left when the walk *stops*.
  ///
  /// A mistake stops it where it happened — that position is the reason the
  /// line was worth playing, and hurrying past it is the one moment the screen
  /// must not hurry. So does the end of the book: with no reply there is
  /// nothing to walk on into, and the position after your own move is the
  /// opponent's to answer, not yours.
  ///
  /// And so does a reply nobody prepared. Being surprised is the one thing a
  /// book cannot do and the door back into building — walking straight past
  /// the sentence that says so, into a position with no answer to give, turns
  /// the best moment the drill has into a dead end reached at speed.
  Future<void> _walkOn(DrillAnswer graded, String boardFen) async {
    if (!_walksOn(graded)) return;

    // Twice the run's beat, because this panel says something the run's does
    // not: when the position comes back. A sentence nobody has time to read is
    // a sentence the drill has stopped saying.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted || _sparring || _lineFen != boardFen) return;

    final back = _whenBack(graded);
    _continueAt(
      boardFen,
      verdict: [
        graded.outcome == 'primary'
            ? 'Tačno — ${_playedSan ?? ''}'
            : 'I to je vaše — ${_playedSan ?? ''}',
        if (_replySan != null) 'protivnik $_replySan',
        if (back.isNotEmpty) back.trim().replaceAll('.', '').toLowerCase(),
      ].join(' · '),
    );
  }

  /// Whether this answer carries the line on by itself.
  ///
  /// Asked in two places — by the walk and by the button that is what is left
  /// when the walk does not happen — so it is one condition rather than two
  /// that have to agree.
  bool _walksOn(DrillAnswer graded) {
    final right = graded.outcome == 'primary' || graded.outcome == 'alternate';
    return right && graded.reply != null && graded.replyCovered;
  }

  /// One step of a run: count it, and either carry on or stop.
  ///
  /// Carrying on is automatic and only after a right answer. A wrong one stops
  /// the run where it happened — that position is the whole reason the run was
  /// worth playing, and scrolling past it at the same speed as the rest would
  /// be the one moment the screen should not hurry.
  Future<void> _sparStep(DrillAnswer graded, String boardFen) async {
    final right = graded.outcome == 'primary' || graded.outcome == 'alternate';
    setState(() {
      _sparPlayed += 1;
      if (!right) _sparMissed += 1;
    });

    if (graded.outcome == 'unprepared') {
      _endSpar('Dovde ide grana — dalje nema vašeg poteza.');
      return;
    }
    if (!right) return;
    if (graded.reply == null) {
      _endSpar('Grana odigrana do kraja.');
      return;
    }

    // Long enough to see what came back, short enough to feel like a game.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || !_sparring || _lineFen != boardFen) return;
    _continueAt(boardFen);
  }

  bool _isPromotion(chess.Chess board, String from, String to) {
    final piece = board.get(from);
    if (piece == null || piece.type != chess.PieceType.PAWN) return false;
    final rank = to.substring(1);
    return rank == '8' || rank == '1';
  }

  String? _fenAfter(String fen, String uci) {
    final board = chess.Chess.fromFEN(fen);
    final ok = board.move({
      'from': uci.substring(0, 2),
      'to': uci.substring(2, 4),
      if (uci.length > 4) 'promotion': uci.substring(4, 5),
    });
    return ok == false ? null : board.fen;
  }

  Future<void> _reveal() async {
    final fen = _fen;
    if (fen == null) return;
    setState(() => _busy = true);
    final move = await _api.revealDrill(color: widget.color, fen: fen);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _revealed = move;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Text('Vežbanje — ${widget.name}'),
        elevation: 0,
        actions: [
          // The branches, from the drill itself. `fromFen` worked from the day
          // it was written, but only somebody who came through the build screen
          // or the radar could reach it — opening the drill gave you the whole
          // colour and no way to say otherwise.
          IconButton(
            onPressed: _busy ? null : _pickBranch,
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Izaberi granu',
          ),
          const SpeechToggleButton(),
          const BoardViewMenu(arrows: true),
          // Bounded and scaled down because the speaker button above pushed
          // this bar one pixel over the edge of a 360 dp phone — measured, by
          // putting the pre-batch `Padding`/`Center` back and watching the
          // 360 dp test throw. A release build would have shown none of that:
          // it clips silently, and the counter would simply have been gone.
          Container(
            constraints: const BoxConstraints(maxWidth: 100),
            padding: const EdgeInsets.only(right: AppSpacing.md),
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _ahead
                    ? 'van rasporeda'
                    : 'na redu: ${_stats.due} · novo: ${_stats.fresh}',
                style: AppText.micro.copyWith(color: context.colors.textMuted),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_fen == null) return _buildEmpty(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = (constraints.maxWidth - 24).clamp(200.0, 420.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Deliberately unkeyed — see the note on the same widget in
              // repertoire_build_screen.dart. A key that changes as the drill
              // moves through a line resets the carried opening name on every
              // question, which is the one thing the banner is for.
              if (_fen != null) OpeningBanner(fen: _fen!),
              _scopeLine(context),
              Center(
                child: BoardWithCoordinates(
                  size: boardSize,
                  orientation: _orientation,
                  builder: (inner) => ChessBoardWithOverlay(
                    controller: _boardController,
                    boardOrientation: _orientation,
                    boardSize: inner,
                    // Locked once the answer is in, and open during the
                    // rehearsal — the rehearsal is played by the student, which
                    // is the whole difference between it and a cutscene.
                    isAllowedToMove: !_busy && _answer == null,
                    isDrawingMode: false,
                    drawingStartSquare: null,
                    arrows: (!AppSettingsService.instance.showChosenMoveArrow ||
                            _prefixArrow == null)
                        ? const []
                        : [_prefixArrow!],
                    engineArrows: const [],
                    lastMoveFrom: _lastMoveFrom,
                    lastMoveTo: _lastMoveTo,
                    onMove: _onMove,
                    onSquareTapForDrawing: (_) {},
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildSparLine(context),
              _buildViaLine(context),
              _buildPrompt(context),
              const SizedBox(height: 10),
              _buildControls(context),
            ],
          ),
        );
      },
    );
  }

  /// The run's own line: which branch, how far, and how it ended.
  ///
  /// One row, and it is the only place that says a run is happening — a board
  /// that simply keeps answering looks the same as the ordinary drill, and the
  /// two are graded differently.
  Widget _buildSparLine(BuildContext context) {
    final note = _sparNote;
    if (!_sparring && note == null) return const SizedBox.shrink();
    final branch = _branchSan ?? 'grana';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(note == null ? Icons.sports_kabaddi : Icons.flag_outlined,
              size: 16,
              color: note == null
                  ? context.colors.accent
                  : context.colors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              note ??
                  'Sparing: $branch · odigrano $_sparPlayed'
                      '${_sparMissed > 0 ? ", greške: $_sparMissed" : ""}',
              style:
                  AppText.caption.copyWith(color: context.colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  /// The road the student chose, and the way back to the schedule.
  ///
  /// Said out loud because it changes what the drill is doing: the questions
  /// are no longer the ones that came up, and nothing answered under a chosen
  /// road is written down. A mode nobody can see they are in is a mode that
  /// looks like a bug.
  Widget _buildViaLine(BuildContext context) {
    final san = _viaSan;
    if (san == null || _sparring) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.alt_route, size: 16, color: context.colors.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Vežbate liniju kroz $san.',
                style: AppText.caption
                    .copyWith(color: context.colors.textPrimary)),
          ),
          TextButton(
            onPressed: _busy ? null : _clearVia,
            child: const Text('Nazad na red'),
          ),
        ],
      ),
    );
  }

  /// Where the board came from, when there is a line behind it.
  Widget _buildLine(BuildContext context) {
    final line = _lineText();
    if (line.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Text(line,
          style: AppText.caption.copyWith(color: context.colors.accent)),
    );
  }

  Widget _buildPrompt(BuildContext context) {
    final graded = _answer;
    if (_rehearsing) {
      final line = _line!;
      // Which of the student's moves this is, and how many there are. Counted
      // over their own moves only: the opponent's answers are not asked for.
      final mine = _prefix.where((m) => m.mine).length;
      final done = _prefix.take(_prefixAt).where((m) => m.mine).length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLine(context),
          Text('Ponovite liniju', style: AppText.bodyBold),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            line.startKnown
                // Earned, and said so: the rehearsal is short because the
                // opening moves are already known cold.
                ? 'Počinjemo odatle dokle znate napamet — potez ${done + 1} od '
                    '$mine do pitanja.'
                : 'Od početka repertoara — potez ${done + 1} od $mine do '
                    'pitanja.',
            style: AppText.caption.copyWith(color: context.colors.textMuted),
          ),
          // The road that was asked for, named. Nothing is given away: the
          // student chose this move by name a moment ago, and being asked to
          // guess it back is how the choice came to look like it had done
          // nothing at all.
          if (_viaHere) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Ova linija ide kroz ${_viaSan ?? ''} — odigrajte ga.',
              style: AppText.caption.copyWith(color: context.colors.accent),
            ),
          ],
          // Which of the student's decisions this line is walking, when there
          // is more than one to walk. Said *before* the move and without
          // naming it: a rehearsal at a fork where the line wants the alternate
          // is otherwise a guess, and playing your own main move there came
          // back as a mistake. Which move is still theirs to remember — that is
          // what the rehearsal is for.
          //
          // Not when the road was chosen: then the move has a name already, and
          // "one of your moves" beneath "play d4" says less than nothing.
          if (_alternateAhead && !_viaHere) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'U ovoj poziciji imate više svojih poteza — ova linija ide kroz '
              'alternativu, ne kroz glavni.',
              style: AppText.caption.copyWith(color: context.colors.info),
            ),
          ],
          if (_prefixNote != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _prefixNote!,
              style: AppText.caption.copyWith(
                color: _prefixNoteMild
                    ? context.colors.info
                    : context.colors.warning,
              ),
            ),
          ],
        ],
      );
    }

    if (graded == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLine(context),
          if (_lastVerdict != null) ...[
            SpeakableInfo(
              text: _lastVerdict!,
              autoSpeak: true,
              child: Text(_lastVerdict!,
                  style:
                      AppText.micro.copyWith(color: context.colors.textMuted)),
            ),
            const SizedBox(height: AppSpacing.xxs),
          ],
          SpeakableInfo(
            autoSpeak: true,
            text:
                '${_forWhite ? 'Šta igrate belim?' : 'Šta igrate crnim?'} ${_revealed == null ? 'Odigrajte potez koji ste izabrali za ovu poziciju.' : 'Vaš potez je ${_revealed!.san}. Odigrajte ga.'}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_forWhite ? 'Šta igrate belim?' : 'Šta igrate crnim?',
                    style: AppText.bodyBold),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  _revealed == null
                      ? 'Odigrajte potez koji ste izabrali za ovu poziciju.'
                      : 'Vaš potez je ${_revealed!.san}. Odigrajte ga.',
                  style: AppText.caption.copyWith(
                    color: _revealed == null
                        ? context.colors.textMuted
                        : context.colors.warning,
                  ),
                ),
              ],
            ),
          ),
          // Outside the spoken block on purpose: the voice says the question
          // and the line under it, and a speaker that visually encloses a
          // sentence it never reads is the drift this widget exists to avoid.
          if (_prefixNote != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _prefixNote!,
              style: AppText.caption.copyWith(
                color: _prefixNoteMild
                    ? context.colors.info
                    : context.colors.warning,
              ),
            ),
          ],
        ],
      );
    }

    final ({Color color, IconData icon, String title, String detail}) face =
        switch (graded.outcome) {
      'primary' => (
          color: context.colors.success,
          icon: Icons.check_circle_outline,
          title: 'Tačno — ${_playedSan ?? ''}',
          detail: _whenBack(graded),
        ),
      'alternate' => (
          color: context.colors.info,
          icon: Icons.alt_route,
          title: 'I to je vaše — ${_playedSan ?? ''}',
          detail: graded.primary == null
              ? _whenBack(graded)
              : 'Glavni potez vam je ${graded.primary!.san}. ${_whenBack(graded)}',
        ),
      'unprepared' => (
          color: context.colors.textMuted,
          icon: Icons.help_outline,
          title: 'Ovu poziciju niste pokrili',
          detail: 'Ovde nema vašeg poteza, pa nema ni ocene. '
              'Otvorite izgradnju i odlučite šta igrate.',
        ),
      _ => (
          color: context.colors.danger,
          icon: Icons.close,
          title: 'Nije to — ${_playedSan ?? ''}',
          detail: graded.primary == null
              ? _whenBack(graded)
              : 'Vaš potez je ${graded.primary!.san}. ${_whenBack(graded)}',
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(face.icon, size: 18, color: face.color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(face.title,
                  style: AppText.bodyBold.copyWith(color: face.color)),
            ),
          ],
        ),
        if (face.detail.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(face.detail,
              style:
                  AppText.caption.copyWith(color: context.colors.textPrimary)),
        ],
        if (graded.practice) ...[
          const SizedBox(height: 6),
          Text(
            'Vežba van rasporeda — ocena se ne upisuje, pa se raspored ove '
            'pozicije nije pomerio.',
            style: AppText.caption.copyWith(color: context.colors.textMuted),
          ),
        ],
        if (_replySan != null) ...[
          const SizedBox(height: 6),
          Text(
            _replyCovered
                ? 'Protivnik je odgovorio $_replySan.'
                : 'Protivnik je odgovorio $_replySan — to niste pokrili.',
            style: AppText.caption.copyWith(
              color: _replyCovered
                  ? context.colors.textMuted
                  : context.colors.warning,
            ),
          ),
        ],
      ],
    );
  }

  /// When the soonest position comes back, in words. Empty when nothing is
  /// scheduled at all, which is a different sentence again.
  String _backAgain() {
    final at = _stats.nextDueAt;
    if (at == null) {
      return 'Sve što ste izgradili vraća se na red kad dođe vreme. ';
    }
    final left = at.difference(DateTime.now());
    if (left.inMinutes <= 1) {
      return 'Sledeća se vraća za koji trenutak. ';
    }
    if (left.inHours < 1) {
      return 'Sledeća se vraća za ${left.inMinutes} minuta. ';
    }
    if (left.inHours < 20) {
      return 'Sledeća se vraća za ${left.inHours} sati. ';
    }
    // Rounded to whole days rather than truncated. SM-2 schedules in days, so
    // "tomorrow" arrives as twenty-three hours and something, and `inDays`
    // would report that as zero — a position due tomorrow reading as due today
    // is the one mistake this sentence must not make.
    final days = (left.inHours / 24).round();
    if (days <= 1) return 'Sledeća se vraća sutra. ';
    return 'Sledeća se vraća za $days dana. ';
  }

  /// When the position comes back, in words rather than in a number of days.
  String _whenBack(DrillAnswer graded) {
    final days = graded.intervalDays;
    if (days == null) return '';
    if (days == 0) return 'Vraća se za koji minut.';
    if (days == 1) return 'Vraća se sutra.';
    if (days < 7) return 'Vraća se za $days dana.';
    if (days < 30) {
      final weeks = (days / 7).round();
      return weeks == 1
          ? 'Vraća se za nedelju dana.'
          : 'Vraća se za $weeks nedelje.';
    }
    final months = (days / 30).round();
    return months == 1
        ? 'Vraća se za mesec dana.'
        : 'Vraća se za $months meseca.';
  }

  Widget _buildControls(BuildContext context) {
    final graded = _answer;
    // Wrap and not Row: three Serbian labels outgrow a 360 dp phone, and a
    // release build clips what does not fit without a word.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (_rehearsing) ...[
          // For somebody who wants the question and not the walk to it. The
          // rehearsal is worth having and must not be a toll gate.
          OutlinedButton.icon(
            onPressed: _busy ? null : _skipRehearsal,
            icon: const Icon(Icons.fast_forward, size: 18),
            label: const Text('Preskoči ponavljanje'),
          ),
          // The other road out of this fork. Only where there is one, and it
          // names nothing until it is pressed.
          if (_nextMine?.isFork ?? false)
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickFork,
              icon: const Icon(Icons.alt_route, size: 18),
              label: const Text('Druga odluka'),
            ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _refuseAndNext,
            icon: const Icon(Icons.skip_next, size: 18),
            label: const Text('Druga linija'),
          ),
        ] else if (_sparNote != null) ...[
          // The run is over. Another branch is the useful next thing, and the
          // queue is still there for whatever is due elsewhere.
          FilledButton.icon(
            onPressed: _busy ? null : _pickBranch,
            icon: const Icon(Icons.account_tree_outlined, size: 18),
            label: const Text('Druga grana'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _loadNext(keepAhead: false),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Nazad na red'),
          ),
        ] else if (graded == null) ...[
          OutlinedButton.icon(
            onPressed: _busy || _revealed != null ? null : _reveal,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Pokaži'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _refuseAndNext,
            icon: const Icon(Icons.skip_next, size: 18),
            label: const Text('Preskoči'),
          ),
        ] else ...[
          if (!graded.isPrepared && widget.onBuildHere != null)
            FilledButton.icon(
              onPressed: () => widget.onBuildHere!(_fen!),
              icon: const Icon(Icons.playlist_add, size: 18),
              label: const Text('Izgradi ovu poziciju'),
            ),
          // What is left of "Nastavi liniju" now that a right answer walks on
          // by itself: the offer to carry on from a mistake, once the right
          // move has been seen. Without a reply there is nothing to carry on
          // into — the position after your own move is the opponent's to
          // answer, and asking you for it was a bug of its own.
          if (_lineFen != null &&
              graded.isPrepared &&
              graded.reply != null &&
              !_walksOn(graded))
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _continueAt(_lineFen!),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Nastavi liniju'),
            ),
          FilledButton.icon(
            onPressed: _busy ? null : _loadNext,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Sledeća'),
          ),
        ],
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    // Two different empty states, and only one of them is good news. In a
    // branch the same two questions are asked about that branch alone, which is
    // why the counts come from the walk rather than from the whole colour.
    final nothingBuilt = _stats.positions == 0;
    final inBranch = _branchFen != null;
    // A chosen road that turns out to hold nothing. Its own sentence, because
    // "ništa nije na redu" reads as a fact about the repertoire when it is a
    // fact about one move — and this screen is drawn *instead of* the panel
    // that carries the road and the way back off it, so without this the
    // student is on a road they cannot see and cannot leave.
    final via = _viaSan;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(nothingBuilt ? Icons.menu_book_outlined : Icons.done_all,
                size: 40),
            const SizedBox(height: AppSpacing.md),
            Builder(builder: (context) {
              final text = via != null
                  ? (nothingBuilt
                      ? 'Iza poteza $via još nema šta da se vežba.'
                      : 'Iza poteza $via ništa nije na redu.')
                  : nothingBuilt
                      ? (inBranch
                          ? 'U ovoj grani nema šta da se vežba.'
                          : 'Još nema šta da se vežba.')
                      : (inBranch
                          ? 'U ovoj grani ništa nije na redu.'
                          : 'Ništa nije na redu.');
              return SpeakableInfo(
                text: text,
                child: Text(
                  text,
                  style: AppText.bodyBold,
                  textAlign: TextAlign.center,
                ),
              );
            }),
            const SizedBox(height: 6),
            Text(
              via != null
                  ? 'Taj potez je vaš, ali iza njega još nije izgrađena '
                      'linija. Otvorite izgradnju i uzmite protivnikove '
                      'odgovore na njega.'
                  : nothingBuilt
                      ? (inBranch
                          ? 'Ova grana je odsečena ili u njoj još nema vaših '
                              'poteza.'
                          : 'Prvo izgradite nekoliko pozicija — vežba pita ono što '
                              'ste vi izabrali.')
                      // When the next one comes back, not only that it will. A
                      // branch of one position, drilled once and scheduled for
                      // tomorrow, used to say nothing but "nothing is due" — which
                      // reads as "this branch cannot be practised".
                      : '${_backAgain()}Do sada znate ${_stats.known} od '
                          '${_stats.positions} pozicija.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
            // The draft review is about one repertoire's root. A combined
            // sitting has ids and no root, so the offer is left out rather
            // than pointed at a root that is not there.
            if (_drafts > 0 && widget.rootFen != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Još $_drafts nepotvrđenih nacrta čeka u ovom repertoaru.',
                style: AppText.caption.copyWith(color: context.colors.warning),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              // Deciding is building, so this leaves the drill rather than
              // opening a window inside it: the position, the book and the
              // engine are all on the build screen, and none of the three fits
              // in a sheet over a board.
              if (widget.onBuildHere != null)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _goBuildDrafts,
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Pregledaj nacrt'),
                ),
            ],
            // Where today stands, on the screen that would otherwise say
            // „ništa nije na redu" and stop. SM-2 is right about retention and
            // says nothing about habit: after two good answers a position is
            // six days away, and a child in their first week opens the app to
            // be told there is nothing to do. The target is the sentence that
            // turns that into something to finish.
            if (AppSettingsService.instance.dailyTarget > 0 &&
                _today != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _today!.positions >= AppSettingsService.instance.dailyTarget
                    ? 'Danas ste odvežbali ${_today!.positions} '
                        '${_today!.positions == 1 ? "poziciju" : "pozicija"} — '
                        'cilj je ispunjen.'
                    : 'Danas ste odvežbali ${_today!.positions} od '
                        '${AppSettingsService.instance.dailyTarget}. '
                        'Vežba van rasporeda se ne ocenjuje, ali se računa.',
                style: AppText.caption.copyWith(color: context.colors.accent),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            // Practising early is allowed, and it is allowed *because* nothing
            // is written down for it. Waiting a day is right for a schedule and
            // wrong for somebody who has just built ten positions and wants to
            // run them once.
            if (!nothingBuilt && via == null) ...[
              FilledButton.icon(
                onPressed: _busy ? null : _practiseAhead,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Vežbaj ipak'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            // The way off a road that led nowhere. This screen replaces the
            // panel the road is normally shown and left from, so without it the
            // only way back to the schedule is out of the drill entirely.
            if (via != null) ...[
              FilledButton.icon(
                onPressed: _busy ? null : _clearVia,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Nazad na red'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Nazad'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchPickerSheet extends StatefulWidget {
  const _BranchPickerSheet({required this.branches, required this.isCombined});
  final List<DrillBranch> branches;
  final bool isCombined;

  @override
  State<_BranchPickerSheet> createState() => _BranchPickerSheetState();
}

class _BranchPickerSheetState extends State<_BranchPickerSheet> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxs),
            // `Wrap`: a title and a button with a count in it are wider than
            // 328 dp together, and a release build clips rather than warns.
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Text('Šta vežbate?',
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.textPrimary)),
                if (_selectedIds.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      final selectedBranches = widget.branches
                          .where((b) => _selectedIds.contains(b.id))
                          .toList();
                      Navigator.pop(
                          context, (branches: selectedBranches, spar: false));
                    },
                    child: Text('Vežbaj izabrane (${_selectedIds.length})'),
                  ),
              ],
            ),
          ),
          // Said where the choice is made and before anything is ticked: the
          // reader who has just picked two openings may reasonably expect two
          // queues, and the schedule is one.
          if (widget.isCombined)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
              child: Text(
                'Pozicija koju oba otvaranja dostižu pita se jednom.',
                style: AppText.caption
                    .copyWith(color: context.colors.textSecondary),
              ),
            ),
          ListTile(
            dense: true,
            leading: Icon(Icons.all_inclusive,
                size: 18, color: context.colors.accent),
            title: Text('Ceo repertoar', style: AppText.bodyLarge),
            subtitle: Text('Sve grane pomešane, redom kojim raspored traži.',
                style: AppText.micro.copyWith(color: context.colors.textMuted)),
            onTap: () => Navigator.pop(
                context, (branches: const <DrillBranch>[], spar: false)),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // Keyed by [id] and never by [key]: two openings that both
                // start 1.e4 c5 share a key, and a list keyed by it drops one
                // of them while the count at the bottom still looks right.
                for (final branch in widget.branches)
                  ListTile(
                    key: ValueKey(branch.id),
                    dense: true,
                    // The checkbox gathers a session; the row still starts
                    // this branch on its own, the way it always has.
                    leading: Checkbox(
                      value: _selectedIds.contains(branch.id),
                      onChanged: (on) => setState(() {
                        if (on == true) {
                          _selectedIds.add(branch.id);
                        } else {
                          _selectedIds.remove(branch.id);
                        }
                      }),
                    ),
                    title: Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        Text(branch.san, style: AppText.bodyLarge),
                        if (branch.repertoire != null)
                          Text(
                            branch.repertoire!.name,
                            style: AppText.bodyLarge
                                .copyWith(color: context.colors.textMuted),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      'dospelo ${branch.due} od ${branch.positions}'
                      '${branch.known > 0 ? " · zna ${branch.known}" : ""}',
                      style: AppText.micro
                          .copyWith(color: context.colors.textMuted),
                    ),
                    // The run, beside the queue rather than instead of it.
                    trailing: IconButton(
                      tooltip: 'Odigraj granu do kraja',
                      icon: const Icon(Icons.play_circle_outline),
                      onPressed: () => Navigator.pop(
                          context, (branches: [branch], spar: true)),
                    ),
                    onTap: () => Navigator.pop(
                        context, (branches: [branch], spar: false)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
