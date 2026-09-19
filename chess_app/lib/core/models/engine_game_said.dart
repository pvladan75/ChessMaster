/// What the ending dialog of an assigned "play it out" game may say, when the
/// game stopped at a move target a tablebase — not this app — is asked to
/// judge (`docs/PLAN-EXERCISE.md`, phase 3b, decisions 1 and 2).
///
/// `EngineGameVerdict.needsTablebase` (`engine_game_task.dart`) says whether
/// this app's own `goalMet` is a guess rather than a fact; this file holds
/// what the screen is allowed to say once it knows, and the three sentences
/// that go with it. „Not judged yet" is not a failure: the tablebase could
/// not be reached, the game still counts as done, and it is judged the next
/// time anybody opens the homework.
library;

import 'engine_game_task.dart';

/// The `POST /assignments/:id/game-result` response, so far as the ending
/// dialog needs it.
///
/// A server from before phase 3a answers with `goalMet` alone — no `pending`,
/// no `judgedBy` — which reads here as "judged already, and not pending":
/// [pending] defaults to false and [judgedBy] to null when the field is
/// absent, which is exactly what an older server means by staying silent
/// about them.
class EngineGameServerVerdict {
  const EngineGameServerVerdict({
    required this.goalMet,
    required this.judgedBy,
    required this.pending,
  });

  /// Null while the answer is not known — pending, or the field was absent.
  final bool? goalMet;

  /// `'rules'`, `'tablebase'`, `'device'`, or null when nothing judged it yet.
  final String? judgedBy;

  final bool pending;

  /// Reads the response, or refuses an answer that cannot be read as one.
  static EngineGameServerVerdict? fromJson(Object? json) {
    if (json is! Map) return null;
    final goalMetRaw = json['goalMet'];
    final judgedByRaw = json['judgedBy'];
    return EngineGameServerVerdict(
      goalMet: goalMetRaw is bool ? goalMetRaw : null,
      judgedBy: judgedByRaw is String ? judgedByRaw : null,
      pending: json['pending'] == true,
    );
  }
}

/// What the ending dialog may say.
enum EngineGameSaid { met, notMet, notJudged }

/// [local] is what this app read off its own board; [server] is what
/// `POST …/game-result` answered, or null when the result could not be sent
/// or read.
///
/// A game the rules alone can end is announced at once, whatever came back —
/// [local]'s own `goalMet` is not a guess there. At a move target a tablebase
/// must judge ([local].needsTablebase), [server]'s word is the word: nothing
/// coming back, or an answer still pending, reads as „not judged yet", never
/// as a fallback to this app's own guess.
EngineGameSaid engineGameSaid(
    EngineGameVerdict local, EngineGameServerVerdict? server) {
  // A game with no goal is the trainer's to judge (phase 15): nothing this
  // app read off its board, and nothing the result route answered, is a
  // verdict — it waits.
  if (local.needsTrainer) return EngineGameSaid.notJudged;
  if (!local.needsTablebase) {
    return local.goalMet ? EngineGameSaid.met : EngineGameSaid.notMet;
  }
  if (server == null || server.pending || server.goalMet == null) {
    return EngineGameSaid.notJudged;
  }
  return server.goalMet! ? EngineGameSaid.met : EngineGameSaid.notMet;
}

/// The sentence for [said]. Three different ones, and „not judged yet" reads
/// as neither a failure nor a wrong answer — the owner is colour-blind, so
/// this is the only thing that says it (the icon beside it is a different
/// *shape*, never colour alone).
String engineGameSaidWords(EngineGameSaid said) => switch (said) {
      EngineGameSaid.met => 'Goal met',
      EngineGameSaid.notMet => 'Goal not met',
      EngineGameSaid.notJudged => 'Not judged yet',
    };
