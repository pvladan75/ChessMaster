import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/lessons/models/lesson_labels.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/draft_history.dart';
import 'package:chess_app/features/tutorial_studio/services/section_split.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_save.dart';
import 'package:chess_app/services/account_local_state.dart';

/// What a move the board reported turned into.
enum MoveOutcome {
  /// The position does not allow it. The board must be put back.
  illegal,

  /// The line grew by one move and the cursor stands on it.
  played,

  /// The move was a second line from a position that already went on, so it
  /// opened a part of its own right after the open one — D1 of
  /// `docs/PLAN-MAPA-DELOVA.md`. The cursor stands on it, in the new part.
  branched,

  /// The move would have opened a part, and the caller said it may not.
  /// Nothing changed; the board must be put back.
  heldBack,
}

/// The tutorial being written — phase 6a of `docs/PLAN-REORGANIZACIJA.md`,
/// the class `docs/PLAN-STUDIO-REDIZAJN.md` §4 drew and the screen never got.
///
/// **What it holds:** the draft, which part is open and where the cursor
/// stands in it, the undo history, the step ids a save handed out, the saved
/// version to go back to, and the last move played. **What it does not hold:**
/// a board controller, a text field, a dialog, a snackbar, a frame. Every
/// mutation is a method here; the desktop screen is one layout over it and
/// the phone layout (6b) is another, and neither keeps a copy of any of this.
///
/// **The draft is the single source of truth.** Until 6a the screen kept the
/// open part's fields of its own and wrote them back in `_syncSelectedSection`
/// before anything was persisted — the shape that let a field left at its
/// default overwrite the part (7.9.2026). Here a field writes through, and
/// there is no second place it lives.
///
/// **Two signals.** [notifyListeners] says „redraw"; [generation] says „the
/// open part or the whole draft was replaced — rebuild your fields from the
/// model". Typing never bumps the generation, because rebuilding a text field
/// under the caret moves the caret. Every change also passes through
/// [persist], which keeps the draft on this device and records it for undo.
///
/// Most of the gate for this class runs with no widget tree at all: build a
/// two-part tutorial, assert the `positionList`, never pump a frame —
/// `test/tutorial_draft_controller_test.dart`.
class TutorialDraftController extends ChangeNotifier {
  TutorialDraftController({
    required TutorialDraft draft,
    TutorialDraftService? slot,
    DraftHistory? history,
  })  : _draft = draft,
        _slot = slot ?? TutorialDraftService.instance,
        _history = history ?? DraftHistory() {
    _startHistory();
  }

  TutorialDraft _draft;
  final TutorialDraftService _slot;

  /// The account wipe this controller was made under — see
  /// [AccountLocalState.epoch]. Taken here, once: a controller that outlives
  /// a sign-out holds the previous account's tutorial.
  final int _epoch = AccountLocalState.epoch;
  final DraftHistory _history;

  TutorialDraft get draft => _draft;

  /// The part that is open.
  TutorialSection get section => _draft.section;

  /// The line being written, and where the trainer is standing on it.
  AnalysisNode get root => section.root;
  AnalysisNode get cursor => section.cursorNode;

  int _generation = 0;

  /// Bumped when the open part changes or the draft is replaced — adopt,
  /// restore, select, add, move, clone, remove, a question placed, a line
  /// inserted. Never on typing, a move or a mark. A layout that keeps text
  /// controllers rebuilds them from the model when this changes.
  int get generation => _generation;

  ({String from, String to})? _lastMove;

  /// The move just played on the open part, for the board's highlight; null
  /// once the cursor moves any other way.
  ({String from, String to})? get lastMove => _lastMove;

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  /// Nothing has changed since the draft was adopted — no step to undo or
  /// redo. The moment the saved version may still be swapped in unasked.
  bool get untouched => !_history.canUndo && !_history.canRedo;

  /// The step id each part has been given, by [TutorialSection.localKey].
  ///
  /// Learned from the draft before every restore — a save has put its ids
  /// there by then — and handed back to a part an undo restores without one.
  /// Kept across restores, so a part undone out of existence and back still
  /// finds its id. Without it, an undo past a save followed by another save
  /// would send the part with no id, the server would mint a new one, and
  /// every schedule row and recorded answer naming the old id would point at
  /// nothing, silently.
  final Map<String, String> _stepIdsByKey = {};

