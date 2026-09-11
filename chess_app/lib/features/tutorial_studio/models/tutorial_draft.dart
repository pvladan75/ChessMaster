import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/studio_lesson_step.dart';
import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/lessons/models/lesson_labels.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';

/// One offered answer of an `ask_choice` section.
///
/// This replaces the `List<String> choices` + `int? correctChoice` pair the
/// model carried until P1. That pair existed because contract C4 of
/// `docs/PLAN-TUTORIJAL.md` froze the **student's** shape — a list of strings,
/// because the answer never travels to the child — and the author's half was
/// added beside it afterwards. `{text, correct}` is the server's own shape, and
/// holding it directly removes the index arithmetic that had to be redone by
/// hand every time an answer was deleted.
class TutorialChoice {
  const TutorialChoice({required this.text, this.correct = false});

  final String text;
  final bool correct;

  TutorialChoice copyWith({String? text, bool? correct}) => TutorialChoice(
        text: text ?? this.text,
        correct: correct ?? this.correct,
      );
}

/// The name the studio gives a part the trainer has not named itself.
///
/// One rule in one place, because batch 57 wrote it in five: the same
/// `RegExp(r'^(Deo|Primer)\s+\d+$')` stood in four mutation methods of
/// `TutorialStudioScreen` and once more in `TutorialSectionsPanel`, each
/// compiling it inside a loop over the parts. Three hand-written copies of one
/// condition is how the `status = 'accepted'` bug got in, and this one decides
/// which of a trainer's titles it is allowed to overwrite.
String generatedSectionTitle(int index) => 'Deo ${index + 1}';

/// Whether [title] is a name the studio generated rather than one the trainer
/// wrote — the only kind [generatedSectionTitle] may renumber over.
///
/// „Primer" is here and not only „Deo" because tutorials written before the
/// word changed are still on the server, and reordering one of those must
/// renumber it rather than leave „Primer 3" standing second.
bool isGeneratedSectionTitle(String title) =>
    _generatedSectionTitle.hasMatch(title.trim());

final RegExp _generatedSectionTitle = RegExp(r'^(Deo|Primer)\s+\d+$');

/// Whether Black is to move in [fen].
///
/// Only ever a guess about the *orientation* — it is what the child's viewer
/// falls back to when a step says nothing about which way round it stands, and
/// a part read back from such a step adopts it so that reopening a tutorial
/// does not change what a child sees. Read off the FEN's second field rather
/// than through `chess`, because a FEN this cannot parse is one no board can
/// load either, and the caller has bigger problems than the orientation.
bool blackToMoveIn(String fen) {
  final fields = fen.trim().split(RegExp(r'\s+'));
  return fields.length > 1 && fields[1].toLowerCase() == 'b';
}

/// One part of a tutorial — „Deo" to the trainer, one `position_list` entry to
/// the server, one `LessonStep` to the child.
///
/// **It holds a tree, not a PGN.** That is decision D1 of
/// `docs/PLAN-STUDIO-REDIZAJN.md` and it is the change the whole redesign
/// rests on: until P1 a finished example was flattened to `fen` + `pgn` and its
/// tree was dropped, so it could never be reopened — which is why a second,
/// weaker editing screen had to exist beside the studio. The `pgn` is derived
/// at save time through [StudioLessonStep], which is still the one place where
/// the position and the line are made to answer for the same node.
class TutorialSection {
  TutorialSection({
    this.stepId,
    required this.root,
    AnalysisNode? cursor,
    this.title = '',
    this.instruction,
    this.kind = LessonStepKind.show,
    List<TutorialChoice>? choices,
    this.solutionSan,
    List<String>? acceptedSans,
    this.blackOrientation = false,
    this.storedPgn,
    this.rejectedMoves = 0,
  })  : choices = choices ?? [],
        acceptedSans = acceptedSans ?? [] {
    cursorNode = cursor ?? root;
    // Recorded against the tree as it arrived. Any edit changes the signature
    // and [storedPgn] stops being used — see [toJson].
    if (storedPgn != null) _storedSignature = treeSignature(root);
  }

