// puzzle_history_screen.dart — which puzzles this account has met.
//
// docs/PLAN-NAPREDAK-VEZBI.md §7, phase 6. The Practise cards say how many
// puzzles were solved and how many wait to be retried; this says which, one
// row each, newest first, with the board each asked about. Reached from a
// card's progress line, opened on that card's source.
//
// **The account's own list, and the same screen for everyone** (§7.5, D3:
// not every user is a trainer or a student, the puzzles are an individual's
// own work, and roles play no part in them). Nothing here asks who the user
// is; the server answers for the signed-in account.
//
// Where a puzzle stands is said in words on every row, never by a colour
// alone: the owner is colour-blind.

import 'package:flutter/material.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/features/exercises/models/exercise_task_words.dart'
    show sideToMoveWords;
import 'package:chess_app/features/library/widgets/library_list.dart'
    show LibraryList;
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import '../puzzle_history_words.dart';

/// The menu's value for „every source" — the API's absent filter.
const String _allSources = 'all';

class PuzzleHistoryScreen extends StatefulWidget {
  const PuzzleHistoryScreen({
    super.key,
    required this.session,
    this.initialSource,
    this.api,
  });

  final UserSession session;

  /// The source the list opens on — the card it was opened from. Anything
  /// that is not a source opens the whole list.
  final String? initialSource;

  /// For tests: a client with a fake server behind it.
  final PuzzleAttemptApi? api;

  @override
  State<PuzzleHistoryScreen> createState() => _PuzzleHistoryScreenState();
}

class _PuzzleHistoryScreenState extends State<PuzzleHistoryScreen> {
  late final PuzzleAttemptApi _api =
      widget.api ?? PuzzleAttemptApi(authToken: widget.session.token);

  late String _source = PuzzleSource.all.contains(widget.initialSource)
      ? widget.initialSource!
      : _allSources;

  /// One of [PuzzleState], or null for every state.
  String? _state;

  List<PuzzleListItem> _items = const [];
  String? _next;
  bool _loading = true;
  bool _loadingMore = false;
  bool _failed = false;
  PuzzleListItem? _chosen;

  /// Bumped by every new question, so an answer to an older one — a filter
  /// the reader has since changed — is dropped instead of drawn.
  int _asked = 0;

  bool get _filtered => _source != _allSources || _state != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final asked = ++_asked;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final page = await _api.list(
      source: _source == _allSources ? null : _source,
      state: _state,
    );
    if (!mounted || asked != _asked) return;
    setState(() {
      _loading = false;
      if (page == null) {
        _failed = true;
        return;
      }
      _items = page.puzzles;
      _next = page.next;
      // A chosen puzzle the new filter left out is not on the screen any more.
      final chosen = _chosen;
      if (chosen != null && !_items.any((i) => i.key == chosen.key)) {
        _chosen = null;
      }
    });
  }

  Future<void> _loadMore() async {
    final next = _next;
    if (next == null || _loadingMore) return;
    final asked = _asked;
    setState(() => _loadingMore = true);
    final page = await _api.list(
      source: _source == _allSources ? null : _source,
      state: _state,
      before: next,
    );
    if (!mounted || asked != _asked) return;
    setState(() {
      _loadingMore = false;
      if (page == null) return;
      _items = [..._items, ...page.puzzles];
      _next = page.next;
    });
    if (page == null && mounted) {
      AppFeedback.error(context, 'The next puzzles could not be loaded.');
    }
  }

  void _setState(String? state) {
    if (state == _state) return;
    _state = state;
    _load();
  }

  void _setSource(String? source) {
    if (source == null || source == _source) return;
    _source = source;
    _load();
  }

  void _tap(PuzzleListItem item, {required bool wide}) {
    if (wide) {
      setState(() => _chosen = item);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final width = MediaQuery.sizeOf(sheetContext).width;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: PuzzleHistoryPanel(
              item: item,
              boardSize: (width - AppSpacing.lg * 2).clamp(200.0, 360.0),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(title: const Text('My puzzles')),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= Breakpoints.wide;
          final list = _buildList(wide: wide);
          if (!wide) return list;
          // As the Library does it: the pane takes what is left over one
          // full column of rows, between a width a board can be read at and
          // one past which every further pixel goes to the list.
          final paneWidth =
              (constraints.maxWidth - 420 - AppSpacing.md).clamp(280.0, 420.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: list),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                key: const ValueKey('puzzle-pane'),
                width: paneWidth,
                child: _pane(paneWidth),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildList({required bool wide}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filters(),
        Expanded(child: _body(wide: wide)),
      ],
    );
  }

  Widget _filters() {
    const states = <String?>[
      null,
      PuzzleState.failed,
      PuzzleState.skipped,
      PuzzleState.solved
    ];
    String label(String? state) => switch (state) {
          PuzzleState.failed => 'Failed',
          PuzzleState.skipped => 'Skipped',
          PuzzleState.solved => 'Solved',
          _ => 'All',
        };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // One line of chips that scrolls on a phone rather than wrapping
          // into two: at 360 dp the header otherwise took three lines, a
          // third of the screen above the list (seen rendered, 1.10.2026).
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final state in states)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      key: ValueKey('puzzle-state-${state ?? 'all'}'),
                      label: Text(label(state)),
                      selected: _state == state,
                      onSelected: (_) => _setState(state),
                    ),
                  ),
              ],
            ),
          ),
          DropdownButton<String>(
            key: const ValueKey('puzzle-source-menu'),
            value: _source,
            onChanged: _setSource,
            items: [
              const DropdownMenuItem(
                  value: _allSources, child: Text('All puzzles')),
              for (final entry in puzzleSourceNames.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body({required bool wide}) {
    final colors = context.colors;
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('The list could not be loaded.',
                style: AppText.body.copyWith(color: colors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            _filtered
                ? 'No puzzles match this filter.'
                : 'No puzzles yet. The puzzles you try on the Practise tab are listed here.',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: colors.textMuted),
          ),
        ),
      );
    }
    final more = _next != null;
    return ListView.builder(
      key: const ValueKey('puzzle-list'),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.lg),
      itemCount: _items.length + (more ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      key: const ValueKey('puzzle-list-more'),
                      onPressed: _loadMore,
                      child: const Text('Show more'),
                    ),
            ),
          );
        }
        final item = _items[index];
        return _PuzzleRow(
          item: item,
          selected: wide && _chosen?.key == item.key,
          onTap: () => _tap(item, wide: wide),
        );
      },
    );
  }

  /// The chosen puzzle, or a line saying what the pane is for — a pane that
  /// is blank until the first tap is a pane that took width it could not
  /// fill (PLAN-LISTE phase 3a).
  Widget _pane(double width) {
    final chosen = _chosen;
    if (chosen == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Tap a puzzle to see it here.',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: context.colors.textMuted),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: PuzzleHistoryPanel(
        item: chosen,
        // The pane's width less its padding, capped so a wide pane does not
        // draw a board larger than the list it sits beside.
        boardSize: (width - AppSpacing.md * 2).clamp(240.0, 360.0),
      ),
    );
  }
}

