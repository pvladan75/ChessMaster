import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/studio_lesson_step.dart';
import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
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
    // `PgnExporterService` always writes headers, so an exported empty tree is
    // never the empty string — batch 54's correction, and it still holds.
    return step.line.movesSan.isEmpty ? '' : step.pgn;
  }

  /// The step read back through the child's parser — the check that a line
  /// which cannot be replayed from its own position is never saved.
  StudioLessonStep get step => StudioLessonStep.from(root);

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

  /// One entry of the `positionList` a save sends.
  ///
  /// A field this part says nothing about is left out of the body rather than
  /// sent as null: the server tells „leave this alone" from „there is none" by
  /// whether the key is there at all, and that distinction has already cost
  /// this project every step of a renamed lesson.
  Map<String, dynamic> toJson() {
    final pgn = pgnForSave;
    return {
      if (stepId != null) 'id': stepId,
      'title': title,
      'fen': root.fen,
      // Omitted rather than sent empty. `buildLessonStep` reads `if (pgn)`, so
      // `''` and absent are the same thing to the server — but only absence
      // round-trips a step that was stored without a line.
      if (pgn.isNotEmpty) 'pgn': pgn,
      if (instruction != null && instruction!.trim().isNotEmpty)
        'instruction': instruction!.trim(),
      'kind': _wire[kind]!,
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
    List<TutorialSection>? sections,
    int selected = 0,
  })  : sections = (sections == null || sections.isEmpty)
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
  List<Map<String, dynamic>> get positionList =>
      [for (final section in sections) section.toJson()];

  /// A saved tutorial, opened for editing.
  factory TutorialDraft.fromLesson(Map<String, dynamic> lesson) {
    final raw = lesson['position_list'];
    final rawId = lesson['id'];
    return TutorialDraft(
      lessonId: rawId is int ? rawId : int.tryParse('$rawId'),
      title: lesson['title']?.toString() ?? '',
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
    sections.insert(at, TutorialSection.blank(fen: fen, title: title));
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