  /// An empty part on [fen], with nothing written after it.
  factory TutorialSection.blank({required String fen, String title = ''}) =>
      TutorialSection(root: AnalysisNode(fen: fen), title: title);

  /// One entry of a saved tutorial's `position_list`, read back into a tree.
  ///
  /// The line is read through [readStepTree], which goes through the child's
  /// own parser. Nothing here parses a PGN a second way.
  factory TutorialSection.fromStep(Map<String, dynamic> step) {
    final fen = step['fen']?.toString() ?? TutorialDraft.startFen;
    final pgn = step['pgn']?.toString();
    final read = readStepTree(fen: fen, pgn: pgn);

    final rawId = step['id'];
    final choices = <TutorialChoice>[];
    for (final raw in (step['choices'] as List?) ?? const []) {
      if (raw is! Map) continue;
      choices.add(TutorialChoice(
        text: raw['text']?.toString() ?? '',
        correct: raw['correct'] == true,
      ));
    }

    return TutorialSection(
      stepId: (rawId is String && rawId.isNotEmpty) ? rawId : null,
      root: read.root,
      rejectedMoves: read.rejectedMoves,
      title: step['title']?.toString() ?? '',
      instruction: step['instruction']?.toString(),
      kind: _kindOf(step['kind']),
      choices: choices,
      solutionSan: step['solutionSan']?.toString(),
      acceptedSans: [
        for (final raw in (step['acceptedSans'] as List?) ?? const [])
          raw.toString(),
      ],
      storedPgn: (pgn != null && pgn.trim().isNotEmpty) ? pgn : null,
      // A stored step that says nothing is not a stored step that says
      // „White". Every part written before this field existed was drawn for
      // the child by working the orientation out from whose turn it is, so
      // that guess is what the part has been showing and that guess is what it
      // adopts. Reading absence as `false` would turn every black-to-move part
      // of every old tutorial round the first time a trainer opened one and
      // pressed save, without touching it.
      blackOrientation: step['blackOrientation'] is bool
          ? step['blackOrientation'] as bool
          : blackToMoveIn(fen),
    );
  }

  /// The server's id for this step, or null for a part that has never been
  /// saved.
  ///
  /// **The most dangerous field in this feature.** `assignment_items.step_key`
  /// and `review_items.step_key` name a step by this value and nothing joins on
  /// it, so an id quietly re-minted is a child's schedule and their recorded
  /// answers orphaned with no error anywhere. `PUT /lessons/:id` refuses a list
  /// that lost its ids — but only when the stored and sent lists are the same
  /// length, so the guard cannot fire the moment a part is added or removed,
  /// which is the whole point of the screen this model is for.
  String? stepId;

  /// The line, and everything written on it.
  AnalysisNode root;

  /// Where the trainer is standing inside this part.
  late AnalysisNode cursorNode;

  String title;
  String? instruction;
  LessonStepKind kind;
  final List<TutorialChoice> choices;

  /// The move an `ask_move` part expects, in SAN.
  String? solutionSan;

  /// The other moves that are also right. Carried because the server stores
  /// them and a round trip that dropped them would delete a trainer's work the
  /// first time they renamed their tutorial.
  final List<String> acceptedSans;

  /// Which way round this part's board stands, for the trainer and then for
  /// the child.
  ///
  /// Always sent, and never null: what the trainer is looking at is what the
  /// child gets, and there is no third state on this side of the wire. The
  /// third state exists on the server, where absence means „written before
  /// anyone could say" — [TutorialSection.fromStep] resolves it on the way in.
  bool blackOrientation;

  /// The exact `pgn` text this part was read from, or null for one written
  /// here. See [toJson] for why it is kept.
  String? storedPgn;
  String? _storedSignature;

  /// How many moves of [storedPgn] could not be played from its own position.
  /// Above zero means the stored line and the stored position describe
  /// different games — the fault that used to reach a child as a board with no
  /// moves on it.
  final int rejectedMoves;

