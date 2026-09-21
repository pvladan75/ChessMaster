// One answer to „who leads this room" — phase 3 of docs/PLAN-SESIJA.md.
//
// The room screen held four: a class getter, two locals that added the
// **account's** role, and one that left out the co-host seat. So an account
// registered 'trener' sitting in somebody's room as a student got half a
// trainer's screen. The rule is `leadsRoom` in board_control_rules.dart, held by
// its own pure test; this file holds the screen to asking it, and once.
//
// The first half reads source, so it is proved by mutation (rule 4): put a
// second definition back and it must fail. Comments are stripped first — the
// story of the old names is told in them, and prose is not code.
//
// Real font (rule 8): with the test font the room's right column overflows.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' show PlayerColor;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import 'support/landscape.dart' show loadRoboto;

/// The screen's code with `//` comments taken out, line by line. A `//` inside
/// a string literal (a URL) would be cut short too; nothing asserted here is
/// about strings.
String _code() =>
    File('lib/screens/chess_game_screen.dart').readAsLinesSync().map((line) {
      final at = line.indexOf('//');
      return at == -1 ? line : line.substring(0, at);
    }).join('\n');

Future<void> _room(WidgetTester tester,
    {required String seat, required String accountRole}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final client = MockClient((req) async {
    if (req.url.path.endsWith('/library/positions')) {
      return http.Response(jsonEncode({'items': []}), 200);
    }
    if (req.url.path == '/trainer/students') {
      return http.Response(jsonEncode({'students': []}), 200);
    }
    return http.Response('[]', 200);
  });
  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    theme: ThemeData(fontFamily: 'Roboto')
        .copyWith(extensions: const [AppColorTokens.light]),
    home: ChessGamePage(
      userSession: UserSession(
          id: 1, token: 'tok', email: 'e', name: 'N', role: accountRole),
      roomCode: '123456',
      initialRole: seat,
      lessonApi: LessonApiService(authToken: 'tok', client: client),
      positionLibrary: PositionLibraryService(authToken: 'tok', client: client),
      groupApi: GroupApiService(client: client),
    ),
  ));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

final _switch = find.byKey(const Key('room-students-may-move'));

/// Since phase 6 the leader's switches are in the Session panel, and a seat
/// without that button has none of them — which is the assertion, rather than
/// „no switch in sight", which a closed panel would also satisfy.
final _sessionButton = find.byKey(const Key('room-session-button'));

Future<void> _openSession(WidgetTester tester) async {
  await tester.tap(_sessionButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

bool _whiteAtBottom(WidgetTester tester) =>
    tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first)
        .boardOrientation ==
    PlayerColor.white;

void main() {
  setUpAll(loadRoboto);

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

  group('the screen asks once', () {
    final code = _code();

    test('the check reads code and not prose', () {
      expect(code, contains('bool get isLeader'));
      expect(code, isNot(contains('It held four definitions')),
          reason: 'comments were not stripped, so the rest proves nothing');
    });

    test('the old names are gone, as identifiers', () {
      for (final name in ['isHost', 'isTrener']) {
        expect(RegExp('\\b$name\\b').hasMatch(code), isFalse,
            reason: '$name is back: a second answer to „who leads"');
      }
    });

    test('the rule is called in one place', () {
      expect('leadsRoom('.allMatches(code), hasLength(1));
    });

    test('no seat is compared by hand, and the account role is not asked', () {
      // `activeRole == 'trener'` survives once: which exit the app bar draws
      // and who sees „Room access" read the seat itself on purpose — the
      // Preparation board „leads" and has neither. (Since phase 6 the second
      // is the Session button, which carries „Room access".) Anything beyond those is a
      // definition growing back.
      expect("activeRole == 'trener'".allMatches(code).length,
          lessThanOrEqualTo(2));
      expect(code, isNot(contains("activeRole == 'host'")));
      expect(code, isNot(contains("userSession.role == 'trener'")),
          reason: '`users.role` plays no part in teaching');
      expect(code, isNot(contains('change_user_role')),
          reason: 'promotion went with the co-host seat');
    });
  });

  group('what the seat is given', () {
    testWidgets('whoever started the session gets the board switch, locked',
        (tester) async {
      await _room(tester, seat: 'trener', accountRole: 'korisnik');
      await _openSession(tester);
      expect(_switch, findsOneWidget);
      expect(tester.widget<SwitchListTile>(_switch).value, isFalse);
      expect(find.text('Only you move on the board.'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('whoever leads sits behind White, a student behind Black',
        (tester) async {
      // The orientation asked for the co-host seat by name, so a trainer who
      // arrived as 'trener' — every trainer, since „New session" — opened on
      // Black's side and had to flip the board by hand.
      await _room(tester, seat: 'trener', accountRole: 'korisnik');
      expect(_whiteAtBottom(tester), isTrue);
      await _close(tester);

      await _room(tester, seat: 'ucenik', accountRole: 'korisnik');
      expect(_whiteAtBottom(tester), isFalse);
      await _close(tester);
    });

    testWidgets(
        'an account registered as a trainer, seated as a student, is a student',
        (tester) async {
      // The account role used to be trusted „in any room", which gave this
      // person the host's column title, the members' role menus and the board.
      await _room(tester, seat: 'ucenik', accountRole: 'trener');
      expect(_sessionButton, findsNothing);
      expect(_switch, findsNothing);
      expect(find.text('Board is locked by the trainer.'), findsOneWidget);
      expect(find.text('Host Controls & History'), findsNothing);
      expect(find.text('Invite students to session'), findsNothing);
      await _close(tester);
    });

    testWidgets('the co-host seat, claimed in a URL, is a student',
        (tester) async {
      await _room(tester, seat: 'host', accountRole: 'korisnik');
      expect(_sessionButton, findsNothing);
      expect(_switch, findsNothing);
      expect(find.text('Board is locked by the trainer.'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('nobody is offered a raw column value to read', (tester) async {
      await _room(tester, seat: 'ucenik', accountRole: 'korisnik');
      for (final raw in ['host_only', 'trainer_only', 'Permission status']) {
        expect(find.textContaining(raw), findsNothing, reason: raw);
      }
      await _close(tester);
    });
  });
}
