import 'package:flutter/material.dart';

import 'package:chess_app/features/tutorial_studio/models/tutorial_beat.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_part_map.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// The parts of a tutorial as a map — phase 3 of `docs/PLAN-MAPA-DELOVA.md`.
///
/// One row per part in film order: its number and how it opens, its name, its
/// moves on one line, and a gutter on the left where the lanes of
/// [partMapOf] are drawn — a solid edge where a part continues, a dashed one
/// where it goes back, a square for a new board and a circle for every other.
///
/// **The open part is marked by weight and shape, never by hue**: a 2 px
/// border, a filled marker with a ring round it, and the words „you are here".
/// The owner reads luminance and shape; a tinted row is a row he cannot find.
///
/// **It follows the selection.** A part opened by anything but a tap on its row
/// — a move that makes a part, a chip in Flow, a clone — is scrolled into view,
/// because a list that keeps showing the rows above the open one is how a
/// screenshot came to show none of three rows marked.
///
/// Stateful only for the scrolling; it decides nothing. A tap reports the
/// index and the screen decides what opening a part means.
class TutorialPartsMap extends StatefulWidget {
  const TutorialPartsMap({
    super.key,
    required this.draft,
    required this.onSelect,
    this.trailing,
    this.scrollable = true,
    this.rowKey,
  });

  final TutorialDraft draft;
  final void Function(int index) onSelect;

  /// Something at the end of a row — the desktop's and the phone's „Turn this
  /// part". Null draws nothing.
  final Widget? Function(int index)? trailing;

  /// True: the rows scroll inside the map, built as they come on screen.
  /// False: every row is built and the map is as tall as they are, for a
  /// screen that scrolls as a whole — the phone's Parts tab.
  final bool scrollable;

  /// The key of row [index]; `part-row-<index>` when not given.
  final Key Function(int index)? rowKey;

  /// Every row is this tall, so the gutter of one row meets the next without a
  /// gap and a lazily built list still draws every edge that crosses it.
  static const double rowHeight = 68;

  /// The gutter's width for [lanes] lanes — 44 px holds three.
  static double gutterWidth(int lanes) =>
      (_laneX(lanes - 1) + _lanePad).clamp(44.0, double.infinity);

  static const double _lanePad = 12;
  static const double _laneGap = 14;
  static double _laneX(int lane) => _lanePad + _laneGap * lane;

  @override
  State<TutorialPartsMap> createState() => _TutorialPartsMapState();
}

