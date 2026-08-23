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

  /// How long a piece takes to slide from its origin to destination square
  /// after a move. 0 disables the animation (piece snaps instantly, as
  /// flutter_chess_board does natively).
  int _moveAnimationDurationMs = 200;

  /// Spoken feedback: whether the app reads its messages out loud, how fast,
  /// and with which of the machine's voices.
  ///
  /// The language is stored as the engine named it rather than as a code the
  /// app invented, because it is handed straight back to the engine. An empty
  /// string means "whatever fits Serbian best", which is what a machine with a
  /// newly installed voice should do without anyone going into settings.
  bool _speechEnabled = false;
  double _speechRate = 0.5;
  String _speechLanguage = '';

  /// Whether the endgame trainer also serves positions and games mined from
  /// online play.
  ///
  /// Off by default, and that is the whole point of the setting. Over-the-board
  /// games and the master bases are one pool; online is a different rating
  /// scale wearing the same numbers, and difficulty in the trainer is the
  /// rating of whoever got the position wrong.
  bool _endgameIncludeOnline = false;

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
  bool get endgameIncludeOnline => _endgameIncludeOnline;
  bool get speechEnabled => _speechEnabled;
  double get speechRate => _speechRate;
  String get speechLanguage => _speechLanguage;

  /// When true, moves no longer get an auto-generated tactical comment —
  /// the user picks which findings to keep (plus their own text) through
  /// the comment dialog's checklist instead.
  bool get manualCommentMode => _manualCommentMode;

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
    _defaultEngineMoveTimeSeconds =
        (prefs.getInt('app_engine_movetime') ?? 2).clamp(1, 60);
    _defaultMultiPV = (prefs.getInt('app_multi_pv') ?? 3).clamp(1, 5);
    _customEnginePath = prefs.getString('custom_engine_path') ?? '';
    _boardSizeScale =
        (prefs.getDouble('app_board_scale') ?? 1.0).clamp(0.6, 1.0);
    _hiddenPanels = (prefs.getStringList('app_hidden_panels') ?? []).toSet();
    _lichessApiToken = prefs.getString('lichess_api_token') ?? '';
    _manualCommentMode = prefs.getBool('app_manual_comment_mode') ?? false;
    _moveAnimationDurationMs =
        (prefs.getInt('app_move_animation_ms') ?? 200).clamp(0, 500);
    _endgameIncludeOnline =
        prefs.getBool('app_endgame_include_online') ?? false;
    _speechEnabled = prefs.getBool('app_speech_enabled') ?? false;
    _speechRate = (prefs.getDouble('app_speech_rate') ?? 0.5).clamp(0.2, 1.0);
    _speechLanguage = prefs.getString('app_speech_language') ?? '';
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

  Future<void> setMoveAnimationDurationMs(int ms) async {
    _moveAnimationDurationMs = ms.clamp(0, 500);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_move_animation_ms', _moveAnimationDurationMs);
  }

  Future<void> setEndgameIncludeOnline(bool include) async {
    _endgameIncludeOnline = include;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_endgame_include_online', _endgameIncludeOnline);
  }

  Future<void> setSpeechEnabled(bool enabled) async {
    _speechEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_speech_enabled', _speechEnabled);
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.2, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('app_speech_rate', _speechRate);
  }

  Future<void> setSpeechLanguage(String language) async {
    _speechLanguage = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_speech_language', _speechLanguage);
  }

  Future<void> setOpeningDbSource(String source) async {
    _openingDbSource = (source == 'chessdb') ? 'chessdb' : 'lichess';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_opening_db_source', _openingDbSource);
  }
}
