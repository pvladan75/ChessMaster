import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/account_standing_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/widgets/home/friends_tab.dart';
import 'package:chess_app/widgets/parent_email_dialog.dart';

/// The parent's half, seen from the app.
///
/// A relationship with a minor stops at `awaiting_parent`: both people agreed
/// and it still does not exist, because the parent has not answered. The app's
/// job is to never draw that as a working relationship — a row that said "Vaš
/// učenik" would tell a trainer they may teach a child they may not — and to
/// leave the child a way to end the wait, which is an address nobody has yet.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.signIn(
      UserSession(
        token: 'token',
        id: 7,
        email: 'ucenik@example.com',
        name: 'Učenik',
        role: 'korisnik',
      ),
      rememberMe: false,
    );
  });

  Widget tab({
    List<dynamic> students = const [],
    List<dynamic> trainers = const [],
    VoidCallback? onFixParentEmail,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: HomeFriendsTab(
            studentEmailController: TextEditingController(),
            isLoadingStudents: false,
            students: students,
            trainers: trainers,
            onAddStudent: () {},
            onDeleteStudent: (_) {},
            onOpenProgress: (_) {},
            iAmTrainerInRequest: true,
            onRoleChanged: (_) {},
            onRefresh: () async {},
            onFixParentEmail: onFixParentEmail ?? () {},
            onEnterLesson: (_) {},
            onOpenPanelAssignment: (_) {},
          ),
        ),
      );

  testWidgets('a student waiting on a parent is not yet a student',
      (tester) async {
    await tester.pumpWidget(tab(students: [
      {'id': 2, 'name': 'Dete', 'status': 'awaiting_parent', 'i_asked': true},
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Čeka saglasnost roditelja'), findsOneWidget);
    expect(find.text('Vaš učenik'), findsNothing);

    // Homework and progress are what an accepted edge unlocks, so the button
    // that leads to them is off. A row that looked ordinary would be the same
    // failure as a control that works while its button is hidden.
    final progress = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.insights),
    );
    expect(progress.onPressed, isNull);
  });

  testWidgets('the child can end the wait from the row itself', (tester) async {
    // Settings is not where a child would think to look, and the row is where
    // they already are, reading that something is waiting.
    var asked = 0;
    await tester.pumpWidget(tab(
      trainers: [
        {
          'id': 1,
          'name': 'Trener',
          'status': 'awaiting_parent',
          'i_asked': true
        },
      ],
      onFixParentEmail: () => asked += 1,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Čeka saglasnost roditelja — dodirnite'), findsOneWidget);
    await tester.tap(find.text('Trener'));
    await tester.pumpAndSettle();

    expect(asked, 1);
  });

  testWidgets('a pending request still reads as pending, not as a parent',
      (tester) async {
    // The two waits are different: one is answered in the bell by the other
    // person, the other by somebody who is not in the app at all.
    await tester.pumpWidget(tab(students: [
      {'id': 2, 'name': 'Dete', 'status': 'pending', 'i_asked': true},
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Čeka potvrdu'), findsOneWidget);
    expect(find.textContaining('roditelj'), findsNothing);
  });

  /// A standing service backed by canned answers, plus what was posted.
  ({AccountStandingService service, List<String> posted}) fake({
    int status = 200,
    String error = 'Adresa nije mogla da se sačuva.',
  }) {
    final posted = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        posted.add(request.body);
        if (status >= 300) {
          return http.Response(jsonEncode({'error': error}), status);
        }
        return http.Response(jsonEncode({'parentEmailOnFile': true}), 200);
      }
      return http.Response(
        jsonEncode({
          'ageKnown': true,
          'birthYear': 2014,
          'age': 11,
          'minor': true,
          'ageOfConsent': 16,
          'parentConsent': {
            'required': true,
            'given': false,
            'parentEmailOnFile': true,
          },
        }),
        200,
      );
    });
    return (service: AccountStandingService(client: client), posted: posted);
  }

  Future<void> openDialog(WidgetTester tester, AccountStandingService s) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showParentEmailDialog(context, standing: s),
              child: const Text('otvori'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('otvori'));
    await tester.pumpAndSettle();
  }

  testWidgets('a saved address closes the dialog', (tester) async {
    final f = fake();
    await openDialog(tester, f.service);

    await tester.enterText(find.byType(TextField), 'roditelj@primer.rs');
    await tester.tap(find.text('Pošalji'));
    await tester.pumpAndSettle();

    expect(jsonDecode(f.posted.single)['parentEmail'], 'roditelj@primer.rs');
    expect(find.byType(TextField), findsNothing);
    // The address is on file afterwards, which is what the screens read to stop
    // asking.
    expect(f.service.current?.parentEmailOnFile, isTrue);
  });

  testWidgets('an address the server refuses keeps the dialog open',
      (tester) async {
    // Closing either way would look the same whether the consent letter went
    // out or nothing at all happened — and a relationship would stay stuck with
    // nobody able to say why.
    final f =
        fake(status: 400, error: 'Unesite ispravnu email adresu roditelja.');
    await openDialog(tester, f.service);

    await tester.enterText(find.byType(TextField), 'roditelj@primer.rs');
    await tester.tap(find.text('Pošalji'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(
        find.text('Unesite ispravnu email adresu roditelja.'), findsOneWidget);
  });

  testWidgets('an address that is not one never leaves the phone',
      (tester) async {
    final f = fake();
    await openDialog(tester, f.service);

    await tester.enterText(find.byType(TextField), 'roditelj');
    await tester.tap(find.text('Pošalji'));
    await tester.pumpAndSettle();

    expect(f.posted, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
  });
}
