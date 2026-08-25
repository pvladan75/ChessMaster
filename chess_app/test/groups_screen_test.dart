import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/groups/screens/groups_screen.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/groups/widgets/room_guests_dialog.dart';

/// Groups, and the guest list they exist for.
///
/// The reason is a trainer's own: with forty students, inviting the same eight
/// every Tuesday means going down a list and finding them each time. What is
/// pinned here is that the convenience never becomes a right — only accepted
/// students are offered — and that the room says out loud what a guest list
/// does to it, since narrowing who can get in must never be a surprise.
class _FakeApi extends GroupApiService {
  _FakeApi({
    this.groups = const [],
    this.groupMembers = const [],
    this.guests = const [],
    this.students = const [],
    this.allowGuests = false,
    this.guestAccessFails = false,
    this.failWith,
  }) : super(client: MockClient((_) async => http.Response('{}', 500)));

  List<StudentGroup> groups;

  /// Named apart from the method it stands in for: a field called `members`
  /// clashes with `members(int)` on the service it extends.
  List<NamedPerson> groupMembers;
  List<RoomGuest> guests;
  final List<Map<String, dynamic>> students;

  /// What the room says about guests, and — separately — a room that will not
  /// answer at all, which is the state the switch must not paint as "off".
  bool? allowGuests;
  final bool guestAccessFails;
  final String? failWith;

  final List<bool> guestSwitches = [];

  String? createdName;
  final List<int> added = [];
  final List<int> removedMembers = [];
  final List<int> invitedGroups = [];
  final List<int> invitedUsers = [];
  final List<int> uninvitedGroups = [];
  int? deletedGroup;

  @override
  Future<List<StudentGroup>> list() async => groups;

  @override
  Future<List<NamedPerson>> members(int groupId) async => groupMembers;

  @override
  Future<List<Map<String, dynamic>>> myStudents() async => students;

  @override
  Future<({StudentGroup? group, String? error})> create(String name) async {
    createdName = name;
    if (failWith != null) return (group: null, error: failWith);
    final made = StudentGroup(id: 1, name: name, members: 0);
    groups = [...groups, made];
    return (group: made, error: null);
  }

  @override
  Future<String?> remove(int groupId) async {
    deletedGroup = groupId;
    groups = groups.where((g) => g.id != groupId).toList();
    return failWith;
  }

  @override
  Future<String?> addMember(int groupId, int studentId) async {
    added.add(studentId);
    return failWith;
  }

  @override
  Future<String?> removeMember(int groupId, int studentId) async {
    removedMembers.add(studentId);
    return failWith;
  }

  @override
  Future<List<RoomGuest>> roomGuests(String roomCode) async => guests;

  @override
  Future<({bool? allowGuests, String? error})> guestAccess(
      String roomCode) async {
    if (guestAccessFails) {
      return (allowGuests: null, error: 'Server nije dostupan.');
    }
    return (allowGuests: allowGuests, error: null);
  }

  @override
  Future<({bool? allowGuests, String? error})> setGuestAccess(
      String roomCode, bool wanted) async {
    guestSwitches.add(wanted);
    if (failWith != null) return (allowGuests: null, error: failWith);
    allowGuests = wanted;
    return (allowGuests: wanted, error: null);
  }

  @override
  Future<String?> invite(
    String roomCode, {
    List<int> groupIds = const [],
    List<int> userIds = const [],
  }) async {
    invitedGroups.addAll(groupIds);
    invitedUsers.addAll(userIds);
    return failWith;
  }

  @override
  Future<String?> uninvite(String roomCode, {int? groupId, int? userId}) async {
    if (groupId != null) uninvitedGroups.add(groupId);
    return failWith;
  }
}

