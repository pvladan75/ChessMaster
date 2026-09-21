// Inviting a whole group into a session — docs/PLAN-SESIJA.md, §5.6.
//
// A group is a way of ticking people, not a second kind of recipient: the chip
// ticks its members as they are today, and what leaves the dialog is a list of
// people. Rule 7: the client is faked and the requests are read.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/invite_students_dialog.dart';

const _students = [
  {'id': 42, 'name': 'Ana', 'status': 'accepted'},
  {'id': 43, 'name': 'Marko', 'status': 'accepted'},
  {'id': 44, 'name': 'Mila', 'status': 'accepted'},
  {'id': 45, 'name': 'Petar', 'status': 'pending'},
];

/// Tuesday: Ana, Marko, Petar (who has not accepted) and 99, who is no longer
/// a student at all. Thursday: Mila. Empty: nobody.
http.Client _server(List<String> asked) => MockClient((req) async {
      asked.add(req.url.path);
      switch (req.url.path) {
        case '/trainer/students':
          return http.Response(jsonEncode({'students': _students}), 200);
        case '/groups':
          return http.Response(
              jsonEncode({
                'groups': [
                  {'id': 1, 'name': 'Tuesday', 'members': 4},
                  {'id': 2, 'name': 'Thursday', 'members': 1},
                  {'id': 3, 'name': 'Empty', 'members': 0},
                ]
              }),
              200);
        case '/groups/1/members':
          return http.Response(
              jsonEncode({
                'members': [
                  {'id': 42, 'name': 'Ana'},
                  {'id': 43, 'name': 'Marko'},
                  {'id': 45, 'name': 'Petar'},
                  {'id': 99, 'name': 'Left last week'},
                ]
              }),
              200);
        case '/groups/2/members':
          return http.Response(
              jsonEncode({
                'members': [
                  {'id': 44, 'name': 'Mila'},
                ]
              }),
              200);
      }
      return http.Response('{}', 404);
    });

Future<({List<String> asked, List<int>? Function() result})> _open(
    WidgetTester tester,
    {Size size = const Size(800, 700)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final asked = <String>[];
  List<int>? result;
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            result = await showDialog<List<int>>(
              context: context,
              builder: (_) => InviteStudentsDialog(
                roomCode: '923337',
                groupApi: GroupApiService(client: _server(asked)),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (asked: asked, result: () => result);
}

bool _ticked(WidgetTester tester, int id) => tester
    .widget<CheckboxListTile>(find.byKey(ValueKey('invite-student-$id')))
    .value!;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'remember_me': true,
      'user_token': 'tok',
      'user_id': 1,
      'user_email': 'e',
      'user_name': 'N',
      'user_role': 'korisnik',
    });
    await SessionService.instance.init();
  });

  testWidgets('a group chip ticks its members who are my students, by name',
      (tester) async {
    final d = await _open(tester);
    await tester.tap(find.byKey(const ValueKey('invite-group-1')));
    await tester.pumpAndSettle();

    expect(_ticked(tester, 42), isTrue);
    expect(_ticked(tester, 43), isTrue);
    expect(_ticked(tester, 44), isFalse, reason: 'Mila is not in Tuesday');
    expect(find.text('Send invitations (2)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('invite-send')));
    await tester.pumpAndSettle();
    expect(d.result(), [42, 43],
        reason: 'neither the pending member nor the one who left is invited');
  });

  testWidgets('one name can be taken out of a ticked group', (tester) async {
    final d = await _open(tester);
    await tester.tap(find.byKey(const ValueKey('invite-group-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invite-student-43')));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('invite-group-1')))
            .selected,
        isFalse,
        reason: 'the chip means all of them, and that is no longer true');
    await tester.tap(find.byKey(const Key('invite-send')));
    await tester.pumpAndSettle();
    expect(d.result(), [42]);
  });

  testWidgets('a second tap unticks the group and leaves the others alone',
      (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('invite-student-44')));
    await tester.tap(find.byKey(const ValueKey('invite-group-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invite-group-1')));
    await tester.pumpAndSettle();

    expect(_ticked(tester, 42), isFalse);
    expect(_ticked(tester, 43), isFalse);
    expect(_ticked(tester, 44), isTrue);
  });

  testWidgets('two groups add up', (tester) async {
    final d = await _open(tester);
    await tester.tap(find.byKey(const ValueKey('invite-group-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invite-group-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-send')));
    await tester.pumpAndSettle();
    expect(d.result(), [42, 43, 44]);
  });

  testWidgets('members are asked for when a chip is tapped, and once',
      (tester) async {
    final d = await _open(tester);
    expect(d.asked.where((p) => p.endsWith('/members')), isEmpty);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('invite-group-1')));
      await tester.pumpAndSettle();
    }
    expect(d.asked.where((p) => p == '/groups/1/members'), hasLength(1));
  });

  testWidgets('an empty group is not offered, and nothing sends nothing',
      (tester) async {
    final d = await _open(tester);
    expect(find.byKey(const ValueKey('invite-group-3')), findsNothing);
    expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('invite-send')))
            .onPressed,
        isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(d.result(), isNull);
  });

  testWidgets('it fits a 360 dp phone', (tester) async {
    await _open(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('invite-student-42')), findsOneWidget);
  });

  testWidgets('on its side a name can still be reached and ticked',
      (tester) async {
    // Measured before the fix: the list was 9 px tall at 640 x 360, because it
    // had a share of the dialog and the header took the rest.
    final d = await _open(tester, size: const Size(640, 360));
    expect(tester.takeException(), isNull);

    final mila = find.byKey(const ValueKey('invite-student-44'));
    await tester.ensureVisible(mila);
    await tester.pumpAndSettle();
    expect(tester.getRect(mila).height, greaterThan(30));
    await tester.tap(mila);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('invite-send')));
    await tester.pumpAndSettle();
    expect(d.result(), [44]);
  });
}
