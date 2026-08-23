import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/widgets/engine_settings_dialog.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

class SettingsScreen extends StatefulWidget {
  final UserSession session;

  const SettingsScreen({super.key, required this.session});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettingsService.instance;
  final _stockfishService = StockfishService();
  late final _lichessTokenController =
      TextEditingController(text: _settings.lichessApiToken);

  static const List<(String, String)> _analysisPanelToggles = [
    ('Stablo poteza', 'move_tree'),
    ('Taktički motivi', 'tactical_motifs'),
    ('Pozicioni faktori', 'positional_factors'),
    ('Opening Explorer (baza otvaranja)', 'opening_explorer'),
    ('Tablebase (Syzygy)', 'syzygy'),
    ('Panel analize engine-a', 'engine_analysis'),
  ];

  Future<void> _openEngineSettings() async {
    await showEngineSettingsDialog(context,
        stockfishService: _stockfishService);
    await _settings.refreshCustomEnginePath();
  }

  Future<void> _saveLichessToken() async {
    await _settings.setLichessApiToken(_lichessTokenController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_settings.lichessApiToken.isEmpty
            ? 'Token uklonjen.'
            : 'Lichess token sačuvan.'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Whoever opens this screen is usually here because of the voice, and may
    // have installed one since the app started. Asking again costs a moment
    // and saves a restart.
    SpeechService.instance.refresh();
  }

  /// Turning speech on has to reach two places: what is remembered, and what
  /// is running. Writing only the setting left the voice silent until a
  /// restart, which reads as the switch not working.
  Future<void> _setSpeechEnabled(bool enabled) async {
    await _settings.setSpeechEnabled(enabled);
    await SpeechService.instance.setEnabled(enabled);
  }

  Future<void> _setSpeechLanguage(String language) async {
    await _settings.setSpeechLanguage(language);
    await SpeechService.instance.setLanguage(language);
  }

  Future<void> _setSpeechRate(double rate) async {
    await _settings.setSpeechRate(rate);
    await SpeechService.instance.setRate(rate);
  }

  /// A sentence with a move in it, on purpose.
  ///
  /// The interesting half of reading chess aloud is the notation, so the test
  /// button has to exercise it - a plain sentence would sound right on a setup
  /// that mangles every verdict the trainer gives.
  static const _speechSample =
      'Tačno. Nakon Rd3 beli gubi remi, a Kf2 ga drži.';

  Widget _speechCard(BuildContext context) {
    final speech = SpeechService.instance;
    return AnimatedBuilder(
      animation: speech,
      builder: (context, _) {
        final languages = speech.availableLanguages;
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Izgovaraj poruke',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    'Poruke iz info panela se čitaju naglas, da pogled može da '
                    'ostane na tabli.',
                    style: AppText.caption
                        .copyWith(color: context.colors.textMuted),
                  ),
                  value: _settings.speechEnabled,
                  onChanged: _setSpeechEnabled,
                ),
                if (speech.state == SpeechState.noVoice ||
                    speech.state == SpeechState.failed) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          speech.state == SpeechState.failed
                              ? 'Ovaj uređaj nema sintezu govora, pa čitanje '
                                  'nije moguće.'
                              : 'Nema instaliranog glasa za srpski. Windows ga '
                                  'i ne nudi — instalirajte hrvatski '
                                  '(Podešavanja → Vreme i jezik → Govor → '
                                  'Dodaj glasove), koji čita srpski latinični '
                                  'tekst ispravno. Na Androidu: Podešavanja → '
                                  'Pristupačnost → Tekst u govor.',
                          style: AppText.caption
                              .copyWith(color: context.colors.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: speech.refresh,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Potraži glasove ponovo'),
                    ),
                  ),
                ],
                if (languages.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text('Jezik govora:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: speech.language,
                    hint: const Text('Izaberite glas'),
                    items: [
                      for (final language in languages)
                        DropdownMenuItem(
                          value: language,
                          child: Text(SpeechService.fitsSerbian(language)
                              ? '$language · čita srpski'
                              : language),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) _setSpeechLanguage(value);
                    },
                  ),
                  Text(
                    'Spisak je ono što uređaj stvarno ima. Glas koji ne čita '
                    'srpski sme da se izabere — pročitaće naš tekst svojom '
                    'fonetikom, što je korisno da se čuje, ali nije za rad. '
                    'Jezik same aplikacije je zasebno pitanje i čeka prevod '
                    'svih tekstova.',
                    style: AppText.caption
                        .copyWith(color: context.colors.textMuted),
                  ),
                ],
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Brzina čitanja:',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      _settings.speechRate.toStringAsFixed(2),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.colors.accent),
                    ),
                  ],
                ),
                Slider(
                  value: _settings.speechRate.clamp(0.2, 1.0),
                  min: 0.2,
                  max: 1.0,
                  divisions: 8,
                  label: _settings.speechRate.toStringAsFixed(2),
                  activeColor: context.colors.accent,
                  onChanged: _setSpeechRate,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _settings.speechEnabled
                        ? () => speech.speak(_speechSample, force: true)
                        : null,
                    icon: const Icon(Icons.volume_up, size: 16),
                    label: const Text('Probaj'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _lichessTokenController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    // Only the credentials go: prefs.clear() used to also wipe the engine path,
    // board scale, panel layout and Lichess token, which survive a sign-out.
    await SessionService.instance.signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Podešavanja Aplikacije'),
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // User Profile Header Card
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                color: Theme.of(context).cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.deepPurple,
                        child: Text(
                          widget.session.name.isNotEmpty
                              ? widget.session.name[0].toUpperCase()
                              : 'K',
                          style: AppText.display
                              .copyWith(color: context.colors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.session.name,
                              style: AppText.headline,
                            ),
                            Text(
                              widget.session.email,
                              style: AppText.bodyLarge
                                  .copyWith(color: context.colors.textMuted),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Korisnik',
                                style: AppText.captionBold
                                    .copyWith(color: context.colors.accent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          widget.session.isGuest ? Icons.login : Icons.logout,
                          color: widget.session.isGuest
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                        tooltip:
                            widget.session.isGuest ? 'Prijavi se' : 'Odjavi se',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Odjava'),
                              content: const Text(
                                  'Da li ste sigurni da želite da se odjavite?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Otkaži')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _logout();
                                  },
                                  child: const Text('Odjavi se'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // The light/system options were removed rather than left broken:
              // the UI hardcodes dark surfaces and white text in ~200 places,
              // so light mode produced white-on-pale text in several panels.
              // Restore this picker once the colors go through theme tokens.

              // A language picker for the *app* used to live here, but there
              // is no localization layer — every string is hardcoded Serbian —
              // so it silently did nothing. Re-add it together with real i18n.
              // The voice's language is a different question and is settable
              // below: it picks among the voices the machine actually has.

              const SizedBox(height: 24),
              Text('STOCKFISH ENGINE',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textMuted)),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                              'Dubina analize Stockfish engine-a (max 50):',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            'Dubina ${_settings.defaultEngineDepth}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: context.colors.accent),
                          ),
                        ],
                      ),
                      Slider(
                        value: _settings.defaultEngineDepth
                            .toDouble()
                            .clamp(5.0, 50.0),
                        min: 5,
                        max: 50,
                        divisions: 45,
                        label: '${_settings.defaultEngineDepth}',
                        activeColor: context.colors.accent,
                        onChanged: (val) {
                          _settings.setEngineDepth(val.round());
                        },
                      ),
                      Text(
                        'Veća dubina daje precizniju analizu (do max 50).',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Maksimalno vreme razmišljanja engine-a:',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            '${_settings.defaultEngineMoveTimeSeconds} s',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.cyanAccent),
                          ),
                        ],
                      ),
                      Slider(
                        value: _settings.defaultEngineMoveTimeSeconds
                            .toDouble()
                            .clamp(1.0, 60.0),
                        min: 1,
                        max: 60,
                        divisions: 59,
                        label: '${_settings.defaultEngineMoveTimeSeconds} s',
                        activeColor: Colors.cyanAccent,
                        onChanged: (val) {
                          _settings.setEngineMoveTimeSeconds(val.round());
                        },
                      ),
                      Text(
                        'Engine igra potez čim dostigne ciljanu dubinu ILI čim istekne podešeno vreme (šta se pre dostigne).',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                              'Broj linija i strelica na tabli (Multi-PV):',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            '${_settings.defaultMultiPV} ${_settings.defaultMultiPV == 1 ? "linija" : "linije"}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: context.colors.warning),
                          ),
                        ],
                      ),
                      Slider(
                        value:
                            _settings.defaultMultiPV.toDouble().clamp(1.0, 5.0),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '${_settings.defaultMultiPV}',
                        activeColor: context.colors.warning,
                        onChanged: (val) {
                          _settings.setMultiPV(val.round());
                        },
                      ),
                      Text(
                        'Prikazuje od 1 do 5 najboljih alternativnih linija i strelica u poziciji.',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                      if (isCustomEngineSupported) ...[
                        const Divider(height: 24),
                        const Text('Lokalni engine (.exe):',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          _settings.customEnginePath.isNotEmpty
                              ? _settings.customEnginePath
                              : 'Podrazumevani (Online / FFI paket)',
                          style: AppText.caption.copyWith(
                            color: _settings.customEnginePath.isNotEmpty
                                ? context.colors.accent
                                : context.colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _openEngineSettings,
                            icon: const Icon(Icons.settings_suggest, size: 16),
                            label: const Text('Podesi lokalni engine'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Text('IZGLED TABLE I PANELA',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textMuted)),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Veličina table:',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            '${(_settings.boardSizeScale * 100).round()}%',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: context.colors.accent),
                          ),
                        ],
                      ),
                      Slider(
                        value: _settings.boardSizeScale.clamp(0.6, 1.0),
                        min: 0.6,
                        max: 1.0,
                        divisions: 8,
                        label: '${(_settings.boardSizeScale * 100).round()}%',
                        activeColor: context.colors.accent,
                        onChanged: (val) {
                          _settings.setBoardSizeScale(val);
                        },
                      ),
                      Text(
                        'Smanjite tablu da biste oslobodili više prostora za panele pored nje.',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Animacija poteza:',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            _settings.moveAnimationDurationMs == 0
                                ? 'Isključeno'
                                : '${_settings.moveAnimationDurationMs} ms',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: context.colors.accent),
                          ),
                        ],
                      ),
                      Slider(
                        value: _settings.moveAnimationDurationMs.toDouble(),
                        min: 0,
                        max: 500,
                        divisions: 10,
                        label: _settings.moveAnimationDurationMs == 0
                            ? 'Isključeno'
                            : '${_settings.moveAnimationDurationMs} ms',
                        activeColor: context.colors.accent,
                        onChanged: (val) {
                          _settings.setMoveAnimationDurationMs(val.round());
                        },
                      ),
                      Text(
                        'Koliko dugo figura klizi ka odredišnom polju. Krajnje levo isključuje animaciju.',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                      const Divider(height: 24),
                      const Text('Paneli u Analizi (Tabla za Analizu):',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      ..._analysisPanelToggles.map((panel) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            value: _settings.isPanelVisible(panel.$2),
                            title: Text(panel.$1, style: AppText.bodyLarge),
                            activeColor: context.colors.accent,
                            onChanged: (val) {
                              _settings.setPanelVisible(panel.$2, val ?? true);
                            },
                          )),
                      const Divider(height: 24),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        value: _settings.manualCommentMode,
                        title: const Text(
                            'Ručno biranje komentara u stablu poteza',
                            style: AppText.bodyLarge),
                        subtitle: Text(
                          'Isključi automatski komentar — sam biraš koje nalaze da zadržiš iz ponuđene liste.',
                          style: AppText.caption
                              .copyWith(color: context.colors.textMuted),
                        ),
                        activeColor: context.colors.accent,
                        onChanged: (val) {
                          _settings.setManualCommentMode(val ?? false);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Text('GOVOR (ČITANJE PORUKA)',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textMuted)),
              const SizedBox(height: 8),
              _speechCard(context),

              const SizedBox(height: 24),
              Text('BAZA OTVARANJA (OPENING EXPLORER)',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textMuted)),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Izvor podataka:',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Lichess'),
                              selected: _settings.openingDbSource == 'lichess',
                              onSelected: (_) =>
                                  _settings.setOpeningDbSource('lichess'),
                              avatar: const Icon(Icons.bar_chart, size: 16),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('ChessDB'),
                              selected: _settings.openingDbSource == 'chessdb',
                              onSelected: (_) =>
                                  _settings.setOpeningDbSource('chessdb'),
                              avatar: const Icon(Icons.memory, size: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _settings.openingDbSource == 'lichess'
                            ? 'Lichess: popularnost poteza iz stvarno odigranih partija igrača. Zahteva besplatni API token ispod — bez njega se automatski koristi ChessDB.'
                            : 'ChessDB: procena kvaliteta poteza iz deljene baze motorske analize (chessdb.cn) — ne zahteva token, ali ne pokazuje statistiku partija.',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                      const Divider(height: 24),
                      Text(
                        'Lichess sada zahteva lični API token za pristup bazi otvaranja (statistika poteza iz odigranih partija). Napravite besplatan token na lichess.org/account/oauth/token (nije potrebna nijedna dozvola/scope) i nalepite ga ovde.',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _lichessTokenController,
                        obscureText: true,
                        style: AppText.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Lichess API token',
                          hintText: 'lip_...',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: _settings.lichessApiToken.isNotEmpty
                              ? Icon(Icons.check_circle,
                                  color: context.colors.accent, size: 18)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: _saveLichessToken,
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Sačuvaj token'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Šahovski trener v2.0 • Pro Edition',
                  style: AppText.body.copyWith(color: context.colors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