class _TutorialPartsMapState extends State<TutorialPartsMap> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _openRow = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealOpenPart();
  }

  @override
  void didUpdateWidget(TutorialPartsMap old) {
    super.didUpdateWidget(old);
    // Only when the open part changed, or the list round it did: a rebuild for
    // a letter typed must not pull back a list the trainer scrolled.
    if (widget.draft.selected != _seenSelected ||
        widget.draft.sections.length != _seenCount) {
      _revealOpenPart();
    }
  }

  int _seenSelected = -1;
  int _seenCount = -1;

  void _revealOpenPart() {
    _seenSelected = widget.draft.selected;
    _seenCount = widget.draft.sections.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.scrollable) {
        if (!_scroll.hasClients) return;
        final position = _scroll.position;
        final top = widget.draft.selected * TutorialPartsMap.rowHeight;
        final bottom = top + TutorialPartsMap.rowHeight;
        final view = position.viewportDimension;
        if (top < position.pixels) {
          _scroll.jumpTo(top);
        } else if (bottom > position.pixels + view) {
          _scroll.jumpTo(
              (bottom - view).clamp(0.0, position.maxScrollExtent).toDouble());
        }
      } else {
        // The screen scrolls as a whole: ask it for the least scrolling that
        // shows the row, whichever side it is on.
        _openRow.currentContext?.findRenderObject()?.showOnScreen();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final map = partMapOf(widget.draft);
    final gutter = TutorialPartsMap.gutterWidth(map.laneCount);

    Widget row(int i) {
      final open = i == widget.draft.selected;
      return _PartRow(
        key: open ? _openRow : null,
        rowKey: widget.rowKey?.call(i) ?? Key('part-row-$i'),
        index: i,
        entry: map.entries[i],
        name: widget.draft.sections[i].label(i),
        gutter: map.gutterOf(i, open: open),
        gutterWidth: gutter,
        open: open,
        trailing: widget.trailing?.call(i),
        onTap: () => widget.onSelect(i),
      );
    }

    if (!widget.scrollable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.draft.sections.length; i++) row(i),
        ],
      );
    }
    return ListView.builder(
      controller: _scroll,
      shrinkWrap: true,
      itemExtent: TutorialPartsMap.rowHeight,
      itemCount: widget.draft.sections.length,
      itemBuilder: (context, i) => row(i),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({
    super.key,
    required this.rowKey,
    required this.index,
    required this.entry,
    required this.name,
    required this.gutter,
    required this.gutterWidth,
    required this.open,
    required this.trailing,
    required this.onTap,
  });

  final Key rowKey;
  final int index;
  final PartMapEntry entry;
  final String name;
  final PartGutter gutter;
  final double gutterWidth;
  final bool open;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final kind = open ? '${entry.rowText} · you are here' : entry.rowText;
    return SizedBox(
      height: TutorialPartsMap.rowHeight,
      child: InkWell(
        key: rowKey,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomPaint(
              key: Key('part-gutter-$index'),
              size: Size(gutterWidth, TutorialPartsMap.rowHeight),
              painter: PartGutterPainter(
                gutter: gutter,
                laneX: TutorialPartsMap._laneX,
                line: colors.textSecondary,
                marker: open ? colors.textPrimary : colors.textSecondary,
                fill: colors.surface,
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.roundedSm,
                  border: open
                      ? Border.all(color: colors.textPrimary, width: 2)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      kind,
                      key: Key('part-kind-$index'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppText.caption.copyWith(color: colors.textSecondary),
                    ),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: (open ? AppText.bodyBold : AppText.body)
                          .copyWith(color: colors.textPrimary),
                    ),
                    Text(
                      entry.moves.isEmpty ? 'a position' : entry.moves,
                      key: Key('part-moves-$index'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppText.caption.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            if (trailing != null) Center(child: trailing),
          ],
        ),
      ),
    );
  }
}

/// One row's slice of the gutter, drawn from [gutter] and nothing else.
class PartGutterPainter extends CustomPainter {
  PartGutterPainter({
    required this.gutter,
    required this.laneX,
    required this.line,
    required this.marker,
    required this.fill,
  });

  final PartGutter gutter;
  final double Function(int lane) laneX;
  final Color line;
  final Color marker;
  final Color fill;

