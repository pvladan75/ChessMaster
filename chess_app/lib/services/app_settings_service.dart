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
  String _lichessApiToken = '';

  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  int get defaultEngineDepth => _defaultEngineDepth;
  int get defaultEngineMoveTimeSeconds => _defaultEngineMoveTimeSeconds;
  int get defaultMultiPV => _defaultMultiPV;
  String get lichessApiToken => _lichessApiToken;

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
    _lichessApiToken = prefs.getString('app_lichess_token') ?? '';
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

  Future<void> setLichessApiToken(String token) async {
    _lichessApiToken = token.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lichess_token', _lichessApiToken);
  }
}
