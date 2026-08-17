// notifications_dialog_test.dart
// The notification list has to survive the notifications that actually exist.
//
// `room_code` stopped being mandatory on 16.8, when a notification began to
// carry a request to teach or be taught — which has no room. The dialog kept
// reading it as a non-null String, so the first such notification threw during
// build and the user got a blank screen where the list should be. The data was
// right; the client's idea of the data was a day out of date.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/home/home_dialogs.dart' as dialogs;

const _phone = Size(360, 640);

/// A room invitation: the only kind that has somewhere to go.
const _roomInvite = {
  'id': 1,
  'kind': 'room',
  'room_code': '123456',
  'title': 'Pozivnica u sesiju',
  'message': 'Pavle vas poziva u sesiju.',
  'is_read': false,
};

/// A request to become someone's student. No room, and `ref_id` instead.
const _studentRequest = {
  'id': 2,
  'kind': 'student_request',
  'room_code': null,
  'ref_id': 8,
  'title': 'Poziv trenera',
  'message': 'pavle želi da vas upiše kao učenika.',
  'is_read': false,
};

const _declined = {
  'id': 3,
  'kind': 'request_declined',
  'room_code': null,
  'title': 'Zahtev nije prihvaćen',
  'message': 'pvladan nije prihvatio vaš zahtev.',
  'is_read': true,
};

Future<void> _open(WidgetTester tester, List<dynamic> notifications,
    {void Function(int, String)? onJoin, Size size = _phone}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => dialogs.showNotificationsDialog(
          context,
          notifications: notifications,
          onJoinFromNotification: onJoin ?? (_, __) {},
        ),
        child: const Text('otvori'),
      ),
    ),
  ));
  await tester.tap(find.text('otvori'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a notification without a room does not blank the screen',
      (tester) async {
    await _open(tester, [_studentRequest]);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('želi da vas upiše'), findsOneWidget);
  });

  testWidgets('one roomless notification does not take the others with it',
      (tester) async {
    // The list is built in one pass, so a throw on any row loses the whole
    // dialog — including the room invitations that were perfectly fine.
    await _open(tester, [_roomInvite, _studentRequest, _declined]);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('poziva vas u sesiju'), findsNothing);
    expect(find.textContaining('vas poziva u sesiju'), findsOneWidget);
    expect(find.textContaining('želi da vas upiše'), findsOneWidget);
    expect(find.textContaining('nije prihvatio'), findsOneWidget);
  });

  testWidgets('only a room invitation offers to join', (tester) async {
    // "Pridruži se" on a request with no room would have nowhere to go.
    await _open(tester, [_roomInvite, _studentRequest, _declined]);

    expect(find.text('Pridruži se'), findsOneWidget);
    expect(find.textContaining('Soba: 123456'), findsOneWidget);
  });

  testWidgets('a request says where it is answered', (tester) async {
    await _open(tester, [_studentRequest]);
    expect(find.text('Odgovorite u tabu Prijatelji.'), findsOneWidget);
  });

  testWidgets('joining passes the room code along', (tester) async {
    // Wider than the others on purpose: this checks the wiring, and the test
    // font is wide enough to push the trailing button out of reach at 360 px,
    // which would fail the tap for a reason that has nothing to do with it.
    int? joinedId;
    String? joinedRoom;
    await _open(tester, [_roomInvite], size: const Size(800, 600),
        onJoin: (id, room) {
      joinedId = id;
      joinedRoom = room;
    });

    await tester.tap(find.text('Pridruži se'));
    await tester.pumpAndSettle();

    expect(joinedId, 1);
    expect(joinedRoom, '123456');
  });

  testWidgets('an empty list says so instead of showing nothing',
      (tester) async {
    await _open(tester, const []);
    expect(find.text('Nemate novih notifikacija.'), findsOneWidget);
  });
}