  /// The saved version — phase 2 of `docs/PLAN-STUDIO-ISTORIJA.md`: the row
  /// fetched when the studio opened, replaced by what each successful save
  /// sent. Null while it is not known, which is also when „Discard changes"
  /// is not offered: a version nobody could read is not one to go back to.
  ///
  /// Kept as a snapshot to restore and a [TutorialDraft.contentSignature] to
  /// compare, never compared as encoded text — the encoding carries the cursor
  /// and node ids, which change without anybody editing anything.
  String? _savedSnapshot;
  String? _savedSignature;

  bool _hasUnsavedChanges = false;

  /// Whether the draft differs from the saved version in anything the trainer
  /// wrote. Refreshed where the draft changes, not computed on read: a
  /// signature of a large tutorial is 38 KB of JSON.
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  bool get savedVersionKnown => _savedSnapshot != null;

  // ── the draft as a whole ─────────────────────────────────────────────────

  /// Makes [draft] the one being written, and the place undo stops.
  void adopt(TutorialDraft draft) {
    _draft = draft;
    _lastMove = null;
    _generation++;
    _startHistory();
    _hasUnsavedChanges = _differsFromSaved();
    notifyListeners();
  }

  /// Holds the draft against the version the server keeps. Returns whether
  /// they differ in anything the trainer wrote.
  ///
  /// A draft kept from before the language field says nothing about it, and
  /// saving it says nothing either — the server keeps its own. It reads as the
  /// server's here rather than as a change nobody made, and not as a step undo
  /// could take back to „not known".
  bool rememberSaved(TutorialDraft saved) {
    if (!_draft.languageKnown && saved.languageKnown) {
      _draft.language = saved.language;
      if (untouched) _startHistory();
    }
    _savedSnapshot = jsonEncode(saved.toJson());
    _savedSignature = saved.contentSignature();
    final differs = _differsFromSaved();
    _setUnsaved(differs);
    return differs;
  }

  /// „Discard changes": the saved version, put back as a change of its own —
  /// recorded like any other, so a mistaken press is one undo away.
  void discardChanges() {
    final snapshot = _savedSnapshot;
    if (snapshot == null) return;
    final saved = _decode(snapshot);
    _giveBackIds(saved);
    _draft = saved;
    _lastMove = null;
    _generation++;
    persist();
    notifyListeners();
  }

  void undo() => _restore(_history.undo());

  void redo() => _restore(_history.redo());

  /// Keeps the draft on this device and records the change for undo.
  ///
  /// Every change passes through here. [typingIn] names the text field a
  /// change came from, so that a sentence typed without a pause is one undo
  /// step rather than one per letter. Listeners are told only when one of the
  /// three things that depend on this — undo, redo, discard — changed, since
  /// the change itself has already been announced by whoever made it.
  void persist({String? typingIn}) {
    _slot.scheduleSave(_draft, epoch: _epoch);
    final couldUndo = _history.canUndo;
    final couldRedo = _history.canRedo;
    final hadUnsaved = _hasUnsavedChanges;
    final signature = _draft.contentSignature();
    _history.record(jsonEncode(_draft.toJson()), signature, typingIn: typingIn);
    _hasUnsavedChanges = _differsFromSaved(signature);
    if (couldUndo != _history.canUndo ||
        couldRedo != _history.canRedo ||
        hadUnsaved != _hasUnsavedChanges) {
      notifyListeners();
    }
  }

  /// Writes the draft to this device now, not after the debounce — for a
  /// screen closing, whose pending timer would die with it.
  Future<void> flush() => _slot.flush(_draft, epoch: _epoch);

  // ── the parts ────────────────────────────────────────────────────────────

  void select(int index) {
    if (index < 0 || index >= _draft.sections.length) return;
    _draft.selected = index;
    section.cursorNode = section.root;
    _partChanged();
  }

