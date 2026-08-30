import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/features/archive/models/mistake_item.dart';
import 'package:chess_app/features/archive/models/mistake_recurrence.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/features/reviews/services/review_api_service.dart'
    show ReviewGrade;
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

class MistakeDrillScreen extends StatefulWidget {
  const MistakeDrillScreen({super.key});

  @override
  State<MistakeDrillScreen> createState() => _MistakeDrillScreenState();
}

class _MistakeDrillScreenState extends State<MistakeDrillScreen> {
  final ArchiveApiService _api = ArchiveApiService.instance;

  List<MistakeItem> _queue = [];
  MistakeItem? _current;
  int _completed = 0;
  bool _loading = true;

  final ChessBoardController _board = ChessBoardController();
  PlayerColor _orientation = PlayerColor.white;

  bool _revealed = false;
  bool _grading = false;
  String? _playerMoveUci;

  MistakeRecurrence? _recurrence;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.fetchMistakesDue(limit: 20);
      final recurrence = await _api.fetchMistakeRecurrence();

      final validItems = items
          .where((i) => i.bestUci != null && i.bestUci!.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _queue = validItems;
        _recurrence = recurrence;
        _completed = 0;
        _loading = false;
        _next();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppFeedback.error(context, 'Greška pri učitavanju grešaka: $e');
    }
  }

  void _next() {
    if (_queue.isEmpty) {
      _current = null;
      return;
    }
    _current = _queue.removeAt(0);
    _revealed = false;
    _playerMoveUci = null;

    _board.loadFen(_current!.fenBefore);
    _orientation = _board.game.turn == chess_lib.Color.WHITE
        ? PlayerColor.white
        : PlayerColor.black;
  }

  Future<void> _grade(ReviewGrade grade) async {
    if (_current == null) return;
    setState(() => _grading = true);
    try {
      final res = await _api.gradeMistake(_current!.id, grade.name);
      if (!mounted) return;
      if (res.ok) {
        AppFeedback.success(context, res.description ?? 'Ocena zabeležena');
        setState(() {
          _completed++;
          _next();
        });
      } else {
        AppFeedback.error(context, res.error ?? 'Greška na serveru');
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Greška: $e');
    } finally {
      if (mounted) setState(() => _grading = false);
    }
  }

  void _onMove(String fromStr, String toStr, String? promotion) {
    if (_revealed) return;

    final moveUci = '$fromStr$toStr${promotion ?? ""}';
    bool moved = false;
    try {
      if (promotion != null) {
        _board.makeMoveWithPromotion(
            from: fromStr, to: toStr, pieceToPromoteTo: promotion);
      } else {
        _board.makeMove(from: fromStr, to: toStr);
      }
      moved = true;
    } catch (_) {
      // makeMove throws or ignores invalid moves depending on flutter_chess_board version.
    }

    if (moved) {
      setState(() {
        _playerMoveUci = moveUci;
        _revealed = true;
      });
    }
  }

  void _reveal() {
    setState(() {
      _revealed = true;
    });
  }

  String _endingName(String key) {
    if (key == 'KPRkpr') return 'Topovske završnice sa pešacima';
    if (key == 'KPRkp') return 'Topovske sa prednošću pešaka';
    if (key == 'KRkr') return 'Čiste topovske završnice';
    if (key == 'KPkp') return 'Pešačke završnice';
    if (key == 'KPk') return 'Kralj i pešak protiv kralja';
    if (key == 'KQkq') return 'Damine završnice';
    if (key == 'KBNk') return 'Matiranje lovcem i skakačem';
    if (key == 'KBBk') return 'Matiranje sa dva lovca';
    if (key == 'KRk') return 'Matiranje topom';
    if (key == 'KQk') return 'Matiranje damom';
    if (key == 'KRNkrn') return 'Top i skakač';
    if (key == 'KRBkrb') return 'Top i lovac';
    return 'Specijalne završnice';
  }

  String _motifName(String key) {
    return key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(title: const Text('Moje greške'), elevation: 0),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_current == null) return _buildDone();

    return LayoutBuilder(
      builder: (context, constraints) {
        final heightBased = (constraints.maxHeight - 260).clamp(200.0, 520.0);
        final widthBased = (constraints.maxWidth - 24).clamp(180.0, 520.0);
        final boardSize = heightBased < widthBased ? heightBased : widthBased;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPrompt(),
              const SizedBox(height: 10),
              Center(
                child: BoardWithCoordinates(
                  size: boardSize,
                  orientation: _orientation,
                  builder: (size) => ChessBoardWithOverlay(
                    controller: _board,
                    boardOrientation: _orientation,
                    boardSize: size,
                    isAllowedToMove: !_revealed,
                    isDrawingMode: false,
                    drawingStartSquare: null,
                    arrows: const [],
                    engineArrows: const [],
                    onMove: _onMove,
                    onSquareTapForDrawing: (_) {},
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_revealed) _buildAnswerReveal(),
              const SizedBox(height: AppSpacing.sm),
              _revealed ? _buildGradeButtons() : _buildRevealButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrompt() {
    final item = _current!;
    final toMove = _board.game.turn == chess_lib.Color.WHITE ? 'Beli' : 'Crni';

    return Card(
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.opponent != null
                        ? 'Protiv ${item.opponent}'
                        : 'Zagonetka',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${_completed + 1}/${_completed + _queue.length + 1}',
                  style: AppText.bodyLarge
                      .copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                    '${item.playedAt.day}.${item.playedAt.month}.${item.playedAt.year}.',
                    style: TextStyle(
                        fontSize: 12.5, color: context.colors.textSecondary)),
                if (item.opening != null)
                  Text('·',
                      style: TextStyle(
                          fontSize: 12.5, color: context.colors.textSecondary)),
                if (item.opening != null)
                  Text(item.opening!,
                      style: TextStyle(
                          fontSize: 12.5, color: context.colors.textSecondary)),
                if (item.result != null)
                  Text('·',
                      style: TextStyle(
                          fontSize: 12.5, color: context.colors.textSecondary)),
                if (item.result != null)
                  Text(item.result!,
                      style: TextStyle(
                          fontSize: 12.5, color: context.colors.textSecondary)),
                if (item.subjectColor != null)
                  Text('·',
                      style: TextStyle(
                          fontSize: 12.5, color: context.colors.textSecondary)),
                if (item.subjectColor != null)
                  Text(item.subjectColor == 'w' ? 'Beli' : 'Crni',
                      style: TextStyle(
                          fontSize: 12.5, color: context.colors.textSecondary)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$toMove na potezu. Setite se boljeg poteza.',
              style:
                  TextStyle(fontSize: 12.5, color: context.colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerReveal() {
    final item = _current!;
    final isCorrect = _playerMoveUci == item.bestUci;
    final color = isCorrect ? context.colors.success : context.colors.danger;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                  color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isCorrect
                      ? 'Bravo! Odigrali ste najbolji potez.'
                      : 'Netačno. Najbolji potez je bio ${item.bestUci}, a vi ste pokušali ${_playerMoveUci ?? 'ništa'}. '
                          'U partiji ste odigrali ${item.playedUci}.',
                  style: AppText.bodyBold.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (item.kind == 'engine') ...[
            Text(
              'Gubitak: ${item.swingCp != null ? "${item.swingCp} cp" : "?"}',
              style:
                  AppText.caption.copyWith(color: context.colors.textPrimary),
            ),
            if (item.theme != null)
              Text(
                'Tema: ${item.theme}',
                style: AppText.caption
                    .copyWith(color: context.colors.textSecondary),
              ),
          ] else if (item.kind == 'tablebase') ...[
            Text(
              'Tabela: ${_wdlString(item.wdlBefore)} -> ${_wdlString(item.wdlAfter)}',
              style:
                  AppText.caption.copyWith(color: context.colors.textPrimary),
            ),
          ],
        ],
      ),
    );
  }

  String _wdlString(int? wdl) {
    if (wdl == null) return '?';
    if (wdl > 0) return 'Dobijeno';
    if (wdl < 0) return 'Izgubljeno';
    return 'Remi';
  }

  Widget _buildRevealButton() {
    return ElevatedButton.icon(
      onPressed: _reveal,
      icon: const Icon(Icons.visibility),
      label: const Text('Prikaži odgovor'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      ),
    );
  }

  Widget _buildGradeButtons() {
    final colors = {
      ReviewGrade.again: context.colors.danger,
      ReviewGrade.hard: context.colors.warning,
      ReviewGrade.good: context.colors.accent,
      ReviewGrade.easy: context.colors.success,
    };

    return Column(
      children: [
        Text(
          'Koliko ste se setili?',
          style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final grade in ReviewGrade.values)
              ElevatedButton(
                onPressed: _grading ? null : () => _grade(grade),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors[grade],
                  foregroundColor: context.colors.canvas,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: AppSpacing.md),
                ),
                child: Text(grade.label),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDone() {
    final nothingDue = _completed == 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  nothingDue ? Icons.check_circle_outline : Icons.task_alt,
                  size: 56,
                  color: context.colors.success,
                ),
                const SizedBox(height: 14),
                Text(
                  nothingDue ? 'Ništa nije na redu.' : 'Gotovo za danas.',
                  style: AppText.headline,
                ),
                const SizedBox(height: 6),
                Text(
                  nothingDue
                      ? 'Igrali ste sjajno i nemate grešaka za uvežbavanje.'
                      : 'Ponovili ste $_completed ${_completed == 1 ? 'grešku' : 'grešaka'}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Osveži'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Nazad'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_recurrence != null &&
              (_recurrence!.motifs.isNotEmpty ||
                  _recurrence!.endings.isNotEmpty)) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('Vaše česte greške',
                style:
                    AppText.title.copyWith(color: context.colors.textPrimary)),
            const SizedBox(height: AppSpacing.md),
            if (_recurrence!.motifs.isNotEmpty) ...[
              Text('Taktika (motivi)',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              ..._recurrence!.motifs.map((m) => ListTile(
                    title: Text(_motifName(m.key), style: AppText.body),
                    trailing:
                        Text('${m.count} grešaka', style: AppText.bodyBold),
                  )),
            ],
            if (_recurrence!.endings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Završnice',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              ..._recurrence!.endings.map((m) => ListTile(
                    title: Text(_endingName(m.key), style: AppText.body),
                    trailing:
                        Text('${m.count} grešaka', style: AppText.bodyBold),
                  )),
            ],
          ]
        ],
      ),
    );
  }
}