/// The board a puzzle asked about is drawn from the side that had to move,
/// as the drill showed it.
bool _whiteBottom(String fen) => sideToMoveWords(fen) == 'White to move';

class _PuzzleRow extends StatelessWidget {
  const _PuzzleRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PuzzleListItem item;
  final bool selected;
  final VoidCallback onTap;

  /// The Library's measured size for a board in a `ListTile`'s leading slot:
  /// that slot is 48 high on a desktop's compact density, and a board asked
  /// for more draws its eighth rank outside itself (21.9.2026).
  static const double _board = LibraryList.thumbnailSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fen = item.fen;
    return Container(
      key: ValueKey('puzzle-row-${item.key}'),
      margin: const EdgeInsets.symmetric(vertical: 2),
      // The chosen row is outlined rather than tinted: a tint is a hue, and
      // a hue is the one thing the owner cannot rely on.
      decoration: BoxDecoration(
        borderRadius: AppRadii.roundedSm,
        border: Border.all(
          color: selected ? colors.textPrimary : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: item.available && fen != null
            ? BoardThumbnail(
                fen: fen, size: _board, isWhiteBottom: _whiteBottom(fen))
            : SizedBox(
                width: _board,
                height: _board,
                child: Icon(Icons.hide_source, color: colors.textMuted),
              ),
        title: Text(
          puzzleKindWords(item),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.bodyBold.copyWith(color: colors.textPrimary),
        ),
        subtitle: Text(
          puzzleSummaryWords(item),
          style: AppText.body.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}

/// One puzzle, larger: what it is, where it stands, its board, and what its
/// table knows of it. The pane beside the list and the sheet on a phone draw
/// this same widget, so the two cannot drift apart.
class PuzzleHistoryPanel extends StatelessWidget {
  const PuzzleHistoryPanel(
      {super.key, required this.item, required this.boardSize});

  final PuzzleListItem item;

  /// Told rather than measured: each caller knows the room it has.
  final double boardSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fen = item.fen;
    final detail = item.detail;
    final facts = <String>[
      'First met ${puzzleDateWords(item.firstAt)} · last tried ${puzzleDateWords(item.latestAt)}',
      if (detail['rating'] != null) 'Rated ${detail['rating']}',
      if (detail['white'] != null && detail['black'] != null)
        '${detail['white']} – ${detail['black']}',
      if ((detail['sourceTitle']?.toString() ?? '').isNotEmpty)
        'From ${detail['sourceTitle']}',
    ];
    // As on the row: a solved puzzle's state already names its try.
    final tries =
        item.state == PuzzleState.solved ? null : puzzleTriesWords(item);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          puzzleKindWords(item),
          textAlign: TextAlign.center,
          style: AppText.subtitle.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          tries == null
              ? puzzleStateWords(item)
              : '${puzzleStateWords(item)} · $tries',
          textAlign: TextAlign.center,
          style: AppText.bodyBold.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        if (item.available && fen != null) ...[
          Text(
            sideToMoveWords(fen),
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Centred, not stretched: a board handed a tight width wider than
          // itself draws its ranks sized from that width (PLAN-LISTE phase 6).
          Center(
            child: BoardThumbnail(
                fen: fen, size: boardSize, isWhiteBottom: _whiteBottom(fen)),
          ),
        ] else
          Text(
            'This puzzle is no longer available.',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: colors.textMuted),
          ),
        const SizedBox(height: AppSpacing.md),
        for (final fact in facts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              fact,
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: colors.textMuted),
            ),
          ),
      ],
    );
  }
}
