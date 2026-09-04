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

bool _startsWith(List<String> path, List<String> prefix) {
  if (path.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (path[i] != prefix[i]) return false;
  }
  return true;
}

bool _isChildOf(WalkthroughStop child, WalkthroughStop parent) =>
    child.path.length == parent.path.length + 1 &&
    _startsWith(child.path, parent.path);

/// The tour, as the reader is actually walked through it.
///
/// Every stop, in `walkthroughOrder`'s order and exactly once — that contract
/// is not touched here — with a returning beat inserted wherever the tour
/// climbs back out of a finished line to start another.
///
/// A climb is any step whose next stop is not a child of the current one. The
/// fork it climbs to is the parent of the stop about to be visited, which is
/// always a stop the tour has already been through (or the root), so the
/// returning beat never shows the reader a position out of nowhere.
List<WalkthroughBeat> walkthroughBeats(List<WalkthroughStop> stops) {
  final beats = <WalkthroughBeat>[];

  for (var k = 0; k < stops.length; k++) {
    if (k > 0 && !_isChildOf(stops[k], stops[k - 1])) {
      final parentPath = stops[k].path.sublist(0, stops[k].path.length - 1);

      // The fork itself. Empty path means the two lines part at the root.
      var parentIndex = -1;
      for (var j = 0; j < k; j++) {
        if (stops[j].path.length == parentPath.length &&
            _startsWith(stops[j].path, parentPath)) {
          parentIndex = j;
          break;
        }
      }

      // The branch just finished is the sibling immediately before this one:
      // the walk is depth-first, so the tour cannot have been anywhere else.
      RepertoireTreeMove? done;
      for (var j = k - 1; j >= 0; j--) {
        if (stops[j].path.length == parentPath.length + 1 &&
            _startsWith(stops[j].path, parentPath)) {
          done = stops[j].move;
          break;
        }
      }

      beats.add(WalkthroughBeat(
        stopIndex: parentIndex,
        returning: true,
        done: done,
        next: stops[k].move,
      ));
    }
    beats.add(WalkthroughBeat(stopIndex: k));
  }

  return beats;
}
