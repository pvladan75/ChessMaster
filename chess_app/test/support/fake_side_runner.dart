// A stand-in for the engine behind „Suggest sides with the engine"
// (`docs/PLAN-MATERIJAL.md`, phase 2): answers from a table by board id,
// records what it was asked, and can stop half way so „Stop keeps what
// landed" can be watched. No Stockfish in a widget test.

import 'dart:async';

import 'package:chess_app/features/position_scanner/services/side_proposal.dart';
import 'package:chess_app/features/position_scanner/services/side_proposal_runner.dart';

class FakeSideRunner extends SideProposalRunner {
  FakeSideRunner(this.answers, {this.usable = true, this.pauseAfter});

  /// What the engine „proposes", by the caller's board id.
  final Map<String, SideProposal> answers;

  /// False plays the network engine, which a book position is refused on.
  final bool usable;

  /// Stops after this many answers and waits on [resume].
  final int? pauseAfter;
  final Completer<void> resume = Completer<void>();

  /// Every run's boards, in the order asked.
  final List<List<SideCandidate>> runs = [];
  bool cancelled = false;

  List<String> get askedIds =>
      [for (final run in runs) ...run.map((c) => c.id)];

  @override
  Future<bool> ensureUsableEngine() async => usable;

  @override
  void cancel() => cancelled = true;

  @override
  Future<void> run(
    List<SideCandidate> positions, {
    required int depth,
    required void Function(String id, SideProposal proposal) onResult,
    required void Function(int done, int total) onProgress,
  }) async {
    cancelled = false;
    runs.add(List.of(positions));
    for (var i = 0; i < positions.length; i++) {
      if (cancelled) return;
      final id = positions[i].id;
      onResult(id, answers[id] ?? SideProposal.empty);
      onProgress(i + 1, positions.length);
      if (pauseAfter == i + 1) await resume.future;
    }
  }
}

SideProposal highProposal(String side, String? answer) => SideProposal(
      side: side,
      confidence: ProposalConfidence.high,
      reason: '${side == 'w' ? 'White' : 'Black'} mates',
      whiteEval: side == 'w' ? 'M1' : '0.00',
      blackEval: side == 'b' ? '-M1' : '0.00',
      answerSan: answer,
    );

SideProposal mediumProposal(String side, String? answer) => SideProposal(
      side: side,
      confidence: ProposalConfidence.medium,
      reason: 'the move is worth much more to '
          '${side == 'w' ? 'White' : 'Black'}',
      whiteEval: side == 'w' ? '+4.10' : '+0.20',
      blackEval: side == 'b' ? '-4.10' : '-0.20',
      answerSan: answer,
    );
