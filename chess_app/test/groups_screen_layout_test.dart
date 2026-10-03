// The gate of phase 8 of docs/PLAN-EKRANI.md: Student groups as the owner
// chose from `docs/skice/ekrani/compare_groups.png` — on a window the groups
// on the left and the chosen group's members on the right (pattern B, rule
// R7); „New group" in the bar and nothing floating over the list (R8, §2.1:
// the floating button covered the last group's ✎ and 🗑); on a phone the
// list, and a group opened by a tap.
//
// The app's own theme with real Roboto, as phase 1 taught.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/groups/screens/groups_screen.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';

import 'support/landscape.dart';
import 'support/render_look.dart';

const _window = Size(1536, 792);
const _phone = Size(360, 640);

/// Groups and their members, nothing sent anywhere.
class _Api extends GroupApiService {
  _Api() : super(client: MockClient((_) async => http.Response('{}', 500)));

  static const _names = {
    1: ['Ana Petrović', 'Marko Ilić', 'Jelena Marković', 'Nikola Đorđević'],
    2: ['Sara Vuković', 'Luka Pavlović'],
  };

  final List<int> asked = [];

  @override
  Future<List<StudentGroup>> list() async => [
        const StudentGroup(id: 1, name: 'Utorak 18h', members: 4),
        const StudentGroup(id: 2, name: 'Početnici', members: 2),
        for (var i = 3; i <= 9; i++)
          StudentGroup(id: i, name: 'Grupa $i', members: 0),
      ];

  @override
  Future<List<NamedPerson>> members(int groupId) async {
    asked.add(groupId);
    var id = 100 * groupId;
    return [
      for (final name in _names[groupId] ?? const <String>[])
        NamedPerson(id: id++, name: name)
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> myStudents() async => const [];
}

Future<_Api> _pump(WidgetTester tester, Size size) async {
  final api = _Api();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: robotoTheme(AppTheme.dark),
    home: GroupsScreen(key: UniqueKey(), students: const [], api: api),
  ));
  await tester.pumpAndSettle();
  return api;
}

Finder _button<T extends Widget>(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is T),
    );

Rect _rect(WidgetTester tester, Finder f) {
  expect(f, findsOneWidget);
  return tester.getRect(f);
}

void main() {
  setUpAll(loadRoboto);

  group('nothing floats over the list (R8, §2.1)', () {
    for (final size in [_window, _phone]) {
      testWidgets('at ${sizeLabel(size)}: New group is in the bar',
          (tester) async {
        await _pump(tester, size);
        expect(tester.takeException(), isNull);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(
            find.descendant(
                of: find.byType(AppBar), matching: find.text('New group')),
            findsOneWidget);
        expect(find.text('New group').hitTestable(), findsOneWidget);
      });
    }
  });

  group('on a window: the groups, and the chosen one beside them', () {
    testWidgets(
        'the first group is open beside the list, its members in columns, '
        'its actions text buttons', (tester) async {
      await _pump(tester, _window);
      final group = _rect(tester, find.text('Utorak 18h').first);
      final member = _rect(tester, find.text('Ana Petrović'));
      expect(member.left, greaterThan(group.right),
          reason: 'the members stand beside the list, not under the group');
      // Columns: the first two members on one line.
      expect(_rect(tester, find.text('Marko Ilić')).top, closeTo(member.top, 1),
          reason: 'members flow in columns on a wide pane');
      expect(_button<TextButton>('Rename'), findsOneWidget);
      expect(_button<TextButton>('Delete group'), findsOneWidget);
      expect(_button<TextButton>('Add students'), findsOneWidget);
      for (final f in [
        find.text('Ana Petrović'),
        _button<TextButton>('Add students'),
        _button<TextButton>('Delete group'),
      ]) {
        expectOnScreen(tester, _window, f);
      }
    });

    testWidgets('choosing another group shows its members in the same pane',
        (tester) async {
      final api = await _pump(tester, _window);
      await tester.tap(find.text('Početnici'));
      await tester.pumpAndSettle();
      expect(find.text('Sara Vuković'), findsOneWidget);
      expect(find.text('Ana Petrović'), findsNothing,
          reason: 'one group at a time');
      expect(api.asked.last, 2);
    });
  });

  group('on a phone: the list, and a group opened by a tap', () {
    testWidgets('the list shows no members until a group is opened',
        (tester) async {
      await _pump(tester, _phone);
      expect(find.text('Ana Petrović'), findsNothing);
      await tester.tap(find.text('Utorak 18h'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Ana Petrović'), findsOneWidget);
      expectOnScreen(tester, _phone, _button<TextButton>('Add students'));
      expect(_button<TextButton>('Delete group'), findsOneWidget);
    });
  });
}