  /// True while the tree still says exactly what [storedPgn] said.
  bool get isPristine =>
      storedPgn != null && _storedSignature == treeSignature(root);

  /// Whether this part has moves after its starting position.
  ///
  /// **Not `pgnForSave.isNotEmpty`, and that difference was a bug.** A part with
  /// no moves still exports a `pgn` when its root carries a note, an arrow or a
  /// coloured square — the exporter writes those ahead of move one on purpose,
  /// so that „pogledaj polje d5" can travel. Judging a part by whether its
  /// exported text is empty therefore called a question with an arrow on it „a
  /// part with a line", and refused to save it. P7a, which gave the trainer a
  /// way to draw, made that the normal way to write a question.
  ///
  /// Asked of the tree rather than of a parsed text, because the tree is the
  /// writable one and cannot disagree with itself. What is *sent* is still read
  /// back through `LessonStepLine` before it leaves — that check is about the
  /// text, and this one is about the lesson.
  bool get hasLine => root.children.isNotEmpty;

  /// True for a part that would hand the child its own answer.
  ///
  /// A step's `pgn` is not redacted on its way to a child — the line *is* the
  /// lesson — and the viewer draws the move strip for every kind. So a question
  /// whose line runs on from the very position being asked about shows the
  /// answer to anyone who presses „Sledeći potez".
  ///
  /// **This is the single refusal the app makes on its own**, and it cannot be
  /// moved to the server: the server stores `pgn` as opaque text and has no PGN
  /// reader, and giving it one would be a second parser disagreeing with this
  /// app's. One getter, read by all three places the rule appears — the question
  /// asked when the kind is chosen, the banner on a tutorial already in that
  /// state, and the refusal at save.
  bool get leaksAnswer => kind == LessonStepKind.askMove && hasLine;

  /// What a save should send as this part's line.
  ///
  /// An untouched part is written back as **the exact text it was read from**.
  /// That is not tidiness: `PgnExporterService` stamps a fresh `[Date]` header
  /// on every call and formats a line its own way, so re-exporting would
  /// rewrite text nobody edited — and anything the exporter cannot say that the
  /// parser could read would be lost on the first save of a tutorial that was
  /// only renamed.
  ///
  /// It is a cache with one invalidation rule and no flag to forget: the
  /// signature is compared against the tree itself, so an edit made anywhere,
  /// by anything, drops it.
  String get pgnForSave {
    if (isPristine) return storedPgn!;
    final step = StudioLessonStep.from(root);
    if (step.line.movesSan.isNotEmpty) return step.pgn;

    // No moves. `PgnExporterService` always writes headers, so an exported
    // empty tree is never the empty string — batch 54's correction, and it
    // still holds for a part that carries nothing at all.
    //
    // **But „no moves" is not „nothing".** A note about the starting position,
    // an arrow or a coloured square lives on the root, and the root is the only
    // place it can live: „pogledaj polje d5" is a whole step, and the exporter
    // was taught to write that comment ahead of move one precisely so it could
    // travel. Judging the part by its move count alone threw it away again on
    // the way out — silently, and the child got a bare diagram.
    final rootCarriesSomething = root.comment.trim().isNotEmpty ||
        root.arrows.isNotEmpty ||
        root.squares.isNotEmpty;
    return rootCarriesSomething ? step.pgn : '';
  }

  /// The step read back through the child's parser — the check that a line
  /// which cannot be replayed from its own position is never saved.
  StudioLessonStep get step => StudioLessonStep.from(root);

  /// Records what the server now holds for this part.
  ///
  /// Called after a successful write, by `commitDraft` and nothing else. Two
  /// things happen here and they are the same thing: the part learns its
  /// [stepId], and its [storedPgn] becomes the text the server stored — so an
  /// untouched part is [isPristine] again and the next save sends that text
  /// back byte for byte rather than a fresh export with a new `[Date]` header
  /// on it.
  void markSaved({required String? id, required String? pgn}) {
    if (id != null) stepId = id;
    storedPgn = (pgn != null && pgn.trim().isNotEmpty) ? pgn : null;
    _storedSignature = storedPgn == null ? null : treeSignature(root);
  }

