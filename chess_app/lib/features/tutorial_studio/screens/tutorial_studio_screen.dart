import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/services/tutorial_language.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node_cursor.dart';
import 'package:chess_app/features/analysis_studio/models/pgn_span.dart';
import 'package:chess_app/features/analysis_studio/services/studio_lesson_step.dart';
import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_beat.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_storage.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_take.dart';
import 'package:chess_app/features/tutorial_studio/services/section_split.dart';
import 'package:chess_app/features/library/models/library_entry.dart'
    show CourseSummary;
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/course_picker_dialog.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_controller.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_parts_transfer.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_editor_entry.dart';
import 'package:chess_app/features/tutorial_studio/widgets/part_picker_dialog.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video_export.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_narration_screen.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_flow_panel.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_pgn_export_dialog.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_parts_map.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_pgn_panel.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_sections_panel.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_bar.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_controller.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';

part 'tutorial_studio_phone_layout.dart';

/// The room a trainer writes a tutorial in. Phase 4 of
/// `docs/PLAN-TUTORIJAL.md`.
///
/// **Why it is not a twelfth action in the Analysis Studio.** That screen is
/// 2446 lines and twelve actions of *analysing* — engine, explorer, tablebase,
/// motifs, game review — and every one of them is noise to somebody writing.
/// More concretely, the authoring flow needs a running list of examples on
/// screen at all times, and there is no room for it in a layout already
/// carrying a board, a move tree and an engine panel.
///
/// **What it holds, and nothing else:** the board, the move tree of the part
/// being written, the fields for the node the trainer is standing on, and the
/// running list of parts with one save at the end.
///
/// **P1 of `docs/PLAN-STUDIO-REDIZAJN.md` changed what is underneath it and
/// nothing that is on it.** A finished part used to be flattened to `fen` +
/// `pgn` and its tree dropped, so it could never be reopened — which is why a
/// second, weaker editing screen had to exist beside this one. Every part now
/// keeps its tree, so the screen holds one [TutorialDraft] and stands on
/// `_draft.section` instead of keeping a working tree beside a list of finished
/// strings. Not one user-facing string moved, which is what makes
/// `test/tutorial_authoring_test.dart` passing **unedited** the proof that the
/// flow survived. The layout this model was built for is P5.
///
/// Everything it draws already existed. Not one line of board, tree or cursor
/// code is copied in here — two models of one tree is the fault this codebase
/// has already paid for twice — and `test/tutorial_studio_test.dart` fails if a
/// copy appears.
/// What the trainer answered about the draft waiting in the slot.
///
/// Three answers rather than two. „Odbaci" and „Nastavi" left no way back out
/// of a question the trainer had not meant to be asked — and the dialog could
/// be dismissed by tapping beside it, which was read as „discard" and deleted
/// an unfinished tutorial without a word.
enum _DraftChoice { resume, fresh, cancel }

/// What the trainer answered when a tutorial opened with changes this device
/// kept and the server never received.
enum _UnsavedChoice { mine, saved }

/// What to do with the position a pasted PGN brought with it.
enum _PastedPosition { take, keep, cancel }

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

/// The studio's Ctrl+Z / Ctrl+Y, stepping aside while [enabled] says no.
///
/// A disabled action does not take the key, so it goes on up to the app's
/// text-editing shortcuts and the focused field undoes its own typing.
class _StudioHistoryAction<T extends Intent> extends CallbackAction<T> {
  _StudioHistoryAction({required super.onInvoke, required this.enabled});

  final bool Function() enabled;

  @override
  bool isEnabled(T intent) => enabled();
}

class TutorialStudioScreen extends StatefulWidget {
  const TutorialStudioScreen({
    super.key,
    required this.session,
    required this.entry,
    this.lessonApi,
    this.narrationStore,
    this.positionLibrary,
  });

  final UserSession session;

  /// Why the screen is being opened — D4 of `docs/PLAN-STUDIO-REDIZAJN.md`.
  ///
  /// Required, and with no default. The screen used to take an optional
  /// handover and load the one stored draft slot regardless, which is exactly
  /// how opening it to start something new came up carrying the last tutorial.
  final TutorialEntry entry;

  /// The seam a test watches the single save through.
  ///
  /// Defaulted to a real service against this session's token, so nothing but a
  /// test ever passes it.
  final LessonApiService? lessonApi;

  /// Where this device keeps recorded takes. Null means the app's own place.
  ///
  /// One seam for the three readers on this screen — the banner, the recording
  /// screen and the export — because a store passed to one of them and not the
  /// others is a test that watches a take nothing else can see.
  final NarrationTakeStore? narrationStore;

  /// The shelf „Add parts from a tutorial…" picks from. The same seam the
  /// room's column already takes, so a test answers for the shelf in one
  /// place rather than faking a picker.
  final PositionLibraryService? positionLibrary;

  @override
  State<TutorialStudioScreen> createState() => _TutorialStudioScreenState();
}

class _TutorialStudioScreenState extends State<TutorialStudioScreen> {
  final ChessBoardController _boardController = ChessBoardController();
  final BoardAnnotationController _annotationController =
      BoardAnnotationController();

  late final LessonApiService _lessonApi =
      widget.lessonApi ?? LessonApiService(authToken: widget.session.token);

  late final NarrationTakeStore _narrationStore =
      widget.narrationStore ?? deviceNarrationStore();

  late final PositionLibraryService _library = widget.positionLibrary ??
      PositionLibraryService(authToken: widget.session.token);

  /// The take this device holds for this tutorial, when it holds one. Read once
  /// on the way in and again whenever the recording screen closes — phase 5.
  NarrationTake? _narrationTake;

  /// The tutorial being written — the draft, which part is open, the cursor,
  /// the history, the saved version. Phase 6a of
  /// `docs/PLAN-REORGANIZACIJA.md`: this screen is one layout over it and
  /// keeps no copy of any of that. What stays here is the screen's own: a
  /// board controller, the drawing mode, the text fields and their epoch,
  /// the dialogs and the messages.
  late final TutorialDraftController _c;

  /// The controller's [TutorialDraftController.generation] the fields were
  /// last built from, and the cursor the board was last loaded from.
  int _seenGeneration = -1;
  AnalysisNode? _seenCursor;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _labelsController = TextEditingController();
  int _selectedTab = 0;

  /// The PGN tab holds text that was not applied. Kept by the panel through
  /// `onEdited`; nothing draws from it, so it is a field and not state.
  bool _pgnEdited = false;

  /// True, and said, when the PGN tab holds text that was not applied.
  ///
  /// The field is rebuilt whenever the open part's line is a different one —
  /// another part opened, the part started over, a snapshot put back — and
  /// its text would be gone without a word; carried across, it would be
  /// applied to a part it was not written for. So every door that would do
  /// that asks here first (the owner's decisions of 25.9.2026, for a move
  /// that opens a part and then for every other way out of a part). Said
  /// before anything else happens, because nothing else does.
  bool _heldForPgn(String what) {
    if (!_pgnEdited) return false;
    AppFeedback.info(context, '$what $_pgnFirst');
    return true;
  }

  static const _pgnFirst = 'Apply or discard the text in the PGN tab first.';

  /// Which of Line/Parts is open on the phone layout ([_PhoneLayout]).
  /// The screen's own, like [_selectedTab] — the controller holds none of it.
  int _phoneTab = 0;

  void _selectPhoneTab(int tab) => setState(() => _phoneTab = tab);

  /// Set when the trainer backs out of the „unfinished tutorial" question.
  ///
  /// The screen flushes its draft on the way out, and the draft it is holding
  /// at that moment is the *blank* one it opened with — so writing it would
  /// overwrite the very tutorial the trainer just chose not to touch. Backing
  /// out has to leave the slot exactly as it was found.
  bool _leftWithoutWriting = false;

  TutorialDraft get _draft => _c.draft;

  /// The line being written, and where the trainer is standing on it.
  AnalysisNode get _root => _c.root;
  AnalysisNode get _current => _c.cursor;

  /// The way the open part faces. The part's, not the screen's: a field of
  /// the screen's own was what let one part's orientation be written over
  /// another's.
  PlayerColor get _orientation =>
      _c.section.blackOrientation ? PlayerColor.black : PlayerColor.white;

  /// The handed-over line, when the screen was opened through the Studio's
  /// door. Null for every other way in.
  TutorialHandover? get _handover => switch (widget.entry) {
        TutorialEntryFromAnalysis(:final handover) => handover,
        _ => null,
      };