  /// The next demonstration, and the board it opens on: „From here" keeps
  /// the child's board from reloading; „New board" starts a fresh example.
  void addSection({required bool continueFromEnd}) {
    _draft.addSection(
      continueFromEnd: continueFromEnd,
      title: generatedSectionTitle(_draft.sections.length),
    );
    _renumberGeneratedTitles();
    _partChanged();
  }

  void moveSection(int from, int to) {
    if (from < 0 || from >= _draft.sections.length) return;
    if (to < 0 || to >= _draft.sections.length || from == to) return;
    _draft.moveSection(from, to);
    _renumberGeneratedTitles();
    _partChanged();
  }

  void cloneSection(int index) {
    if (index < 0 || index >= _draft.sections.length) return;
    _draft.cloneSection(index);
    _renumberGeneratedTitles();
    _partChanged();
  }

  /// Parts taken out of another tutorial, added to the one being written.
  ///
  /// Answers how many arrived, and leaves the trainer standing on the first of
  /// them — a trainer who has just fetched four parts wants to look at them,
  /// not at the part they were on before.
  ///
  /// **Copies, and the copy is what makes this safe.** `TutorialSection.copy()`
  /// drops the `stepId`, so a part that already belongs to a saved tutorial
  /// cannot arrive here still claiming to be that step. The parts handed in are
  /// never stored, only read.
  ///
  /// **A draft holding nothing but a blank part is replaced rather than
  /// appended to.** A tutorial just started holds one; appending after it
  /// would leave an empty first part in front of everything fetched, and the
  /// trainer would have to notice it and delete it.
  ///
  /// [holdsOnlyABlankPart] and not [isEmptyDraft], though they look like the
  /// same question. [isEmptyDraft] also asks whether the tutorial has a title,
  /// because it answers „is this stored draft worth offering to resume" — and
  /// a trainer who types a name before doing anything else is exactly the one
  /// who would be left with the stray part. What matters here is only whether
  /// there is any teaching in the draft to append to.
  int addSectionsFrom(List<TutorialSection> parts) {
    if (parts.isEmpty) return 0;

    final copies = [for (final part in parts) part.copy()];
    final startsEmpty = holdsOnlyABlankPart(_draft);
    final at = startsEmpty ? 0 : _draft.sections.length;

    if (startsEmpty) {
      _draft.sections
        ..clear()
        ..addAll(copies);
    } else {
      _draft.sections.addAll(copies);
    }

    _draft.selected = at;
    _renumberGeneratedTitles();
    _partChanged();
    return copies.length;
  }

  /// Copies of the parts at [indices], in the order this tutorial has them.
  ///
  /// Nothing is changed here — it is what „take these into a new tutorial"
  /// reads, and the answer must not depend on the order the trainer ticked
  /// the boxes in: a tutorial's parts are a sequence, and four of them pulled
  /// out still run in the order they were written.
  List<TutorialSection> copiesOf(Iterable<int> indices) {
    final wanted = indices.toSet();
    return [
      for (var i = 0; i < _draft.sections.length; i++)
        if (wanted.contains(i)) _draft.sections[i].copy(),
    ];
  }

  /// False when it is the last part, which cannot be deleted.
  bool removeSection(int index) {
    if (!_draft.removeSection(index)) return false;
    _renumberGeneratedTitles();
    _partChanged();
    return true;
  }

  /// A name of the trainer's own, or none: an empty name is the generated one.
  void renameSection(int index, String name) {
    if (index < 0 || index >= _draft.sections.length) return;
    _draft.sections[index].title =
        name.trim().isEmpty ? generatedSectionTitle(index) : name.trim();
    persist();
    notifyListeners();
  }

  /// The part is cut at the beat the trainer is standing on, and they are left
  /// on the new line's first position, to play it. No renumbering:
  /// [TutorialSection.label] names a part with no name of its own by where it
  /// stands, on screen and on the wire alike.
  void insertLine() {
    final cut = splitForLine(section, cursor);
    _draft.replaceSelected(cut.parts);
    _draft.selected = _draft.sections.indexOf(cut.line);
    _partChanged();
  }

  // ── the line of the open part ────────────────────────────────────────────

