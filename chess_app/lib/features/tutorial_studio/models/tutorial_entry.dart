import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';

/// Why the tutorial studio is being opened.
///
/// D4 of `docs/PLAN-STUDIO-REDIZAJN.md`, and it exists because of the first
/// thing the owner reported: opening the studio to start something new came up
/// carrying the last tutorial. The cause was that the screen had no idea what
/// it was being opened *for* — it loaded the one stored draft slot
/// unconditionally, and a handover replaced only the working tree, so the title
/// and every finished part came back whatever the trainer had asked for.
///
/// There is no fourth case and deliberately no default. A screen that can be
/// opened without saying why is a screen that has to guess, and guessing is
/// what this type replaces.
sealed class TutorialEntry {
  const TutorialEntry();

  /// „Novi tutorijal" — a name, and nothing else.
  ///
  /// The stored draft is **not** adopted. If one exists and has anything in it
  /// the screen says so by name and lets the trainer choose; silence is what
  /// made this feel haunted. Answering „Odbaci" throws the slot away, because a
  /// draft the trainer has just declined must not come back tomorrow.
  const factory TutorialEntry.blank(String title) = TutorialEntryBlank;

  /// „Uredi sačuvani tutorijal" — one row of `GET /lessons`, with its
  /// `position_list`.
  ///
  /// A stored draft is adopted only when it is a draft **of this tutorial**,
  /// which is what `TutorialDraft.lessonId` is for. Anything else belongs to a
  /// different tutorial and is left alone.
  const factory TutorialEntry.saved(Map<String, dynamic> lesson) =
      TutorialEntrySaved;

  /// The Analysis Studio's door: a position, or a whole line, worked out with
  /// the engine and sent here rather than retyped.
  ///
  /// [intoOpenDraft] is answered **at the door**, by the Studio, before it
  /// navigates — „u tutorijal koji uređujem" or „u nov tutorijal". It is not
  /// asked here: a question about where a line should go belongs beside the
  /// line, while the trainer can still see it.
  const factory TutorialEntry.fromAnalysis(
    TutorialHandover handover, {
    bool intoOpenDraft,
  }) = TutorialEntryFromAnalysis;
}

class TutorialEntryBlank extends TutorialEntry {
  const TutorialEntryBlank(this.title);
  final String title;
}

class TutorialEntrySaved extends TutorialEntry {
  const TutorialEntrySaved(this.lesson);
  final Map<String, dynamic> lesson;
}

class TutorialEntryFromAnalysis extends TutorialEntry {
  const TutorialEntryFromAnalysis(this.handover, {this.intoOpenDraft = true});
  final TutorialHandover handover;

  /// True — the default and today's behaviour — carries on with the tutorial
  /// already being written and makes the handed-over line its open part.
  final bool intoOpenDraft;
}
