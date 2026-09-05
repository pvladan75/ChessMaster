import 'package:chess_app/core/services/tour_walk.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_order.dart';

/// One beat of the tour: a position the reader is taken to, in order.
///
/// Most beats are a stop — a move, played on the board. A **returning** beat is
/// not a move at all: it is the tour coming back to the fork it is about to
/// branch from, so the reader sees the position a second line starts out of
/// before it starts.
///
/// The owner asked for this after watching the tour: at the end of a line the
/// board used to jump straight into the next branch, several moves away and
/// several plies back, and there was nothing on screen saying where the two
/// lines part. The beat is that missing sentence, and it costs one press.
class WalkthroughBeat {
  const WalkthroughBeat({
    required this.stopIndex,
    this.returning = false,
    this.done,
    this.next,
  });

  /// Which stop the board stands on. **-1 is the root position**, which a
  /// returning beat uses when two first moves fork at the root itself.
  final int stopIndex;

  /// Whether this beat exists only to show the fork again.
  final bool returning;

  /// The reply whose line the tour has just finished. Returning beats only.
  final RepertoireTreeMove? done;

  /// The reply the tour is about to take. Returning beats only.
  final RepertoireTreeMove? next;
}

/// The tour, as the reader is actually walked through it.
///
/// The arithmetic lives in `core/services/tour_walk.dart` and knows nothing
/// about repertoires — it was extracted there in phase 3 of
/// `PLAN-INTERAKTIVNA-LEKCIJA.md` so a lesson step's line can be walked the
/// same way, with the same return to the fork. This function is the adapter:
/// it hands over the paths and turns the indices that come back into the moves
/// this feature speaks in.
List<WalkthroughBeat> walkthroughBeats(List<WalkthroughStop> stops) {
  final beats = tourBeats([for (final stop in stops) stop.path]);

  RepertoireTreeMove? moveAt(int index) =>
      index < 0 || index >= stops.length ? null : stops[index].move;

  return [
    for (final beat in beats)
      WalkthroughBeat(
        stopIndex: beat.stopIndex,
        returning: beat.returning,
        done: moveAt(beat.doneIndex),
        next: moveAt(beat.nextIndex),
      ),
  ];
}
