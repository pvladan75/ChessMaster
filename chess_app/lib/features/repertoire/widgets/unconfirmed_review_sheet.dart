import 'package:flutter/material.dart';

import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

Future<void> showUnconfirmedReviewSheet(
  BuildContext context, {
  required String color,
  required String rootFen,
  required List<String> rootPath,
  required String? gateUci,
  required String? breadth,
  required int? minRating,
  required RepertoireApiService api,
  required void Function(String fen, String rejectedUci) onJump,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _UnconfirmedReviewSheet(
      color: color,
      rootFen: rootFen,
      rootPath: rootPath,
      gateUci: gateUci,
      breadth: breadth,
      minRating: minRating,
      api: api,
      onJump: onJump,
    ),
  );
}

class _UnconfirmedReviewSheet extends StatefulWidget {
  const _UnconfirmedReviewSheet({
    required this.color,
    required this.rootFen,
    required this.rootPath,
    required this.gateUci,
    required this.breadth,
    required this.minRating,
    required this.api,
    required this.onJump,
  });

  final String color;
  final String rootFen;
  final List<String> rootPath;
  final String? gateUci;
  final String? breadth;
  final int? minRating;
  final RepertoireApiService api;
  final void Function(String fen, String rejectedUci) onJump;

  @override
  State<_UnconfirmedReviewSheet> createState() =>
      _UnconfirmedReviewSheetState();
}

class _UnconfirmedReviewSheetState extends State<_UnconfirmedReviewSheet> {
  bool _loading = true;
  List<UnconfirmedNode> _nodes = [];
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final walk = await widget.api.unconfirmedPositions(
      color: widget.color,
      rootFen: widget.rootFen,
      rootPath: widget.rootPath,
      gateUci: widget.gateUci,
      breadth: widget.breadth,
      minRating: widget.minRating,
      limit: 5,
    );
    if (!mounted) return;
    setState(() {
      if (walk != null) {
        _nodes = walk.positions.toList();
        _total = walk.total;
      }
      _loading = false;
    });
  }

  Future<void> _confirm(UnconfirmedNode node, RepertoireMove move) async {
    setState(() => _loading = true);
    final done = await widget.api.confirmNode(
      color: widget.color,
      fen: node.fen,
      uci: move.uci,
    );
    if (!mounted) return;
    if (done) {
      _nodes.remove(node);
      _total = (_total - 1).clamp(0, 999999);
      if (_nodes.isEmpty) {
        await _load();
      } else {
        setState(() => _loading = false);
      }
    } else {
      setState(() => _loading = false);
      AppFeedback.error(context, 'Nije sačuvano — server nije odgovorio.');
    }
  }

  Future<void> _skip(UnconfirmedNode node) async {
    setState(() => _loading = true);
    final done = await widget.api.skipNode(
      color: widget.color,
      fen: node.fen,
    );
    if (!mounted) return;
    if (done) {
      _nodes.remove(node);
      _total = (_total - 1).clamp(0, 999999);
      if (_nodes.isEmpty) {
        await _load();
      } else {
        setState(() => _loading = false);
      }
    } else {
      setState(() => _loading = false);
      AppFeedback.error(context, 'Nije preskočeno — server nije odgovorio.');
    }
  }

  void _playAlternative(UnconfirmedNode node, RepertoireMove move) {
    Navigator.of(context).pop();
    widget.onJump(node.fen, move.uci);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _nodes.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_nodes.isEmpty) {
      return SafeArea(
        child: SizedBox(
          height: 200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Nema više nepotvrđenih poteza.', style: AppText.bodyBold),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Zatvori'),
              ),
            ],
          ),
        ),
      );
    }

    final node = _nodes.first;
    final move = node.moves.first;
    final line =
        node.path.isNotEmpty ? node.path.join(' ') : 'Početna pozicija';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: context.colors.textPrimary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Pregled nacrta ($_total ostalo)',
                    style: AppText.title,
                  ),
                ),
                const CloseButton(),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              line,
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Predlog: ${move.san}',
              style: AppText.headline.copyWith(color: context.colors.accent),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _loading ? null : () => _confirm(node, move),
              child: const Text('Potvrdi'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: _loading ? null : () => _playAlternative(node, move),
              child: const Text('Odigraj drugi potez'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _loading ? null : () => _skip(node),
              child: const Text('Preskoči (iseci granu)'),
            ),
          ],
        ),
      ),
    );
  }
}
