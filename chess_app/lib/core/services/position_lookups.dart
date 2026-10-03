import 'package:flutter/foundation.dart';

import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/services/position_info_service.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';

/// The tablebase and the opening explorer for the position on a board, in one
/// home (`docs/PLAN-MOTOR-I-PANELI.md`, D8).
///
/// A screen hands it the board with [lookUp] and says which panels are drawn
/// with [show]. A hidden panel asks nothing; a panel shown over a board asks
/// for the position already there. Each look-up has a request id, so an answer
/// for a board that has moved on is dropped.
class PositionLookups extends ChangeNotifier {
  PositionLookups({
    SyzygyTablebaseService? tablebase,
    OpeningExplorerService? explorer,
  })  : _tablebaseService = tablebase ?? SyzygyTablebaseService.instance,
        _explorerService = explorer ?? OpeningExplorerService.instance;

  final SyzygyTablebaseService _tablebaseService;
  final OpeningExplorerService _explorerService;

  bool _disposed = false;
  String? _fen;
  bool _showTablebase = false;
  bool _showExplorer = false;

  bool _tablebaseEligible = false;
  bool _tablebaseLoading = false;
  SyzygyResult? _tablebase;
  int _tablebaseRequest = 0;

  bool _explorerLoading = false;
  OpeningExplorerResult? _explorer;
  String? _explorerReason;
  int _explorerRequest = 0;

  bool get tablebaseEligible => _tablebaseEligible;
  bool get tablebaseLoading => _tablebaseLoading;
  SyzygyResult? get tablebase => _tablebase;

  bool get explorerLoading => _explorerLoading;
  OpeningExplorerResult? get explorer => _explorer;
  String? get explorerReason => _explorerReason;

  /// The tablebase's own question, for a reader that wants an answer without
  /// the panel (the position study and the comment on a move).
  Future<SyzygyResult?> Function(String fen, {bool mateDistance})
      get tablebaseLookup => _tablebaseService.lookup;

  /// The banner's text for [fen]: ECO and name from the book outside the
  /// endgame, else the phase's name.
  static String openingName(String fen) {
    final phaseInfo = PositionInfoService.analyzeFen(fen);
    final bookEntry = OpeningBookService.instance.lookupByFen(fen);
    return (!phaseInfo.isEndgame && bookEntry != null)
        ? '${bookEntry.eco} · ${bookEntry.name}'
        : phaseInfo.openingName;
  }

  /// Says which panels are drawn; null leaves a panel as it is. Showing one
  /// asks for the position already looked up, hiding one clears its answer.
  void show({bool? tablebase, bool? explorer}) {
    var changed = false;
    final fen = _fen;
    if (tablebase != null && tablebase != _showTablebase) {
      _showTablebase = tablebase;
      changed = true;
      if (tablebase) {
        if (fen != null) _askTablebase(fen);
      } else {
        _tablebaseRequest++;
        _tablebase = null;
        _tablebaseLoading = false;
      }
    }
    if (explorer != null && explorer != _showExplorer) {
      _showExplorer = explorer;
      changed = true;
      if (explorer) {
        if (fen != null) _askExplorer(fen);
      } else {
        _explorerRequest++;
        _explorer = null;
        _explorerReason = null;
        _explorerLoading = false;
      }
    }
    if (changed) _notify();
  }

  /// Asks each shown panel about [fen]; a hidden one asks nothing.
  void lookUp(String fen) {
    _fen = fen;
    _tablebaseEligible = PositionInfoService.analyzeFen(fen).isSyzygyReady;
    if (_showTablebase) _askTablebase(fen);
    if (_showExplorer) _askExplorer(fen);
    _notify();
  }

  Future<void> _askTablebase(String fen) async {
    final id = ++_tablebaseRequest;
    _tablebaseEligible = PositionInfoService.analyzeFen(fen).isSyzygyReady;
    _tablebase = null;
    if (!_tablebaseEligible) {
      _tablebaseLoading = false;
      return;
    }
    _tablebaseLoading = true;
    final result = await _tablebaseService.lookup(fen, mateDistance: true);
    if (_disposed || id != _tablebaseRequest) return;
    _tablebase = result;
    _tablebaseLoading = false;
    _notify();
  }

  Future<void> _askExplorer(String fen) async {
    final id = ++_explorerRequest;
    _explorerLoading = true;
    _explorer = null;
    _explorerReason = null;
    final lookup = await _explorerService.lookup(fen);
    if (_disposed || id != _explorerRequest) return;
    _explorerLoading = false;
    if (lookup.isAvailable) {
      _explorer = lookup.result;
    } else {
      _explorerReason = lookup.reason;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
