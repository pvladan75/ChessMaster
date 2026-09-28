/// Studies of real positions, made by the app's own builder on the real
/// engine and worded by the real model — phase 0 of
/// `docs/PLAN-STUDIJA-POZICIJE.md`, the measurement its owner reads.
///
///     set STUDY_ENV=<the backend's .env, for the model's key>
///     set STUDY_ONLY=owner1,owner2          (default: every position)
///     set STUDY_DEPTH=20                    (default 20)
///     set STUDY_WORDS=0                     (default 1: ask the model)
///     set STUDY_OUT=<a folder>              (default build/position_study)
///     set STUDY_RECORD=1                    (default 0: keep the engine's and
///                                            the tablebase's answers, for a
///                                            test to build the study from)
///     flutter test tool/position_study.dart
///
/// For every position of `tools/position_study/positions.json`: the facts
/// (`PositionStudyBuilder`), the request (`studyWordsRequest`), the words
/// (`tools/position_study/words.js`, which runs the server's own prompt and
/// shape check), the verdict (`judgeStudyWords`), the tree (`writeStudy`) and
/// its PGN — and one report that sets every slot's facts beside the words the
/// model made of them.
///
/// A test rather than a script for the reason `review_game.dart` gives, and in
/// `tool/` so the suite's count is untouched.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_facts.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_tree.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_words.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart'
    show SyzygyResult;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/uci_engine.dart';

const _guesses = [
  r'%APPDATA%\rs.pejovic\Mislisha\engine\stockfish.exe',
  r'%APPDATA%\com.example\chess_app\engine\stockfish.exe',
];

