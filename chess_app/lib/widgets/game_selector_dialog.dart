import 'package:flutter/material.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

class GameSelectorDialog extends StatefulWidget {
  final List<PgnGameInfo> games;
  final Function(PgnGameInfo game) onGameSelected;

  const GameSelectorDialog({
    super.key,
    required this.games,
    required this.onGameSelected,
  });

  @override
  State<GameSelectorDialog> createState() => _GameSelectorDialogState();
}

class _GameSelectorDialogState extends State<GameSelectorDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  /// The `Result` header a row must carry, or null for every game.
  ///
  /// Written as the PGN writes it, so the filter is an exact match on a tag
  /// rather than a guess about who won — the collection is one account's own
  /// games today, but nothing here has to know that, and „wins" would have to.
  String? _result;

  /// Below this the five columns become two stacked lines (§3.3 of the
  /// suggestions document). 560 is what the five need before the names start
  /// being ellipsed to nothing; a 360 dp phone gives this dialog 296.
  static const double tableFrom = 560;

  /// The row heights. §2.3 asks for 36–40 dense; the stacked row carries two
  /// lines and needs more.
  static const double tableRowHeight = 38;
  static const double stackedRowHeight = 56;

  /// The two columns that hold a fixed thing rather than a name.
  static const double _dateWidth = 92;
  static const double _resultWidth = 64;

  /// One row of the table — the header and every game go through here, which
  /// is what makes a cell sit under its heading. Two copies of these widths
  /// would be two sets of widths (rule 12).
  Widget _cells({
    required Widget white,
    required Widget black,
    required Widget date,
    required Widget result,
    required Widget moves,
  }) {
    Widget cell(Widget child, {int? flex, double? width}) {
      final padded = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: child,
      );
      return width != null
          ? SizedBox(width: width, child: padded)
          : Expanded(flex: flex!, child: padded);
    }

    return Row(
      children: [
        cell(white, flex: 3),
        cell(black, flex: 3),
        cell(date, width: _dateWidth),
        cell(result, width: _resultWidth),
        cell(moves, flex: 5),
      ],
    );
  }

  /// „1/2-1/2" is how a PGN says a draw and „½-½" is how a reader does. The
  /// other two results already read the same either way.
  String _resultWords(String raw) => raw == '1/2-1/2' ? '½-½' : raw;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Whether [game] matches [needle] — the two player names and the moves,
  /// and nothing else. The rest of the header map (`Event`, `Date`,
  /// `Result`, ...) is deliberately not read: a search that walked the whole
  /// map would find a date or a result and silently reorder the list.
  bool _matches(PgnGameInfo game, String needle, String movesNeedle) {
    if ((game.headers['White'] ?? '').toLowerCase().contains(needle)) {
      return true;
    }
    if ((game.headers['Black'] ?? '').toLowerCase().contains(needle)) {
      return true;
    }
    // The moves, read through `MoveTree.sanTokens`, not the raw body. The
    // owner's games carry `{ [%clk 0:03:00] }` after every move, so
    // `1. e4 { … } 1... c5` does not contain `e4 c5` and the move half of this
    // search found nothing on real data. Both sides are read the same way, so
    // a reader who types `1. e4 c5` and one who types `e4 c5` get the same
    // answer.
    if (movesNeedle.isEmpty) return false;
    return _movesOf(game).contains(movesNeedle);
  }

  /// `e4 c5 Nf3 d6`, cached: the list is rebuilt on every keystroke and a
  /// collection of four thousand games would otherwise be re-read each time.
  final Map<PgnGameInfo, String> _moveCache = {};

  String _movesOf(PgnGameInfo game) => _moveCache.putIfAbsent(
      game, () => MoveTree.sanTokens(game.pgnBody).join(' ').toLowerCase());

  /// A preview of the PGN body that stops at a whitespace boundary instead
  /// of cutting inside a move, with runs of whitespace collapsed to one
  /// space. The ellipsis is appended only when something was actually
  /// dropped.
  String _pgnPreview(String pgnBody) {
    // Written out from the moves rather than sliced out of the file, so the
    // line reads the same whatever the exporter put between the moves. Before
    // this it showed `1. e4 { [%clk 0:03:00] } 1... c5 { [%clk 0:03:00] } 2.`
    // — two moves where eight fit.
    final moves = MoveTree.sanTokens(pgnBody);
    if (moves.isEmpty) return '';

    final line = StringBuffer();
    var shown = 0;
    for (var i = 0; i < moves.length; i++) {
      // A body that starts with Black to move numbers from 1 here too; these
      // previews are of whole games, and a number that is one out is worth
      // less than a second parser to get it right.
      final piece = i.isEven ? '${i ~/ 2 + 1}. ${moves[i]}' : moves[i];
      if (line.isNotEmpty && line.length + piece.length + 1 > 60) break;
      if (line.isNotEmpty) line.write(' ');
      line.write(piece);
      shown++;
    }
    return shown < moves.length ? '$line...' : line.toString();
  }

  /// „All" and the three results a game can end in.
  ///
  /// A result rather than „wins" and „losses", which the mockup asked for:
  /// those would need to know which side this account played, and the only
  /// way to that is guessing a name out of the headers. A result is a fact
  /// the file already states.
  Widget _filterChips() {
    const options = <String, String?>{
      'All': null,
      '1-0': '1-0',
      '½-½': '1/2-1/2',
      '0-1': '0-1',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            key: ValueKey('game-filter-${entry.value ?? 'all'}'),
            label: Text(entry.key),
            selected: _result == entry.value,
            onSelected: (_) => setState(() => _result = entry.value),
          ),
      ],
    );
  }

  Widget _headerRow() {
    final style = AppText.caption.copyWith(
      color: context.colors.textMuted,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _cells(
        white: Text('White', style: style),
        black: Text('Black', style: style),
        date: Text('Date', style: style),
        result: Text('Result', style: style),
        moves: Text('First moves', style: style),
      ),
    );
  }

  Widget _row(PgnGameInfo game, {required bool wide}) {
    final colors = context.colors;
    final white = game.headers['White'] ?? '';
    final black = game.headers['Black'] ?? '';
    final date = game.headers['Date'] ?? '';
    final result = _resultWords(game.headers['Result'] ?? '');
    final moves = _pgnPreview(game.pgnBody);

    void choose() {
      // The order phase 1 settled and a `NavigatorObserver` case watches:
      // popped first, reported after.
      Navigator.pop(context);
      widget.onGameSelected(game);
    }

    Widget text(String s, {TextStyle? style}) =>
        Text(s, style: style, overflow: TextOverflow.ellipsis, maxLines: 1);

    final body = wide
        ? _cells(
            white: text(game.headers['White'] ?? '', style: AppText.body),
            black: text(game.headers['Black'] ?? '', style: AppText.body),
            date: text(date,
                style: AppText.caption.copyWith(color: colors.textMuted)),
            result: text(result, style: AppText.caption),
            moves: text(moves,
                style: AppText.caption.copyWith(color: colors.textMuted)),
          )
        // §3.3: the same facts on two lines, because five columns in 296 px
        // would be five unreadable ones.
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: text('$white vs $black',
                            style: AppText.bodyLargeBold)),
                    const SizedBox(width: 8),
                    Text(result, style: AppText.caption),
                  ],
                ),
                text('$date · $moves',
                    style: AppText.caption.copyWith(color: colors.textMuted)),
              ],
            ),
          );

    return InkWell(onTap: choose, child: body);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final needle = query.toLowerCase();
    final games = widget.games;
    final movesNeedle = MoveTree.sanTokens(query).join(' ').toLowerCase();
    final searched = query.isEmpty
        ? games
        : games.where((g) => _matches(g, needle, movesNeedle)).toList();
    // The chip narrows what the search left, rather than replacing it: two
    // filters that each work and do not compose is the fault worth guarding.
    final filtered = _result == null
        ? searched
        : searched.where((g) => g.headers['Result'] == _result).toList();
    final total = games.length;

    // AlertDialog lays title, content and actions out under an
    // IntrinsicWidth, which takes the widest intrinsic and forces every
    // child to it — so the size is read from MediaQuery instead, the same
    // instinct BoardPreviewDialog already carries. Clamped on both
    // dimensions so a very large window does not give the dialog the width
    // of the screen.
    final mediaSize = MediaQuery.of(context).size;
    // Wider and taller than phase 1 allowed, because a table earns the room:
    // five columns need it across, and how many games are on screen at once is
    // the whole complaint this dialog exists to answer.
    final dialogWidth = (mediaSize.width - 64).clamp(280.0, 900.0);
    final dialogHeight = (mediaSize.height - 240).clamp(240.0, 720.0);
    final wide = dialogWidth >= tableFrom;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(
        query.isEmpty
            ? 'Choose a game from the collection ($total)'
            : 'Choose a game from the collection — ${filtered.length} of $total',
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by player or move',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            _filterChips(),
            const SizedBox(height: 8),
            if (wide) _headerRow(),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No game matches "$query"',
                        textAlign: TextAlign.center,
                        style: AppText.body
                            .copyWith(color: context.colors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      itemExtent: wide ? tableRowHeight : stackedRowHeight,
                      itemBuilder: (context, index) => KeyedSubtree(
                        key: ValueKey('game-row-$index'),
                        child: _row(filtered[index], wide: wide),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
