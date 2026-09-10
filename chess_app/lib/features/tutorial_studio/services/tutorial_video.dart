/// A tutorial as the frames of a video — phase 2 of `docs/PLAN-ZAVRSNICA.md`.
///
/// **The renderer is `chess_backend/videoRenderer.js` and it already exists.**
/// It draws one PNG per second with `@napi-rs/canvas` and pipes them into
/// `ffmpeg`, and it takes a list of events with timestamps. What it was built
/// for is a recorded lesson, where the trainer's voice carried the teaching; a
/// tutorial has no voice, so the sentence, the arrows and the coloured squares
/// have to be *in* the picture. Teaching the renderer to draw those three is
/// the other half of this phase.
///
/// **Why the list is built here and not there.** The server stores a step's
/// `pgn` as opaque text and has no PGN reader, deliberately: a second parser is
/// a second opinion about what a trainer wrote, and this project has already
/// paid once for two parsers disagreeing about one line. So the app — which
/// holds the tree, the comments and the drawings — hands the finished list over
/// and the server renders it.
///
/// **The order is the child's, not the tree's.** It comes from [beatsOf],
/// which is the same projection the „Tok" timeline draws and which was written
/// from the narration loop in `lesson_viewer_screen.dart`: standing on a node
/// the child sees that node's marks, reads that node's sentence, and only then
/// is the next move played. A video that played the move first would be
/// teaching something the tutorial does not say.
library;

import 'dart:math' as math;
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/tutorial_studio/models/tutorial_beat.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';

/// The list of events, and how long the film runs.
typedef TutorialVideo = ({List<Map<String, dynamic>> events, int seconds});

/// How long a beat stays on screen, in whole seconds.
///
/// Whole seconds because the renderer draws one frame per second and applies
/// every event whose timestamp has passed — two beats inside one second would
/// collapse into one frame, and the second one would never be seen.
///
/// There is no voice to wait for, so the only thing that decides is how long
/// the sentence takes to read. Twelve characters a second is deliberately
/// slower than an adult reads: the reader is a child, the words are about a
/// position they are also looking at, and a caption that is gone before it is
/// finished is worse than a slow film.
int dwellSecondsFor(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return _minBeatSeconds;
  final needed = (trimmed.length / _charsPerSecond).ceil();
  return needed.clamp(_minBeatSeconds, _maxBeatSeconds);
}

const int _minBeatSeconds = 2;
const int _maxBeatSeconds = 12;
const int _charsPerSecond = 12;

/// One stop of the film: the beat, the part it belongs to, and what is written
/// under the board while it is on screen.
typedef FilmBeat = ({
  TutorialSection section,
  TutorialBeat beat,
  String caption
});

/// Every beat of [draft], in the order the film shows them.
///
/// **This is the one walk of a tutorial as a film**, and there are two readers
/// of it: [tutorialVideoOf], which turns each stop into an event, and the
/// recording screen, which shows each stop while the trainer talks over it.
/// A recorded marker names an event by its index, so the two must agree on the
/// index by construction rather than by two loops that happen to match today.
List<FilmBeat> filmBeatsOf(TutorialDraft draft) {
  final stops = <FilmBeat>[];
  for (final section in draft.sections) {
    final beats = beatsOf(section.root, section.root);
    for (var i = 0; i < beats.length; i++) {
      stops.add((
        section: section,
        beat: beats[i],
        caption:
            _captionOf(section, beats[i], isLastBeat: i == beats.length - 1),
      ));
    }
  }
  return stops;
}

/// Every part of [draft], in order, as one film.
///
/// A part contributes one event per beat of its main line. The first of them
/// is an `init` — it sets the position, which is what a new part is — and the
/// rest are `move`s, so the renderer can mark the square a piece came from.
///
/// A part that **asks** something carries its task on its last beat, under
/// whatever was written there. That is where the child meets it: the viewer
/// walks the line, and when the line runs out it reads the question. A video
/// that put the question first would ask before showing.
TutorialVideo tutorialVideoOf(TutorialDraft draft) {
  final events = <Map<String, dynamic>>[];
  var atMs = 0;

  for (final stop in filmBeatsOf(draft)) {
    final node = stop.beat.node;
    final opensPart = stop.beat.index == 0;
    final caption = stop.caption;

    events.add({
      'timestampMs': atMs,
      'eventType': opensPart ? 'init' : 'move',
      'data': {
        'fen': node.fen,
        // Asked of the beat's place on the line, not of the node's fields:
        // the opening position of a part is a position, and nothing arrived
        // at it. `MoveTree` calls its own root „Root", which is a
        // placeholder a reader must never be shown.
        if (!opensPart) ...{
          if (node.moveSan != null) 'san': node.moveSan!,
          ..._fromTo(node),
        },
        if (caption.isNotEmpty) 'text': caption,
        if (node.arrows.isNotEmpty)
          'arrows': [
            for (final arrow in node.arrows)
              {'from': arrow.from, 'to': arrow.to, 'color': arrow.colorCode},
          ],
        if (node.squares.isNotEmpty)
          'squares': [
            for (final square in node.squares)
              {'square': square.square, 'color': square.colorCode},
          ],
        // Per event, because a tutorial may be written from one side in one
        // part and the other in the next — the field already travels to the
        // child, and a film that ignored it would show a board the trainer
        // never wrote from. Not the renderer's own `perspective`, which
        // spells the two sides „trainer" and „student"; a colour is what
        // this actually is.
        'orientation': stop.section.blackOrientation ? 'black' : 'white',
      },
    });

    atMs += dwellSecondsFor(caption) * 1000;
  }

  return (events: events, seconds: atMs ~/ 1000);
}

/// What is written under the board on this beat.
///
/// Two things can be there and they are not the same thing: what the trainer
/// wrote *about this position*, and — on the last beat of a part that asks —
/// the task itself. Both, in that order, when both exist.
String _captionOf(
  TutorialSection section,
  TutorialBeat beat, {
  required bool isLastBeat,
}) {
  final written = beat.node.comment.trim();
  final asks = section.kind != LessonStepKind.show;
  final task = section.instruction?.trim() ?? '';

  if (!isLastBeat || !asks || task.isEmpty) return written;
  if (written.isEmpty) return task;
  return '$written\n$task';
}

/// The squares a move came from and went to, for the highlight the renderer
/// already draws. Read off the uci, which is the only field that has them.
Map<String, String> _fromTo(AnalysisNode node) {
  final uci = node.moveUci;
  if (uci == null || uci.length < 4) return const {};
  return {'from': uci.substring(0, 2), 'to': uci.substring(2, 4)};
}

/// A film nobody should be asked to sit through, and one nobody would see.
///
/// The caller refuses rather than rendering: an empty tutorial produces no
/// frames, and `ffmpeg` given no frames fails with a message about a pipe
/// rather than about a tutorial.
bool canRenderVideo(TutorialVideo video) =>
    video.events.isNotEmpty && video.seconds >= _minBeatSeconds;

/// The longest a tutorial may run, in seconds.
///
/// One frame per second and a canvas draw each, so an hour of film is an hour
/// of frames to draw. The renderer already clamps its own duration to 3600;
/// this is here so the app can say why before anything is sent.
const int maxVideoSeconds = 3600;

/// Whether [video] fits inside [maxVideoSeconds].
bool fitsInOneFilm(TutorialVideo video) => video.seconds <= maxVideoSeconds;

/// The number the renderer is given, clamped the way it clamps it itself.
int renderableSeconds(TutorialVideo video) =>
    math.min(video.seconds, maxVideoSeconds);
