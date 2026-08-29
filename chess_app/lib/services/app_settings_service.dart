import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/theme/board_skins.dart';

class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService instance = AppSettingsService._internal();

  AppSettingsService._internal();

  ThemeMode _themeMode = ThemeMode.dark;

  /// How hard the engine plays **when it is the one making the move**.
  ///
  /// Three levels rather than a depth in plies, because that is the question a
  /// person actually has: "how strong an opponent do I want". The depths behind
  /// them are [kEnginePlayDepths]. Until 27.8.2026 this one number was also the
  /// depth every board analysed at, so making the opponent easier quietly made
  /// every evaluation in the app shallower — two unrelated questions answered
  /// by one slider. Analysis now asks the board it is on.
  String _enginePlayLevel = 'srednje';

  /// How long the engine may think before it has to move anyway, when the
  /// depth above has not been reached in time.
  int _defaultEngineMoveTimeSeconds = 2;

  /// Where a board's own depth/line dials start, and where they are remembered.
  ///
  /// Not the same as the play level and deliberately kept apart from it: a
  /// person who wants an easy opponent still wants to see what the engine
  /// really thinks of the position.
  int _analysisDepth = 20;
  int _analysisLines = 3;
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

  /// Whether boards are framed with file letters and rank numbers.
  ///
  /// On by default. The people this app is for are learning to read a board,
  /// and half the screens turn it around on their own — the endgame trainer
  /// orients every position toward whoever has to solve it — so "which way is
  /// this" stops being answerable from the pieces alone. It is a setting
  /// because a trainer who already reads coordinates wants the extra room the
  /// gutter takes, especially on a phone.
  bool _showBoardCoordinates = true;

  /// Which board and which pieces the reader has chosen.
  ///
  /// Stored as ids rather than as resolved skins, and **not normalised on
  /// read**: an id this build does not know falls back to `classic` when it is
  /// resolved, but the stored string is left alone. So a preference written by
  /// a newer build survives a downgrade and comes back when they upgrade
  /// again, instead of being silently overwritten with the default the older
  /// build understood.
  String _boardSkinId = BoardSkin.classic.id;
  String _pieceSkinId = PieceSkin.classic.id;

  /// Which opening database the Analysis Studio Opening Explorer panel
  /// queries: 'lichess' (real-game move popularity, needs an API token) or
  /// 'chessdb' (ChessDB.cn's shared engine analysis, no token needed).
  String _openingDbSource = 'lichess';

  ThemeMode get themeMode => _themeMode;

  /// The three levels, and what each one is worth in plies.
  static const Map<String, int> kEnginePlayDepths = {
    'lako': 18,
    'srednje': 24,
    'tesko': 30,
  };

  /// The reader-facing name of each level, in the order they are offered.
  static const Map<String, String> kEnginePlayLevelNames = {
    'lako': 'Lako',
    'srednje': 'Srednje',
    'tesko': 'Teško',
  };

  String get enginePlayLevel => _enginePlayLevel;

  /// The depth the engine plays to. Reading a level rather than a number
  /// everywhere means the three levels can be retuned in one place.
  int get enginePlayDepth => kEnginePlayDepths[_enginePlayLevel] ?? 24;

  int get defaultEngineMoveTimeSeconds => _defaultEngineMoveTimeSeconds;
  int get analysisDepth => _analysisDepth;
  int get analysisLines => _analysisLines;
  String get customEnginePath => _customEnginePath;
  double get boardSizeScale => _boardSizeScale;
  String get lichessApiToken => _lichessApiToken;
  String get openingDbSource => _openingDbSource;
  bool get endgameIncludeOnline => _endgameIncludeOnline;
  bool get showBoardCoordinates => _showBoardCoordinates;

  /// The chosen skins, resolved. Every board in the app reads these rather than
  /// the ids, so an id nothing recognises draws `classic` instead of nothing.
  BoardSkin get boardSkin => BoardSkin.byId(_boardSkinId);
  PieceSkin get pieceSkin => PieceSkin.byId(_pieceSkinId);
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

    _defaultEngineMoveTimeSeconds =
        (prefs.getInt('app_engine_movetime') ?? 2).clamp(1, 60);

    // Migration, once: the old single depth was both the opponent's strength
    // and the analysis depth. It becomes the nearest level for play, and the
    // analysis depth keeps the number the reader had actually chosen.
    final storedLevel = prefs.getString('app_engine_play_level');
    final legacyDepth = prefs.getInt('app_engine_depth');
    if (kEnginePlayDepths.containsKey(storedLevel)) {
      _enginePlayLevel = storedLevel!;
    } else if (legacyDepth != null) {
      _enginePlayLevel = _levelNearest(legacyDepth);
      await prefs.setString('app_engine_play_level', _enginePlayLevel);
    }

    _analysisDepth =
        (prefs.getInt('app_analysis_depth') ?? legacyDepth ?? 20).clamp(6, 50);
    _analysisLines = (prefs.getInt('app_analysis_lines') ??
            prefs.getInt('app_multi_pv') ??
            3)
        .clamp(1, 5);
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
    _showBoardCoordinates = prefs.getBool('app_board_coordinates') ?? true;
    _boardSkinId = prefs.getString('app_board_skin') ?? BoardSkin.classic.id;
    _pieceSkinId = prefs.getString('app_piece_skin') ?? PieceSkin.classic.id;
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

  /// Which of the three levels is closest to a depth somebody had set by hand.
  static String _levelNearest(int depth) {
    var best = 'srednje';
    var bestGap = 1 << 30;
    kEnginePlayDepths.forEach((level, plies) {
      final gap = (plies - depth).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = level;
      }
    });
    return best;
  }

  Future<void> setEnginePlayLevel(String level) async {
    if (!kEnginePlayDepths.containsKey(level)) return;
    _enginePlayLevel = level;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_engine_play_level', level);
  }

  /// Remembers what a board's dials were last set to.
  ///
  /// Saved rather than kept per screen so the next board opens where the last
  /// one was left — the dial is still the board's, but nobody has to set it
  /// again on every screen they visit.
  Future<void> setAnalysisDepth(int depth) async {
    _analysisDepth = depth.clamp(6, 50);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_analysis_depth', _analysisDepth);
  }

  Future<void> setAnalysisLines(int count) async {
    _analysisLines = count.clamp(1, 5);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_analysis_lines', _analysisLines);
  }

  Future<void> setEngineMoveTimeSeconds(int seconds) async {
    _defaultEngineMoveTimeSeconds = seconds.clamp(1, 60);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_engine_movetime', _defaultEngineMoveTimeSeconds);
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

  Future<void> setShowBoardCoordinates(bool show) async {
    _showBoardCoordinates = show;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_board_coordinates', show);
  }

  /// Ignores an id no catalogue holds, the same way [setEnginePlayLevel] does:
  /// a setter that quietly stores a value nothing can draw is the shape of bug
  /// this codebase keeps finding.
  Future<void> setBoardSkin(String id) async {
    if (!BoardSkin.all.any((s) => s.id == id)) return;
    _boardSkinId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_board_skin', id);
  }

  Future<void> setPieceSkin(String id) async {
    if (!PieceSkin.all.any((s) => s.id == id)) return;
    _pieceSkinId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_piece_skin', id);
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
