import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService instance = AppSettingsService._internal();

  AppSettingsService._internal();

  ThemeMode _themeMode = ThemeMode.dark;
  int _defaultEngineDepth = 18;
  int _defaultEngineMoveTimeSeconds = 2;
  int _defaultMultiPV = 3;
  String _customEnginePath = '';
  double _boardSizeScale = 1.0;
  Set<String> _hiddenPanels = {};
  String _lichessApiToken = '';
  bool _manualCommentMode = false;

  /// How the user makes a move on the board: 'drag' (drag-and-drop, default)
  /// or 'tap' (tap piece, then tap destination square).
  String _moveInputMode = 'drag';

  /// How long a piece takes to slide from its origin to destination square
  /// after a move. 0 disables the animation (piece snaps instantly, as
  /// flutter_chess_board does natively).
  int _moveAnimationDurationMs = 200;

  /// Which opening database the Analysis Studio Opening Explorer panel
  /// queries: 'lichess' (real-game move popularity, needs an API token) or
  /// 'chessdb' (ChessDB.cn's shared engine analysis, no token needed).
  String _openingDbSource = 'lichess';

  ThemeMode get themeMode => _themeMode;
  int get defaultEngineDepth => _defaultEngineDepth;
  int get defaultEngineMoveTimeSeconds => _defaultEngineMoveTimeSeconds;
  int get defaultMultiPV => _defaultMultiPV;
  String get customEnginePath => _customEnginePath;
  double get boardSizeScale => _boardSizeScale;
  String get lichessApiToken => _lichessApiToken;
  String get openingDbSource => _openingDbSource;

  /// When true, moves no longer get an auto-generated tactical comment —
  /// the user picks which findings to keep (plus their own text) through
  /// the comment dialog's checklist instead.
  bool get manualCommentMode => _manualCommentMode;

  String get moveInputMode => _moveInputMode;
  int get moveAnimationDurationMs => _moveAnimationDurationMs;

  /// Panels default to visible; only explicitly hidden keys are stored, so
  /// new panels added later don't need a migration to stay visible.
  bool isPanelVisible(String key) => !_hiddenPanels.contains(key);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // The UI is dark-only today (hardcoded surfaces/white text), so the theme
    // picker was removed. Anyone who had already chosen light or system would
    // otherwise stay stuck there with no control left to escape it.
    _themeMode = ThemeMode.dark;
    if (prefs.getString('app_theme_mode') != 'dark') {
      await prefs.setString('app_theme_mode', 'dark');
    }

    _defaultEngineDepth = (prefs.getInt('app_engine_depth') ?? 18).clamp(5, 50);
    _defaultEngineMoveTimeSeconds = (prefs.getInt('app_engine_movetime') ?? 2).clamp(1, 60);
    _defaultMultiPV = (prefs.getInt('app_multi_pv') ?? 3).clamp(1, 5);
    _customEnginePath = prefs.getString('custom_engine_path') ?? '';
    _boardSizeScale = (prefs.getDouble('app_board_scale') ?? 1.0).clamp(0.6, 1.0);
    _hiddenPanels = (prefs.getStringList('app_hidden_panels') ?? []).toSet();
    _lichessApiToken = prefs.getString('lichess_api_token') ?? '';
    _manualCommentMode = prefs.getBool('app_manual_comment_mode') ?? false;
    _moveInputMode = (prefs.getString('app_move_input_mode') == 'tap') ? 'tap' : 'drag';
    _moveAnimationDurationMs = (prefs.getInt('app_move_animation_ms') ?? 200).clamp(0, 500);
    final storedSource = prefs.getString('app_opening_db_source');
    _openingDbSource = (storedSource == 'chessdb') ? 'chessdb' : 'lichess';
    notifyListeners();
  }

  /// Re-reads the engine path from prefs (call after EngineDownloadService
  /// or the manual file picker writes a new one).
  Future<void> refreshCustomEnginePath() async {
    final prefs = await SharedPreferences.getInstance();
    _customEnginePath = prefs.getString('custom_engine_path') ?? '';
    notifyListeners();
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

  Future<void> setManualCommentMode(bool enabled) async {
    _manualCommentMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_manual_comment_mode', _manualCommentMode);
  }

  Future<void> setMoveInputMode(String mode) async {
    _moveInputMode = (mode == 'tap') ? 'tap' : 'drag';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_move_input_mode', _moveInputMode);
  }

  Future<void> setMoveAnimationDurationMs(int ms) async {
    _moveAnimationDurationMs = ms.clamp(0, 500);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_move_animation_ms', _moveAnimationDurationMs);
  }

  Future<void> setOpeningDbSource(String source) async {
    _openingDbSource = (source == 'chessdb') ? 'chessdb' : 'lichess';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_opening_db_source', _openingDbSource);
  }
}