  @override
  void initState() {
    super.initState();
    final handover = _handover;

    final draft = switch (widget.entry) {
      // The saved tutorial is the draft. Nothing is taken out of the local slot
      // until it has said which tutorial it belongs to — see
      // [_adoptStoredDraft].
      TutorialEntrySaved(:final lesson) => TutorialDraft.fromLesson(lesson),
      // The same reader, and no id: the first "Save tutorial" creates it.
      TutorialEntryImported(:final lesson) => TutorialDraft.fromLesson(lesson),
      TutorialEntryBlank(:final title) => TutorialDraft(
          title: title,
          sections: [
            TutorialSection.blank(
              fen: TutorialDraft.startFen,
              title: generatedSectionTitle(0),
            ),
          ],
        ),
      TutorialEntryFromAnalysis() => TutorialDraft(
          sections: [
            TutorialSection.blank(
              fen: handover?.root.fen ?? TutorialDraft.startFen,
              title: generatedSectionTitle(0),
            ),
          ],
        ),
    };

    if (handover != null) {
      // Before the split, so every part it makes faces the same way.
      draft.section.blackOrientation = handover.blackOrientation;
      openLineAsParts(draft, handover.root);
    }
    _c = TutorialDraftController(draft: draft);
    _c.addListener(_onController);
    // Every field of the open part, from the part — the lesson of 7.9.2026: a
    // field left at its default is a default written back over the part on
    // the next change. See `test/tutorial_reopen_test.dart`.
    _refillFields();
    unawaited(_adoptStoredDraft());
    unawaited(_loadNarrationTake());
  }

  /// This device's take for the open tutorial, for [_narrationBanner].
  ///
  /// **Started, never awaited by anything that draws.** It asks the platform
  /// for the app's own folder, and a screen that waits on a folder it may not
  /// need is a screen that does not open when that call does not return — which
  /// is what a widget test's clock does to it, and what cost the export dialog
  /// twelve tests in phase 4. Nothing here is a failure worth a sentence: no
  /// folder, no take, no banner.
  Future<void> _loadNarrationTake() async {
    final id = _draft.lessonId;
    NarrationTake? take;
    if (id != null) {
      try {
        take = (await _narrationStore.load(id)).stored?.take;
      } catch (_) {
        take = null;
      }
    }
    if (!mounted) return;
    setState(() => _narrationTake = take);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _labelsController.dispose();
    // Flushed rather than left to the debounce: a pending timer dies with the
    // screen, and a draft that is only ever written 600 ms after the last move
    // is a draft that is never written when the trainer closes the window.
    //
    // Unless the trainer backed out of the stored-draft question, in which case
    // this screen holds a blank draft and writing it would delete theirs.
    if (!_leftWithoutWriting) unawaited(_c.flush());
    _c.removeListener(_onController);
    _c.dispose();
    super.dispose();
  }

  /// Decides what to do with the draft left in the local slot.
  ///
  /// One slot, one draft, and until P3b it was loaded on every open regardless
  /// of what the trainer had asked for — which is complaint 1.1 of
  /// `docs/PLAN-STUDIO-REDIZAJN.md`, in one line. What the entry says now
  /// decides:
  ///
  /// * **from the Studio's door** — the parts already written come back, and
  ///   the handed-over line becomes the open one. That is the flow the door
  ///   exists for: work the next part out in the Studio, hand it over, carry on
  ///   with the same tutorial. Unless the door said otherwise, in which case
  ///   nothing is adopted.
  /// * **a saved tutorial** — only a draft **of that tutorial** is adopted. A
  ///   draft of another one is somebody else's unfinished business, and is left
  ///   exactly where it is and unmentioned.
  /// * **a new tutorial** — nothing is adopted, and if the slot holds anything
  ///   the trainer is asked, by name. Silence is what made this feel haunted.
  Future<void> _adoptStoredDraft() async {
    final stored = await TutorialDraftService.instance.load();
    if (!mounted) return;

    switch (widget.entry) {
      case TutorialEntryFromAnalysis(:final intoOpenDraft):
        if (stored == null || !intoOpenDraft) return;
        final handover = _handover!;
        // The parts already written stay; the one being written is the line
        // the trainer just handed over.
        stored.selected = stored.sections.length - 1;
        openLineAsParts(stored, handover.root);
        _c.adopt(stored);

      case TutorialEntrySaved():
        // A draft that never belonged to a tutorial, or belonged to a different
        // one, says nothing about this one.
        final mine = stored != null &&
                stored.lessonId != null &&
                stored.lessonId == _draft.lessonId
            ? stored
            : null;
        if (mine != null) _c.adopt(mine);
        await _compareWithSaved(keptOnDevice: mine != null);

      case TutorialEntryImported():
        // Nothing to adopt. The trainer asked for *this file*, and a draft left
        // in the slot is some other tutorial's unfinished business — the same
        // answer a saved tutorial gives to a draft that is not its own. It is
        // not offered either: a question about an unrelated draft, asked at the
        // moment a file was picked, is the haunting P3b removed.
        return;

      case TutorialEntryBlank():
        if (stored == null || TutorialDraftController.isEmptyDraft(stored)) {
          return;
        }
        final choice = await _askAboutStoredDraft(stored);
        if (!mounted) return;
        switch (choice) {
          case _DraftChoice.resume:
            _c.adopt(stored);
          case _DraftChoice.fresh:
            // Thrown away rather than left behind: a draft the trainer has
            // just declined must not be waiting for them the next time they
            // start something. This is the one branch that loses work, which
            // is why the question says so in those words.
            await TutorialDraftService.instance.clear();
          case _DraftChoice.cancel:
            // Neither tutorial is touched: not the stored one, and not this
            // blank screen, which goes away.
            _leftWithoutWriting = true;
            final navigator = Navigator.of(context);
            if (navigator.canPop()) navigator.pop();
        }
    }
  }

  /// Asks about the draft in the slot, **by name**.
  ///
  /// The name is the whole point. „You have an unfinished draft" is a question
  /// nobody can answer; „Opozicija, 3 dela" is one they can.
  Future<_DraftChoice> _askAboutStoredDraft(TutorialDraft stored) async {
    final name = stored.title.trim().isEmpty ? 'unnamed' : stored.title.trim();
    final answer = await showDialog<_DraftChoice>(
      context: context,
      // Not dismissible: tapping beside this dialog used to answer it, and the
      // answer it gave was „discard".
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('You have an unfinished tutorial'),
        content: Text(
          'Last time you were writing tutorial "$name" '
          '(${stored.sections.length} ${_partsWord(stored.sections.length)}). '
          'Continue where you left off or start a new one? '
          'If you start a new one, the unfinished one will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_DraftChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_DraftChoice.fresh),
            child: const Text('New'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_DraftChoice.resume),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    // A dialog that comes back with nothing — a back button, a route popped
    // from elsewhere — is a question that was not answered, and an unanswered
    // question must never be read as the answer that deletes something.
    return answer ?? _DraftChoice.cancel;
  }

  static String _partsWord(int count) => count == 1 ? 'part' : 'parts';

  /// Reads the saved version of the open tutorial and holds the draft on
  /// screen against it — phase 2 of `docs/PLAN-STUDIO-ISTORIJA.md`.
  ///
  /// Until then a draft this device kept of the same tutorial was adopted
  /// without a word. That was deliberate, since work survives a closed window,
  /// and it is how a part deleted and never saved was still deleted the next
  /// time the tutorial opened: nothing told „changes you made" from „what is
  /// saved", and nothing led back.
  ///
  /// **The draft is adopted before this is asked, not after.** The answer is a
  /// network round trip of up to twenty seconds, and a trainer who starts
  /// writing in that time must not have their work swapped out from under
  /// them when it arrives. So the question is asked only while nothing has
  /// changed since the studio opened; after that, the saved version is only
  /// remembered, and „Discard changes" leads back to it.
  Future<void> _compareWithSaved({required bool keptOnDevice}) async {
    final id = _draft.lessonId;
    if (id == null) return;
    final row = await _lessonApi.fetchTutorial(id);
    if (!mounted) return;

    if (row == null) {
      // A question that cannot be answered correctly is not asked. The draft
      // opens as it always did, and the trainer is told why nothing was asked.
      if (keptOnDevice) {
        AppFeedback.info(
          context,
          'Could not reach the server to compare this tutorial with its saved '
          'version. It opened with the changes kept on this device.',
        );
      }
      return;
    }

    final saved = TutorialDraft.fromLesson(row);
    final untouched = _c.untouched;
    final differs = _c.rememberSaved(saved);

    if (!differs || !untouched) return;
    if (!keptOnDevice) {
      // Nothing of the trainer's is on screen, only the row the library list
      // handed over — which is older than the last save when that save was
      // made elsewhere. The saved version is simply the tutorial.
      _c.adopt(saved);
      return;
    }
    final choice = await _askAboutUnsavedChanges();
    if (!mounted) return;
    if (choice == _UnsavedChoice.saved) _discardChanges();
  }

  /// „This tutorial has changes you have not saved": continue with them, or
  /// open the saved version.
  ///
  /// Neither answer loses anything for as long as the studio is open: the saved
  /// version is put on screen as an undoable change, exactly as „Discard
  /// changes" puts it, so Ctrl+Z brings the changes back. That is why the
  /// question can be asked plainly rather than as a warning.
  Future<_UnsavedChoice> _askAboutUnsavedChanges() async {
    final title = _draft.title.trim();
    final name = title.isEmpty ? 'This tutorial' : '"$title"';
    final answer = await showDialog<_UnsavedChoice>(
      context: context,
      // Not dismissible, for the reason [_askAboutStoredDraft] gives.
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('This tutorial has changes you have not saved'),
        content: Text(
          '$name was changed on this device and not saved. Continue with '
          'those changes, or open the version saved on the server? Undo '
          'brings the changes back until you close the tutorial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_UnsavedChoice.saved),
            child: const Text('Open the saved version'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_UnsavedChoice.mine),
            child: const Text('Continue with my changes'),
          ),
        ],
      ),
    );
    // Unanswered is the answer that changes nothing on screen.
    return answer ?? _UnsavedChoice.mine;
  }