  static const double _markerSize = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final stroke = Paint()
      ..color = line
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final run in gutter.through) {
      _vertical(canvas, stroke, laneX(run.lane), 0, size.height, run.dashed);
    }
    for (final run in gutter.arriving) {
      _vertical(canvas, stroke, laneX(run.lane), 0, mid, run.dashed);
    }
    final from = laneX(gutter.markerLane);
    for (final run in gutter.leaving) {
      final x = laneX(run.lane);
      if (x != from) _horizontal(canvas, stroke, from, x, mid, run.dashed);
      _vertical(canvas, stroke, x, mid, size.height, run.dashed);
    }

    final centre = Offset(from, mid);
    final shape = gutter.square
        ? Rect.fromCenter(
            center: centre, width: _markerSize, height: _markerSize)
        : null;
    final body = Paint()
      ..color = gutter.open ? marker : fill
      ..style = PaintingStyle.fill;
    final edge = Paint()
      ..color = marker
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    if (shape != null) {
      canvas
        ..drawRect(shape, body)
        ..drawRect(shape, edge);
    } else {
      canvas
        ..drawCircle(centre, _markerSize / 2, body)
        ..drawCircle(centre, _markerSize / 2, edge);
    }
    // **Which way an edge goes**, the owner's question of 26.9.2026: a line
    // that enters a part ends in an arrowhead pointing into its marker, so a
    // marker with a line above and a line below says which one it came by.
    // A path, and the only path this painter draws.
    final head = Paint()
      ..color = line
      ..style = PaintingStyle.fill;
    for (final run in gutter.arriving) {
      final x = laneX(run.lane);
      final tip = mid - _markerSize / 2 - (gutter.open ? 4 : 1);
      canvas.drawPath(
        Path()
          ..moveTo(x, tip)
          ..lineTo(x - 4, tip - 6)
          ..lineTo(x + 4, tip - 6)
          ..close(),
        head,
      );
    }
    if (gutter.open) {
      final ring = Paint()
        ..color = marker
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      if (shape != null) {
        canvas.drawRect(shape.inflate(3), ring);
      } else {
        canvas.drawCircle(centre, _markerSize / 2 + 3, ring);
      }
    }
  }

  void _vertical(
      Canvas canvas, Paint paint, double x, double y0, double y1, bool dash) {
    if (!dash) {
      canvas.drawLine(Offset(x, y0), Offset(x, y1), paint);
      return;
    }
    for (var y = y0; y < y1; y += 7) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + 4).clamp(y0, y1)), paint);
    }
  }

  void _horizontal(
      Canvas canvas, Paint paint, double x0, double x1, double y, bool dash) {
    final lo = x0 < x1 ? x0 : x1;
    final hi = x0 < x1 ? x1 : x0;
    if (!dash) {
      canvas.drawLine(Offset(lo, y), Offset(hi, y), paint);
      return;
    }
    for (var x = lo; x < hi; x += 7) {
      canvas.drawLine(Offset(x, y), Offset((x + 4).clamp(lo, hi), y), paint);
    }
  }

  @override
  bool shouldRepaint(PartGutterPainter old) =>
      old.gutter != gutter || old.line != line || old.marker != marker;
}

/// „Part 3 of 8 · continues from part 2" — the open part's own line, above
/// its Flow. The part it hangs from is a link that opens it.
class TutorialPartHeader extends StatelessWidget {
  const TutorialPartHeader({
    super.key,
    required this.draft,
    required this.onOpenPart,
  });

  final TutorialDraft draft;
  final void Function(int index) onOpenPart;

  @override
  Widget build(BuildContext context) {
    final map = partMapOf(draft);
    final i = draft.selected;
    final entry = map.entries[i];
    final lead = 'Part ${i + 1} of ${draft.sections.length} · ';
    final (said, link) = switch (entry.entry) {
      PartEntry.fresh => ('new board', null),
      PartEntry.continues => ('continues from', 'part ${entry.from!.part + 1}'),
      PartEntry.returns => (
          entry.afterMove != null
              ? 'back to after ${entry.afterMove}'
              : 'back to the start of',
          entry.afterMove != null
              ? 'in part ${entry.from!.part + 1}'
              : 'part ${entry.from!.part + 1}',
        ),
    };
    final style = AppText.body.copyWith(color: context.colors.textSecondary);
    return Wrap(
      key: const Key('part-header'),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$lead$said', style: style),
        if (link != null) ...[
          const SizedBox(width: 4),
          InkWell(
            key: const Key('part-header-source'),
            onTap: () => onOpenPart(entry.from!.part),
            child: Text(
              link,
              style: style.copyWith(
                color: context.colors.textPrimary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// For the open part: the beats later parts go back to, each with the parts
/// that start there — what Flow draws as „Part 4 starts here · 18... h6".
/// Keyed by the node's id.
Map<String, List<({int part, String move})>> partsStartingIn(
    TutorialDraft draft) {
  final map = partMapOf(draft);
  final open = draft.selected;
  // The film's own walk of one part — `filmBeatsOf` walks each part this way.
  final beats = beatsOf(draft.section.root, draft.section.root);
  final out = <String, List<({int part, String move})>>{};
  for (final e in map.entries) {
    if (e.entry != PartEntry.returns || e.from!.part != open) continue;
    if (e.from!.beat >= beats.length) continue;
    final node = beats[e.from!.beat].node;
    final first = e.moves.split(' ');
    // „18... h6" is two tokens and „19. Rxe5" too; a part that is only a
    // position has no move to name.
    final move = e.moves.isEmpty ? '' : first.take(2).join(' ');
    (out[node.id] ??= []).add((part: e.part, move: move));
  }
  return out;
}
