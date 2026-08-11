import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/models/analysis_models.dart';

/// Stand-in for a screen. Only its identity matters to the service.
class _FakeScreen {
  final String name;
  _FakeScreen(this.name);
  @override
  String toString() => 'Screen($name)';
}

void main() {
  group('StockfishService subscriber stack', () {
    late StockfishService service;

    setUp(() {
      // The service is a singleton, so each test starts from a clean stack.
      service = StockfishService();
      service.onEvaluationChanged = null;
      service.onMultiPVUpdated = null;
    });

    String? lastNotified;

    void Function(String, String, String, int, int, bool, String) evalCallbackFor(String tag) {
      return (evaluation, bestMove, continuation, multipv, depth, isFinal, analyzedFen) {
        lastNotified = tag;
      };
    }

    test('1. Attaching a screen makes its callback active', () {
      final screen = _FakeScreen('A');
      service.attach(screen, onEvaluation: evalCallbackFor('A'));

      expect(service.onEvaluationChanged, isNotNull);
      service.onEvaluationChanged!('0.30', 'e2e4', '', 1, 12, false, 'fen');
      expect(lastNotified, 'A');

      service.detach(screen);
    });

    test('2. Pushing a second screen takes over the engine', () {
      final a = _FakeScreen('A');
      final b = _FakeScreen('B');

      service.attach(a, onEvaluation: evalCallbackFor('A'));
      service.attach(b, onEvaluation: evalCallbackFor('B'));

      service.onEvaluationChanged!('0.30', 'e2e4', '', 1, 12, false, 'fen');
      expect(lastNotified, 'B');

      service.detach(b);
      service.detach(a);
    });

    test('3. Popping the top screen restores the one underneath', () {
      // This is the regression: the screen below used to be left with null
      // callbacks, so its engine went silently dead after returning from a
      // pushed screen.
      final a = _FakeScreen('A');
      final b = _FakeScreen('B');

      service.attach(a, onEvaluation: evalCallbackFor('A'));
      service.attach(b, onEvaluation: evalCallbackFor('B'));
      service.detach(b);

      expect(service.onEvaluationChanged, isNotNull,
          reason: 'Screen A must still be listening after B pops');

      service.onEvaluationChanged!('0.30', 'e2e4', '', 1, 12, false, 'fen');
      expect(lastNotified, 'A');

      service.detach(a);
    });

    test('4. Detaching the last screen clears the callbacks', () {
      final a = _FakeScreen('A');
      service.attach(a, onEvaluation: evalCallbackFor('A'));
      service.detach(a);

      expect(service.onEvaluationChanged, isNull);
      expect(service.onMultiPVUpdated, isNull);
    });

    test('5. Re-attaching the same screen replaces its registration', () {
      final a = _FakeScreen('A');
      service.attach(a, onEvaluation: evalCallbackFor('first'));
      service.attach(a, onEvaluation: evalCallbackFor('second'));

      service.onEvaluationChanged!('0.30', 'e2e4', '', 1, 12, false, 'fen');
      expect(lastNotified, 'second');

      // A single detach must fully remove it, proving no duplicate entry exists.
      service.detach(a);
      expect(service.onEvaluationChanged, isNull);
    });

    test('6. Detaching an unknown screen leaves the active screen alone', () {
      final a = _FakeScreen('A');
      final stranger = _FakeScreen('stranger');

      service.attach(a, onEvaluation: evalCallbackFor('A'));
      service.detach(stranger);

      expect(service.onEvaluationChanged, isNotNull);
      service.onEvaluationChanged!('0.30', 'e2e4', '', 1, 12, false, 'fen');
      expect(lastNotified, 'A');

      service.detach(a);
    });

    test('7. MultiPV callbacks follow the same stack discipline', () {
      final a = _FakeScreen('A');
      final b = _FakeScreen('B');
      String? multiPvTag;

      service.attach(a, onMultiPV: (Map<int, AnalysisLine> lines) => multiPvTag = 'A');
      service.attach(b, onMultiPV: (Map<int, AnalysisLine> lines) => multiPvTag = 'B');

      service.onMultiPVUpdated!(<int, AnalysisLine>{});
      expect(multiPvTag, 'B');

      service.detach(b);
      service.onMultiPVUpdated!(<int, AnalysisLine>{});
      expect(multiPvTag, 'A');

      service.detach(a);
    });
  });
}