  /// „Discard changes": the saved version, put back as a change of its own —
  /// recorded like any other, so a mistaken press is one Ctrl+Z away.
  void _discardChanges() {
    _annotationController.stop();
    _c.discardChanges();
  }

  /// The one place this screen hears the controller. A structural change
  /// rebuilds the fields from the model; a cursor that moved puts its position
  /// on the board; everything redraws.
  void _onController() {
    if (!mounted) return;
    if (_c.generation != _seenGeneration) {
      _refillFields();
    } else if (!identical(_seenCursor, _c.cursor)) {
      _boardController.loadFen(_c.cursor.fen);
      _seenCursor = _c.cursor;
    }
    setState(() {});
  }

  /// Fills the fields from the part that is open.
  void _refillFields() {
    _seenGeneration = _c.generation;
    _annotationController.cancelPending();
    final section = _c.section;
    _titleController.text = _draft.title;
    _labelsController.text = _draft.tags.join(', ');
    _boardController.loadFen(_c.cursor.fen);
    _seenCursor = _c.cursor;
  }

  void _undo() {
    if (_heldForPgn('Undo would replace this part.')) return;
    _annotationController.stop();
    _c.undo();
  }

  void _redo() {
    if (_heldForPgn('Redo would replace this part.')) return;
    _annotationController.stop();
    _c.redo();
  }

  /// The one cursor this screen is walked by — the strip's buttons and the
  /// arrow keys read it from here rather than each building their own.
  ///
  /// [AnalysisNodeCursor] is what makes the strip *ask* at a fork instead of
  /// walking into the first child. That rule matters more on this side than on
  /// the student's: a trainer who wrote two answers to one move and gets only
  /// one of them back has lost the sideline they wrote the tutorial for.
  AnalysisNodeCursor _moveCursor() =>
      AnalysisNodeCursor(currentNode: _current, onSelect: _jumpTo);

  void _jumpTo(AnalysisNode node) {
    // Drawing is left, not just interrupted. A half-drawn arrow was already
    // forgotten here — it would otherwise land on a position its first
    // square does not belong to — but the mode itself stayed on, so the next
    // click on the new beat's board drew instead of doing what it looked
    // like it would do. Asked for live on 7.9.2026: the toolbar must not
    // still be lit on a beat the trainer has only just arrived at.
    _annotationController.stop();
    _c.jumpTo(node);
  }

