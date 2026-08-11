import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/screens/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final UserSession session;

  const SettingsScreen({super.key, required this.session});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettingsService.instance;

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
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: const Text('🌙 Tamna Tema (Dark Mode)'),
                      subtitle: const Text('Elegantne tamne nijanse za ugodniji rad noću'),
                      value: ThemeMode.dark,
                      groupValue: _settings.themeMode,
                      activeColor: Colors.deepPurpleAccent,
                      onChanged: (val) {
                        if (val != null) _settings.setThemeMode(val);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      title: const Text('☀️ Svetla Tema (Light Mode)'),
                      subtitle: const Text('Čist svetao izgled sa visokim kontrastom'),
                      value: ThemeMode.light,
                      groupValue: _settings.themeMode,
                      activeColor: Colors.deepPurpleAccent,
                      onChanged: (val) {
                        if (val != null) _settings.setThemeMode(val);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<ThemeMode>(
                      title: const Text('🌓 Sistemska Tema'),
                      subtitle: const Text('Automatsko prilagođavanje podešavanjima vašeg uređaja'),
                      value: ThemeMode.system,
                      groupValue: _settings.themeMode,
                      activeColor: Colors.deepPurpleAccent,
                      onChanged: (val) {
                        if (val != null) _settings.setThemeMode(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text('JEZIK I REGION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('🇷🇸 Srpski'),
                      value: 'sr',
                      groupValue: _settings.language,
                      activeColor: Colors.tealAccent,
                      onChanged: (val) {
                        if (val != null) _settings.setLanguage(val);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      title: const Text('🇬🇧 English'),
                      value: 'en',
                      groupValue: _settings.language,
                      activeColor: Colors.tealAccent,
                      onChanged: (val) {
                        if (val != null) _settings.setLanguage(val);
                      },
                    ),
                  ],
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