  /// A copy with no identity: a new part carrying the same teaching.
  ///
  /// [stepId] is deliberately not carried. Two parts sharing one step id is a
  /// child's progress appearing in the wrong half of the tutorial — the same
  /// reason `POST /lessons/:id/clone` mints fresh ids server-side.
  TutorialSection copy() => TutorialSection(
        root: copyTree(root),
        title: title,
        instruction: instruction,
        kind: kind,
        choices: [for (final c in choices) c],
        solutionSan: solutionSan,
        acceptedSans: [...acceptedSans],
        blackOrientation: blackOrientation,
      );

  /// What this part is called — in the list, and on the child's screen.
  ///
  /// „Deo 1, Deo 2, Deo 3" is a table of contents that says nothing about a
  /// tutorial, and the word is an idea a trainer should not have to hold: they
  /// write a demonstration, ask a question, start a new position. So a part is
  /// called by what it says, and a trainer who wants a name types one.
  ///
  ///  1. the name the trainer typed, if they typed one;
  ///  2. the first sentence the part carries — about its starting position,
  ///     else the first one written along its line, else the task it sets;
  ///  3. „Deo N", which is the only place that word is still read.
  ///
  /// A title stored as „Deo 2" or „Primer 2" is **not** the trainer's own:
  /// every tutorial written before this was named that way, and reading those
  /// as chosen names would pin a list of numbers over a tutorial with plenty
  /// to say for itself. [isGeneratedSectionTitle] is the one place that rule
  /// lives.
  String label(int index) {
    final own = title.trim();
    if (own.isNotEmpty && !isGeneratedSectionTitle(own)) return own;
    return _spoken() ?? generatedSectionTitle(index);
  }

  /// The first thing this part says, or null when it says nothing.
  String? _spoken() {
    final rootComment = _shorten(root.comment);
    if (rootComment != null) return rootComment;

    for (var node = root; node.children.isNotEmpty;) {
      node = node.children.first;
      final said = _shorten(node.comment);
      if (said != null) return said;
    }

    return _shorten(instruction ?? '');
  }

  /// One sentence of [text], short enough to read in a list.
  static String? _shorten(String text) {
    final flat = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (flat.isEmpty) return null;

    // The end of the first sentence — but not the dot of „1. e4", which is a
    // move number and not a full stop.
    final stop = RegExp(r'(?<![0-9])[.!?…](\s|$)').firstMatch(flat);
    final sentence =
        stop == null ? flat : flat.substring(0, stop.start + 1).trim();

    if (sentence.length <= _labelLimit) return sentence;
    final cut = sentence.substring(0, _labelLimit - 1);
    final lastSpace = cut.lastIndexOf(' ');
    return '${lastSpace > 20 ? cut.substring(0, lastSpace) : cut.trim()}…';
  }

  static const int _labelLimit = 60;

