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
import 'package:chess_app/widgets/home/home_dialogs.dart' show badgeExplanation;

const _phone = Size(360, 640);

/// A room invitation: the only kind that has somewhere to go.
const _roomInvite = {
  'id': 1,
  'kind': 'room',
  'room_code': '123456',
  'title': 'Pozivnica u sesiju',
  'message': 'Pavle vas poziva u sesiju.',
  'is_read': false,
  // The server's word that the room is still a session (since 21.9.2026).
  'room_live': true,
};

/// The same invitation once its session is over — the one the owner pressed on
/// 21.9.2026 and sat alone in an old room for.
const _endedInvite = {
  'id': 9,
  'kind': 'room',
  'room_code': '856933',
  'title': 'Pozivnica u sesiju',
  'message': 'Pavle vas je pozvao juče.',
  'is_read': false,
  'room_live': false,
};

/// An invitation from a server that does not say. Not a door either.
const _silentInvite = {
  'id': 10,
  'kind': 'room',
  'room_code': '777777',
  'title': 'Pozivnica u sesiju',
  'message': 'Pavle vas je pozvao nekad.',
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
  Future<bool> Function(int)? onDelete,
  Future<bool> Function()? onClearAll,
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
          onDeleteNotification: onDelete ?? (_) async => true,
          onClearAll: onClearAll ?? () async => true,
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

  testWidgets('an invitation to a session that has ended is not a door',
      (tester) async {
    await _open(tester, [_endedInvite, _silentInvite]);

    expect(find.text('Join'), findsNothing);
    expect(find.textContaining('Room: 856933'), findsNothing);
    expect(find.text('This session has ended.'), findsNWidgets(2));
  });

  testWidgets('a live invitation beside an ended one is the only one to join',
      (tester) async {
    await _open(tester, [_endedInvite, _roomInvite]);

    expect(find.text('Join'), findsOneWidget);
    expect(find.textContaining('Room: 123456'), findsOneWidget);
    expect(find.text('This session has ended.'), findsOneWidget);
  });

  testWidgets('only a room invitation offers to join', (tester) async {
    // "Join" on a request with no room would have nowhere to go.
    await _open(tester, [_roomInvite, _studentRequest, _declined]);

    expect(find.text('Join'), findsOneWidget);
    expect(find.textContaining('Room: 123456'), findsOneWidget);
  });

  testWidgets('a waiting request is answered here, not somewhere else',
      (tester) async {
    await _open(tester, [_studentRequest],
        pending: const [_pending], size: const Size(800, 600));

    // The bell is the owner now. It used to point at the Prijatelji tab, and
    // the notification stayed unread for good because nothing tied the answer
    // back to it.
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
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
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);

    final line = tester.getRect(find.text('wants to add you as a student'));
    expect(line.width, greaterThan(180),
        reason: 'the sentence is squeezed into a column too narrow to read');

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(find.text('Request accepted.'), findsOneWidget);
  });

  testWidgets('a request is offered once, not twice', (tester) async {
    await _open(tester, [_studentRequest],
        pending: const [_pending], size: const Size(800, 600));

    // The notification for a request that is still waiting would repeat the
    // same thing directly under the row that can answer it.
    expect(
        find.textContaining('wants to add you as a student'), findsOneWidget);
  });

  testWidgets('a request outlives its notification', (tester) async {
    // /notifications returns the last twenty. A request whose notification has
    // scrolled out of that must not become unanswerable.
    await _open(tester, const [],
        pending: const [_pending], size: const Size(800, 600));

    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('You have no new notifications.'), findsNothing);
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

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(answeredId, 8);
    expect(accepted, isTrue);
    // The dialog stays open and reports the outcome rather than vanishing from
    // under the finger that answered it.
    expect(find.text('Request accepted.'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('a refused answer leaves the request where it was',
      (tester) async {
    await _open(tester, const [],
        pending: const [_pending],
        size: const Size(800, 600),
        onRespond: (_, __) async => false);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    // The server said no. Pretending otherwise would lose the request.
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Request accepted.'), findsNothing);
  });

  testWidgets('an answered request is history, without buttons',
      (tester) async {
    // Nothing pending: the notification is all that is left of it.
    await _open(tester, [_studentRequest]);

    expect(find.text('Answered.'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
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

    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(joinedId, 1);
    expect(joinedRoom, '123456');
  });

  testWidgets('an empty list says so instead of showing nothing',
      (tester) async {
    await _open(tester, const []);
    expect(find.text('You have no new notifications.'), findsOneWidget);
  });

// The bell's number counts two unlike things. Saying so is the whole point, and
// in Serbian saying it means counting three ways.

  test('the bell says what its number is made of', () {
    expect(badgeExplanation(waiting: 1, unread: 2),
        '1 request awaiting your response · 2 new notifications');
    expect(badgeExplanation(waiting: 0, unread: 1), '1 new notification');
    expect(badgeExplanation(waiting: 2, unread: 0),
        '2 requests awaiting your response');
    expect(badgeExplanation(waiting: 0, unread: 0), '');
  });

  test('counts singular and plural notifications', () {
    expect(badgeExplanation(waiting: 0, unread: 1), '1 new notification');
    expect(badgeExplanation(waiting: 0, unread: 5), '5 new notifications');
    expect(badgeExplanation(waiting: 0, unread: 11), '11 new notifications');
    expect(badgeExplanation(waiting: 0, unread: 12), '12 new notifications');
    expect(badgeExplanation(waiting: 0, unread: 21), '21 new notifications');
    expect(badgeExplanation(waiting: 0, unread: 22), '22 new notifications');
    expect(badgeExplanation(waiting: 0, unread: 25), '25 new notifications');
  });

  testWidgets('the explanation is shown above the list', (tester) async {
    await _open(tester, [_studentRequest, _roomInvite],
        pending: const [_pending]);

    expect(find.textContaining('1 request awaiting your response'),
        findsOneWidget);
  });

  // Deleted from the bell since 22.9.2026; until then a notification stayed
  // for ever.
  group('deleting notifications', () {
    testWidgets('one goes when the server says so, and only then',
        (tester) async {
      final asked = <int>[];
      var answer = false;
      await _open(tester, [_declined, _endedInvite], onDelete: (id) async {
        asked.add(id);
        return answer;
      });
      await tester.tap(find.byKey(const ValueKey('notification-delete-3')));
      await tester.pumpAndSettle();
      expect(asked, [3]);
      expect(find.textContaining('nije prihvatio'), findsOneWidget,
          reason: 'the row left although the server kept it');

      answer = true;
      await tester.tap(find.byKey(const ValueKey('notification-delete-3')));
      await tester.pumpAndSettle();
      expect(find.textContaining('nije prihvatio'), findsNothing);
      expect(find.textContaining('pozvao juče'), findsOneWidget,
          reason: 'another notification went with it');
    });

    testWidgets('Clear all empties the list and leaves the requests',
        (tester) async {
      var cleared = 0;
      await _open(tester, [_declined, _roomInvite, _studentRequest],
          pending: [_pending], onClearAll: () async {
        cleared++;
        return true;
      });
      await tester.tap(find.byKey(const ValueKey('notifications-clear-all')));
      await tester.pumpAndSettle();
      expect(cleared, 1);
      expect(find.textContaining('nije prihvatio'), findsNothing);
      expect(find.textContaining('vas poziva u sesiju'), findsNothing);
      expect(find.text('pavle'), findsOneWidget,
          reason: 'a request still waiting is not a notification to clear');
      expect(
          find.byKey(const ValueKey('notifications-clear-all')), findsNothing);
    });

    testWidgets('an invitation with Join and its delete fit a 360 dp phone',
        (tester) async {
      await _open(tester, [_roomInvite]);
      expect(tester.takeException(), isNull);
      final join = tester.getRect(find.text('Join'));
      final delete =
          tester.getRect(find.byKey(const ValueKey('notification-delete-1')));
      expect(join.right, lessThanOrEqualTo(delete.left));
      expect(delete.right, lessThanOrEqualTo(_phone.width));
    });
  });
}