  /// A move the board reported, dragged or tapped.
  ///
  /// [mayOpenPart] false holds back a move that would open a part (D1), and
  /// only such a move: the screen passes it while the PGN tab holds text that
  /// was not applied, because a new part rebuilds that field for the new part
  /// and the text would be gone without a word — and carrying it across would
  /// apply it to a part it was not written for.
  MoveOutcome playMove(
    String from,
    String to,
    String promotion, {
    bool mayOpenPart = true,
  }) {
    final played = playedMove(
      fen: cursor.fen,
      from: from,
      to: to,
      promotion: promotion,
    );
    if (played == null) return MoveOutcome.illegal;

    // **A part is one line** — D1 of `docs/PLAN-MAPA-DELOVA.md`. The film
    // walks first children, so a second child here would be saved, drawn in
    // „Tree" and never filmed. A move the line already plays walks into it; a
    // new one where the line goes on opens a part of its own.
    final goesOn = cursor.children.isNotEmpty;
    final alreadyPlayed = cursor.children.any((c) => c.moveUci == played.uci);
    if (goesOn && !alreadyPlayed) {
      if (!mayOpenPart) return MoveOutcome.heldBack;
      _openPartFrom(cursor, san: played.san, uci: played.uci, fen: played.fen);
      _lastMove = (from: from, to: to);
      notifyListeners();
      return MoveOutcome.branched;
    }

    final child = cursor.addChild(
      childFen: played.fen,
      san: played.san,
      uci: played.uci,
    );
    section.cursorNode = child;
    _lastMove = (from: from, to: to);
    persist();
    notifyListeners();
    return MoveOutcome.played;
  }

  /// A part right after the open one, on [fork]'s position, whose line is the
  /// move just played there. The open part is not touched.
  ///
  /// The new part carries [fork]'s arrows and squares and not its sentence:
  /// the film reaches it by going back („Back to the position after …"), the
  /// board reloads there and the marks are drawn again, while the sentence has
  /// been read out where it was written — `splitForLine`'s rule for the part
  /// that goes back. It faces the way the open part faces.
  void _openPartFrom(
    AnalysisNode fork, {
    required String san,
    required String uci,
    required String fen,
  }) {
    final root = AnalysisNode(
      fen: fork.fen,
      arrows: [...fork.arrows],
      squares: [...fork.squares],
    );
    final move = root.addChild(childFen: fen, san: san, uci: uci);
    final at = _draft.selected + 1;
    _draft.sections.insert(
      at,
      TutorialSection(
        root: root,
        cursor: move,
        blackOrientation: section.blackOrientation,
      ),
    );
    _draft.selected = at;
    _renumberGeneratedTitles();
    _generation++;
    persist();
  }

  void jumpTo(AnalysisNode node) {
    section.cursorNode = node;
    _lastMove = null;
    persist();
    notifyListeners();
  }

  /// Takes a move back, with everything written under it. The root is the
  /// part's starting position rather than a move, and is left alone.
  ///
  /// The cursor is moved off the subtree before it is detached: a cursor left
  /// inside it would be a board showing a position the part no longer holds.
  /// One change, one undo step — the move back and the move away together.
  void deleteNode(AnalysisNode node) {
    final parent = node.parent;
    if (parent == null) return;
    if (_cursorIsAtOrBelow(node)) {
      section.cursorNode = parent;
      _lastMove = null;
    }
    parent.removeChild(node);
    persist();
    notifyListeners();
  }

  /// A variation inside the open part moved one place among its siblings —
  /// only a part saved before 26.9.2026 still has one (D4 of
  /// `docs/PLAN-MAPA-DELOVA.md`). One undo step; nothing when it cannot move.
  void moveVariation(AnalysisNode node, {required bool earlier}) {
    final parent = node.parent;
    if (parent == null || !parent.moveVariation(node, earlier: earlier)) return;
    persist();
    notifyListeners();
  }

  /// Makes a sideline the line the child walks.
  void promoteNode(AnalysisNode node) {
    final parent = node.parent;
    if (parent == null) return;
    parent.promoteToMainLine(node);
    persist();
    notifyListeners();
  }

