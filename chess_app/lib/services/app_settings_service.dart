import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService instance = AppSettingsService._internal();

  AppSettingsService._internal();

  ThemeMode _themeMode = ThemeMode.dark;
  String _language = 'sr'; // 'sr' or 'en'
  int _defaultEngineDepth = 18;
  int _defaultEngineMoveTimeSeconds = 2;
  int _defaultMultiPV = 3;
  String _customEnginePath = '';
  double _boardSizeScale = 1.0;
  Set<String> _hiddenPanels = {};
  String _lichessApiToken = '';

  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  int get defaultEngineDepth => _defaultEngineDepth;
  int get defaultEngineMoveTimeSeconds => _defaultEngineMoveTimeSeconds;
  int get defaultMultiPV => _defaultMultiPV;
  String get customEnginePath => _customEnginePath;
  double get boardSizeScale => _boardSizeScale;
  String get lichessApiToken => _lichessApiToken;

  /// Panels default to visible; only explicitly hidden keys are stored, so
  /// new panels added later don't need a migration to stay visible.
  bool isPanelVisible(String key) => !_hiddenPanels.contains(key);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('app_theme_mode') ?? 'dark';
    if (themeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeStr == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.dark;
    }

    _language = prefs.getString('app_language') ?? 'sr';
    _defaultEngineDepth = (prefs.getInt('app_engine_depth') ?? 18).clamp(5, 50);
    _defaultEngineMoveTimeSeconds = (prefs.getInt('app_engine_movetime') ?? 2).clamp(1, 60);
    _defaultMultiPV = (prefs.getInt('app_multi_pv') ?? 3).clamp(1, 5);
    _customEnginePath = prefs.getString('custom_engine_path') ?? '';
    _boardSizeScale = (prefs.getDouble('app_board_scale') ?? 1.0).clamp(0.6, 1.0);
    _hiddenPanels = (prefs.getStringList('app_hidden_panels') ?? []).toSet();
    _lichessApiToken = prefs.getString('lichess_api_token') ?? '';
    notifyListeners();
  }

  /// Re-reads the engine path from prefs (call after EngineDownloadService
  /// or the manual file picker writes a new one).
  Future<void> refreshCustomEnginePath() async {
    final prefs = await SharedPreferences.getInstance();
    _customEnginePath = prefs.getString('custom_engine_path') ?? '';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String str = 'dark';
    if (mode == ThemeMode.light) str = 'light';
    if (mode == ThemeMode.system) str = 'system';
    await prefs.setString('app_theme_mode', str);
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
  }

  Future<void> setEngineDepth(int depth) async {
    _defaultEngineDepth = depth.clamp(5, 50);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_engine_depth', _defaultEngineDepth);
  }

  Future<void> setEngineMoveTimeSeconds(int seconds) async {
    _defaultEngineMoveTimeSeconds = seconds.clamp(1, 60);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_engine_movetime', _defaultEngineMoveTimeSeconds);
  }

  Future<void> setMultiPV(int count) async {
    _defaultMultiPV = count.clamp(1, 5);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_multi_pv', _defaultMultiPV);
  }

  Future<void> setBoardSizeScale(double scale) async {
    _boardSizeScale = scale.clamp(0.6, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('app_board_scale', _boardSizeScale);
  }

  Future<void> setPanelVisible(String key, bool visible) async {
    if (visible) {
      _hiddenPanels.remove(key);
    } else {
      _hiddenPanels.add(key);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('app_hidden_panels', _hiddenPanels.toList());
  }

  Future<void> setLichessApiToken(String token) async {
    _lichessApiToken = token.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lichess_api_token', _lichessApiToken);
  }
}
