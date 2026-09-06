import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;

/// One worked example of the tutorial — exactly one lesson step, as the backend
/// already takes it.
///
/// Contract C4 of `docs/PLAN-TUTORIJAL.md`. The wire shape is the one
/// `chess_backend/services/lessonSteps.js` validates; it is quoted here rather
/// than restated, because a second idea of what a step is is how this codebase
/// ended up with two PGN parsers.
///
/// **[correctChoice] is the one field C4 did not name, added by the lead on
/// 6.9.2026 before batch E started rather than discovered inside it.** C4 froze
/// `List<String> choices`, which is right for the *student's* model
/// ([LessonStep.choices] is a list of strings, because the answer is the thing
/// being asked and never travels to the child) — but the author has to say
/// which one is right, and the server takes `[{text, correct}]` with exactly
/// one `correct: true`. Without it an `ask_choice` example is unsaveable.
class TutorialExample {
  const TutorialExample({
    required this.fen,
    required this.pgn,
    required this.title,
    this.instruction,
    this.kind = LessonStepKind.show,
    this.choices = const [],
    this.correctChoice,
    this.solutionSan,
  });

  /// The position this example opens on.
  final String fen;

  /// The line that runs on from it, with each move's words and drawings.
  ///
  /// [fen] and [pgn] come from one node of the tree — see [StudioLessonStep] —
  /// so a line that cannot be played from its own position is caught before it
  /// is saved rather than by a child.
  final String pgn;

  final String title;
  final String? instruction;
  final LessonStepKind kind;

  /// The answers offered on an `ask_choice` example, in the order they are
  /// shown.
  final List<String> choices;

  /// Which of [choices] is the right one. Null while nothing has been picked.
  final int? correctChoice;

  /// The move an `ask_move` example expects, in SAN.
  final String? solutionSan;

  TutorialExample copyWith({
    String? fen,
    String? pgn,
    String? title,
    String? instruction,
    LessonStepKind? kind,
    List<String>? choices,
    int? correctChoice,
    String? solutionSan,
  }) =>
      TutorialExample(
        fen: fen ?? this.fen,
        pgn: pgn ?? this.pgn,
        title: title ?? this.title,
        instruction: instruction ?? this.instruction,
        kind: kind ?? this.kind,
        choices: choices ?? this.choices,
        correctChoice: correctChoice ?? this.correctChoice,
        solutionSan: solutionSan ?? this.solutionSan,
      );

  static const Map<LessonStepKind, String> _wire = {
    LessonStepKind.show: 'show',
    LessonStepKind.askMove: 'ask_move',
    LessonStepKind.askChoice: 'ask_choice',
  };

  /// One entry of the `positionList` a save sends.
  ///
  /// A field the example says nothing about is left out of the body rather than
  /// sent as null: the server tells "leave this alone" from "there is none"
  /// by whether the key is there at all, and that distinction has already cost
  /// this project every step of a renamed lesson.
  Map<String, dynamic> toJson() => {
        'fen': fen,
        'pgn': pgn,
        'title': title,
        if (instruction != null && instruction!.trim().isNotEmpty)
          'instruction': instruction!.trim(),
        'kind': _wire[kind]!,
        if (kind == LessonStepKind.askChoice && choices.isNotEmpty)
          'choices': [
            for (var i = 0; i < choices.length; i++)
              {'text': choices[i], 'correct': i == correctChoice},
          ],
        if (solutionSan != null && solutionSan!.isNotEmpty)
          'solutionSan': solutionSan,
      };

  factory TutorialExample.fromJson(Map<String, dynamic> json) {
    final rawChoices = (json['choices'] as List?) ?? const [];
    final texts = <String>[];
    int? correct;
    for (final raw in rawChoices) {
      if (raw is! Map) continue;
      if (raw['correct'] == true) correct = texts.length;
      texts.add(raw['text']?.toString() ?? '');
    }

    return TutorialExample(
      fen: json['fen']?.toString() ?? '',
      pgn: json['pgn']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      instruction: json['instruction']?.toString(),
      kind: _wire.entries
          .firstWhere((e) => e.value == json['kind'],
              orElse: () => const MapEntry(LessonStepKind.show, 'show'))
          .key,
      choices: texts,
      correctChoice: correct,
      solutionSan: json['solutionSan']?.toString(),
    );
  }
}

/// The tutorial being written, before any of it reaches the server.
///
/// Held by `TutorialStudioScreen` and persisted on the device by
/// [TutorialDraftService] — decision 3: one `POST /lessons/save` at the end,
/// not a write per example, so a session interrupted halfway leaves nothing
/// half-written in the trainer's library.
class TutorialDraft {
  TutorialDraft({this.title = '', List<TutorialExample>? examples})
      : examples = examples ?? [];

  String title;

  /// Primer 1, Primer 2, … in the order they were written.
  final List<TutorialExample> examples;

  /// The body of the single save. Built here so the screen that sends it has
  /// no second opinion about the shape.
  List<Map<String, dynamic>> get positionList =>
      [for (final example in examples) example.toJson()];

  Map<String, dynamic> toJson() => {
        'title': title,
        'examples': [for (final example in examples) example.toJson()],
      };

  factory TutorialDraft.fromJson(Map<String, dynamic> json) => TutorialDraft(
        title: json['title']?.toString() ?? '',
        examples: [
          for (final raw in (json['examples'] as List?) ?? const [])
            if (raw is Map)
              TutorialExample.fromJson(Map<String, dynamic>.from(raw)),
        ],
      );
}