  /// One entry of the `positionList` a save sends.
  ///
  /// A field this part says nothing about is left out of the body rather than
  /// sent as null: the server tells „leave this alone" from „there is none" by
  /// whether the key is there at all, and that distinction has already cost
  /// this project every step of a renamed lesson.
  Map<String, dynamic> toJson({int index = 0}) {
    final pgn = pgnForSave;
    return {
      if (stepId != null) 'id': stepId,
      // [label], not the raw field: what the trainer reads in the list is what
      // the child is sent, because it is the same function. Batch 57's finding
      // was a panel that drew a row's number over a stored title that said
      // something else — the right words over the wrong data — and computing
      // the name once is the version of that fix that cannot come apart.
      'title': label(index),
      'fen': root.fen,
      // Omitted rather than sent empty. `buildLessonStep` reads `if (pgn)`, so
      // `''` and absent are the same thing to the server — but only absence
      // round-trips a step that was stored without a line.
      if (pgn.isNotEmpty) 'pgn': pgn,
      if (instruction != null && instruction!.trim().isNotEmpty)
        'instruction': instruction!.trim(),
      'kind': _wire[kind]!,
      // Which way round the child opens this part.
      //
      // Sent even when it is false, unlike everything else here, and that is
      // the point: the viewer works out the orientation from whose turn it is
      // when the step does not say, so „false" and „absent" are two different
      // instructions. A trainer who deliberately left a black-to-move position
      // the white way round has to be able to say so.
      'blackOrientation': blackOrientation,
      if (solutionSan != null && solutionSan!.isNotEmpty)
        'solutionSan': solutionSan,
      if (acceptedSans.isNotEmpty) 'acceptedSans': [...acceptedSans],
      if (kind == LessonStepKind.askChoice && choices.isNotEmpty)
        'choices': [
          for (final choice in choices)
            {'text': choice.text, 'correct': choice.correct},
        ],
    };
  }

  /// What the on-device draft slot stores.
  ///
  /// The **tree**, not the pgn: an arrow drawn and not yet saved has to survive
  /// the window closing, and reading a PGN back would go through the parser
  /// again for no reason. [storedPgn] is carried only while it is still valid,
  /// so a restored part can never write a line the trainer has already edited.
  Map<String, dynamic> toLocalJson() => {
        if (stepId != null) 'id': stepId,
        'title': title,
        'tree': root.toJson(),
        'cursor': _pathTo(root, cursorNode),
        'blackOrientation': blackOrientation,
        if (isPristine) 'storedPgn': storedPgn,
        if (instruction != null) 'instruction': instruction,
        'kind': _wire[kind]!,
        if (choices.isNotEmpty)
          'choices': [
            for (final choice in choices)
              {'text': choice.text, 'correct': choice.correct},
          ],
        if (solutionSan != null) 'solutionSan': solutionSan,
        if (acceptedSans.isNotEmpty) 'acceptedSans': [...acceptedSans],
      };

  factory TutorialSection.fromLocalJson(Map<String, dynamic> json) {
    final treeJson = json['tree'];
    final root = treeJson is Map
        ? AnalysisNode.fromJson(Map<String, dynamic>.from(treeJson))
        : AnalysisNode(fen: TutorialDraft.startFen);

    final rawId = json['id'];
    final section = TutorialSection(
      stepId: (rawId is String && rawId.isNotEmpty) ? rawId : null,
      root: root,
      title: json['title']?.toString() ?? '',
      instruction: json['instruction']?.toString(),
      kind: _kindOf(json['kind']),
      choices: [
        for (final raw in (json['choices'] as List?) ?? const [])
          if (raw is Map)
            TutorialChoice(
              text: raw['text']?.toString() ?? '',
              correct: raw['correct'] == true,
            ),
      ],
      solutionSan: json['solutionSan']?.toString(),
      acceptedSans: [
        for (final raw in (json['acceptedSans'] as List?) ?? const [])
          raw.toString(),
      ],
      blackOrientation: json['blackOrientation'] == true,
      storedPgn: json['storedPgn']?.toString(),
    );
    section.cursorNode = _resolve(root,
        ((json['cursor'] as List?) ?? const []).whereType<int>().toList());
    return section;
  }

  static const Map<LessonStepKind, String> _wire = {
    LessonStepKind.show: 'show',
    LessonStepKind.askMove: 'ask_move',
    LessonStepKind.askChoice: 'ask_choice',
  };

  /// An unknown kind reads as `show`, which is what every lesson stored before
  /// kinds existed is. The server refuses an unknown one; this side has nothing
  /// to gain by refusing to open a tutorial it could show.
  static LessonStepKind _kindOf(dynamic raw) => _wire.entries
      .firstWhere((e) => e.value == raw,
          orElse: () => const MapEntry(LessonStepKind.show, 'show'))
      .key;

