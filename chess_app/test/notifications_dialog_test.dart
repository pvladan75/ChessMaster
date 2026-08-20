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

/// The same request as `_studentRequest`, as `/relationships/pending` returns
/// it — the list that decides what is still unanswered.
const _pending = {
  'id': 8,
  'i_am_student': true,
  'other_name': 'pavle',
  'other_email': 'x@y.z',
};

Future<void> _open(
  WidgetTester tester,
  List<dynamic> notifications, {
  List<dynamic> pending = const [],
  void Function(int, String)? onJoin,
  Future<bool> Function(int, bool)? onRespond,
  Size size = _phone,
}) async {
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
          pendingRequests: pending,
          onJoinFromNotification: onJoin ?? (_, __) {},
          onRespondToRequest: onRespond ?? (_, __) async => true,
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

  testWidgets('a waiting request is answered here, not somewhere else',
      (tester) async {
    await _open(tester, [_studentRequest],
        pending: const [_pending], size: const Size(800, 600));

    // The bell is the owner now. It used to point at the Prijatelji tab, and
    // the notification stayed unread for good because nothing tied the answer
    // back to it.
    expect(find.text('Prihvati'), findsOneWidget);
    expect(find.text('Odbij'), findsOneWidget);
    expect(find.text('Odgovorite u tabu Prijatelji.'), findsNothing);
  });

  testWidgets('a request can be answered on a phone, and still reads',
      (tester) async {
    // The buttons used to sit beside the text, which in a 360 px dialog left
    // the sentence about a hundred pixels and broke it one word per line.
    // Nothing overflowed — it was simply unreadable, and several tests in this
    // file were widened to 800 to get around it.
    await _open(tester, const [], pending: const [_pending]);

    expect(tester.takeException(), isNull);
    expect(find.text('Prihvati'), findsOneWidget);
    expect(find.text('Odbij'), findsOneWidget);

    final line = tester.getRect(find.text('želi da vas upiše kao učenika'));
    expect(line.width, greaterThan(180),
        reason: 'the sentence is squeezed into a column too narrow to read');

    await tester.tap(find.text('Prihvati'));
    await tester.pumpAndSettle();
    expect(find.text('Zahtev je prihvaćen.'), findsOneWidget);
  });

  testWidgets('a request is offered once, not twice', (tester) async {
    await _open(tester, [_studentRequest],
        pending: const [_pending], size: const Size(800, 600));

    // The notification for a request that is still waiting would repeat the
    // same thing directly under the row that can answer it.
    expect(find.textContaining('želi da vas upiše'), findsOneWidget);
  });

  testWidgets('a request outlives its notification', (tester) async {
    // /notifications returns the last twenty. A request whose notification has
    // scrolled out of that must not become unanswerable.
    await _open(tester, const [],
        pending: const [_pending], size: const Size(800, 600));

    expect(find.text('Prihvati'), findsOneWidget);
    expect(find.text('Nemate novih notifikacija.'), findsNothing);
  });

  testWidgets('answering says what was decided, in place of the row',
      (tester) async {
    int? answeredId;
    bool? accepted;
    await _open(tester, const [],
        pending: const [_pending],
        size: const Size(800, 600), onRespond: (id, accept) async {
      answeredId = id;
      accepted = accept;
      return true;
    });

    await tester.tap(find.text('Prihvati'));
    await tester.pumpAndSettle();

    expect(answeredId, 8);
    expect(accepted, isTrue);
    // The dialog stays open and reports the outcome rather than vanishing from
    // under the finger that answered it.
    expect(find.text('Zahtev je prihvaćen.'), findsOneWidget);
    expect(find.text('Prihvati'), findsNothing);
  });

  testWidgets('a refused answer leaves the request where it was',
      (tester) async {
    await _open(tester, const [],
        pending: const [_pending],
        size: const Size(800, 600),
        onRespond: (_, __) async => false);

    await tester.tap(find.text('Prihvati'));
    await tester.pumpAndSettle();

    // The server said no. Pretending otherwise would lose the request.
    expect(find.text('Prihvati'), findsOneWidget);
    expect(find.text('Zahtev je prihvaćen.'), findsNothing);
  });

  testWidgets('an answered request is history, without buttons',
      (tester) async {
    // Nothing pending: the notification is all that is left of it.
    await _open(tester, [_studentRequest]);

    expect(find.text('Odgovoreno.'), findsOneWidget);
    expect(find.text('Prihvati'), findsNothing);
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
