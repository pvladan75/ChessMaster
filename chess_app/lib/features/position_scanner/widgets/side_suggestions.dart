// side_suggestions.dart — the engine asked about whose move it is, and what
// the move is, **before** a scan is saved (`docs/PLAN-MATERIJAL.md`, phase 2).
//
// Until this phase the only door was „Check with engine" on Saved Positions,
// after saving, and the picture path — which has no printed solution and needs
// it most — never reached it. Both scanner screens now drive one
// [SideSuggestions] and draw the same bar and the same note under a board.
//
// The rule of 19.8.2026 stands: the engine proposes, a person decides. A
// proposal is held here in memory and changes nothing until „Set side",
// „Set side and answer" or „Accept all confident" is pressed.
library;

import 'package:flutter/material.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

import '../services/side_proposal.dart';
import '../services/side_proposal_runner.dart';

/// How a run ended.
enum SuggestOutcome {
  /// Every board was asked, or the run was stopped; what landed is kept.
  finished,

  /// The engine that would answer is the network one, which has never seen a
  /// book diagram. Nothing was run.
  noLocalEngine,
}

/// One run of the engine over a screen's boards, and what it proposed.
class SideSuggestions extends ChangeNotifier {
  SideSuggestions({SideProposalRunner? runner}) : _runner = runner;

  /// What the depth picker offers: from 12, every depth up to
  /// [AppSettingsService.kMaxEngineDepth] (it stopped at 24 until 17.9.2026).
  static final List<int> depths = [
    for (var d = 12; d <= AppSettingsService.kMaxEngineDepth; d++) d
  ];

  /// Said when [SuggestOutcome.noLocalEngine] — the words „Check with engine"
  /// used on Saved Positions.
  static const String noLocalEngineMessage =
      'Engine is not running locally and cannot respond — network engine does '
      'not recognize book positions. Check Settings → Local engine (.exe).';

  SideProposalRunner? _runner;
  SideProposalRunner get _engine => _runner ??= SideProposalRunner();

  /// By the caller's board id. Kept when a run is stopped.
  final Map<String, SideProposal> proposals = {};

  bool running = false;
  int done = 0;
  int total = 0;
  int depth = 16;

  bool _disposed = false;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void setDepth(int value) {
    depth = value;
    _changed();
  }

  /// Asks the engine about [boards], one at a time, each answer landing as
  /// it comes.
  Future<SuggestOutcome> start(List<SideCandidate> boards) async {
    if (running || boards.isEmpty) return SuggestOutcome.finished;
    running = true;
    done = 0;
    total = boards.length;
    _changed();

    // Starting the engine is what decides whether it is a local one.
    final usable = await _engine.ensureUsableEngine();
    if (_disposed) return SuggestOutcome.finished;
    if (!usable) {
      running = false;
      _changed();
      return SuggestOutcome.noLocalEngine;
    }

    await _engine.run(
      boards,
      depth: depth,
      onResult: (id, proposal) {
        proposals[id] = proposal;
        _changed();
      },
      onProgress: (d, t) {
        done = d;
        total = t;
        _changed();
      },
    );
    running = false;
    _changed();
    return SuggestOutcome.finished;
  }

  /// Stops after the board being searched; what landed stays.
  void stop() {
    _engine.cancel();
    running = false;
    _changed();
  }

  /// Drops the proposal for [id] — once accepted, or once the board's side
  /// was set by hand.
  void forget(String id) {
    if (proposals.remove(id) != null) _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    if (running) _engine.cancel();
    super.dispose();
  }
}

/// The bar above a screen's boards: ask, how far, stop, and accept the
/// confident ones in one go.
class SuggestSidesBar extends StatelessWidget {
  const SuggestSidesBar({
    super.key,
    required this.suggestions,
    required this.eligible,
    required this.onSuggest,
    required this.confident,
    required this.onAcceptConfident,
  });

  final SideSuggestions suggestions;

  /// How many boards a run would ask about. None, and the button is off.
  final int eligible;
  final VoidCallback onSuggest;

  /// How many high proposals are waiting on boards still unsettled.
  final int confident;
  final VoidCallback onAcceptConfident;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = suggestions;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonalIcon(
          key: const ValueKey('suggest-sides'),
          onPressed: s.running || eligible == 0 ? null : onSuggest,
          icon: const Icon(Icons.psychology_outlined, size: 18),
          label: const Text('Suggest sides with the engine'),
        ),
        DropdownButton<int>(
          key: const ValueKey('suggest-sides-depth'),
          value: s.depth,
          onChanged: s.running ? null : (v) => s.setDepth(v ?? s.depth),
          items: [
            for (final d in SideSuggestions.depths)
              DropdownMenuItem(value: d, child: Text('Depth $d')),
          ],
        ),
        if (s.running) ...[
          Text('${s.done} of ${s.total}',
              key: const ValueKey('suggest-sides-progress'),
              style: AppText.body.copyWith(color: colors.textSecondary)),
          TextButton(
            key: const ValueKey('suggest-sides-stop'),
            onPressed: s.stop,
            child: const Text('Stop'),
          ),
        ],
        if (confident > 0)
          OutlinedButton(
            key: const ValueKey('suggest-sides-accept-confident'),
            onPressed: onAcceptConfident,
            child: Text('Accept all confident ($confident)'),
          ),
      ],
    );
  }
}

/// What the engine proposed for one board, and the two ways to take it.
///
/// „Set side and answer" appears only when the engine named a move. For a
/// medium proposal it is a separate tick on purpose: a book can ask for a
/// defence, and the move the engine likes need not be the one it asks for.
class ProposalNote extends StatelessWidget {
  const ProposalNote({
    super.key,
    required this.id,
    required this.proposal,
    required this.onSetSide,
    required this.onSetSideAndAnswer,
  });

  final String id;
  final SideProposal proposal;
  final VoidCallback onSetSide;
  final VoidCallback onSetSideAndAnswer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final p = proposal;
    final evals = [
      if (p.whiteEval.isNotEmpty) 'White ${p.whiteEval}',
      if (p.blackEval.isNotEmpty) 'Black ${p.blackEval}',
    ].join(' · ');
    final side = p.side == 'w' ? 'White' : 'Black';
    return Column(
      key: ValueKey('proposal-$id'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          p.hasAnswer
              ? '$side to move${p.answerSan == null ? '' : ', ${p.answerSan}'}'
                  ' — ${p.confidence == ProposalConfidence.high ? 'confident' : 'likely'}'
              : 'No proposal',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.bodyBold.copyWith(color: colors.textPrimary),
        ),
        Text(
          evals.isEmpty ? p.reason : '${p.reason} ($evals)',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption.copyWith(color: colors.textSecondary),
        ),
        if (p.hasAnswer)
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              TextButton(
                key: ValueKey('proposal-set-side-$id'),
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6)),
                onPressed: onSetSide,
                child: const Text('Set side'),
              ),
              if (p.answerSan != null)
                TextButton(
                  key: ValueKey('proposal-set-answer-$id'),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6)),
                  onPressed: onSetSideAndAnswer,
                  child: const Text('Set side and answer'),
                ),
            ],
          ),
      ],
    );
  }
}
