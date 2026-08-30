import 'dart:async';
import 'package:flutter/material.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/features/archive/models/endgame_audit.dart';
import 'package:chess_app/features/archive/models/endgame_mistake.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

class EndgameAuditScreen extends StatefulWidget {
  const EndgameAuditScreen({
    super.key,
    required this.session,
    required this.username,
  });

  final UserSession session;
  final String username;

  @override
  State<EndgameAuditScreen> createState() => _EndgameAuditScreenState();
}

class _EndgameAuditScreenState extends State<EndgameAuditScreen> {
  String? _auditId;
  EndgameAudit? _audit;
  List<EndgameMistake>? _mistakes;
  bool _loading = false;
  String? _errorMsg;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startAudit();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startAudit() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final id =
          await ArchiveApiService.instance.startEndgameAudit(widget.username);
      _auditId = id;
      _pollAudit();
    } catch (e) {
      if (e is EndgameAuditAlreadyRunningException) {
        if (mounted) {
          _auditId = e.auditId;
          _pollAudit();
        }
      } else {
        if (mounted) {
          setState(() {
            _loading = false;
            _errorMsg = 'Došlo je do greške prilikom pokretanja provere.';
          });
        }
      }
    }
  }

  Future<void> _pollAudit() async {
    if (_auditId == null) return;
    try {
      final audit = await ArchiveApiService.instance.getEndgameAudit(_auditId!);
      if (mounted) {
        setState(() {
          _audit = audit;
          _errorMsg = null;
        });
        if (audit.status == 'done') {
          _fetchMistakes();
        } else if (audit.status == 'failed') {
          setState(() {
            _loading = false;
            _errorMsg = 'Provera nije uspela.';
          });
        } else {
          _pollTimer = Timer(const Duration(seconds: 1), _pollAudit);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = 'Došlo je do greške prilikom provere.';
        });
      }
    }
  }

  Future<void> _fetchMistakes() async {
    try {
      final mistakes =
          await ArchiveApiService.instance.getEndgameMistakes(limit: 50);
      if (mounted) {
        setState(() {
          _mistakes = mistakes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = 'Došlo je do greške prilikom preuzimanja nalaza.';
        });
      }
    }
  }

  String _getMaterialName(String fen) {
    final pieces = fen.split(' ')[0].replaceAll(RegExp(r'[^a-zA-Z]'), '');
    final chars = pieces.toLowerCase().split('')..sort();
    final material = chars.join('');

    // Group them by material
    if (material == 'k') return 'Samo kraljevi';
    if (!material.contains('r') &&
        !material.contains('b') &&
        !material.contains('n') &&
        !material.contains('q')) {
      return 'Pešačka završnica';
    }
    if (material.contains('r') &&
        !material.contains('b') &&
        !material.contains('n') &&
        !material.contains('q')) {
      return 'Topovska završnica';
    }
    if (material.contains('b') &&
        !material.contains('r') &&
        !material.contains('n') &&
        !material.contains('q')) {
      return 'Lovačka završnica';
    }
    if (material.contains('n') &&
        !material.contains('r') &&
        !material.contains('b') &&
        !material.contains('q')) {
      return 'Skakačka završnica';
    }
    if (material.contains('q')) {
      return 'Završnica sa damama';
    }

    return 'Mešovita završnica';
  }

  Map<String, List<EndgameMistake>> _groupMistakes() {
    if (_mistakes == null) return {};
    final map = <String, List<EndgameMistake>>{};
    for (final m in _mistakes!) {
      final name = _getMaterialName(m.fenBefore);
      map.putIfAbsent(name, () => []).add(m);
    }

    // Sort inside a group by how much was thrown away (cost)
    for (final list in map.values) {
      list.sort((a, b) {
        final costA = a.wdlBefore - a.wdlAfter;
        final costB = b.wdlBefore - b.wdlAfter;
        return costB.compareTo(costA); // worst first
      });
    }

    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: const Text('Završnice iz mojih partija'),
        backgroundColor: context.colors.surface,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _audit == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMsg!,
                style: AppText.body.copyWith(color: context.colors.danger)),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _startAudit,
              child: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      );
    }

    if (_audit != null &&
        _audit!.status != 'done' &&
        _audit!.status != 'failed') {
      return Column(
        children: [
          _buildCounters(_audit!),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _audit!.subject != widget.username
                        ? 'Provera je već u toku za korisnika ${_audit!.subject}...'
                        : 'Provera je u toku...',
                    style: AppText.body
                        .copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (_audit != null) _buildCounters(_audit!),
        if (_mistakes != null) Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildCounters(EndgameAudit audit) {
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.all(AppSpacing.md),
      width: double.infinity,
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: [
          Text('partije ${audit.gamesDone}/${audit.gamesTotal}',
              style:
                  AppText.body.copyWith(color: context.colors.textSecondary)),
          Text('pozicije ${audit.positionsProbed}',
              style:
                  AppText.body.copyWith(color: context.colors.textSecondary)),
          Text('iz keša ${audit.cacheHits}',
              style:
                  AppText.body.copyWith(color: context.colors.textSecondary)),
          Text('nalaza ${audit.mistakesFound}',
              style:
                  AppText.body.copyWith(color: context.colors.textSecondary)),
          if (audit.positionsUnknown > 0)
            Text('nepoznato ${audit.positionsUnknown}',
                style: AppText.body.copyWith(color: context.colors.danger)),
        ],
      ),
    );
  }

  Widget _buildList() {
    final groups = _groupMistakes();
    if (groups.isEmpty) {
      return Center(
        child: Text(
          'Nema pronađenih grešaka.',
          style: AppText.body.copyWith(color: context.colors.textSecondary),
        ),
      );
    }

    final sortedGroups = groups.keys.toList()
      ..sort((a, b) => groups[b]!.length.compareTo(groups[a]!.length));

    final flatList = <dynamic>[];
    for (final groupName in sortedGroups) {
      flatList.add(groupName);
      flatList.addAll(groups[groupName]!);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: flatList.length,
      itemBuilder: (context, i) {
        final item = flatList[i];
        if (item is String) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              item,
              style: AppText.title.copyWith(color: context.colors.textPrimary),
            ),
          );
        } else if (item is EndgameMistake) {
          return _buildMistakeCard(item);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMistakeCard(EndgameMistake m) {
    if (m.bestUci == null) {
      return const SizedBox.shrink();
    }

    final whiteToMove = m.fenBefore.contains(' w ');
    final orientation = whiteToMove ? PlayerColor.white : PlayerColor.black;

    String costText = '';
    var costColor = context.colors.textSecondary;
    if (m.wdlBefore == 2 && m.wdlAfter <= 0) {
      costText = 'Bacio dobitak';
      costColor = context.colors.danger;
    } else if (m.wdlBefore == 0 && m.wdlAfter == -2) {
      costText = 'Bacio remi';
      costColor = context.colors.warning;
    } else if (m.wdlBefore == 2 && m.wdlAfter == 1) {
      costText = 'Ugrožen dobitak';
    } else if (m.wdlBefore == 1 && m.wdlAfter <= 0) {
      costText = 'Bacio dobitak (50 poteza)';
      costColor = context.colors.danger;
    } else if (m.wdlBefore == 0 && m.wdlAfter == -1) {
      costText = 'Bacio remi (50 poteza)';
      costColor = context.colors.warning;
    } else {
      costText = 'Slabiji rezultat';
    }

    final dateStr = m.playedAt != null
        ? m.playedAt!.toLocal().toString().split(' ')[0]
        : '';
    final gameInfo = '${m.opponent ?? "Nepoznat"}, $dateStr, ${m.result ?? ""}';

    return Card(
      color: context.colors.surfaceRaised,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BoardThumbnail(
                  fen: m.fenBefore,
                  size: 120,
                  isWhiteBottom: whiteToMove,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(Icons.trending_down, color: costColor, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(costText,
                              style:
                                  AppText.bodyBold.copyWith(color: costColor)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        gameInfo,
                        style: AppText.body
                            .copyWith(color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EndgameTrainerScreen(
                      session: widget.session,
                      fen: m.fenBefore,
                      mode:
                          m.wdlBefore > 0 ? EndgameMode.win : EndgameMode.draw,
                    ),
                  ));
                },
                child: const Text('Odigraj poziciju'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
