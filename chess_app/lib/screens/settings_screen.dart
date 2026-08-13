import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/screens/login_screen.dart';
import 'package:chess_app/widgets/engine_settings_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final UserSession session;

  const SettingsScreen({super.key, required this.session});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettingsService.instance;
  final _stockfishService = StockfishService();
  late final _lichessTokenController = TextEditingController(text: _settings.lichessApiToken);

  static const List<(String, String)> _analysisPanelToggles = [
    ('Stablo poteza', 'move_tree'),
    ('Opening Explorer (baza otvaranja)', 'opening_explorer'),
    ('Tablebase (Syzygy)', 'syzygy'),
    ('Panel analize engine-a', 'engine_analysis'),
  ];

  Future<void> _openEngineSettings() async {
    await showEngineSettingsDialog(context, stockfishService: _stockfishService);
    await _settings.refreshCustomEnginePath();
  }

  Future<void> _saveLichessToken() async {
    await _settings.setLichessApiToken(_lichessTokenController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_settings.lichessApiToken.isEmpty ? 'Token uklonjen.' : 'Lichess token sačuvan.'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  void dispose() {
    _lichessTokenController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginRegisterScreen()),
      (route) => false,
    );
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          widget.session.name.isNotEmpty ? widget.session.name[0].toUpperCase() : 'K',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.session.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              widget.session.email,
                              style: TextStyle(color: Colors.grey[400], fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Korisnik',
                                style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          widget.session.isGuest ? Icons.login : Icons.logout,
                          color: widget.session.isGuest ? Colors.greenAccent : Colors.redAccent,
                        ),
                        tooltip: widget.session.isGuest ? 'Prijavi se' : 'Odjavi se',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Odjava'),
                              content: const Text('Da li ste sigurni da želite da se odjavite?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Otkaži')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
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

              const SizedBox(height: 24),
              const Text('IZGLED I TEMA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: RadioGroup<ThemeMode>(
                  groupValue: _settings.themeMode,
                  onChanged: (val) {
                    if (val != null) _settings.setThemeMode(val);
                  },
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: const Text('🌙 Tamna Tema (Dark Mode)'),
                        subtitle: const Text('Elegantne tamne nijanse za ugodniji rad noću'),
                        value: ThemeMode.dark,
                        activeColor: Colors.deepPurpleAccent,
                      ),
                      const Divider(height: 1),
                      RadioListTile<ThemeMode>(
                        title: const Text('☀️ Svetla Tema (Light Mode)'),
                        subtitle: const Text('Čist svetao izgled sa visokim kontrastom'),
                        value: ThemeMode.light,
                        activeColor: Colors.deepPurpleAccent,
                      ),
                      const Divider(height: 1),
                      RadioListTile<ThemeMode>(
                        title: const Text('🌓 Sistemska Tema'),
                        subtitle: const Text('Automatsko prilagođavanje podešavanjima vašeg uređaja'),
                        value: ThemeMode.system,
                        activeColor: Colors.deepPurpleAccent,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Text('JEZIK I REGION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: RadioGroup<String>(
                  groupValue: _settings.language,
                  onChanged: (val) {
                    if (val != null) _settings.setLanguage(val);
                  },
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('🇷🇸 Srpski'),
                        value: 'sr',
                        activeColor: Colors.tealAccent,
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        title: const Text('🇬🇧 English'),
                        value: 'en',
                        activeColor: Colors.tealAccent,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Text('STOCKFISH ENGINE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Dubina analize Stockfish engine-a (max 50):', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            'Dubina ${_settings.defaultEngineDepth}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent),
                          ),
                        ],
                      ),
                      Slider(
                        value: _settings.defaultEngineDepth.toDouble().clamp(5.0, 50.0),
                        min: 5,
                        max: 50,
                        divisions: 45,
                        label: '${_settings.defaultEngineDepth}',
                        activeColor: Colors.tealAccent,
                        onChanged: (val) {
                          _settings.setEngineDepth(val.round());
                        },
                      ),
                      Text(
                        'Veća dubina daje precizniju analizu (do max 50).',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Maksimalno vreme razmišljanja engine-a:', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            '${_settings.defaultEngineMoveTimeSeconds} s',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                          ),
                        ],
                      ),
                      Slider(
                        value: _settings.defaultEngineMoveTimeSeconds.toDouble().clamp(1.0, 60.0),
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
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Broj linija i strelica na tabli (Multi-PV):', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            '${_settings.defaultMultiPV} ${_settings.defaultMultiPV == 1 ? "linija" : "linije"}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent),
                          ),
                        ],
                      ),
                      Slider(
                        value: _settings.defaultMultiPV.toDouble().clamp(1.0, 5.0),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '${_settings.defaultMultiPV}',
                        activeColor: Colors.amberAccent,
                        onChanged: (val) {
                          _settings.setMultiPV(val.round());
                        },
                      ),
                      Text(
                        'Prikazuje od 1 do 5 najboljih alternativnih linija i strelica u poziciji.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                      if (isCustomEngineSupported) ...[
                        const Divider(height: 24),
                        const Text('Lokalni engine (.exe):', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          _settings.customEnginePath.isNotEmpty
                              ? _settings.customEnginePath
                              : 'Podrazumevani (Online / FFI paket)',
                          style: TextStyle(
                            fontSize: 11,
                            color: _settings.customEnginePath.isNotEmpty ? Colors.tealAccent : Colors.grey[400],
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
              const Text('IZGLED TABLE I PANELA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Veličina table:', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            '${(_settings.boardSizeScale * 100).round()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent),
                          ),
                        ],
                      ),
                      Slider(
                        value: _settings.boardSizeScale.clamp(0.6, 1.0),
                        min: 0.6,
                        max: 1.0,
                        divisions: 8,
                        label: '${(_settings.boardSizeScale * 100).round()}%',
                        activeColor: Colors.tealAccent,
                        onChanged: (val) {
                          _settings.setBoardSizeScale(val);
                        },
                      ),
                      Text(
                        'Smanjite tablu da biste oslobodili više prostora za panele pored nje.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                      const Divider(height: 24),
                      const Text('Paneli u Analizi (Tabla za Analizu):', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      ..._analysisPanelToggles.map((panel) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            value: _settings.isPanelVisible(panel.$2),
                            title: Text(panel.$1, style: const TextStyle(fontSize: 13)),
                            activeColor: Colors.tealAccent,
                            onChanged: (val) {
                              _settings.setPanelVisible(panel.$2, val ?? true);
                            },
                          )),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Text('LICHESS OPENING EXPLORER', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lichess sada zahteva lični API token za pristup bazi otvaranja (statistika poteza iz odigranih partija). Napravite besplatan token na lichess.org/account/oauth/token (nije potrebna nijedna dozvola/scope) i nalepite ga ovde.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _lichessTokenController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Lichess API token',
                          hintText: 'lip_...',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: _settings.lichessApiToken.isNotEmpty
                              ? const Icon(Icons.check_circle, color: Colors.tealAccent, size: 18)
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
                  'ChessMaster v2.0 • Pro Edition',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
