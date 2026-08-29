import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_drill_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_new_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// The repertoires a student has started, and the door to a new one.
///
/// A repertoire here is a **name for a starting position**, not a box that
/// holds moves: the moves belong to the student and their colour, so a second
/// repertoire that reaches the same position already knows what they play
/// there. That is why the card shows one count for every repertoire of the same
/// colour — flattering it would be lying about what was built.
class RepertoireListScreen extends StatefulWidget {
  const RepertoireListScreen({super.key, this.api, this.judge});

  /// Injected in tests, which have no server.
  final RepertoireApiService? api;
  final OpeningJudgeService? judge;

  @override
  State<RepertoireListScreen> createState() => _RepertoireListScreenState();
}

class _RepertoireListScreenState extends State<RepertoireListScreen> {
  late final RepertoireApiService _api = widget.api ?? RepertoireApiService();

  List<RepertoireSummary> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _api.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  /// A screen and not a dialog, because the position is chosen by playing the
  /// moves on a board — and a board inside an AlertDialog on a 360 dp phone is
  /// a board nobody can use.
  Future<void> _create() async {
    final made = await Navigator.of(context).push<RepertoireSummary>(
      MaterialPageRoute(builder: (_) => RepertoireNewScreen(api: _api)),
    );
    if (made == null || !mounted) return;
    await _load();
    if (!mounted) return;
    _open(made);
  }

  void _open(RepertoireSummary item, {String? at}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RepertoireBuildScreen(
        name: item.name,
        color: item.color,
        rootFen: at ?? item.rootFen,
        api: widget.api,
        judge: widget.judge,
      ),
    ));
  }

  /// Practising what was built. A separate door rather than a mode inside the
  /// build screen: building spends the reader's Lichess allowance and drilling
  /// spends nothing, and two things that cost so differently should not look
  /// like one button with a switch on it.
  void _drill(RepertoireSummary item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RepertoireDrillScreen(
        name: item.name,
        color: item.color,
        api: widget.api,
        // Landing in an unprepared position is the drill working as intended,
        // so the way on is building that very position — not a dead end and
        // not a trip back through the list.
        onBuildHere: (fen) {
          Navigator.of(context).pop();
          _open(item, at: fen);
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(title: const Text('Repertoar'), elevation: 0),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Novi'),
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_outlined, size: 40),
              const SizedBox(height: AppSpacing.md),
              Text('Još nijedan repertoar.',
                  style: AppText.bodyBold, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'Napravite jedan i aplikacija će vas pitati šta biste igrali, '
                'poziciju po poziciju. Ništa se ne uči napamet — bira se, i '
                'ono što izaberete ostaje vaše.',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final item = _items[i];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
          child: ListTile(
            leading: Icon(
              item.forWhite ? Icons.circle_outlined : Icons.circle,
              color: context.colors.textSecondary,
            ),
            title: Text(item.name, style: AppText.bodyBold),
            subtitle: Text(
              '${item.forWhite ? "Beli" : "Crni"} · '
              '${item.moves} ${item.moves == 1 ? "potez" : "poteza"} u grafu',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Vežbaj',
                  icon: const Icon(Icons.fitness_center),
                  onPressed: () => _drill(item),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _open(item),
          ),
        );
      },
    );
  }
}