  /// Starts the part over on [fen], with nothing written after it.
  void startFrom(String fen) {
    final fresh = AnalysisNode(fen: fen);
    section
      ..root = fresh
      ..cursorNode = fresh
      // The stored text described the line that was just thrown away.
      ..storedPgn = null;
    _lastMove = null;
    persist();
    notifyListeners();
  }

  /// A whole line read from text, made the part's line — and made into parts
  /// at every fork (D2 of `docs/PLAN-MAPA-DELOVA.md`), the first of them left
  /// open. The cursor goes to the end of that one's line: the trainer pressed
  /// Apply having just written a move. Answers how many parts it became.
  int replaceLine(AnalysisNode root) {
    final count = openLineAsParts(_draft, root);
    section.cursorNode = endOfMainLine(section.root);
    if (count > 1) {
      _renumberGeneratedTitles();
      _generation++;
    }
    _lastMove = null;
    persist();
    notifyListeners();
    return count;
  }

  /// The words of one move. [typing] says the text is being typed into a
  /// field, so a sentence is one undo step; a dialog's answer is a change of
  /// its own.
  void setComment(AnalysisNode node, String text, {bool typing = false}) {
    node.comment = text;
    persist(typingIn: typing ? 'comment:${node.id}' : null);
    notifyListeners();
  }

  /// Turns **every** part over, each from the way it stands now, so a
  /// deliberate mix survives and a tutorial does not end up facing two ways
  /// after one press (14.9.2026).
  void flipAll() {
    for (final part in _draft.sections) {
      part.blackOrientation = !part.blackOrientation;
    }
    persist();
    notifyListeners();
  }

  /// One part turned on its own — from its row („Turn this part").
  void setPartOrientation(int index, bool black) {
    if (index < 0 || index >= _draft.sections.length) return;
    _draft.sections[index].blackOrientation = black;
    persist();
    notifyListeners();
  }

  // ── the tutorial's own fields ────────────────────────────────────────────

  void setTitle(String text) {
    _draft.title = text;
    persist(typingIn: 'title');
  }

  /// Comma-separated, normalised into the draft; the field keeps what was
  /// typed, so the comma the trainer just wrote is not deleted under them.
  void setLabels(String text) {
    _draft.tags
      ..clear()
      ..addAll(normaliseLabels(text.split(',')));
    persist(typingIn: 'labels');
  }

  /// A menu calls back for the answer it already shows too. Picking „Not set"
  /// on a draft that never knew its language must not turn silence into „not
  /// said" — the three states `LanguageWrite` exists for.
  void setLanguage(String? code) {
    if (code == _draft.language) return;
    _draft.language = code;
    persist();
    notifyListeners();
  }

  // ── saving ───────────────────────────────────────────────────────────────

  /// Why the draft cannot be sent as it stands, in the trainer's words, or
  /// null. Parts are named, not counted: a refusal that says „a part" to
  /// somebody with fourteen has told them they are wrong and not where.
  String? validate() {
    if (_draft.title.trim().isEmpty) return 'Tutorial must have a title.';
    return null;
  }

  /// Sends the draft — the first time creates the tutorial, every time after
  /// edits the same one (`commitDraft`). Returns the refusal or the server's
  /// own sentence, or null when it was saved.
  ///
  /// What is sent is taken before it is sent: a trainer can type while the
  /// request is out, and those words are not saved just because the answer
  /// arrived after them. Its ids are handed back by [_giveBackIds] if it is
  /// ever restored.
  Future<String?> save(LessonApiService api) async {
    final refusal = validate();
    if (refusal != null) return refusal;

    _draft.title = _draft.title.trim();
    final sentSnapshot = jsonEncode(_draft.toJson());
    final sentSignature = _draft.contentSignature();
    final error = await commitDraft(_draft, api);
    if (error != null) return error;

    _savedSnapshot = sentSnapshot;
    _savedSignature = sentSignature;
    // The draft now knows its lesson id and every step id, so the next save
    // edits this tutorial instead of making a second one.
    persist();
    notifyListeners();
    return null;
  }

  /// The parts, quoted, by the names the list of parts shows — so the trainer
  /// can find them there.
  String namesOf(List<TutorialSection> parts) =>
      parts.map((s) => '"${s.label(_draft.sections.indexOf(s))}"').join(', ');

