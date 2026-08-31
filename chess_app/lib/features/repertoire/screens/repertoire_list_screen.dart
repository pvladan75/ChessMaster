import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_coverage_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_drill_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_new_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
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

  List<RepertoireSummary> _items = const [];
  bool _loading = true;

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

  void _open(RepertoireSummary item, {String? at}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RepertoireBuildScreen(
        name: item.name,
        color: item.color,
        rootFen: at ?? item.rootFen,
        // Only when we are opening the repertoire's own root. `at` is some
        // other position the reader jumped to, and the stored line does not
        // lead there — a breadcrumb built from it would name the wrong moves,
        // which is worse than showing none.
        rootPath: at == null ? item.rootPath : const [],
        api: widget.api,
        judge: widget.judge,
        // Straight from the position on the board into practising that branch.
        // Building and drilling are still two doors — this one is opened from
        // inside, over the ten positions that were just made.
        onDrillHere: (fen) => _drill(item, from: fen),
      ),
    ));
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
      AppFeedback.error(context, 'Server nije odgovorio.');
      return;
    }
    if (found.moves == 0) {
      AppFeedback.info(
          context, 'Nema poteza iz uvoza — sve u ovoj boji ste izabrali sami.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Očisti poteze iz uvoza'),
        content: Text(
          'U boji „${item.forWhite ? "beli" : "crni"}" ima ${found.moves} '
          '${found.moves == 1 ? "potez" : "poteza"} u '
          '${found.positions} ${found.positions == 1 ? "poziciji" : "pozicija"} '
          'za koje ne postoji zapis da ste ih vi izabrali. Gotovo sigurno su '
          'ušli uvozom partija.\n\n'
          'Ovo je procena, ne dokaz: jedini trag je da li je uz potez '
          'zabeležen vaš izbor. Potezi koje ste izabrali pre nego što je taj '
          'zapis postojao izgledali bi isto.\n\n'
          'Brisanje se ne može poništiti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Obriši'),
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
      AppFeedback.info(context, 'Obrisano ${found.moves} poteza iz uvoza.');
    } else {
      AppFeedback.error(context, 'Nije obrisano — server nije odgovorio.');
    }
  }

  /// Removes a repertoire: its name and its starting point, never its moves.
  Future<void> _delete(RepertoireSummary item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Obriši „${item.name}"?'),
        content: const Text(
          'Briše se samo ime i početna pozicija. Potezi ostaju — oni pripadaju '
          'boji, a ne jednom repertoaru, pa ih drugi repertoari iste boje i '
          'dalje koriste.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final api = widget.api ?? RepertoireApiService();
    final done = await api.deleteRepertoire(item.id);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    if (!done) {
      AppFeedback.error(context, 'Nije obrisano — server nije odgovorio.');
    }
  }

  void _coverage(RepertoireSummary item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RepertoireCoverageScreen(
        name: item.name,
        color: item.color,
        rootFen: item.rootFen,
        rootPath: item.rootPath,
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

  void _drill(RepertoireSummary item, {String? from}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RepertoireDrillScreen(
        name: item.name,
        color: item.color,
        // The repertoire's own root and the moves that led to it, so the drill
        // can put the question at the end of the line that reaches it instead
        // of on a bare board four moves into something.
        rootFen: item.rootFen,
        rootPath: item.rootPath,
        fromFen: from,
        api: widget.api,
        // Landing in an unprepared position is the drill working as intended,
        // so the way on is building that very position — not a dead end and
        // not a trip back through the list.
        onBuildHere: (fen) {
          Navigator.of(context).pop();
          _open(item, at: fen);
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(title: const Text('Repertoar'), elevation: 0),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Novi'),
      ),
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
              Text('Još nijedan repertoar.',
                  style: AppText.bodyBold, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'Napravite jedan i aplikacija će vas pitati šta biste igrali, '
                'poziciju po poziciju. Ništa se ne uči napamet — bira se, i '
                'ono što izaberete ostaje vaše.',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted),
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
            leading: Icon(
              item.forWhite ? Icons.circle_outlined : Icons.circle,
              color: context.colors.textSecondary,
            ),
            title: Text(item.name, style: AppText.bodyBold),
            subtitle: Text(
              '${item.forWhite ? "Beli" : "Crni"} · '
              '${item.moves} ${item.moves == 1 ? "potez" : "poteza"} u grafu',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Vežbaj',
                  icon: const Icon(Icons.fitness_center),
                  onPressed: () => _drill(item),
                ),
                // A menu in place of the chevron, which said only "this row
                // opens". Everything a repertoire can be asked for is in one
                // place and none of it costs the row any width — the map and
                // the tree were both a screen deep and one of them was not
                // found at all.
                PopupMenuButton<String>(
                  tooltip: 'Još',
                  onSelected: (choice) {
                    switch (choice) {
                      case 'coverage':
                        _coverage(item);
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
                      value: 'coverage',
                      child: ListTile(
                        leading: Icon(Icons.radar),
                        title: Text('Pokrivenost'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'imported',
                      child: ListTile(
                        leading: Icon(Icons.cleaning_services_outlined),
                        title: Text('Očisti poteze iz uvoza'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Obriši repertoar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () => _open(item),
          ),
        );
      },
    );
  }
}