  /// Child indices from the root down to [target] — indices rather than ids,
  /// because [AnalysisNode.fromJson] mints fresh ones.
  static List<int> _pathTo(AnalysisNode root, AnalysisNode target) {
    final path = <int>[];
    var node = target;
    while (node.parent != null) {
      final parent = node.parent!;
      final index = parent.children.indexWhere((c) => c.id == node.id);
      if (index < 0) return const [];
      path.insert(0, index);
      node = parent;
    }
    return node.id == root.id ? path : const [];
  }

  static AnalysisNode _resolve(AnalysisNode root, List<int> path) {
    var node = root;
    for (final index in path) {
      if (index < 0 || index >= node.children.length) break;
      node = node.children[index];
    }
    return node;
  }
}

/// The tutorial being written — every part of it, and which one is open.
///
/// Held by `TutorialStudioScreen` and persisted on the device by
/// `TutorialDraftService`. Decision 3 of `docs/PLAN-TUTORIJAL.md` still holds:
/// one write at the end, not a write per part, so a session interrupted halfway
/// leaves nothing half-written in the trainer's library.
///
/// [lessonId] is what P2 adds, and it does two things. It tells a second
/// „Sačuvaj" to update rather than to create a second tutorial, and it gives
/// the local draft slot an identity — so opening a *different* tutorial can no
/// longer come up carrying the last one's parts, which is the confusion the
/// owner met.
class TutorialDraft {
  TutorialDraft({
    this.lessonId,
    this.title = '',
    this.description,
    List<String>? tags,
    List<TutorialSection>? sections,
    int selected = 0,
  })  : tags = tags == null ? <String>[] : normaliseLabels(tags),
        sections = (sections == null || sections.isEmpty)
            ? [TutorialSection.blank(fen: startFen)]
            : sections,
        _selected = selected {
    _selected = _selected.clamp(0, this.sections.length - 1);
  }

  static const String startFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  /// Which saved tutorial this draft is, or null for one that has never been
  /// saved.
  int? lessonId;

  String title;

  /// What the tutorial is about, in a sentence. Written by the JSON import and
  /// by nothing else today; it is carried rather than displayed so that a save
  /// does not throw away what the import stored.
  String? description;

  /// The labels this tutorial is found by — `saved_lessons.tags`.
  ///
  /// The same column the saved-position dialog has always written and the same
  /// one `GET /lessons/labels` and the `includeTags`/`excludeTags` filter read.
  /// It is a tutorial's only sorting handle: a trainer with forty of them has
  /// a list nobody scrolls to the end of.
  final List<String> tags;

  /// Deo 1, Deo 2, … in the order the child meets them. Never empty: `PUT`
  /// writes `position_list = NULL` for an empty list, so a tutorial emptied
  /// here would lose every step with nothing left to join on and complain.
  final List<TutorialSection> sections;

  int _selected;

  int get selected => _selected;

  set selected(int value) =>
      _selected = value.clamp(0, sections.length - 1).toInt();

  /// The part being written.
  TutorialSection get section => sections[_selected];

  /// The body of the save. Built here so the screen that sends it has no second
  /// opinion about the shape.
  List<Map<String, dynamic>> get positionList => [
        for (var i = 0; i < sections.length; i++) sections[i].toJson(index: i),
      ];

  /// A saved tutorial, opened for editing.
  ///
  /// Also the reader for an imported one: a file that has never been saved
  /// arrives here without an `id`, which is what makes the first press of
  /// „Save tutorial" create it rather than edit something.
  factory TutorialDraft.fromLesson(Map<String, dynamic> lesson) {
    final raw = lesson['position_list'];
    final rawId = lesson['id'];
    return TutorialDraft(
      lessonId: rawId is int ? rawId : int.tryParse('$rawId'),
      title: lesson['title']?.toString() ?? '',
      description: lesson['description']?.toString(),
      tags: [
        for (final tag in (lesson['tags'] as List?) ?? const []) tag.toString(),
      ],
      sections: [
        for (final entry in raw is List ? raw : const [])
          if (entry is Map)
            TutorialSection.fromStep(Map<String, dynamic>.from(entry)),
      ],
    );
  }

