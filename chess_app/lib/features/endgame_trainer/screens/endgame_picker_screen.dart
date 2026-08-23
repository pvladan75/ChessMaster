import 'package:flutter/material.dart';

import 'package:chess_app/core/services/serbian_plural.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';

import '../models/endgame_puzzle.dart' show EndgameMode;
import '../services/endgame_api_service.dart';

/// Choosing what to practise, in the two levels a trainer thinks in.
///
/// The families come first — rook endings, pawn endings, five more — and under
/// each one the exact shapes it comes in, with how many positions stand behind
/// them. Rook endings alone come in thirteen, so a single flat list of 128 keys
/// would be a wall rather than a choice.
///
/// Everything starts ticked. A picker that opens empty makes the reader do work
/// before they can do anything at all, so pressing the button and going
/// straight on is the same as it was before this screen existed.
///
/// And the total is exact, not an estimate. The counts arrive split by rating
/// band, so every combination is added up here rather than sent to the server
/// to be answered with "nothing matches" after the fact.
class EndgamePickerScreen extends StatefulWidget {
  const EndgamePickerScreen({
    super.key,
    required this.session,
    required this.mode,
    required this.onStart,
    this.api,
  });

  final UserSession session;

  /// Converting a win and holding a draw are separate exercises, so the picker
  /// is opened for one of them and counts only that one.
  final EndgameMode mode;

  /// Called with what was chosen. The caller owns where it goes next.
  final void Function(EndgameChoice choice) onStart;

  /// Injected in tests, which have no server.
  final EndgameApiService? api;

  @override
  State<EndgamePickerScreen> createState() => _EndgamePickerScreenState();
}

class _EndgamePickerScreenState extends State<EndgamePickerScreen> {
  late final EndgameApiService _api =
      widget.api ?? EndgameApiService(authToken: widget.session.token);

  EndgameCatalog? _catalog;
  bool _loading = true;

  final Set<String> _chosen = {};
  final Set<String> _open = {};
  String? _band;
  bool _oppositeOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final catalog = await _api.fetchCatalog(mode: widget.mode);
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _loading = false;
      _chosen
        ..clear()
        ..addAll(catalog?.allMaterials ?? const <String>{});
      // The biggest family opens by itself, since it is what most sessions are
      // about and an all-collapsed list looks like it holds nothing.
      _open.clear();
      if (catalog != null && catalog.families.isNotEmpty) {
        _open.add(catalog.families.first.id);
      }
    });
  }

  void _toggleFamily(EndgameFamily family, bool select) {
    setState(() {
      for (final ending in family.endings) {
        if (select) {
          _chosen.add(ending.material);
        } else {
          _chosen.remove(ending.material);
        }
      }
    });
  }

  bool? _familyState(EndgameFamily family) {
    final on = family.endings.where((e) => _chosen.contains(e.material)).length;
    if (on == 0) return false;
    if (on == family.endings.length) return true;
    return null; // some of it, which the checkbox shows as a dash
  }

  int get _total =>
      _catalog?.countFor(
        materials: _chosen,
        bandId: _band,
        oppositeOnly: _oppositeOnly,
      ) ??
      0;

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == EndgameMode.draw
        ? 'Šta vežbamo — održati remi'
        : 'Šta vežbamo — dobitak';

    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: _buildBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final catalog = _catalog;
    if (catalog == null || catalog.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Spisak završnica trenutno nije dostupan.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _load, child: const Text('Pokušaj ponovo')),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      children: [
        _buildLevels(catalog),
        if (catalog.oppositeBishops > 0) _buildOppositeSwitch(catalog),
        const SizedBox(height: 8),
        for (final family in catalog.families) _buildFamily(family),
      ],
    );
  }

  Widget _buildLevels(EndgameCatalog catalog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nivo', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Svi nivoi'),
              selected: _band == null,
              onSelected: (_) => setState(() => _band = null),
            ),
            for (final band in catalog.bands)
              ChoiceChip(
                label: Text(band.name),
                selected: _band == band.id,
                onSelected: (_) => setState(() => _band = band.id),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Nivo je rejting igrača koji je u toj poziciji pogrešio.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildOppositeSwitch(EndgameCatalog catalog) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _oppositeOnly,
      onChanged: (value) => setState(() => _oppositeOnly = value),
      title: const Text('Samo raznobojni lovci'),
      subtitle: Text(
        'U celoj zbirci ih je ${catalog.oppositeBishops}. '
        'Nivo se tada ne primenjuje.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildFamily(EndgameFamily family) {
    final open = _open.contains(family.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          CheckboxListTile(
            tristate: true,
            value: _familyState(family),
            onChanged: (_) =>
                _toggleFamily(family, _familyState(family) != true),
            title: Text(family.name),
            subtitle: Text('${family.count} pozicija, '
                '${family.endings.length} ${_shapeWord(family.endings.length)}'),
            secondary: IconButton(
              icon: Icon(open ? Icons.expand_less : Icons.expand_more),
              tooltip: open ? 'Sakrij' : 'Prikaži vrste',
              onPressed: () => setState(
                  () => open ? _open.remove(family.id) : _open.add(family.id)),
            ),
          ),
          if (open)
            for (final ending in family.endings)
              CheckboxListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 32, right: 16),
                value: _chosen.contains(ending.material),
                onChanged: (on) => setState(() {
                  if (on == true) {
                    _chosen.add(ending.material);
                  } else {
                    _chosen.remove(ending.material);
                  }
                }),
                title: Text(ending.label),
                subtitle: Text('${ending.material} · '
                    '${_positions(ending.countIn(_band))}'),
              ),
        ],
      ),
    );
  }

  /// One vrsta, two to four vrste, five and up vrsta.
  String _shapeWord(int n) => serbianCount(
        n,
        one: 'vrsta',
        few: 'vrste',
        many: 'vrsta',
      );

  /// One pozicija, two to four pozicije, five and up pozicija.
  String _positions(int n) => serbianCount(
        n,
        one: '$n pozicija',
        few: '$n pozicije',
        many: '$n pozicija',
      );

  Widget _buildBar() {
    final total = _total;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                total == 0
                    ? 'Nijedna pozicija ne odgovara ovom izboru'
                    : 'Izabrano: ${_positions(total)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              // Nothing to serve means nothing to start, and saying so here is
              // better than a screen that opens and reports it.
              onPressed: total == 0
                  ? null
                  : () => widget.onStart(EndgameChoice(
                        materials: Set.of(_chosen),
                        materialsParam: _catalog?.materialsParamFor(_chosen),
                        bandId: _band,
                        oppositeOnly: _oppositeOnly,
                      )),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Počni'),
            ),
          ],
        ),
      ),
    );
  }
}
