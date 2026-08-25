import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/course_picker_dialog.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import '../models/scanned_position.dart';
import '../services/scanner_api_service.dart';
import '../services/side_proposal.dart';
import '../services/side_proposal_runner.dart';
import '../widgets/assign_positions_dialog.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// Everything the trainer has kept from their own books.
///
/// The scanner without this screen saved into a void: the first live run stored
/// 120 positions correctly and there was nowhere in the app to see them. Kept
/// deliberately plain — a position is useful the moment it can be opened on the
/// analysis board, which is one tap from here.
class SavedPositionsScreen extends StatefulWidget {
  const SavedPositionsScreen({super.key, required this.session});

  final UserSession session;

  @override
  State<SavedPositionsScreen> createState() => _SavedPositionsScreenState();
}

class _SavedPositionsScreenState extends State<SavedPositionsScreen> {
  late final ScannerApiService _api =
      ScannerApiService(authToken: widget.session.token);
  late final PositionLibraryService _library =
      PositionLibraryService(authToken: widget.session.token);

  List<SavedPosition>? _positions;
  bool _loading = true;
  bool _failed = false;
  String? _source; // null = all books

  /// The engine's opinion per position, held only in memory. A proposal is not
  /// an answer, so it is never written to the database until it is accepted.
  final Map<String, SideProposal> _proposals = {};
  SideProposalRunner? _runner;
  bool _checking = false;
  int _checkDone = 0;
  int _checkTotal = 0;
  int _depth = 16;

  /// Positions ticked for homework. Empty means selection mode is off, so the
  /// screen stays a browser until the trainer actually starts choosing.
  final Set<String> _picked = {};