  /// Adds a part after the one open and stands the trainer on it.
  ///
  /// [continueFromEnd] starts it on the position the open part's line ran out
  /// at, which is exactly the position the child's screen joins on — show, then
  /// ask, on one board with no reset. False starts on a fresh board instead.
  void addSection({required bool continueFromEnd, String title = ''}) {
    final at = _selected + 1;
    final fen = continueFromEnd ? endOfMainLine(section.root).fen : startFen;
    // The way round the trainer is looking, carried over. A part added with
    // „Odavde" *continues* the one before it — the child crosses that join
    // without the pieces being reloaded — so a board that flips at the join is
    // the one thing the join exists to prevent. It carries over for „Nova
    // tabla" too: somebody writing a tutorial from Black's side is still
    // writing from Black's side on the next diagram. Reported live on
    // 7.9.2026.
    final blackOrientation = section.blackOrientation;
    sections.insert(
      at,
      TutorialSection.blank(fen: fen, title: title)
        ..blackOrientation = blackOrientation,
    );
    _selected = at;
  }

  /// Removes one part. False — and nothing removed — when it is the last one.
  bool removeSection(int index) {
    if (sections.length <= 1) return false;
    if (index < 0 || index >= sections.length) return false;
    sections.removeAt(index);
    _selected = _selected.clamp(0, sections.length - 1);
    return true;
  }

  void moveSection(int from, int to) {
    if (from < 0 || from >= sections.length) return;
    if (to < 0 || to >= sections.length || from == to) return;
    final moved = sections.removeAt(from);
    sections.insert(to, moved);
    _selected = to;
  }

  /// Puts [parts] where the open one stands, and keeps the first of them open.
  ///
  /// What „Traži potez na tabli" does to a part: one goes out and up to three
  /// come back, all of them standing on positions that join. The selection is
  /// left on the first, and the caller moves it to whichever of them the
  /// trainer should be looking at.
  void replaceSelected(List<TutorialSection> parts) {
    if (parts.isEmpty) return;
    sections.replaceRange(_selected, _selected + 1, parts);
  }

  /// Duplicates a part. The copy carries no step id — see
  /// [TutorialSection.copy].
  void cloneSection(int index) {
    if (index < 0 || index >= sections.length) return;
    sections.insert(index + 1, sections[index].copy());
    _selected = index + 1;
  }

  Map<String, dynamic> toJson() => {
        if (lessonId != null) 'lessonId': lessonId,
        'title': title,
        if (description != null) 'description': description,
        if (tags.isNotEmpty) 'tags': tags,
        'selected': _selected,
        'sections': [for (final section in sections) section.toLocalJson()],
      };

  /// Reads the on-device slot back.
  ///
  /// It also reads the shape the slot held **before** P1 —
  /// `{title, examples: [{fen, pgn, …}]}` — so a trainer who upgrades in the
  /// middle of writing does not lose what they had. Reading it costs nothing:
  /// [TutorialSection.fromStep] is exactly the reader an old example needs.
  factory TutorialDraft.fromJson(Map<String, dynamic> json) {
    final modern = json['sections'];
    if (modern is List) {
      return TutorialDraft(
        lessonId: json['lessonId'] is int ? json['lessonId'] as int : null,
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString(),
        tags: [
          for (final tag in (json['tags'] as List?) ?? const []) tag.toString(),
        ],
        sections: [
          for (final raw in modern)
            if (raw is Map)
              TutorialSection.fromLocalJson(Map<String, dynamic>.from(raw)),
        ],
        selected: json['selected'] is int ? json['selected'] as int : 0,
      );
    }

    return TutorialDraft(
      title: json['title']?.toString() ?? '',
      sections: [
        for (final raw in (json['examples'] as List?) ?? const [])
          if (raw is Map)
            TutorialSection.fromStep(Map<String, dynamic>.from(raw)),
      ],
    );
  }
}