void main() {
  final env = Platform.environment;
  final depth = int.tryParse(env['STUDY_DEPTH'] ?? '') ?? 20;
  final outDir = env['STUDY_OUT'] ?? 'build/position_study';
  final askModel = (env['STUDY_WORDS'] ?? '1') != '0';
  final record = (env['STUDY_RECORD'] ?? '0') == '1';
  final only = (env['STUDY_ONLY'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  final root = _toolsDir();
  final positions =
      (jsonDecode(File('$root/positions.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>()
          .where((p) => only.isEmpty || only.contains(p['id']))
          .toList();

  test('studies ${positions.length} positions at depth $depth', () async {
    Directory(outDir).createSync(recursive: true);
    final engine = await UciEngine.start(_findEngine());
    final client = http.Client();
    final report = StringBuffer()
      ..writeln('# Position studies, depth $depth')
      ..writeln();
    try {
      for (final p in positions) {
        final id = p['id'] as String;
        final fen = p['fen'] as String;
        stdout.writeln('== $id  $fen');
        final watch = Stopwatch()..start();
        final searches = <Map<String, dynamic>>[];
        final tables = <Map<String, dynamic>>[];
        final PositionStudy study;
        try {
          study = await PositionStudyBuilder(
            analyzer: (f,
                {required depth,
                required multiPV,
                timeout = const Duration(minutes: 3)}) async {
              final lines = await engine.analyze(f,
                  depth: depth, multiPV: multiPV, timeout: timeout);
              searches.add({
                'fen': f,
                'multiPV': multiPV,
                'lines': [
                  for (final l in lines)
                    {
                      'multipv': l.multipv,
                      'depth': l.depth,
                      'evaluation': l.evaluation,
                      'pv': l.continuationLan,
                    },
                ],
              });
              return lines;
            },
            depth: depth,
            tablebase: (f) async {
              final raw = await _lichessRaw(client, f);
              tables.add({'fen': f, 'answer': raw});
              return raw == null ? null : SyzygyResult.fromJson(f, raw);
            },
            timeout: const Duration(minutes: 3),
          ).build(fen, onProgress: (n, of, what) {
            stdout.writeln('   ${n + 1}/$of  $what');
          });
        } on StudyRefused catch (e) {
          report.writeln('## $id — refused: ${e.reason}\n');
          continue;
        }
        final engineSeconds = watch.elapsedMilliseconds / 1000.0;
        if (record) {
          File('$outDir/${id}_engine.json')
              .writeAsStringSync(const JsonEncoder.withIndent(' ').convert({
            'fen': fen,
            'depth': depth,
            'searches': searches,
            'tablebase': tables,
          }));
        }
        final request = studyWordsRequest(study);
        final requestFile = File('$outDir/${id}_request.json')
          ..writeAsStringSync(
              const JsonEncoder.withIndent(' ').convert(request.toJson()));

        var slots = <String, String>{};
        Map<String, dynamic>? answer;
        if (askModel) {
          final answerFile = File('$outDir/${id}_answer.json');
          final run = await Process.run(
            'node',
            ['$root/words.js', requestFile.path, answerFile.path],
            environment: env,
          );
          if (answerFile.existsSync()) {
            answer = jsonDecode(answerFile.readAsStringSync())
                as Map<String, dynamic>;
            slots = ((answer['slots'] as Map?) ?? const {})
                .map((k, v) => MapEntry('$k', '$v'));
          }
          if (run.exitCode != 0) {
            stdout.writeln('   words.js exited ${run.exitCode}: '
                '${run.stderr.toString().trim()}');
          }
        }
        final verdict = judgeStudyWords(request, slots);

        final node = AnalysisNode(fen: fen);
        final written = writeStudy(node, study, words: verdict.kept);
        final pgn = PgnExporterService.exportToPgn(node, customHeaders: {
          'Event': 'Position study $id',
          'White': '?',
          'Black': '?',
        });
        File('$outDir/$id.pgn').writeAsStringSync(pgn);

        report.write(_report(
          p,
          study,
          request,
          slots,
          verdict,
          written,
          pgn,
          engineSeconds: engineSeconds,
          answer: answer,
        ));
        stdout.writeln('   ${study.searches} searches, '
            '${engineSeconds.toStringAsFixed(1)} s; '
            '${verdict.kept.length} of ${request.slots.length} slots kept, '
            '${verdict.refused.length} refusals');
      }
    } finally {
      engine.close();
      client.close();
    }
    File('$outDir/report.md').writeAsStringSync(report.toString());
    stdout.writeln('written: $outDir/report.md');
  }, timeout: const Timeout(Duration(hours: 3)));
}

String _report(
  Map<String, dynamic> p,
  PositionStudy study,
  StudyWordsRequest request,
  Map<String, String> slots,
  StudyWordsVerdict verdict,
  StudyWritten written,
  String pgn, {
  required double engineSeconds,
  required Map<String, dynamic>? answer,
}) {
  final b = StringBuffer()
    ..writeln('## ${p['id']} — ${p['what']}')
    ..writeln()
    ..writeln('`${study.fen}`')
    ..writeln()
    ..writeln('- searches: ${study.searches}, engine '
        '${engineSeconds.toStringAsFixed(1)} s');
  if (answer != null) {
    final attempts = (answer['attempts'] as List).cast<Map<String, dynamic>>();
    final tokens = attempts.fold<int>(
        0, (n, a) => n + ((a['tokens']?['total'] ?? 0) as int));
    b.writeln('- model: ${attempts.length} attempt(s), $tokens tokens, '
        '${(answer['seconds'] as num).toStringAsFixed(1)} s');
  }
  b.writeln('- slots: ${request.slots.length} offered, ${slots.length} '
      'written, ${verdict.kept.length} kept');
  b.writeln('- tree: ${written.moves} moves, ${written.sentences} sentences');
  for (final problem in study.problems) {
    b.writeln('- **search lost**: $problem');
  }
  for (final refusal in verdict.refused) {
    b.writeln('- **refused**: $refusal');
  }
  b.writeln();
  for (final item in request.items) {
    b.writeln('### ${item.id} — ${item.kind.name}: ${item.label}');
    b.writeln();
    for (final slot in item.slots) {
      final said = slots[slot.id];
      final kept = verdict.kept.containsKey(slot.id);
      b
        ..writeln('**`${slot.id}`** facts: ${slot.text}')
        ..writeln()
        ..writeln(said == null
            ? '> *(left out by the model)*'
            : '> ${kept ? '' : '~~'}$said${kept ? '' : '~~ *(refused)*'}')
        ..writeln();
    }
  }
  b
    ..writeln('```pgn')
    ..writeln(pgn.trim())
    ..writeln('```')
    ..writeln();
  return b.toString();
}

DateTime _lastAsked = DateTime.fromMillisecondsSinceEpoch(0);

/// Lichess, asked directly and a second apart — the tool has no account and
/// so no server to ask. The answer as it came, for a fixture to keep.
Future<Map<String, dynamic>?> _lichessRaw(
    http.Client client, String fen) async {
  final wait =
      const Duration(seconds: 1) - DateTime.now().difference(_lastAsked);
  if (!wait.isNegative) await Future<void>.delayed(wait);
  _lastAsked = DateTime.now();
  try {
    final res = await client
        .get(Uri.parse('https://tablebase.lichess.ovh/standard'
            '?fen=${Uri.encodeComponent(fen)}'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

String _toolsDir() {
  for (final candidate in [
    '../tools/position_study',
    'tools/position_study',
  ]) {
    if (Directory(candidate).existsSync()) return candidate;
  }
  throw StateError('tools/position_study not found — run from chess_app/.');
}

String _findEngine() {
  final given = Platform.environment['STOCKFISH_PATH'];
  for (final candidate in [given, ..._guesses]) {
    if (candidate == null) continue;
    final path = candidate.replaceAllMapped(
        RegExp(r'%(\w+)%'), (m) => Platform.environment[m.group(1)!] ?? '');
    if (File(path).existsSync()) return path;
  }
  throw StateError('Stockfish not found. Set STOCKFISH_PATH.');
}