  /// One part, and nothing in it: no moves, no words, and no name of the
  /// trainer's own.
  ///
  /// What „is there anything here to append to" means — see
  /// [addSectionsFrom] for why this is not [isEmptyDraft]. The name is asked
  /// about because a part the trainer has named is a part they meant, even
  /// with nothing on the board yet; the generated „Part 1" is not a name.
  static bool holdsOnlyABlankPart(TutorialDraft draft) {
    if (draft.sections.length != 1) return false;
    final only = draft.sections.single;
    final named = only.title.trim();
    return only.root.children.isEmpty &&
        only.root.comment.trim().isEmpty &&
        (named.isEmpty || isGeneratedSectionTitle(named));
  }

  /// Nothing worth offering: one part, no moves, no words, no name.
  static bool isEmptyDraft(TutorialDraft draft) =>
      draft.title.trim().isEmpty &&
      draft.sections.length == 1 &&
      draft.sections.single.root.children.isEmpty &&
      draft.sections.single.root.comment.trim().isEmpty;

  /// Whether [node] holds anything beyond the move itself — what a deletion
  /// is worth asking about.
  static bool carriesWork(AnalysisNode node) =>
      node.children.isNotEmpty ||
      node.comment.trim().isNotEmpty ||
      node.arrows.isNotEmpty ||
      node.squares.isNotEmpty;

  // ── inside ───────────────────────────────────────────────────────────────

  void _partChanged() {
    _lastMove = null;
    _generation++;
    persist();
    notifyListeners();
  }

  /// Puts the generated names back in order after the parts have moved. Only
  /// the names the studio wrote itself — a title the trainer typed is theirs.
  void _renumberGeneratedTitles() {
    for (var i = 0; i < _draft.sections.length; i++) {
      final title = _draft.sections[i].title;
      if (title.trim().isEmpty || isGeneratedSectionTitle(title)) {
        _draft.sections[i].title = generatedSectionTitle(i);
      }
    }
  }

  bool _cursorIsAtOrBelow(AnalysisNode node) {
    for (AnalysisNode? n = cursor; n != null; n = n.parent) {
      if (identical(n, node)) return true;
    }
    return false;
  }

  void _startHistory() {
    _history.start(jsonEncode(_draft.toJson()), _draft.contentSignature());
  }

  /// Puts a snapshot back as the draft being written.
  ///
  /// Not through [persist]: a restore is not a change, and recording it would
  /// make the next undo undo the undo. The on-device slot is still written, so
  /// closing the window keeps what is on screen.
  void _restore(String? snapshot) {
    if (snapshot == null) return;
    final restored = _decode(snapshot);
    _giveBackIds(restored);
    _draft = restored;
    _lastMove = null;
    _generation++;
    _hasUnsavedChanges = _differsFromSaved();
    _slot.scheduleSave(_draft, epoch: _epoch);
    notifyListeners();
  }

  /// **The identities a save handed out survive going back past it.**
  ///
  /// A snapshot from before the first save has no lesson id, and restoring it
  /// as it is would make the next save create a second tutorial. Its parts
  /// have no step ids either; each gets back the one its key was given, unless
  /// another part already holds it.
  void _giveBackIds(TutorialDraft restored) {
    restored.lessonId ??= _draft.lessonId;
    for (final part in _draft.sections) {
      final id = part.stepId;
      if (id != null) _stepIdsByKey[part.localKey] = id;
    }
    final held = {
      for (final s in restored.sections)
        if (s.stepId != null) s.stepId!,
    };
    for (final part in restored.sections) {
      if (part.stepId != null) continue;
      final id = _stepIdsByKey[part.localKey];
      if (id != null && held.add(id)) part.stepId = id;
    }
  }

  static TutorialDraft _decode(String snapshot) => TutorialDraft.fromJson(
      Map<String, dynamic>.from(jsonDecode(snapshot) as Map));

  bool _differsFromSaved([String? signature]) =>
      _savedSignature != null &&
      (signature ?? _draft.contentSignature()) != _savedSignature;

  void _setUnsaved(bool value) {
    if (_hasUnsavedChanges == value) return;
    _hasUnsavedChanges = value;
    notifyListeners();
  }
}
