// Home's Recordings: the host deletes their own, and only their own
// (22.9.2026). The list holds the host's recordings *and* those a trainer
// shared with this reader (`recordingShares.readableRecordings`); a shared one
// is the trainer's to delete, and the server refuses anybody else anyway, so a
// button on it would be a door that only ever says no.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/trainer_panel/models/trainer_panel.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/home/dashboard_tab.dart';

const _me = 7;

final _recordings = [
  {
    'id': 1,
    'host_id': _me,
    'title': 'My Lucena',
    'created_at': '2026-09-22T10:00:00.000Z',
    'duration_ms': 90000,
  },
  {
    'id': 2,
    'host_id': 99,
    'title': 'Shared by my trainer',
    'created_at': '2026-09-21T10:00:00.000Z',
    'host_name': 'Vladan',
  },
];

Future<List<dynamic>> _home(
  WidgetTester tester, {
  bool offerDelete = true,
  Size size = const Size(1000, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final asked = <dynamic>[];
  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: Scaffold(
      body: HomeDashboardTab(
        userName: 'Ana',
        liveSessions: const [],
        recordings: _recordings,
        isLoadingRecordings: false,
        panel: TrainerPanel.empty,
        onOpenPanelAssignment: (_) {},
        onOpenStudent: (_, __) {},
        hasTrainer: true,
        onOpenAssignments: () {},
        onOpenReviews: () {},
        onJoinSession: (_) {},
        onRefreshRecordings: () {},
        onOpenReplay: (_) {},
        onDeleteRecording: offerDelete ? asked.add : null,
        currentUserId: _me,
      ),
    ),
  ));
  await tester.pump();
  return asked;
}

Finder _delete(int id) => find.descendant(
      of: find.byKey(ValueKey('home-recording-$id')),
      matching: find.byTooltip('Delete recording'),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('my own recording offers delete, and it asks about that one',
      (tester) async {
    final asked = await _home(tester);
    expect(find.byKey(const ValueKey('home-recording-1')), findsOneWidget);
    expect(_delete(1), findsOneWidget);

    await tester.tap(_delete(1));
    expect(asked, hasLength(1));
    expect((asked.single as Map)['id'], 1);
  });

  testWidgets('one a trainer shared with me offers none', (tester) async {
    await _home(tester);
    expect(find.byKey(const ValueKey('home-recording-2')), findsOneWidget,
        reason: 'the shared card is missing, so its absence proves nothing');
    expect(_delete(2), findsNothing);
  });

  testWidgets('no callback, no button anywhere', (tester) async {
    await _home(tester, offerDelete: false);
    expect(find.byTooltip('Delete recording'), findsNothing);
  });

  testWidgets('on a 360 dp phone both buttons fit beside the title',
      (tester) async {
    // A release build clips a row that does not fit; a test build throws.
    await _home(tester, size: const Size(360, 2000));
    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.byKey(const ValueKey('home-recording-1')));
    final bin = tester.getRect(_delete(1));
    expect(bin.right, lessThanOrEqualTo(card.right),
        reason: 'the delete button hangs past the card');
  });
}