  /// Takes a move back, with everything written under it.
  ///
  /// **The menu was already there and did nothing.** `AnalysisMoveTreeWidget`
  /// draws „Unapredi u Glavnu Liniju" and „Obriši Ovu Varijantu" on a
  /// long-press or a right-click, and this screen passed neither callback — so
  /// a trainer opened it, pressed „Obriši", and the move stayed. The only way
  /// to take a move back was to retype the line in the „PGN" tab, which is
  /// where the owner found it on 7.9.2026: „ne mogu da se brišu potezi (ili ne
  /// vidim kako)". The dead entries are hidden now, and these two are wired.
  ///
  /// It asks first only when there is something to lose — a move with words,
  /// drawings or moves under it. A trainer taking back a piece they dropped on
  /// the wrong square should not have to answer a question about it, and a
  /// dialog on every deletion is a dialog that gets dismissed unread.
  Future<void> _deleteNode(AnalysisNode node) async {
    final parent = node.parent;
    // The root is the part's starting position rather than a move. There is a
    // way to throw that away and it is „Obriši deo".
    if (parent == null) return;

    if (TutorialDraftController.carriesWork(node)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete move?'),
          content: Text(
            '"${node.moveNumberLabel}${node.moveSan}" and everything '
            'written after it will be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }

    _annotationController.stop();
    _c.deleteNode(node);
  }

  /// Makes a sideline the line the child walks.
  ///
  /// It matters more here than in the Analysis Studio: the „Tok" timeline and
  /// the narrated walk both follow first children, so which branch is main is
  /// a decision about the lesson rather than about how the tree is drawn.
  void _promoteNode(AnalysisNode node) => _c.promoteNode(node);

  /// A move the board reported, dragged or tapped.
  ///
  /// A move the position does not allow puts the board back where it was rather
  /// than growing a line out of it: the board is the trainer's only view of
  /// where they are, and leaving it showing a position the tree does not hold is
  /// how the two quietly part company.
  void _onMove(String from, String to, String promotion) {
    _annotationController.cancelPending();
    switch (_c.playMove(from, to, promotion, mayOpenPart: !_pgnEdited)) {
      case MoveOutcome.illegal:
        // The board has already moved the piece; the part has not.
        _boardController.loadFen(_current.fen);
      case MoveOutcome.heldBack:
        // Put back first, then said. The PGN tab keeps its text even while
        // another tab is showing, so the sentence names the tab.
        _boardController.loadFen(_current.fen);
        AppFeedback.info(
            context, 'This move would start a new part. $_pgnFirst');
      case MoveOutcome.played:
        break;
      case MoveOutcome.branched:
        // Done, then said: the part exists before the sentence about it.
        final move = _current;
        final part = _c.draft.selected + 1;
        AppFeedback.info(
          context,
          '${move.moveNumberLabel}${move.moveSan} starts part $part. '
          'The film shows it after part ${part - 1}.',
        );
    }
  }

  /// Starts the part over on [fen], with nothing written after it.
  void _startFrom(String fen) {
    _annotationController.cancelPending();
    _c.startFrom(fen);
  }

  /// Turns **every** part over, each from the way it stands now.
  ///
  /// It turned the open part alone until 14.9.2026, and nothing on the screen
  /// said so: the owner flipped part 1 of a twelve-part tutorial and found it
  /// facing the other way from the eleven after it, in the viewer and in the
  /// film. Parts that face different ways keep facing different ways — a
  /// tutorial with parts 1 and 3 from Black and part 2 from White comes out
  /// 1 and 3 from White and 2 from Black — so a deliberate mix survives, and
  /// one part is turned on its own from its row ([_turnPart]).
  void _flipBoard() => _c.flipAll();

  /// „Turn this part" — one part, from its own row.
  ///
  /// Its door used to be „Preview tutorial", the student's viewer run on the
  /// draft, and that door went with the viewer (docs/PLAN-TUTORIJAL-VIDEO.md,
  /// D12): a tutorial is a film now, and this was the one job the preview did
  /// that nothing else could.
  void _turnPart(int index) =>
      _c.setPartOrientation(index, !_c.draft.sections[index].blackOrientation);

  /// The second and third of the three ways a start position gets here — a FEN
  /// typed in and the board editor. The first is the handover. It is the
  /// Studio's own dialog, so a trainer who has set a position once has set it
  /// everywhere.
  ///
  /// `onPgnLoaded` is deliberately not passed: importing a PGN into a tree is
  /// the Analysis Studio's job, and a line brought in that way arrives here
  /// through the door as a whole tree rather than through a second importer
  /// written beside the first.
  void _showSetupDialog() {
    if (_heldForPgn('That would start the part over.')) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AnalysisBoardSetupDialog(
        initialFen: _current.fen,
        onPositionSet: _startFrom,
      ),
    );
  }

  /// Ctrl+Z and Ctrl+Y (and Ctrl+Shift+Z) are the studio's, **inside text
  /// fields too**.
  ///
  /// The plan first left Ctrl+Z to a focused field. It was changed for a reason
  /// only the platform shows: on Windows a text field keeps its focus when the
  /// trainer then drags a piece on the board, so after writing a sentence and
  /// playing a move, Ctrl+Z would have gone to the field's own letter-by-letter
  /// history and left the move standing. The studio's history holds typing too,
  /// one step per pause, so one undo is enough for both. These shortcuts sit
  /// nearer the fields than the app's text-editing ones, which is what makes
  /// them win.
  ///
  /// **Except over unapplied PGN text.** The studio's undo rebuilds the part,
  /// and the field with it, so while the PGN tab holds text of its own the
  /// studio's history steps aside and the keys reach the field — a typo fixed
  /// with Ctrl+Z used to throw the whole text away. The toolbar's Undo still
  /// says why it will not ([_heldForPgn]).
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, control: true): _RedoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            _RedoIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _UndoIntent: _StudioHistoryAction<_UndoIntent>(
            enabled: () => !_pgnEdited,
            onInvoke: (_) {
              _undo();
              return null;
            },
          ),
          _RedoIntent: _StudioHistoryAction<_RedoIntent>(
            enabled: () => !_pgnEdited,
            onInvoke: (_) {
              _redo();
              return null;
            },
          ),
        },
        child: _buildScreen(context),
      ),
    );
  }

  Widget _buildScreen(BuildContext context) {
    // Phase 6b of `docs/PLAN-REORGANIZACIJA.md` §7: a touch platform narrower
    // than [Breakpoints.wide] gets Line | Task | Parts over this same
    // controller, in `tutorial_studio_phone_layout.dart`.
    //
    // **Neither signal alone is right, so this reads both.** `dart:io`'s
    // `Platform` is what `tutorial_studio_availability.dart` already reads
    // for „is this Windows" — real and host-independent on a device, but
    // blind to `debugDefaultTargetPlatformOverride`, which is exactly what
    // the phone gate sets and how it stands at 360 dp without touching a real
    // device. `Theme.of(context).platform` sees that override, but
    // `flutter test` defaults it to `TargetPlatform.android` whenever nothing
    // overrides it — which is every one of the studio's own narrow-window
    // tests — so reading the theme alone routed them into this layout too and
    // broke four files that test the desktop's own narrow branch. The
    // override is read directly, and only when a test has actually set it,
    // is this a phone; everywhere else — including inside `flutter test` on
    // whatever host it runs on — `dart:io` decides, exactly as it already
    // does for the door to this screen.
    final override = debugDefaultTargetPlatformOverride;
    final isTouch = override == TargetPlatform.android ||
        override == TargetPlatform.iOS ||
        (override == null && !kIsWeb && (Platform.isAndroid || Platform.isIOS));
    if (!Breakpoints.isWide(context) && isTouch) {
      return LayoutBuilder(
        builder: (context, constraints) => _buildPhone(constraints),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tutorial Studio',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: AppText.title,
        ),
        actions: [
          IconButton(
            key: const Key('tutorial-undo'),
            icon: const Icon(Icons.undo),
            tooltip: 'Undo (Ctrl+Z)',
            onPressed: _c.canUndo ? _undo : null,
          ),
          IconButton(
            key: const Key('tutorial-redo'),
            icon: const Icon(Icons.redo),
            tooltip: 'Redo (Ctrl+Y)',
            onPressed: _c.canRedo ? _redo : null,
          ),
          // Beside undo and redo because it is one of them: back to the saved
          // version, and itself undoable. Measured as Windows draws the bar
          // (Segoe UI, the app's theme): the actions take 453 px, nothing
          // overflows at 600 dp, and the title's 111 px are whole down to
          // about 610.
          IconButton(
            key: const Key('discard-changes'),
            icon: const Icon(Icons.restore),
            tooltip: 'Discard changes',
            onPressed: _c.hasUnsavedChanges ? _discardChanges : null,
          ),
          IconButton(
            icon: Icon(Icons.tune, color: context.colors.accent),
            tooltip: 'Position setup',
            onPressed: _showSetupDialog,
          ),
          IconButton(
            key: const Key('record-narration'),
            icon: const Icon(Icons.mic_none),
            tooltip: 'Record narration',
            onPressed: _recordNarration,
          ),
          IconButton(
            key: const Key('export-video'),
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Export video',
            onPressed: _exportVideo,
          ),
          // Beside the video because it is the other way a tutorial leaves the
          // app. It costs the bar 48 px, which the title pays for: the actions
          // were measured at 453 px as Windows draws them and are 501 now, so
          // „Tutorial Studio" is whole down to about 660 dp instead of 610 and
          // ellipses below that. A name that shortens is cheaper than an export
          // nobody can reach.
          IconButton(
            key: const Key('export-tutorial-pgn'),
            icon: const Icon(Icons.save_alt),
            tooltip: 'Save as .pgn',
            onPressed: _exportPgn,
          ),
          FilledButton(
            onPressed: _saveTutorial,
            child: const Text('Save tutorial'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      // Arrow keys drive the same cursor the strip's buttons do. This screen is
      // written on with a keyboard and a mouse, and reading a line with the
      // mouse alone is what makes a desktop window feel like a phone in a frame.
      body: MoveKeyboardShortcuts(
        cursor: _moveCursor(),
        // _jumpTo does its own setState.
        onChanged: () {},
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= Breakpoints.wide;
            // Beside the tree on a real window, under it on a narrow one. The
            // board never takes more height than it has: a `Row` wider than the
            // screen is clipped in silence in a release build, and this screen
            // is the one that has the most to put in a row.
            final boardPaneWidth =
                constraints.maxWidth - 460 - AppSpacing.md * 3;
            final maxHeightLimit = (constraints.maxHeight - 120).clamp(
              280.0,
              double.infinity,
            );
            final boardSize = wide
                ? boardPaneWidth.clamp(280.0, maxHeightLimit)
                : constraints.maxWidth - AppSpacing.lg * 2;

            final board = _boardColumn(boardSize.toDouble());
            if (!wide) {
              // **The tab strip does not scroll.** The owner's report of
              // 12.9.2026: „Flow, tree i pgn kartice ne treba da se skrivaju
              // prilikom skrolovanja … skroluje se samo ono ispod njih." So the
              // page is slivers rather than one scroll view, with the strip
              // pinned between what is above it and the cards it labels — which
              // are the tallest thing on the screen and the reason anybody
              // scrolls here at all.
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(children: [board, _authoringColumn()]),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _PinnedEditorTabs(
                      // Opaque, and painted here rather than inside the
                      // delegate: `flutter_chess_board` re-exports the chess
                      // package's own `Color`, so naming that type in a field
                      // of this library is ambiguous.
                      child: ColoredBox(
                        color: context.colors.canvas,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: _editorTabs(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    sliver: SliverToBoxAdapter(child: _editorPanels()),
                  ),
                ],
              );
            }
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    key: const Key('board-pane'),
                    child: Center(child: SingleChildScrollView(child: board)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _authoringPaneWide(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _boardColumn(double boardSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _boardCard(boardSize),
        SizedBox(
          width: boardSize,
          child: BoardAnnotationBar(
            mode: _annotationController.mode,
            selectedColorCode: _annotationController.colorCode,
            onArrowPressed: _toggleArrowMode,
            onSquarePressed: _toggleSquareMode,
            onColorSelected: _selectColor,
            onClearPressed: _clearMarks,
            rangeMode: _annotationController.rangeMode,
            onRangePressed: _toggleRangeMode,
          ),
        ),
        SizedBox(
          width: boardSize,
          child: MoveNavigationControls(
            cursor: _moveCursor(),
            centerLabel: null,
            iconSize: 20,
            onFlipBoard: _flipBoard,
          ),
        ),
      ],
    );
  }

  /// The board framed in a card, at [boardSize] — what every layout with
  /// height to spare for a border draws. Split out of [_boardColumn] for the
  /// phone's landscape layout (6b), which gives the board slot exactly a
  /// square (`LandscapeBoardLayout`) and has no height to lose to one — it
  /// calls [_chessBoard] straight through [BoardWithCoordinates] instead.
  Widget _boardCard(double boardSize) {
    return SizedBox(
      width: boardSize,
      height: boardSize,
      child: Card(
        elevation: 4,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: BoardWithCoordinates(
            size: boardSize - AppSpacing.sm * 2,
            orientation: _orientation,
            builder: _chessBoard,
          ),
        ),
      ),
    );
  }

  /// The board itself, at whatever [BoardWithCoordinates] leaves it — no
  /// second copy of its wiring anywhere else in this screen.
  Widget _chessBoard(double boardSize) => ChessBoardWithOverlay(
        controller: _boardController,
        boardOrientation: _orientation,
        boardSize: boardSize,
        isAllowedToMove: true,
        isDrawingMode: _annotationController.isDrawing,
        drawingStartSquare: _annotationController.pendingFrom,
        // The arrows and the rings the trainer drew on this move. The node
        // has carried them since phase 2 of the interactive lesson plan and
        // nothing wrote one until P7a: every arrow in every lesson before
        // that got there by being typed into a PGN by hand. The bar beside it
        // writes them now, through `BoardAnnotationController`.
        arrows: _current.arrows,
        squares: _current.squares,
        engineArrows: const [],
        lastMoveFrom: _c.lastMove?.from,
        lastMoveTo: _c.lastMove?.to,
        onMove: _onMove,
        onSquareTapForDrawing: _onSquareTapForDrawing,
      );

  void _toggleArrowMode() {
    setState(() {
      if (_annotationController.mode == AnnotationMode.arrow) {
        _annotationController.stop();
      } else {
        _annotationController.setMode(AnnotationMode.arrow);
      }
    });
  }

  /// SHIFT, asked at the moment of the tap rather than tracked.
  ///
  /// `HardwareKeyboard` already holds this and is right whether the key went
  /// down before or after the pointer; a listener of our own would be a second
  /// copy of that state, and a copy that stays true when the window loses
  /// focus mid-gesture. Always false on a phone, which is what the button is
  /// for.
  bool get _shiftHeld => HardwareKeyboard.instance.isShiftPressed;

  void _toggleRangeMode() {
    setState(() {
      _annotationController.rangeMode = !_annotationController.rangeMode;
      // Turning it off half-way through leaves a square named and nothing to
      // join it to.
      if (!_annotationController.rangeMode) {
        _annotationController.pendingRangeFrom = null;
      }
    });
  }

  void _toggleSquareMode() {
    setState(() {
      if (_annotationController.mode == AnnotationMode.square) {
        _annotationController.stop();
      } else {
        _annotationController.setMode(AnnotationMode.square);
      }
    });
  }

  void _selectColor(String code) {
    setState(() {
      _annotationController.setColor(code);
    });
  }

  void _clearMarks() {
    final changed = _annotationController.clearMarks(
      arrows: _current.arrows,
      squares: _current.squares,
    );
    if (changed) {
      setState(() {});
      _c.persist();
    }
  }

  void _onSquareTapForDrawing(String square) {
    final changed = _annotationController.tap(
      square,
      arrows: _current.arrows,
      squares: _current.squares,
      // The button or the key, and the same code path either way. SHIFT is the
      // shortcut a trainer at a desk reaches for; the button is the only one of
      // the two that exists on a phone.
      asRange: _annotationController.rangeMode || _shiftHeld,
    );
    setState(() {});
    if (changed) {
      _c.persist();
    }
  }

  /// Tapping the open part again only puts the cursor back on its start, so
  /// that one is never held back.
  void _selectSection(int index) {
    if (index != _c.draft.selected && _heldForPgn(_otherPart)) return;
    _c.select(index);
  }

  static const _otherPart = 'That would open another part.';

  /// „Novi prikaz" — the next demonstration, and the board it opens on.
  ///
  /// The one question left, and it is about a *position* rather than about
  /// parts: „Odavde" keeps the child's board from reloading, which is what
  /// makes two demonstrations in a row read as one; „Nova tabla" starts a
  /// fresh example. The old wording asked where a *deo* begins, which is the
  /// word this screen no longer makes a trainer think in.
  Future<void> _addShowSection() async {
    if (_heldForPgn(_otherPart)) return;
    final continueFromEnd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Where does it start?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('New board'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('From here'),
          ),
        ],
      ),
    );
    if (!mounted || continueFromEnd == null) return;
    _c.addSection(continueFromEnd: continueFromEnd);
  }

  /// „Insert a line here" — phase 3 of `docs/PLAN-STUDIO-ISTORIJA.md`.
  ///
  /// The part is cut at the beat the trainer is standing on, and they are left
  /// on the new line's first position, to play it. [splitForLine] decides what
  /// goes where; the screen only puts the parts in place. Undoable like every
  /// other change, which is what makes a cut in the wrong place cheap.
  ///
  /// Reached only from the current beat's card in „Flow", which draws the
  /// button only when [canSplitForLine] holds — beside „Delete this move", so
  /// it costs no height. In the parts panel, measured as Windows draws it, a
  /// fourth action pushes the icon buttons onto a third row: the list of
  /// parts goes from 114 px to 70 at 1366 × 768 and from 87 to 43 at
  /// 840 × 700, which is one row of parts.
  void _insertLine() {
    if (_heldForPgn(_otherPart)) return;
    _annotationController.stop();
    _c.insertLine();
    AppFeedback.success(context, 'New line inserted. Play it on the board.');
  }

  /// „Preimenuj" — the trainer's own name for a part, or none.
  ///
  /// Emptying the field is not a failure to name it: a part with no name of its
  /// own is called by what it says, which is what [TutorialSection.label] does
  /// and what most parts are better off with.
  Future<void> _renameSection(int index) async {
    if (index < 0 || index >= _draft.sections.length) return;
    final section = _draft.sections[index];
    final own = isGeneratedSectionTitle(section.title.trim())
        ? ''
        : section.title.trim();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: own, hint: section.label(index)),
    );
    if (!mounted || name == null) return;
    _c.renameSection(index, name);
  }

  /// „Add parts from a tutorial…" — another tutorial's parts, copied in here.
  ///
  /// Three questions in a row, each answerable from what is on screen: which
  /// tutorial, which of its parts, and then it is done. The source is only
  /// read; copying is what makes that true, and it is why this needs no second
  /// write and cannot half-succeed.
  Future<void> _addPartsFromTutorial() async {
    if (_heldForPgn(_otherPart)) return;
    final chosen = await showDialog<CourseSummary>(
      context: context,
      builder: (_) => CoursePickerDialog(
        service: _library,
        title: 'Take parts from which tutorial?',
      ),
    );
    if (chosen == null || !mounted) return;

    if (chosen.id == _draft.lessonId) {
      AppFeedback.info(
          context, 'That is this tutorial. Use „Clone part" to repeat a part.');
      return;
    }

    final source = await loadPartsOf(_lessonApi, chosen.id);
    if (!mounted) return;
    if (source == null) {
      AppFeedback.error(
          context, '„${chosen.title}" could not be read. Nothing was added.');
      return;
    }

    final picked = await showPartPickerDialog(
      context,
      title: 'Parts of „${source.title}"',
      subtitle: 'They are copied. „${source.title}" keeps all of them.',
      labels: [
        for (var i = 0; i < source.parts.length; i++) source.parts[i].label(i),
      ],
      confirmLabel: 'Add',
    );
    if (picked == null || !mounted) return;

    final added = _c.addSectionsFrom([
      for (final i in picked.indices) source.parts[i],
    ]);
    if (!mounted) return;
    AppFeedback.success(
      context,
      added == 1
          ? '1 part added. Save the tutorial to keep it.'
          : '$added parts added. Save the tutorial to keep it.',
    );
  }

  /// „Take parts into a new tutorial…" — parts of this one, written out as a
  /// tutorial of their own.
  ///
  /// **Saved on the spot, and this screen does not move.** The studio holds one
  /// draft; opening the new tutorial here would have to ask what to do with
  /// unsaved changes in the one being written, and the answer to that question
  /// is worth less than never asking it. The owner chose this on 20.9.2026.
  /// The new tutorial is offered afterwards, as a door rather than a jump.
  Future<void> _extractPartsToNewTutorial() async {
    final picked = await showPartPickerDialog(
      context,
      title: 'Take parts into a new tutorial',
      subtitle: 'They are copied. This tutorial keeps all of them.',
      labels: [
        for (var i = 0; i < _draft.sections.length; i++)
          _draft.sections[i].label(i),
      ],
      confirmLabel: 'Create',
      nameLabel: 'Name of the new tutorial',
      initialName:
          _draft.title.trim().isEmpty ? '' : '${_draft.title.trim()} (parts)',
    );
    if (picked == null || !mounted) return;

    final outcome = await extractToNewTutorial(
      api: _lessonApi,
      title: picked.name,
      parts: _c.copiesOf(picked.indices),
      from: (
        lessonId: _draft.lessonId ?? 0,
        title: _draft.title,
        parts: const <TutorialSection>[],
        language: _draft.language,
        languageKnown: _draft.languageKnown,
        tags: _draft.tags,
      ),
    );
    if (!mounted) return;

    if (outcome.error != null) {
      AppFeedback.error(context, outcome.error!);
      return;
    }

    final count = picked.indices.length;
    AppFeedback.show(
      context,
      () => SnackBar(
        content: Text(count == 1
            ? '„${picked.name}" saved, with 1 part.'
            : '„${picked.name}" saved, with $count parts.'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => _openSavedTutorial(outcome.lessonId!),
        ),
      ),
    );
  }

  /// Opens a tutorial this screen has just written, in a studio of its own.
  ///
  /// Pushed rather than adopted: the draft open here is untouched underneath,
  /// and closing the new one comes back to it.
  Future<void> _openSavedTutorial(int id) async {
    final row = await _lessonApi.fetchTutorial(id);
    if (!mounted) return;
    if (row == null) {
      AppFeedback.error(
          context,
          'The tutorial was saved, but cannot be opened '
          'right now. It is in the library.');
      return;
    }
    await openTutorialEditor(
      context,
      session: widget.session,
      api: _lessonApi,
      lesson: row,
    );
  }

  /// Moving a part opens the part moved, so only moving the open one keeps
  /// the PGN tab's text where it was written.
  void _moveSection(int from, int to) {
    if (from != _c.draft.selected && _heldForPgn(_otherPart)) return;
    _c.moveSection(from, to);
  }

  void _cloneSection(int index) {
    if (_heldForPgn(_otherPart)) return;
    _c.cloneSection(index);
  }

  /// Deleting a part after the open one leaves it open; deleting it, or one
  /// before it, leaves another part at its place.
  void _removeSection(int index) {
    if (index <= _c.draft.selected && _heldForPgn(_otherPart)) return;
    if (!_c.removeSection(index)) {
      AppFeedback.info(context, 'The last part cannot be deleted.');
    }
  }

  /// Make a video of what is being written, from where it is being written.
  ///
  /// The owner asked for this door on 9.9.2026 — „dijalog za renderovanje
  /// premestimo tamo gde se tutorijal pravi" — and it is the same door the
  /// saved-tutorials list has: `exportTutorialVideo` owns the refusals, the
  /// narration options, the request and the finished dialog, so the two places
  /// cannot drift into being two features.
  ///
  /// **It needs a saved tutorial**, because the server renders a lesson by its
  /// id and meters the render against the account that owns it. Offering it on
  /// an unsaved draft would mean either a silent save nobody asked for or a
  /// refusal two clicks later, so the answer is a sentence and the Save button
  /// is right beside it.
  /// The whole tutorial as a `.pgn` file — phase 4 of
  /// `docs/PLAN-PGN-TUTORIJAL.md`.
  ///
  /// The draft is handed over as it stands, so a part written a moment ago is
  /// in the file whether or not it has been saved. The dialog says how the
  /// parts come apart into games and what a PGN cannot carry, and it is the one
  /// place that decides either.
  Future<void> _exportPgn() async {
    await showTutorialPgnExportDialog(context, _draft);
  }

  Future<void> _exportVideo() async {
    final id = _draft.lessonId;
    if (id == null) {
      AppFeedback.info(context, 'Save the tutorial first, then export it.');
      return;
    }
    await exportTutorialVideo(
      context: context,
      api: _lessonApi,
      lessonId: id,
      title: _draft.title,
      draft: _draft,
      narrationStore: _narrationStore,
    );
  }

  /// The trainer's own voice over this tutorial — phase 1 of
  /// `docs/PLAN-SNIMANJE.md`.
  ///
  /// **A saved tutorial only**, for the same reason as the export beside it: a
  /// take is kept under the tutorial's id, and a draft that has never been
  /// saved has none — a take keyed to nothing is a file nobody can reach.
  ///
  /// The part being written is synced first, so the beats the trainer talks
  /// over are the ones on screen rather than the ones last saved.
  Future<void> _recordNarration() async {
    final id = _draft.lessonId;
    if (id == null) {
      AppFeedback.info(context, 'Save the tutorial first, then record it.');
      return;
    }
    // Asked, not assumed: the server derives the longest take from its render
    // budget. When it cannot be asked the screen stops at the shorter fallback,
    // because a take cut early is always accepted and one cut late is not.
    final maxMs = await _lessonApi.narrationMaxMs(id) ?? narrationFallbackMaxMs;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TutorialNarrationScreen(
          lessonId: id,
          title: _draft.title.trim(),
          draft: _draft,
          store: _narrationStore,
          maxMs: maxMs,
        ),
      ),
    );
    // A trainer who recorded again has answered the banner, and one who did not
    // is still owed it. Read rather than assumed: the screen may have kept a
    // take, replaced one, or left the old one exactly where it was.
    await _loadNarrationTake();
  }

  /// The open part as text, with the map of where each node sits in it.
  ///
  /// **A fresh export, not `pgnForSave`.** That getter answers with the exact
  /// text the server stored while the part is untouched — right for a save, and
  /// wrong here: the spans describe the text the writer just wrote, and a
  /// stored text formatted even slightly differently would put the caret and
  /// the right-click menu on the wrong move. What is *sent* is still the stored
  /// text; what is *shown* is the tree.
  PgnWithSpans get _exportOfOpenPart =>
      StudioLessonStep.textWithSpans(_draft.section.root);

  /// The node with this id, anywhere in the open part's tree.
  AnalysisNode? _nodeById(String id) {
    AnalysisNode? walk(AnalysisNode node) {
      if (node.id == id) return node;
      for (final child in node.children) {
        final hit = walk(child);
        if (hit != null) return hit;
      }
      return null;
    }

    return walk(_root);
  }

  /// „Dodaj strelicu" and „Označi polje": stand on the move that was clicked and
  /// hand the drawing to the board.
  ///
  /// **No second way of drawing is written.** The board and
  /// `BoardAnnotationController` already do this, and a menu that put marks on
  /// nodes by itself would be the second copy of a rule this repository has
  /// paid for more than once.
  void _drawFromText(String nodeId, AnnotationMode mode) {
    final node = _nodeById(nodeId);
    if (node == null) return;
    if (node.id != _current.id) _jumpTo(node);
    setState(() => _annotationController.setMode(mode));
    AppFeedback.info(
      context,
      mode == AnnotationMode.arrow
          ? 'Draw an arrow on the board.'
          : 'Click a square on the board.',
    );
  }

  /// „Dodaj komentar": the words of one move, edited where the trainer asked.
  Future<void> _editCommentFromText(String nodeId) async {
    final node = _nodeById(nodeId);
    if (node == null) return;
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _CommentDialog(initial: node.comment),
    );
    if (!mounted || saved == null) return;
    _c.setComment(node, saved);
  }

  /// Reads the trainer's text and, if it replays, makes it the part's line.
  ///
  /// Through `readStepTree` — that is `LessonStepLine`, the reader the child's
  /// screen uses. Nothing here parses a PGN a second way, which is the rule
  /// `step_tree.dart` carries and the reason this tab is a rendering rather
  /// than a second editor.
  ///
  /// **Refused rather than partly applied.** `MoveTree.parsePgn` skips a move it
  /// cannot play without a word, so a text with one bad move would otherwise
  /// replace the part with the moves it happened to understand — the trainer
  /// watching a line they wrote come back shorter, with no error. The likeliest
  /// cause is not a typo but a game pasted from the initial position into a part
  /// that stands on move twelve, where every move is rejected at once.
  Future<void> _applyPgn(String text) async {
    final section = _draft.section;

    // A pasted game usually carries its own `[FEN]`, and it is nearly always a
    // different position from the one this part stands on — in which case every
    // move is rejected at once and the count says nothing useful. So the
    // question is asked **before** the parse, and only when the two positions
    // really differ. Clocks are not part of that comparison: a line walked to
    // here and a part written from here are the same board to a child.
    var startFen = section.root.fen;
    final header = MoveTree.fenHeaderOf(text);
    if (header != null && !MoveTree.samePosition(header, startFen)) {
      final answer = await _askAboutPastedPosition(
        title: 'Text starts from a different position',
        explanation:
            'This PGN has its own starting position, different from the position of this '
            'part. If you use it, the student will open this part on that position.',
        takeLabel: 'Use that position',
      );
      if (!mounted || answer == _PastedPosition.cancel) return;
      if (answer == _PastedPosition.take) startFen = header;
    }

    var read = readStepTree(fen: startFen, pgn: text);

    // A text with no `[FEN]` says nothing about where it starts, so there was
    // nothing to ask about and the trainer got only the count of moves that
    // would not play — „samo mi ovo javi", 7.9.2026. But a PGN without a
    // header is a game from the standard opening position, which is a position
    // like any other: if the text plays cleanly from **there** and not from
    // here, the same question can be asked, and now it is grounded in the
    // reading rather than in a guess about what the trainer meant.
    //
    // Only when it replays whole. A text that half fits the opening position
    // is not a game from it, and offering to move the part onto a position
    // that also rejects moves would trade one silent loss for another.
    if (read.rejectedMoves > 0 && header == null) {
      final fromStart = readStepTree(fen: TutorialDraft.startFen, pgn: text);
      if (fromStart.rejectedMoves == 0 && fromStart.root.children.isNotEmpty) {
        final answer = await _askAboutPastedPosition(
          title: 'Text does not start from here',
          explanation:
              'This PGN has no starting position, and its moves cannot '
              'be played from the position of this part — they can from the starting position. '
              'If you use it, the student will open this part from the starting position.',
          takeLabel: 'Use starting position',
        );
        if (!mounted || answer == _PastedPosition.cancel) return;
        if (answer == _PastedPosition.take) {
          startFen = TutorialDraft.startFen;
          read = fromStart;
        }
      }
    }

    if (read.rejectedMoves > 0) {
      AppFeedback.error(
        context,
        'Not applied: ${read.rejectedMoves} '
        '${_movesWord(read.rejectedMoves)} cannot be played from the position '
        'of this part.'
        // Said only when it is the answer to „why did it not ask me
        // anything?". With a `[FEN]` the question was asked and answered.
        '${header == null ? ' The text has no starting position ([FEN]), so '
            'where it starts cannot be detected.' : ''}',
      );
      return;
    }

    // The end of the line, not its beginning — the controller's rule. A
    // trainer presses „Apply" having just typed a move on the end of the
    // text, and being thrown back to the opening position means finding their
    // way to it again on every application (reported live on 7.9.2026). It is
    // also what „Flow" then shows: the last card is the one they wrote.
    // Nothing to invalidate by hand: `isPristine` compares `treeSignature`
    // against the tree itself, and this is a different tree.
    _annotationController.cancelPending();
    final parts = _c.replaceLine(read.root);
    AppFeedback.success(
      context,
      parts == 1
          ? 'Applied.'
          : 'Applied as $parts parts: every side line is a part of its own.',
    );
  }

  /// Asked once, never assumed: taking the pasted position changes the board a
  /// child opens this part on.
  ///
  /// Two questions, one dialog, because they have the same three answers and
  /// the same consequence. The first is „this text brought a position of its
  /// own"; the second is „this text brought none, and only plays from the
  /// opening position".
  Future<_PastedPosition> _askAboutPastedPosition({
    required String title,
    required String explanation,
    required String takeLabel,
  }) async {
    final answer = await showDialog<_PastedPosition>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_PastedPosition.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_PastedPosition.keep),
            child: const Text('Keep existing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_PastedPosition.take),
            child: Text(takeLabel),
          ),
        ],
      ),
    );
    return answer ?? _PastedPosition.cancel;
  }

  static String _movesWord(int count) => count == 1 ? 'move' : 'moves';

  Future<void> _saveTutorial() async {
    // The refusals and the request are the controller's; what is said about
    // them is this screen's.
    final error = await _c.save(_lessonApi);
    if (!mounted) return;
    if (error == null) {
      AppFeedback.success(context, 'Tutorial saved.');
    } else {
      AppFeedback.error(context, error);
    }
  }

  /// The tutorial's name, written once and drawn by both layouts.
  ///
  /// Both halves of this screen need it and batch 58 arrived with the field —
  /// and the four lines of comment explaining it — copied into each. A widget
  /// written twice is a widget that gets fixed once.
  Widget _titleField() {
    return TextField(
      key: const Key('tutorial-title'),
      controller: _titleController,
      decoration: const InputDecoration(labelText: 'Tutorial title'),
      // Written into the draft rather than only held in the controller. The
      // draft is what `TutorialDraftService` stores, so a title that lives only
      // here comes back empty next time — with every part still in place, which
      // is what made it invisible.
      onChanged: _c.setTitle,
    );
  }

  /// The labels this tutorial will be found by.
  ///
  /// Comma-separated text rather than the chip editor
  /// `SavePositionDialog` draws, and that is a decision rather than a shortcut:
  /// this pane is 460 px wide with a board beside it, and a chip field that
  /// grows by a row per label pushes the parts list off the bottom. The rule
  /// about what a label may be is not written twice either way —
  /// [normaliseLabels] is the one reading of it.
  Widget _labelsField() {
    return TextField(
      key: const Key('tutorial-labels'),
      controller: _labelsController,
      // The comma convention is taught by the hint rather than said in a
      // `helperText`, which would be a second line of height.
      decoration: const InputDecoration(
        labelText: 'Labels',
        hintText: 'endgame, rook',
      ),
      // Normalised into the draft and **not** back into the field: rewriting
      // the text under the caret would delete the comma the trainer has just
      // typed, every time. The field holds what was typed; the draft holds
      // what it means.
      onChanged: _c.setLabels,
    );
  }

  /// The language this tutorial is written in, which decides the voice that
  /// reads it to the child — `docs/PLAN-JEZIK-GLASA.md`, phase 5.
  ///
  /// A plain `DropdownButton` under an `InputDecorator`, **not** a
  /// `DropdownButtonFormField`: a form field keeps the value it was built with,
  /// and this screen swaps in a stored draft after its first frame — so a form
  /// field would go on showing the language of a draft that is no longer here.
  /// This one reads the draft on every build.
  Widget _languageField() {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Language'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          key: const Key('tutorial-language'),
          isDense: true,
          isExpanded: true,
          // A code this build does not know reads as „Not set" rather than
          // being guessed at — and is sent back untouched unless the trainer
          // picks something.
          value: TutorialLanguage.of(_draft.language)?.code,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Not set', overflow: TextOverflow.ellipsis),
            ),
            for (final language in TutorialLanguage.all)
              DropdownMenuItem<String?>(
                value: language.code,
                child: Text(language.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _c.setLanguage,
        ),
      ),
    );
  }

  /// The three fields that belong to the tutorial rather than to a part.
  ///
  /// **Side by side, and that is a height decision rather than a taste.** The
  /// wide pane ends in a parts list held against the bottom of the window, and
  /// the panel's own header is as short as batch 58 could make it — it
  /// overflowed an 840 dp window by two pixels when its buttons were two rows.
  /// A second full-width field above it overflowed by another 24, which a
  /// release build draws as a parts list with its last row simply missing.
  /// In one row the labels cost nothing: the row is as tall as the title field
  /// already was.
  ///
  /// The language joined them on 11.9.2026, measured with the real Windows
  /// font rather than the test font, which draws every letter as a square. A
  /// row of its own under these two cost 56 px and overflowed 840 × 800. A
  /// third equal share of this row left „Serbian (Cyrillic)" 63 px of the 116
  /// it needs, so both Serbian entries read „Serbia…" — the one pair the menu
  /// exists to tell apart. So it takes **its own width** and the title and
  /// labels share the rest: 159 and 106 px at 840, against 271 and 181 before,
  /// and the shortest window that lays out is unchanged. The cap keeps a large
  /// text scale from squeezing the title to nothing; at an ordinary scale it
  /// never binds.
  Widget _headerFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _titleField()),
        const SizedBox(width: AppSpacing.sm),
        Expanded(flex: 2, child: _labelsField()),
        const SizedBox(width: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          // An `isExpanded` dropdown asks for a bounded width, and a Row gives
          // a child that is not flexible none — so it is sized to its widest
          // entry first, and that width is what it gets.
          child: IntrinsicWidth(child: _languageField()),
        ),
      ],
    );
  }

  /// The table of contents, wired to the screen that owns the draft.
  Widget _sectionsPanel() {
    return TutorialSectionsPanel(
      draft: _draft,
      onSelect: _selectSection,
      onAddShow: _addShowSection,
      onMove: _moveSection,
      onClone: _cloneSection,
      onRename: _renameSection,
      onRemove: _removeSection,
      onAddPartsFrom: _addPartsFromTutorial,
      onExtractParts: _extractPartsToNewTutorial,
      onTurn: _turnPart,
    );
  }

  Widget _authoringPaneWide() {
    return SizedBox(
      key: const Key('authoring-pane'),
      width: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerFields(),
          _narrationBanner(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            key: const Key('sections-half'),
            flex: 2,
            child: _sectionsPanel(),
          ),
          const Divider(),
          Expanded(
            key: const Key('editor-half'),
            flex: 3,
            // The strip is outside the scroll view, not inside it: scrolling the
            // cards must not take their own labels off the screen. The owner's
            // report of 12.9.2026.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _editorTabs(),
                const SizedBox(height: AppSpacing.xs),
                Expanded(child: SingleChildScrollView(child: _editorPanels())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The tree of the part being written, and everything written *about* it.
  Widget _authoringColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titleField(),
        _labelsField(),
        _languageField(),
        _narrationBanner(),
        const SizedBox(height: AppSpacing.md),
        _sectionsPanel(),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  /// Said when this device's recording no longer follows the tutorial —
  /// phase 5 of `docs/PLAN-SNIMANJE.md`.
  ///
  /// **Here rather than at the export, and that is the whole point of the
  /// phase.** Edit a sentence, add a part, reorder two, and the markers name
  /// beats they were not recorded against; the export can only refuse, which
  /// is a trainer told at the end that the last hour is gone. The screen that
  /// caused it is the screen that can undo it, and the two doors are the two
  /// answers: record it again, or make the film without the voice.
  ///
  /// **A take that is merely silent or short is not this banner's business.**
  /// The recording screen says both of those about the take it is showing, and
  /// neither is caused by editing — a banner over the editor for them would be
  /// a warning about something this screen cannot do anything about.
  Widget _narrationBanner() {
    final take = _narrationTake;
    if (take == null) return const SizedBox.shrink();
    // Walked only where there is a take to judge, which is the rare case: for
    // every tutorial nobody has recorded this costs nothing at all.
    final stops = filmBeatsOf(_draft);
    if (stops.isEmpty) return const SizedBox.shrink();
    final mismatch = takeMismatchOf(
      take,
      beats: stops.length,
      signature: filmSignatureOf(stops),
    );
    final said = switch (mismatch) {
      TakeMismatch.beatsChanged =>
        'Your recording was made when this tutorial had ${take.eventCount} '
            'beats, and it has ${stops.length} now.',
      TakeMismatch.edited =>
        'This tutorial has been edited since your recording was made, so the '
            'recording no longer follows it.',
      // Both are the recording screen's to say, and neither is this screen's
      // doing. `none` is the ordinary state of a tutorial with a good take.
      TakeMismatch.none ||
      TakeMismatch.silent ||
      TakeMismatch.incomplete =>
        null,
    };
    if (said == null) return const SizedBox.shrink();

    return Padding(
      key: const Key('narration-stale-banner'),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Material(
        color: context.colors.infoContainer,
        borderRadius: AppRadii.roundedSm,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.mic_off_outlined,
                    size: 18,
                    color: context.colors.onInfoContainer,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      said,
                      style: AppText.body.copyWith(
                        color: context.colors.onInfoContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    key: const Key('narration-stale-record'),
                    onPressed: _recordNarration,
                    child: const Text('Record again'),
                  ),
                  TextButton(
                    key: const Key('narration-stale-export'),
                    onPressed: _exportVideo,
                    child: const Text('Export without your voice'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// „Flow", „Tree", „PGN" — pinned in both layouts, because scrolling the
  /// cards must not hide the strip that says which of them you are looking at.
  Widget _editorTabs() {
    return Row(
      children: [
        _tabButton(
          key: const Key('tok-tab'),
          label: 'Flow',
          isSelected: _selectedTab == 0,
          onTap: () => setState(() => _selectedTab = 0),
        ),
        const SizedBox(width: AppSpacing.xs),
        _tabButton(
          key: const Key('stablo-tab'),
          label: 'Tree',
          isSelected: _selectedTab == 1,
          onTap: () => setState(() => _selectedTab = 1),
        ),
        const SizedBox(width: AppSpacing.xs),
        _tabButton(
          key: const Key('pgn-tab'),
          label: 'PGN',
          isSelected: _selectedTab == 2,
          onTap: () => setState(() => _selectedTab = 2),
        ),
      ],
    );
  }

  /// What the strip labels: one of the three, under the open part's own line
  /// („Part 3 of 8 · continues from part 2").
  Widget _editorPanels() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TutorialPartHeader(draft: _draft, onOpenPart: _selectSection),
        const SizedBox(height: AppSpacing.xs),
        IndexedStack(
          index: _selectedTab,
          children: [
            TutorialFlowPanel(
              root: _root,
              current: _current,
              onSelect: _jumpTo,
              // Redrawn on every letter, because the sentence is also the
              // part's name: the panel calls [TutorialSection.label], which
              // reads the first thing the part says. The beat cards keep
              // their own controllers and focus nodes, so rebuilding them
              // under the caret costs a frame and changes nothing the trainer
              // sees.
              onCommentChanged: (node, text) =>
                  _c.setComment(node, text, typing: true),
              onDelete: _deleteNode,
              // None when there is no line to cut, so the button is not drawn
              // at all rather than drawn to do nothing.
              onInsertLine:
                  canSplitForLine(_draft.section) ? _insertLine : null,
              // „Part 4 starts here · 18... h6" on a beat a later part goes
              // back to, which opens that part.
              partsStartingHere: partsStartingIn(_draft),
              onOpenPart: _selectSection,
            ),
            AnalysisMoveTreeWidget(
              rootNode: _root,
              activeNode: _current,
              onSelectNode: _jumpTo,
              onPromoteNode: _promoteNode,
              onDeleteNode: _deleteNode,
            ),
            // Keyed by the tree it is showing: a new part, or a text that has
            // just been applied, is a different line and the field follows it.
            // Anything else — a move played, an arrow drawn — leaves the
            // trainer's unapplied text alone, which `didUpdateWidget` decides.
            TutorialPgnPanel(
              key: ValueKey(_root.id),
              export: _exportOfOpenPart,
              currentNodeId: _current.id,
              onApply: _applyPgn,
              onCaretMoved: (id) {
                final node = _nodeById(id);
                if (node != null && node.id != _current.id) _jumpTo(node);
              },
              onDrawArrow: (id) => _drawFromText(id, AnnotationMode.arrow),
              onMarkSquare: (id) => _drawFromText(id, AnnotationMode.square),
              onEditComment: _editCommentFromText,
              onEdited: (edited) => _pgnEdited = edited,
            ),
          ],
        ),
      ],
    );
  }

  Widget _tabButton({
    required Key key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: isSelected ? context.colors.surfaceRaised : context.colors.surface,
      borderRadius: AppRadii.roundedSm,
      child: InkWell(
        borderRadius: AppRadii.roundedSm,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.roundedSm,
            border: Border.all(
              color: isSelected
                  ? context.colors.borderStrong
                  : context.colors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: (isSelected ? AppText.bodyBold : AppText.body).copyWith(
              color: isSelected
                  ? context.colors.textPrimary
                  : context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The one-field dialog behind „Dodaj komentar".
///
/// A `StatefulWidget` rather than a `TextEditingController` created beside
/// `showDialog`, and that is a fix this repository has already paid for once:
/// disposing on the dialog's future asserts, because the future completes on
/// `pop` while the route is still animating out and the field is still being
/// rebuilt. The controller has to belong to something that goes away with the
/// route.
/// „Preimenuj" — a name of the trainer's own, or none at all.
///
/// The hint is the name the part goes by now, so emptying the field reads as
/// „call it what it says" rather than as leaving something blank.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial, required this.hint});

  final String initial;
  final String hint;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Title'),
      content: TextField(
        key: const Key('section-name-field'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Title',
          hintText: widget.hint,
          helperText: 'Empty — named after what is written in it.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _CommentDialog extends StatefulWidget {
  const _CommentDialog({required this.initial});

  final String initial;

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Comment for this move'),
      content: TextField(
        key: const Key('pgn-comment-field'),
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: null,
        keyboardType: TextInputType.multiline,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// The „Flow / Tree / PGN" strip, held at the top of the narrow layout while the
/// cards it labels scroll under it.
///
/// The owner's report of 12.9.2026: „Flow, tree i pgn kartice ne treba da se
/// skrivaju prilikom skrolovanja, tj. skrolovanje ne sme na njih da utiče.
/// Skroluje se samo ono ispod njih." In the wide layout the strip simply sits
/// outside a scroll view of its own; on a narrow window the board and the parts
/// list are above it in the same scroll, so it takes a pinned sliver.
class _PinnedEditorTabs extends SliverPersistentHeaderDelegate {
  const _PinnedEditorTabs({required this.child});

  /// Painted opaque by the caller: the cards pass underneath, and a header you
  /// can see through is a header that cannot be read once anything is behind
  /// it.
  final Widget child;

  /// The strip's own height plus the gap under it. `_tabButton` sets
  /// `minHeight: 48`, and the gap is part of the pinned block so that the
  /// background covers it too — a card sliding into a four-pixel transparent
  /// seam is exactly what this exists to stop.
  static const double _extent = 48 + AppSpacing.xs;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      child;

  @override
  bool shouldRebuild(_PinnedEditorTabs oldDelegate) =>
      oldDelegate.child != child;
}
