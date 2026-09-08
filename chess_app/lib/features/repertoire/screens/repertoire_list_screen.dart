import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_coverage_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_drill_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_new_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_walkthrough_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_gate_picker.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// The repertoires a student has started, and the door to a new one.
///
/// A repertoire here is a **name for a starting position**, not a box that
/// holds moves: the moves belong to the student and their colour, so a second
/// repertoire that reaches the same position already knows what they play
/// there. That is why the card shows one count for every repertoire of the same
/// colour — flattering it would be lying about what was built.
class RepertoireListScreen extends StatefulWidget {
  const RepertoireListScreen({super.key, this.api, this.judge});

  /// Injected in tests, which have no server.
  final RepertoireApiService? api;
  final OpeningJudgeService? judge;

  @override
  State<RepertoireListScreen> createState() => _RepertoireListScreenState();
}

class _RepertoireListScreenState extends State<RepertoireListScreen> {
  late final RepertoireApiService _api = widget.api ?? RepertoireApiService();
  bool _loading = true;
  List<RepertoireSummary> _items = const [];

  /// How much each repertoire still has waiting, once it has been counted.
  /// Empty until then, and a card says nothing rather than guessing.
  Map<int, RepertoireProgress> _progress = const {};

  final Set<int> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _api.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
    // After the cards, never before them. This is a walk per repertoire —
    // about a third of a second each — and the list is what somebody opens to
    // choose where to work; it must be on screen while the numbers are still
    // being counted.
    final progress = await _api.progress(
      minRating: AppSettingsService.instance.repertoireMinRating,
    );
    if (!mounted || progress == null) return;
    setState(() {
      _progress = {for (final row in progress) row.id: row};
    });
  }

  /// A screen and not a dialog, because the position is chosen by playing the
  /// moves on a board — and a board inside an AlertDialog on a 360 dp phone is
  /// a board nobody can use.
  Future<void> _create() async {
    final made = await Navigator.of(context).push<RepertoireSummary>(
      MaterialPageRoute(builder: (_) => RepertoireNewScreen(api: _api)),
    );
    if (made == null || !mounted) return;
    await _load();
    if (!mounted) return;
    _open(made);
  }

  Future<void> _openDrafts(RepertoireSummary item) async {
    final walk = await _api.unconfirmedPositions(
      color: item.color,
      rootFen: item.rootFen,
      rootPath: item.rootPath,
      gateUci: item.viaUci,
      minRating: AppSettingsService.instance.repertoireMinRating,
      limit: 1,
    );
    if (!mounted) return;
    if (walk != null && walk.positions.isNotEmpty) {
      _open(item, at: walk.positions.first.fen);
    } else {
      _open(item);
    }
  }

  /// Opening a repertoire, and counting again on the way back.
  ///
  /// Everything that changes these numbers happens on the screen this pushes —
  /// a move kept, a draft confirmed, a branch cut. Without the reload the list
  /// went on showing what was true when the app started, which is the same
  /// staleness the banner had and reads worse here: this is the screen somebody
  /// uses to decide where the work is.
  void _open(RepertoireSummary item, {String? at}) {
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => RepertoireBuildScreen(
        name: item.name,
        id: item.id,
        color: item.color,
        rootFen: at ?? item.rootFen,
        // Only when we are opening the repertoire's own root. `at` is some
        // other position the reader jumped to, and the stored line does not
        // lead there — a breadcrumb built from it would name the wrong moves,
        // which is worse than showing none.
        rootPath: at == null ? item.rootPath : const [],
        // Same rule as the breadcrumb above, and for the same reason: the gate
        // is a move out of *this repertoire's root*. Jumping in at some other
        // position, there is no fork there for it to narrow, and applying it
        // would filter a position it says nothing about.
        gateUci: at == null ? item.viaUci : null,
        minRating: AppSettingsService.instance.repertoireMinRating,
        breadth: item.breadth,
        api: widget.api,
        judge: widget.judge,
        // Straight from the position on the board into practising that branch.
        // Building and drilling are still two doors — this one is opened from
        // inside, over the ten positions that were just made.
        onDrillHere: (fen) => _drill(item, from: fen),
      ),
    ))
        .then((_) {
      if (mounted) _load();
    });
  }

  /// Practising what was built. A separate door rather than a mode inside the
  /// build screen: building spends the reader's Lichess allowance and drilling
  /// spends nothing, and two things that cost so differently should not look
  /// like one button with a switch on it.
  /// The map of a repertoire: how far each of the opponent's answers has been
  /// taken.
  ///
  /// Reached from here rather than from inside the build screen, because it is
  /// about the repertoire and not about a position in it. Both ways out of the
  /// map lead back through this screen, which is the one place that knows how
  /// to open either door.
  /// Takes out the moves nobody was ever asked about.
  ///
  /// Until 31.8.2026 a repertoire could also be built out of imported games,
  /// and it wrote into the same graph as the build screen — so those moves are
  /// in the student's hand-built repertoire, indistinguishable from decisions,
  /// and the drill asks for them. The seed is gone; this is for what it left.
  ///
  /// The count comes first and the sentence says plainly that it is a guess,
  /// because it is: the only signal is whether a kept attempt was ever recorded
  /// for the move. Nothing is deleted until that has been read.
  Future<void> _cleanImported(RepertoireSummary item) async {
    final api = widget.api ?? RepertoireApiService();
    final found = await api.importedMoves(color: item.color);
    if (!mounted) return;
    if (found == null) {
      AppFeedback.error(context, 'The server did not respond.');
      return;
    }
    if (found.moves == 0) {
      AppFeedback.info(context,
          'No imported moves — everything for this color was chosen by you.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean imported moves'),
        content: Text(
          'For color "${item.forWhite ? "white" : "black"}" there are ${found.moves} '
          '${found.moves == 1 ? "move" : "moves"} in '
          '${found.positions} ${found.positions == 1 ? "position" : "positions"} '
          'with no record of you having chosen them. Almost certainly '
          'introduced by game imports.\n\n'
          'This is an estimate, not proof: the only trace is whether '
          'your choice was recorded with the move. Moves chosen before '
          'that record existed would look the same.\n\n'
          'Deleting cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final done = await api.forgetImportedMoves(color: item.color);
    if (!mounted) return;
    // Do the thing, then say it.
    await _load();
    if (!mounted) return;
    if (done) {
      AppFeedback.info(context,
          'Deleted ${found.moves} imported ${found.moves == 1 ? "move" : "moves"}.');
    } else {
      AppFeedback.error(context, 'Not deleted — the server did not respond.');
    }
  }

  /// Choosing the move this repertoire goes through at its root.
  ///
  /// The case it exists for: two repertoires from the same position — after
  /// 1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 one plays 4.b4 and the other 4.0-0 — where the
  /// moves are one graph, correctly, and the *view* was one graph too, so each
  /// showed the other's whole opening.
  ///
  /// The moves already kept in that position come first in the list, since the
  /// gate is nearly always one of them; every other legal move is under them,
  /// because a repertoire being redirected may go through a move it has not
  /// kept yet.
  Future<void> _pickGate(RepertoireSummary item) async {
    final kept = await _api.movesAt(color: item.color, fen: item.rootFen);
    if (!mounted) return;
    final picked = await showGatePicker(
      context,
      rootFen: item.rootFen,
      kept: kept.map((move) => move.uci).toList(),
      current: item.viaUci,
    );
    // Closed without deciding. An empty string is "no gate", which is a
    // decision and is stored.
    if (picked == null || !mounted) return;

    final done = await _api.setGate(
      item.id,
      viaUci: picked.isEmpty ? null : picked,
    );
    if (!mounted) return;
    // Do the thing, then say it.
    await _load();
    if (!mounted) return;
    if (!done.saved) {
      AppFeedback.error(context, 'Not saved — the server did not respond.');
    } else if (done.viaSan == null) {
      AppFeedback.info(
          context, 'Repertoire is no longer restricted to one move.');
    } else {
      AppFeedback.info(context, 'Repertoire goes through ${done.viaSan}.');
    }
  }

  /// Removes a repertoire: its name and its starting point always, and its
  /// moves when the reader says so.
  ///
  /// The count comes first, and it is a *subtraction*: what only this
  /// repertoire reaches, with everything another repertoire of the same colour
  /// still stands on left out. Deleting the name has always been safe and stays
  /// the default — the moves belong to the colour — but there was no door at
  /// all to the moves themselves, and deleting every repertoire left a graph
  /// nothing could reach and nothing could clear.
  Future<void> _delete(RepertoireSummary item) async {
    final preview = await _api.removalPreview(
      item.id,
      minRating: AppSettingsService.instance.repertoireMinRating,
    );
    if (!mounted) return;

    var withMoves = false;
    var withComments = false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Delete "${item.name}"?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Name and starting position are always deleted. Moves belong to '
                  'the color, not a single repertoire, so they stay by default.',
                ),
                if (preview == null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'How many moves would be removed with it could not be calculated '
                    '— the server did not respond. You can delete moves later from '
                    'this screen.',
                    style: AppText.caption
                        .copyWith(color: context.colors.textMuted),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.sm),
                  CheckboxListTile(
                    value: withMoves,
                    onChanged: preview.moves == 0
                        ? null
                        : (on) => setLocal(() {
                              withMoves = on ?? false;
                              if (!withMoves) withComments = false;
                            }),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      preview.moves == 0
                          ? 'No moves kept only by this repertoire.'
                          : 'Also delete moves: ${preview.moves} in '
                              '${preview.positions} '
                              '${preview.positions == 1 ? "position" : "positions"}',
                      style: AppText.body,
                    ),
                    subtitle: preview.moves == 0
                        ? null
                        : Text(
                            'Of which ${preview.decisions} '
                            '${preview.decisions == 1 ? "was chosen by you" : "were chosen by you"}'
                            '${preview.shared > 0 ? ", while ${preview.shared} ${preview.shared == 1 ? "position remains" : "positions remain"} because another repertoire of the same color holds them" : ""}.'
                            '\nBranches not prepared, added replies, '
                            'training schedule, and engine evaluations for those '
                            'positions also go. This cannot be undone.',
                            style: AppText.caption
                                .copyWith(color: context.colors.textMuted),
                          ),
                  ),
                  if (withMoves && preview.comments > 0)
                    CheckboxListTile(
                      value: withComments,
                      onChanged: (on) =>
                          setLocal(() => withComments = on ?? false),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Also delete my comments (${preview.comments})',
                        style: AppText.body,
                      ),
                      subtitle: Text(
                        'They stay by default: what you wrote cannot '
                        'be recalculated, and returns as soon as you reach '
                        'this position again.',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true || !mounted) return;

    final done = await _api.deleteRepertoire(
      item.id,
      withMoves: withMoves,
      includeComments: withComments,
    );
    if (!mounted) return;
    // Do the thing, then say it.
    await _load();
    if (!mounted) return;
    if (!done) {
      AppFeedback.error(context, 'Not deleted — the server did not respond.');
    } else if (withMoves && preview != null && preview.moves > 0) {
      AppFeedback.info(context,
          'Also deleted ${preview.moves} ${preview.moves == 1 ? "move" : "moves"}.');
    }
  }

  /// Empties a whole side: every move, cut, extra reply, attempt, review and
  /// engine evaluation stored for it.
  ///
  /// The door that had to exist. A repertoire is a name for a starting point,
  /// so deleting every repertoire of a colour leaves the moves standing with no
  /// root to reach them from — the prune refuses to run without one, correctly,
  /// since "no roots" must never read as "nothing is reachable". This is on the
  /// app bar rather than on a card, because the state it is for is the one with
  /// no cards left.
  Future<void> _eraseColor(String color) async {
    final stats = await _api.colorStats(color: color);
    if (!mounted) return;
    final side = color == 'w' ? 'White' : 'Black';
    if (stats == null) {
      AppFeedback.error(context, 'The server did not respond.');
      return;
    }
    if (stats.isEmpty) {
      AppFeedback.info(context, 'No saved moves for $side.');
      return;
    }

    var withComments = false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Delete all moves for $side?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved: ${stats.moves} '
                  '${stats.moves == 1 ? "move" : "moves"} in '
                  '${stats.positions} '
                  '${stats.positions == 1 ? "position" : "positions"}, of which '
                  '${stats.decisions} '
                  '${stats.decisions == 1 ? "was chosen by you" : "were chosen by you"}.',
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Branches not prepared, added replies, training schedule, and '
                  'engine evaluations for this color also go. The repertoires themselves '
                  '(name and starting position) stay — delete them individually.'
                  '\n\nDeleting cannot be undone.',
                  style:
                      AppText.caption.copyWith(color: context.colors.textMuted),
                ),
                if (stats.comments > 0)
                  CheckboxListTile(
                    value: withComments,
                    onChanged: (on) =>
                        setLocal(() => withComments = on ?? false),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Also delete my comments (${stats.comments})',
                      style: AppText.body,
                    ),
                    subtitle: Text(
                      'They stay by default: what you wrote cannot '
                      'be recalculated.',
                      style: AppText.caption
                          .copyWith(color: context.colors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true || !mounted) return;

    final done = await _api.eraseColor(
      color: color,
      includeComments: withComments,
    );
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    if (done) {
      AppFeedback.info(context,
          'Deleted ${stats.moves} ${stats.moves == 1 ? "move" : "moves"} for $side.');
    } else {
      AppFeedback.error(context, 'Not deleted — the server did not respond.');
    }
  }

  void _coverage(RepertoireSummary item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RepertoireCoverageScreen(
        name: item.name,
        color: item.color,
        rootFen: item.rootFen,
        rootPath: item.rootPath,
        gateUci: item.viaUci,
        minRating: AppSettingsService.instance.repertoireMinRating,
        api: widget.api,
        onBuildAt: (fen) {
          Navigator.of(context).pop();
          _open(item, at: fen);
        },
        onDrillAt: (fen) {
          Navigator.of(context).pop();
          _drill(item, from: fen);
        },
      ),
    ));
  }

  /// Ticking a card, and the one thing that cannot be ticked with it.
  ///
  /// One sitting asks about one side, so a repertoire of the other colour is
  /// refused with a sentence rather than silently ignored. The refusal is
  /// decided first and said last: a message must never be able to take down
  /// the thing it reports on.
  void _toggleSelection(RepertoireSummary item) {
    if (_selectedIds.contains(item.id)) {
      setState(() => _selectedIds.remove(item.id));
      return;
    }
    if (_selectedIds.isNotEmpty) {
      final first = _items.firstWhere((e) => e.id == _selectedIds.first);
      if (first.color != item.color) {
        AppFeedback.error(
            context, 'A single session can only ask about one side.');
        return;
      }
    }
    setState(() => _selectedIds.add(item.id));
  }

  /// Several openings, one sitting.
  ///
  /// No root goes with it: the server reads each door's root, gate and breadth
  /// from its own row, which is why [ids] and [rootFen] are alternatives rather
  /// than parallel parameters.
  void _startCombinedSession() {
    if (_selectedIds.isEmpty) return;
    final selectedItems =
        _items.where((e) => _selectedIds.contains(e.id)).toList();
    final first = selectedItems.first;

    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => RepertoireDrillScreen(
        name: 'Combined',
        color: first.color,
        minRating: AppSettingsService.instance.repertoireMinRating,
        api: widget.api,
        ids: _selectedIds.toList(),
      ),
    ))
        .then((_) {
      if (mounted) setState(() => _selectedIds.clear());
    });
  }

  void _drill(RepertoireSummary item, {String? from}) {
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => RepertoireDrillScreen(
        name: item.name,
        color: item.color,
        // The repertoire's own root and the moves that led to it, so the drill
        // can put the question at the end of the line that reaches it instead
        // of on a bare board four moves into something.
        rootFen: item.rootFen,
        rootPath: item.rootPath,
        gateUci: item.viaUci,
        fromFen: from,
        minRating: AppSettingsService.instance.repertoireMinRating,
        breadth: item.breadth,
        api: widget.api,
        // Landing in an unprepared position is the drill working as intended,
        // so the way on is building that very position — not a dead end and
        // not a trip back through the list.
        onBuildHere: (fen) {
          Navigator.of(context).pop();
          _open(item, at: fen);
        },
      ),
    ))
        .then((_) {
      if (mounted) _load();
    });
  }

  void _walkthrough(RepertoireSummary item) {
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => RepertoireWalkthroughScreen(
        name: item.name,
        color: item.color,
        rootFen: item.rootFen,
        rootPath: item.rootPath,
        gateUci: item.viaUci,
        minRating: AppSettingsService.instance.repertoireMinRating,
        breadth: item.breadth,
        api: _api,
        onBuildHere: (fen) {
          Navigator.of(context).pop();
          _open(item, at: fen);
        },
      ),
    ))
        .then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: const Text('Repertoire'),
        elevation: 0,
        actions: [
          // The band the book answers from, on the screen that owns every
          // repertoire rather than buried in Settings: it decides what "the
          // most played move" means, which is the sentence the whole build
          // loop is built on.
          PopupMenuButton<int>(
            tooltip: 'Opponent rating',
            icon: const Icon(Icons.groups_outlined),
            onSelected: (band) async {
              await AppSettingsService.instance.setRepertoireMinRating(band);
              if (!context.mounted) return;
              setState(() {});
              AppFeedback.info(context,
                  'Book now answers from games rated $band and above.');
            },
            itemBuilder: (context) => [
              for (final band in kRepertoireRatingBands)
                PopupMenuItem(
                  value: band,
                  child: Text(
                    band == AppSettingsService.instance.repertoireMinRating
                        ? '$band+ ✓'
                        : '$band+',
                  ),
                ),
            ],
          ),
          // Emptying a colour, and it is on the app bar rather than on a card
          // for one reason: the state it exists for is the one where there are
          // no cards. Delete every repertoire and the moves stay — they belong
          // to the colour — and until this menu there was nothing anywhere that
          // could reach them again.
          PopupMenuButton<String>(
            tooltip: 'Delete moves from database',
            icon: const Icon(Icons.delete_sweep_outlined),
            onSelected: _eraseColor,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'w',
                child: ListTile(
                  leading: Icon(Icons.circle_outlined),
                  title: Text('Delete all moves for White'),
                ),
              ),
              PopupMenuItem(
                value: 'b',
                child: ListTile(
                  leading: Icon(Icons.circle),
                  title: Text('Delete all moves for Black'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('New'),
            ),
      // A bar that grows with its content rather than a `BottomAppBar`, whose
      // height is fixed at 80: two buttons do not fit on one line at 360 dp,
      // and the second run was laid out four pixels below the bottom of the
      // screen — off it entirely in a release build, which paints no stripes.
      bottomNavigationBar: _isSelectionMode
          ? Material(
              color: context.colors.surface,
              elevation: 8,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(() => _selectedIds.clear()),
                        icon: const Icon(Icons.close),
                        label: Text('Cancel',
                            style: AppText.bodyBold
                                .copyWith(color: context.colors.textSecondary)),
                      ),
                      FilledButton(
                        onPressed: _startCombinedSession,
                        child: Text('Drill selected (${_selectedIds.length})'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_outlined, size: 40),
              const SizedBox(height: AppSpacing.md),
              Text('No repertoires yet.',
                  style: AppText.bodyBold, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'Create one and the app will ask what you would play, '
                'position by position. Nothing is memorized by rote — you choose, '
                'and what you choose stays yours.',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              // Said here because this is where it surprises somebody: the
              // list is empty and the next repertoire opens onto a tree full
              // of moves. They were never in the repertoire — they belong to
              // the colour — and the menu above empties them.
              Text(
                'Moves you chose earlier are still saved with the color, so '
                'a new repertoire for the same color knows them right away. If you '
                'want a clean start, delete moves for White or Black in the '
                'menu above ("Delete moves from database").',
                style: AppText.micro.copyWith(color: context.colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final item = _items[i];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
          child: ListTile(
            leading: _isSelectionMode
                ? Checkbox(
                    value: _selectedIds.contains(item.id),
                    onChanged: (_) => _toggleSelection(item),
                  )
                : Icon(
                    item.forWhite ? Icons.circle_outlined : Icons.circle,
                    color: context.colors.textSecondary,
                  ),
            title: Text(item.name, style: AppText.bodyBold),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.forWhite ? "White" : "Black"} · '
                  // The gate, where there is one. Two repertoires from the same
                  // position are otherwise two identical rows with different
                  // names.
                  '${item.viaSan != null ? "via ${item.viaSan} · " : ""}'
                  '${item.moves} ${item.moves == 1 ? "move" : "moves"} in graph',
                  style:
                      AppText.caption.copyWith(color: context.colors.textMuted),
                ),
                // How much is left, which is the question this screen is
                // opened with — „N poteza u grafu" says how much was built.
                // Silent until the walk answers: a card that guessed zero
                // would send somebody past the repertoire that needs them.
                if (_progress[item.id]?.open != null)
                  Text(
                    _progress[item.id]!.open == 0
                        ? 'all answered'
                        : '${_progress[item.id]!.open} unanswered ${_progress[item.id]!.open == 1 ? "position" : "positions"}',
                    style: AppText.caption.copyWith(
                      color: _progress[item.id]!.open == 0
                          ? context.colors.textMuted
                          : context.colors.accent,
                    ),
                  ),
              ],
            ),
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // This repertoire's own drafts. It used to be the colour's,
                // so three white repertoires wore the same 42 and none of them
                // was telling you about itself.
                if ((_progress[item.id]?.draft ?? 0) > 0)
                  InkWell(
                    onTap: () => _openDrafts(item),
                    borderRadius: AppRadii.roundedPill,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      margin: const EdgeInsets.only(right: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: context.colors.warning,
                        borderRadius: AppRadii.roundedPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_note,
                              size: 16, color: context.colors.canvas),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${_progress[item.id]!.draft}',
                            style: AppText.captionBold
                                .copyWith(color: context.colors.canvas),
                          ),
                        ],
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Drill',
                  icon: const Icon(Icons.fitness_center),
                  onPressed: () => _drill(item),
                ),
                // A menu in place of the chevron, which said only "this row
                // opens". Everything a repertoire can be asked for is in one
                // place and none of it costs the row any width — the map and
                // the tree were both a screen deep and one of them was not
                // found at all.
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (choice) {
                    switch (choice) {
                      case 'walkthrough':
                        _walkthrough(item);
                        break;
                      case 'coverage':
                        _coverage(item);
                        break;
                      case 'gate':
                        _pickGate(item);
                        break;
                      case 'imported':
                        _cleanImported(item);
                        break;
                      case 'delete':
                        _delete(item);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'walkthrough',
                      child: ListTile(
                        leading: Icon(Icons.menu_book_outlined),
                        title: Text('Explore repertoire'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'coverage',
                      child: ListTile(
                        leading: Icon(Icons.radar),
                        title: Text('Gaps in repertoire'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'gate',
                      child: ListTile(
                        leading: Icon(Icons.alt_route),
                        title: Text('Which move it goes through'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'imported',
                      child: ListTile(
                        leading: Icon(Icons.cleaning_services_outlined),
                        title: Text('Clean imported moves'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete repertoire'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(item);
              } else {
                _open(item);
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) _toggleSelection(item);
            },
          ),
        );
      },
    );
  }
}
