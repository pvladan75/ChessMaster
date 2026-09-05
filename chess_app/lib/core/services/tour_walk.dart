/// Walking a tour: a list of stops, each knowing where it sits.
///
/// All of this was written for „Upoznaj repertoar" (`PLAN-UPOZNAJ-REPERTOAR.md`,
/// phases 3 and 4) and watched running there. None of it is about repertoires.
/// Every rule here is about **paths** — where a stop sits relative to the one
/// before it — and the interactive lesson of `PLAN-INTERAKTIVNA-LEKCIJA.md`
/// needs the same arithmetic to walk a step's line: into a side variation, and
/// back to the fork it left.
///
/// It speaks in **indices**, never in moves. That is what keeps it free of any
/// one feature: the caller holds the payload, hands over the paths, and turns
/// the indices back into its own objects. The repertoire's `WalkthroughBeat`
/// resolves them to `RepertoireTreeMove`; a lesson will resolve them to
/// something else; neither has to teach this file what it is walking.
library;

/// Whether [path] begins with [prefix]. The empty prefix is the root, and
/// everything is inside it.
bool pathStartsWith(List<String> path, List<String> prefix) {
  if (path.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (path[i] != prefix[i]) return false;
  }
  return true;
}

bool _isChildOf(List<String> child, List<String> parent) =>
    child.length == parent.length + 1 && pathStartsWith(child, parent);

/// One beat of a tour: a stop the reader is taken to, in order.
///
/// Most beats are a stop, played. A **returning** beat is not a move at all: it
/// is the tour coming back to the fork it is about to branch from, so the reader
/// sees the position a second line starts out of before it starts.
///
/// The owner asked for this after watching the tour: at the end of a line the
/// board used to jump straight into the next branch, several moves away and
/// several plies back, and nothing on screen said where the two lines part. The
/// beat is that missing sentence, and it costs one press.
class TourBeat {
  const TourBeat({
    required this.stopIndex,
    this.returning = false,
    this.doneIndex = -1,
    this.nextIndex = -1,
  });

  /// Which stop the board stands on. **-1 is the root**, which a returning beat
  /// uses when two first moves fork at the root itself.
  final int stopIndex;

  /// Whether this beat exists only to show the fork again.
  final bool returning;

  /// The stop whose line the tour has just finished. Returning beats only, -1
  /// otherwise.
  ///
  /// The *branch* that finished, not the last stop walked: a tour coming out of
  /// „e6 d4" has finished e6, and telling the reader it finished d4 would name
  /// a move that is not one of the choices at this fork.
  final int doneIndex;

  /// The stop whose line the tour is about to take. Returning beats only.
  final int nextIndex;
}

/// The tour as it is actually driven.
///
/// Every stop, in the order given and exactly once — that contract belongs to
/// whoever built the list and is not touched here — with a returning beat
/// inserted wherever the tour climbs back out of a finished line to start
/// another.
///
/// A climb is any step whose next stop is not a child of the current one. The
/// fork it climbs to is the parent of the stop about to be visited, which is
/// always somewhere the tour has already been (or the root), so a returning beat
/// never shows the reader a position out of nowhere.
List<TourBeat> tourBeats(List<List<String>> paths) {
  final beats = <TourBeat>[];

  for (var k = 0; k < paths.length; k++) {
    if (k > 0 && !_isChildOf(paths[k], paths[k - 1])) {
      final parentPath = paths[k].sublist(0, paths[k].length - 1);

      // The fork itself. An empty path means the two lines part at the root.
      var parentIndex = -1;
      for (var j = 0; j < k; j++) {
        if (paths[j].length == parentPath.length &&
            pathStartsWith(paths[j], parentPath)) {
          parentIndex = j;
          break;
        }
      }

      // The branch just finished is the sibling immediately before this one:
      // the walk is depth-first, so the tour cannot have been anywhere else.
      var doneIndex = -1;
      for (var j = k - 1; j >= 0; j--) {
        if (paths[j].length == parentPath.length + 1 &&
            pathStartsWith(paths[j], parentPath)) {
          doneIndex = j;
          break;
        }
      }

      beats.add(TourBeat(
        stopIndex: parentIndex,
        returning: true,
        doneIndex: doneIndex,
        nextIndex: k,
      ));
    }
    beats.add(TourBeat(stopIndex: k));
  }

  return beats;
}

/// The stops leading one move forward from [stopIndex], in tour order.
///
/// -1 asks about the root. A child is a stop whose path is the current one plus
/// a single move, taken while the walk is still inside the current subtree —
/// the scan stops at the first path that leaves it, so a sibling's children are
/// never offered as this position's replies.
List<int> tourForwardIndices(List<List<String>> paths, int stopIndex) {
  final prefix = stopIndex < 0 ? const <String>[] : paths[stopIndex];
  final found = <int>[];
  for (var j = stopIndex + 1; j < paths.length; j++) {
    if (!pathStartsWith(paths[j], prefix)) break;
    if (paths[j].length == prefix.length + 1) found.add(j);
  }
  return found;
}

/// The beat at the end of the line the tour is standing on.
///
/// [beatIndex] is a beat, and so is the answer. A returning beat is never part
/// of the line: it stands on the fork, which is an ancestor rather than a
/// descendant, so the scan stops there of its own accord — which is exactly the
/// „never jump into a sibling variation" rule falling out rather than being
/// special-cased.
int tourLastIndex(
  List<List<String>> paths,
  List<TourBeat> beats,
  int beatIndex,
) {
  final standingOn = beatIndex < 0 || beatIndex >= beats.length
      ? -1
      : beats[beatIndex].stopIndex;
  final prefix = standingOn < 0 ? const <String>[] : paths[standingOn];

  var lastIndex = beatIndex;
  for (var j = beatIndex + 1; j < beats.length; j++) {
    final at = beats[j].stopIndex;
    if (at >= 0 && !beats[j].returning && pathStartsWith(paths[at], prefix)) {
      lastIndex = j;
    } else {
      break;
    }
  }
  return lastIndex;
}

/// The beat that *plays* [stopIndex], or -1.
///
/// A stop is played exactly once, so this is unambiguous — the returning beats
/// that also name it are the tour standing at a fork, not walking into it.
int tourBeatOfStop(List<TourBeat> beats, int stopIndex) =>
    beats.indexWhere((b) => !b.returning && b.stopIndex == stopIndex);