void main() {
  Future<void> pumpGroups(
    WidgetTester tester,
    _FakeApi api, {
    List<dynamic> students = const [],
    Size size = const Size(500, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: GroupsScreen(students: students, api: api),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('an empty screen says what a group is for', (tester) async {
    await pumpGroups(tester, _FakeApi());

    expect(find.text('Još nema grupa.'), findsOneWidget);
    expect(find.textContaining('pozovete grupu'), findsOneWidget);
  });

  testWidgets('a group is made by name, and counted in the list',
      (tester) async {
    final api = _FakeApi();
    await pumpGroups(tester, api);

    await tester.tap(find.text('Nova grupa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Utorak 18h');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(api.createdName, 'Utorak 18h');
    expect(find.text('Utorak 18h'), findsOneWidget);
    expect(find.text('0 učenika'), findsOneWidget);
  });

  testWidgets('a taken name is said in the server\'s own words',
      (tester) async {
    final api = _FakeApi(failWith: 'To ime je već zauzeto.');
    await pumpGroups(tester, api);

    await tester.tap(find.text('Nova grupa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Utorak 18h');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(find.text('To ime je već zauzeto.'), findsOneWidget);
  });

  testWidgets('only accepted students are offered for a group', (tester) async {
    // A group must not become a second way to attach yourself to somebody who
    // has not agreed to be taught by you. The server refuses it too; this keeps
    // the screen from offering what the server will turn down.
    final api = _FakeApi(
      groups: const [StudentGroup(id: 1, name: 'Utorak 18h', members: 0)],
      groupMembers: const [],
    );
    await pumpGroups(tester, api, students: const [
      {'id': 9, 'name': 'Mika', 'status': 'accepted'},
      {'id': 11, 'name': 'Neko Ko Nije Potvrdio', 'status': 'pending'},
    ]);

    await tester.tap(find.text('Utorak 18h'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dodaj učenike'));
    await tester.pumpAndSettle();

    expect(find.text('Mika'), findsOneWidget);
    expect(find.text('Neko Ko Nije Potvrdio'), findsNothing);

    await tester.tap(find.text('Mika'));
    await tester.pump();
    await tester.tap(find.text('Dodaj'));
    await tester.pumpAndSettle();

    expect(api.added, [9]);
  });

  testWidgets('members are shown by name, and can be taken out',
      (tester) async {
    final api = _FakeApi(
      groups: const [StudentGroup(id: 1, name: 'Utorak 18h', members: 1)],
      groupMembers: const [NamedPerson(id: 9, name: 'Mika')],
    );
    await pumpGroups(tester, api);

    await tester.tap(find.text('Utorak 18h'));
    await tester.pumpAndSettle();
    expect(find.text('Mika'), findsOneWidget);
    // No addresses in a list of people, most of whom are children.
    expect(find.textContaining('@'), findsNothing);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(api.removedMembers, [9]);
  });

  Future<void> pumpGuests(WidgetTester tester, _FakeApi api) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RoomGuestsDialog(roomCode: '123456', api: api),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('an empty guest list says the room is open to all your students',
      (tester) async {
    // And that adding one narrows it — said out loud rather than discovered,
    // because a screen that quietly changes who can get in is the same class of
    // surprise as a control that works while its button is hidden.
    await pumpGuests(tester, _FakeApi());

    expect(find.textContaining('otvorena za sve vaše učenike'), findsOneWidget);
    expect(find.textContaining('ulaze samo oni'), findsOneWidget);
  });

  testWidgets('a whole group is invited with one tap', (tester) async {
    final api = _FakeApi(
      groups: const [StudentGroup(id: 3, name: 'Utorak 18h', members: 8)],
    );
    await pumpGuests(tester, api);

    expect(find.text('Pozovi grupu'), findsOneWidget);
    await tester.tap(find.text('Utorak 18h (8)'));
    await tester.pumpAndSettle();

    expect(api.invitedGroups, [3]);
  });

  testWidgets('one student can be invited on their own', (tester) async {
    // Asked for in the same breath as groups: sometimes it is one person.
    final api = _FakeApi(students: const [
      {'id': 9, 'name': 'Mika', 'status': 'accepted'},
    ]);
    await pumpGuests(tester, api);

    expect(find.text('Pozovi pojedinačno'), findsOneWidget);
    await tester.tap(find.text('Mika'));
    await tester.pumpAndSettle();

    expect(api.invitedUsers, [9]);
  });

  testWidgets('the guest switch shows what the room says, and flips it',
      (tester) async {
    // The column existed for a day with nothing in the app that could see it.
    // Off is the default, and the default is what decides who is in the room
    // nobody thought about — so it has to be visible to be relied on.
    final api = _FakeApi();
    await pumpGuests(tester, api);

    expect(find.text('Soba prima goste'), findsOneWidget);
    expect(find.textContaining('ulaze samo prijavljeni'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(api.guestSwitches, [true]);
    // Said in the words that matter: the code is all it takes, and a recorded
    // lesson records whoever came in on it.
    expect(find.textContaining('svako ko zna kod sobe'), findsOneWidget);
    expect(find.textContaining('u snimku'), findsOneWidget);
  });

  testWidgets('a room that takes guests says the list does not stop them',
      (tester) async {
    // The two controls are independent on purpose, which is precisely why the
    // dialog must not let "ulaze samo oni sa ovog spiska" stand alone while the
    // guest door is open.
    final api = _FakeApi(
      allowGuests: true,
      guests: const [RoomGuest(kind: 'group', id: 3, name: 'Utorak 18h')],
    );
    await pumpGuests(tester, api);

    expect(find.text('Ulaze samo oni sa ovog spiska.'), findsOneWidget);
    expect(find.textContaining('bez obzira na spisak'), findsOneWidget);
  });

  testWidgets('a setting that could not be read says so, instead of "off"',
      (tester) async {
    // The recurring bug in this codebase, in a switch: a step that fails
    // quietly and reports the comfortable answer one layer up. Here the
    // comfortable answer would be a room drawn as closed while it is open.
    await pumpGuests(tester, _FakeApi(guestAccessFails: true));

    expect(find.byType(SwitchListTile), findsNothing);
    expect(
        find.textContaining('Ne znam da li soba prima goste'), findsOneWidget);
    expect(find.text('Pokušaj ponovo'), findsOneWidget);
  });

  testWidgets('the guest dialog fits a 360 dp phone', (tester) async {
    // A release build paints no overflow stripes: a row wider than the screen
    // is simply clipped, and the control past the edge is unreachable. In a
    // *test* build it throws, which is the only cheap way to find it — and the
    // row with "Pokušaj ponovo" in it is exactly the shape that has bitten
    // three times already.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final api in [
      _FakeApi(allowGuests: true, guests: const [
        RoomGuest(kind: 'group', id: 3, name: 'Utorak 18h'),
      ]),
      _FakeApi(guestAccessFails: true),
    ]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: RoomGuestsDialog(roomCode: '123456', api: api)),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a list with somebody on it says the room is now narrowed',
      (tester) async {
    final api = _FakeApi(
      guests: const [RoomGuest(kind: 'group', id: 3, name: 'Utorak 18h')],
    );
    await pumpGuests(tester, api);

    expect(find.text('Ulaze samo oni sa ovog spiska.'), findsOneWidget);
    expect(find.text('cela grupa'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(api.uninvitedGroups, [3]);
  });
}