  /// Which positions a run covers. Re-checking settled ones is worth offering:
  /// the engine can disagree with an answer already recorded, and that
  /// disagreement is the only way to catch a side that was set wrongly.
  bool _includeSettled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final list = await _api.listSaved();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = list == null;
      _positions = list;
    });
  }

  List<String> get _sources {
    final names = <String>{};
    for (final p in _positions ?? const <SavedPosition>[]) {
      names.add(p.sourceTitle ?? 'bez izvora');
    }
    return names.toList()..sort();
  }

  List<SavedPosition> get _visible {
    final all = _positions ?? const <SavedPosition>[];
    if (_source == null) return all;
    return all
        .where((p) => (p.sourceTitle ?? 'bez izvora') == _source)
        .toList();
  }

  /// Positions a run would cover, in the order they are shown.
  List<SavedPosition> get _checkTargets {
    final all = _visible;
    return _includeSettled ? all : all.where((p) => p.needsReview).toList();
  }

  /// Proposals worth accepting without looking at each one.
  ///
  /// High confidence only, and never one that contradicts a side already
  /// settled — overturning a person's answer in bulk is exactly the thing this
  /// whole flow exists to prevent. Those are left for the trainer to look at.
  List<SavedPosition> get _confidentAcceptable {
    return (_positions ?? const <SavedPosition>[]).where((p) {
      final proposal = _proposals[p.puzzleId];
      if (proposal == null || !proposal.hasAnswer) return false;
      if (proposal.confidence != ProposalConfidence.high) return false;
      return p.needsReview;
    }).toList();
  }

  /// Hands the ticked positions to a student.
  Future<void> _assign() async {
    if (_picked.isEmpty) return;
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AssignPositionsDialog(
        session: widget.session,
        puzzleIds: _picked.toList(),
      ),
    );
    if (message == null || !mounted) return;
    setState(_picked.clear);
    AppFeedback.show(context, () => SnackBar(content: Text(message)));
  }

  /// Puts the ticked positions into an existing lesson.
  ///
  /// The other half of one library: a position could be scanned, confirmed and
  /// set as homework, but never taught from — the lesson editor could not see
  /// the scanner's table at all.
  ///
  /// The task travels with the position. A step without one is a board with no
  /// question on it, which is the oldest complaint about this feature.
  Future<void> _addToLesson() async {
    if (_picked.isEmpty) return;
    final chosen = (_positions ?? const <SavedPosition>[])
        .where((p) => _picked.contains(p.puzzleId))
        .toList();
    if (chosen.isEmpty) return;

    final course = await showDialog<CourseSummary>(
      context: context,
      builder: (context) =>
          CoursePickerDialog(service: _library, count: chosen.length),
    );
    if (course == null || !mounted) return;

    var added = 0;
    String? firstError;
    for (final position in chosen) {
      final error = await _library.appendStep(
        lessonId: course.id,
        title: position.sourceLabel == null
            ? 'Pozicija sa strane ${position.sourcePage ?? '?'}'
            : '#${position.sourceLabel} · ${position.sourceTitle ?? 'knjiga'}',
        fen: position.fen,
        instruction: position.instruction,
        solutionSan: position.solutionSan,
      );
      if (error == null) {
        added++;
      } else {
        firstError ??= error;
      }
    }
    if (!mounted) return;

    setState(_picked.clear);
    // Both numbers, always. "Dodato" alone would hide the ones that did not go
    // in, and those are the ones worth knowing about.
    final message = firstError == null
        ? 'Dodato $added u „${course.title}".'
        : 'Dodato $added, nije prošlo ${chosen.length - added}: $firstError';
    AppFeedback.show(context, () => SnackBar(content: Text(message)));
  }

  Future<void> _runCheck() async {
    final targets = _checkTargets;
    if (targets.isEmpty) return;

    final runner = SideProposalRunner();

    setState(() {
      _runner = runner;
      _checking = true;
      _checkDone = 0;
      _checkTotal = targets.length;
    });

    // Starting the engine is what decides whether it is a local one, so this
    // has to happen before the question can be answered — not before the
    // progress bar appears, since starting a binary takes a moment.
    final usable = await runner.ensureUsableEngine();
    if (!mounted) return;
    if (!usable) {
      setState(() {
        _checking = false;
        _runner = null;
      });
      AppFeedback.show(
          context,
          () => const SnackBar(
                content: Text(
                  'Motor nije pokrenut kao lokalni, pa ne može da odgovori — mrežni ne '
                  'poznaje pozicije iz knjiga. Proveri Podešavanja → Lokalni engine (.exe).',
                ),
                duration: Duration(seconds: 8),
              ));
      return;
    }

    await runner.run(
      targets,
      depth: _depth,
      onResult: (puzzleId, proposal) {
        if (!mounted) return;
        setState(() => _proposals[puzzleId] = proposal);
      },
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _checkDone = done;
          _checkTotal = total;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _checking = false;
      _runner = null;
    });
  }

  void _togglePick(SavedPosition position) {
    if (!_picked.remove(position.puzzleId)) _picked.add(position.puzzleId);
  }

  void _cancelCheck() {
    _runner?.cancel();
    setState(() => _checking = false);
  }

  /// Writes one proposal down, after a person has agreed to it.
  Future<bool> _accept(SavedPosition position, SideProposal proposal) async {
    final side = proposal.side;
    if (side == null) return false;
    final fen = await _api.setSideToMove(position.puzzleId, side);
    if (fen == null) return false;
    if (!mounted) return false;
    setState(() {
      position.settleSide(side, fen);
      _proposals.remove(position.puzzleId);
    });
    return true;
  }

  Future<void> _acceptAllConfident() async {
    final batch = _confidentAcceptable;
    if (batch.isEmpty) return;
    var accepted = 0;
    for (final position in batch) {
      final proposal = _proposals[position.puzzleId];
      if (proposal == null) continue;
      if (await _accept(position, proposal)) accepted += 1;
      if (!mounted) return;
    }
    AppFeedback.show(
      context,
      () => SnackBar(content: Text('Prihvaćeno $accepted od ${batch.length}.')),
    );
  }

  /// Lets the trainer write what the student is meant to do here.
  ///
  /// A derived task ("mate in one") is reporting; anything beyond that is
  /// teaching, and teaching is the trainer's voice. So the field is theirs to
  /// write and nothing ever generates over what they wrote.
  Future<void> _editInstruction(SavedPosition position) async {
    final controller = TextEditingController(text: position.instruction ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Šta učenik treba da uradi?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'npr. Nađi mat u jednom potezu, pazi na odbranu skakačem',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Odustani')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Sačuvaj')),
        ],
      ),
    );
    controller.dispose();
    if (text == null || !mounted) return;

    final ok = await _api.setInstruction(position.puzzleId, text);
    if (!mounted) return;
    if (!ok) {
      AppFeedback.show(context,
          () => const SnackBar(content: Text('Uputstvo nije sačuvano.')));
      return;
    }
    setState(() => position.instruction = text.isEmpty ? null : text);
  }

  /// Opens a position on the analysis board — but not before whose move it is
  /// has actually been decided.
  ///
  /// A diagram does not print the side to move, so an unconfirmed position is
  /// stored with white and flagged. FEN has no way to carry "nobody knows", so
  /// once it leaves this screen the guess is indistinguishable from a fact: the
  /// board loads it, the engine analyses that side, and the arrow answers a
  /// question nobody ever asked. Found live, on a position where the book never
  /// said. So the question gets asked here, once, and the answer is kept.
  Future<void> _open(SavedPosition position) async {
    if (!position.needsReview) {
      context.push(AppRoutes.analysisPath(fen: position.fen));
      return;
    }

    final side = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ko je na potezu?'),
        content: Text(
          position.sourceLabel == null
              ? 'Knjiga to ne kaže za ovu poziciju (strana ${position.sourcePage}). '
                  'Dok se ne odluči, motor bi analizirao pogrešnu stranu.'
              : 'Knjiga to ne kaže za dijagram #${position.sourceLabel} '
                  '(strana ${position.sourcePage}). Dok se ne odluči, motor bi '
                  'analizirao pogrešnu stranu.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Odustani')),
          TextButton(
              onPressed: () => Navigator.pop(context, 'b'),
              child: const Text('Crni')),
          FilledButton(
              onPressed: () => Navigator.pop(context, 'w'),
              child: const Text('Beli')),
        ],
      ),
    );
    if (side == null || !mounted) return;

    final fen = await _api.setSideToMove(position.puzzleId, side);
    if (!mounted) return;
    if (fen == null) {
      AppFeedback.show(
          context,
          () => const SnackBar(
              content:
                  Text('Ta strana ne može biti na potezu u ovoj poziciji.')));
      return;
    }
    setState(() => position.settleSide(side, fen));
    context.push(AppRoutes.analysisPath(fen: fen));
  }

  Future<void> _delete(SavedPosition position) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Obrisati poziciju?'),
        content: Text(position.sourceLabel == null
            ? 'Pozicija sa strane ${position.sourcePage}.'
            : 'Dijagram #${position.sourceLabel}, strana ${position.sourcePage}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Odustani')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Obriši')),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await _api.deleteSaved(position.puzzleId);
    if (!mounted) return;
    if (!ok) {
      AppFeedback.show(context,
          () => const SnackBar(content: Text('Brisanje nije uspelo.')));
      return;
    }
    setState(() => _positions =
        _positions?.where((p) => p.puzzleId != position.puzzleId).toList());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: const Text('Moje pozicije'),
        backgroundColor: colors.surface,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Osveži',
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final colors = context.colors;
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_failed) {
      return _Message(
        icon: Icons.cloud_off,
        title: 'Nije moguće doći do servera.',
        detail: 'Pozicije su sačuvane, samo se trenutno ne mogu učitati.',
        action:
            FilledButton(onPressed: _load, child: const Text('Pokušaj opet')),
      );
    }

    final all = _positions ?? const <SavedPosition>[];
    if (all.isEmpty) {
      return _Message(
        icon: Icons.auto_stories_outlined,
        title: 'Još nema sačuvanih pozicija.',
        detail: 'Skenirajte dijagrame iz svoje knjige i potvrdite ih.',
        action: FilledButton.icon(
          onPressed: () => context.push(AppRoutes.scan),
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('Skeniraj pozicije'),
        ),
      );
    }

    final items = _visible;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: colors.surfaceRaised,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${all.length} pozicija',
                  style: TextStyle(
                      color: colors.textPrimary, fontWeight: FontWeight.w600)),
              if (all.any((p) => p.needsReview))
                Text('${all.where((p) => p.needsReview).length} traži pogled',
                    style: TextStyle(color: colors.warning, fontSize: 12)),
              if (all.any((p) => !p.needsReview && p.solutionSan == null))
                Text(
                    '${all.where((p) => !p.needsReview && p.solutionSan == null).length} bez rešenja',
                    style: TextStyle(color: colors.info, fontSize: 12)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('sve'),
                selected: _source == null,
                onSelected: (_) => setState(() => _source = null),
              ),
              for (final name in _sources)
                ChoiceChip(
                  label: Text(name),
                  selected: _source == name,
                  onSelected: (_) => setState(() => _source = name),
                ),
            ],
          ),
        ),
        _engineBar(),
        if (_picked.isNotEmpty) _selectionBar(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 230,
              mainAxisExtent: 296,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _SavedCard(
              position: items[index],
              proposal: _proposals[items[index].puzzleId],
              picked: _picked.contains(items[index].puzzleId),
              selecting: _picked.isNotEmpty,
              onOpen: () => _picked.isEmpty
                  ? _open(items[index])
                  : setState(() => _togglePick(items[index])),
              onLongPress: () => setState(() => _togglePick(items[index])),
              onDelete: () => _delete(items[index]),
              onEditInstruction: () => _editInstruction(items[index]),
              onAccept: () {
                final proposal = _proposals[items[index].puzzleId];
                if (proposal != null) _accept(items[index], proposal);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Shown only while choosing, so it never takes room from the grid otherwise.
  Widget _selectionBar() {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      color: colors.accent.withValues(alpha: 0.15),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      // Wrap, not Row: three actions and a count do not fit across a phone, and
      // a Row would overflow rather than fold.
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Izabrano ${_picked.length}',
              style: TextStyle(color: colors.textPrimary, fontSize: 13)),
          TextButton(
              onPressed: () => setState(_picked.clear),
              child: const Text('Poništi')),
          OutlinedButton.icon(
            onPressed: _addToLesson,
            icon: const Icon(Icons.playlist_add),
            label: const Text('Dodaj u lekciju'),
          ),
          FilledButton.icon(
            onPressed: _assign,
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Zadaj učeniku'),
          ),
        ],
      ),
    );
  }

  /// The engine controls: how deep, over what, and a way to stop.
  ///
  /// Depth is the trainer's to choose because it is a trade they can feel —
  /// shallow is quick and sometimes wrong, deep is slow and rarely is. And a run
  /// is repeatable at a different depth precisely because the first answer may
  /// not convince.
  Widget _engineBar() {
    final colors = context.colors;
    final targets = _checkTargets.length;
    final confident = _confidentAcceptable.length;

    return Container(
      width: double.infinity,
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_checking) ...[
            SizedBox(
              width: 140,
              child: LinearProgressIndicator(
                value: _checkTotal == 0 ? null : _checkDone / _checkTotal,
              ),
            ),
            Text('provereno $_checkDone / $_checkTotal',
                style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            TextButton.icon(
              onPressed: _cancelCheck,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Prekini'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: targets == 0 ? null : _runCheck,
              icon: const Icon(Icons.psychology_outlined),
              label: Text('Proveri motorom ($targets)'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('dubina ',
                    style:
                        TextStyle(color: colors.textSecondary, fontSize: 12)),
                DropdownButton<int>(
                  value: _depth,
                  isDense: true,
                  onChanged: (value) =>
                      value == null ? null : setState(() => _depth = value),
                  items: const [12, 16, 20, 24]
                      .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                      .toList(),
                ),
              ],
            ),
            FilterChip(
              label: const Text('i već odlučene'),
              selected: _includeSettled,
              onSelected: (value) => setState(() => _includeSettled = value),
              backgroundColor: colors.surfaceRaised,
            ),
            if (confident > 0)
              OutlinedButton.icon(
                onPressed: _acceptAllConfident,
                icon: const Icon(Icons.done_all),
                label: Text('Prihvati pouzdane ($confident)'),
              ),
            if (_proposals.isNotEmpty)
              TextButton(
                onPressed: () => setState(_proposals.clear),
                child: const Text('Obriši predloge'),
              ),
          ],
        ],
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({
    required this.position,
    required this.proposal,
    required this.picked,
    required this.selecting,
    required this.onLongPress,
    required this.onOpen,
    required this.onDelete,
    required this.onAccept,
    required this.onEditInstruction,
  });

  final SavedPosition position;

  /// The engine's opinion, when one has been asked for. Shown beside the
  /// position, never folded into it — accepting is a separate act.
  final SideProposal? proposal;

  /// Ticked for homework. Selection starts on a long press, so an ordinary tap
  /// keeps opening the board until the trainer has actually begun choosing.
  final bool picked;
  final bool selecting;
  final VoidCallback onLongPress;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onAccept;
  final VoidCallback onEditInstruction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Three states, not two. Settling the side to move used to clear the yellow
    // border and leave a position with no solution looking finished — but being
    // *unfinished* and being *doubtful* are different things and deserve
    // different marks. Yellow means something disagrees; the softer mark means
    // nothing is wrong, there is just nothing recorded yet.
    final incomplete = !position.needsReview && position.solutionSan == null;
    final borderColor = position.needsReview
        ? colors.warning
        : incomplete
            ? colors.info
            : colors.border;

    return InkWell(
      onTap: onOpen,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: picked ? colors.surfaceRaised : colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: picked ? colors.accent : borderColor,
            width: picked ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    position.sourceLabel == null
                        ? 'str. ${position.sourcePage ?? '?'}'
                        : '#${position.sourceLabel} · str. ${position.sourcePage}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ),
                if (selecting)
                  Icon(
                    picked ? Icons.check_circle : Icons.circle_outlined,
                    size: 18,
                    color: picked ? colors.accent : colors.textMuted,
                  )
                else
                  InkWell(
                    onTap: onDelete,
                    child: Icon(Icons.delete_outline,
                        size: 18, color: colors.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Center(child: BoardThumbnail(fen: position.fen, size: 140)),
            const Spacer(),
            // The notes under the board grew from one line to three — solution,
            // the unconfirmed-side warning, and the engine's opinion — and a
            // fixed-height card cannot hold whatever arrives. Flexible with
            // clipping means adding a fourth note can never overflow the tile
            // again; the grid gives the block room for the usual three.
            Flexible(
              child: ClipRect(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The task the student is sent. Plain text gave no sign it
                    // could be edited, so nobody would ever have found it — the
                    // pencil is the whole affordance.
                    InkWell(
                      onTap: onEditInstruction,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              position.instruction ??
                                  'dodaj zadatak za učenika',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: position.instruction == null
                                    ? colors.warning
                                    : colors.textPrimary,
                                fontSize: 11,
                                fontStyle: position.instruction == null
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_outlined,
                              size: 13, color: colors.textMuted),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                            position.sideToMove == 'w'
                                ? Icons.circle
                                : Icons.circle_outlined,
                            size: 11,
                            color: colors.textPrimary),
                        const SizedBox(width: 5),
                        Text(
                          position.solutionSan ?? 'bez rešenja',
                          style: TextStyle(
                            color:
                                incomplete ? colors.info : colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    // Without this the yellow border says only "something", and
                    // the trainer cannot know the side was never confirmed.
                    if (position.needsReview)
                      Text('strana na potezu nije potvrđena',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: colors.warning, fontSize: 11)),
                    if (proposal != null) _proposalRow(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The engine's proposal, and a way to take it.
  ///
  /// Where it contradicts a side already settled the row says so loudly rather
  /// than offering a quiet one-tap overwrite: somebody already answered this,
  /// and a machine changing their mind for them is the failure this whole flow
  /// exists to avoid. Still offered — just not silently.
  Widget _proposalRow(BuildContext context) {
    final colors = context.colors;
    final p = proposal!;

    // A run that found nothing still has something to say. Six positions came
    // back undecidable because *both* sides mate — and "white M1, black M6" is
    // enough for a trainer to settle in a second, while silence is not.
    if (!p.hasAnswer) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'motor: ${p.reason}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textMuted, fontSize: 11),
        ),
      );
    }

    final disagrees =
        p.disagreesWith(position.sideToMove) && !position.needsReview;
    final tone = disagrees
        ? colors.danger
        : p.confidence == ProposalConfidence.high
            ? colors.success
            : colors.info;
    final named = p.side == 'w' ? 'beli' : 'crni';

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              disagrees
                  ? 'motor se ne slaže: $named — ${p.reason}'
                  : 'motor: $named — ${p.reason}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tone, fontSize: 11),
            ),
          ),
          InkWell(
            onTap: onAccept,
            child: Icon(Icons.check_circle_outline, size: 18, color: tone),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colors.textMuted),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(color: colors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(detail,
                style: TextStyle(color: colors.textMuted, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}
