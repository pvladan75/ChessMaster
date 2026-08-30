import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/widgets/import_counters.dart';
import 'package:chess_app/theme/app_theme.dart';

ArchiveRun runWith({
  required int read,
  required int stored,
  required int duplicate,
  required int skipped,
  Map<String, int> reasons = const {},
}) {
  return ArchiveRun(
    id: 1,
    source: 'pgn',
    subject: 'test_user',
    status: 'done',
    gamesRead: read,
    gamesStored: stored,
    gamesDuplicate: duplicate,
    gamesSkipped: skipped,
    skippedByReason: reasons,
    startedAt: '2026-08-30T00:00:00.000Z',
  );
}

Widget host(ArchiveRun run) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ImportCounters(run: run),
        ),
      ),
    );

void main() {
  testWidgets('the four counters are drawn and fit on 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
        host(runWith(read: 4126, stored: 4126, duplicate: 0, skipped: 0)));
    await tester.pumpAndSettle();

    expect(find.text('pročitano 4126'), findsOneWidget);
    expect(find.text('upisano 4126'), findsOneWidget);
    expect(find.text('već postojalo 0'), findsOneWidget);
    expect(find.text('preskočeno 0'), findsOneWidget);
  });

  testWidgets('a non-zero skip count is drawn with its reasons, still fitting',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(runWith(
      read: 4126,
      stored: 3826,
      duplicate: 0,
      skipped: 300,
      reasons: const {'not-standard-variant': 297, 'no-moves': 3},
    )));
    await tester.pumpAndSettle();

    expect(
      find.text('preskočeno 300: 297 nije standardni šah, 3 bez poteza'),
      findsOneWidget,
    );
  });

  test('an unknown reason key survives as itself rather than disappearing', () {
    expect(
      ImportCounters.describeSkipped(2, const {'something-new': 2}),
      'preskočeno 2: 2 something-new',
    );
  });
}
