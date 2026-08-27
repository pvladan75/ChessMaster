// relationship_request_direction_test.dart
// Who teaches whom is the sender's choice, not a side effect of who typed first.
//
// Before this, the app could only send one of the two requests the server has
// always accepted, so the person who entered the other's email became the
// trainer. Nothing failed — the relationship was simply backwards, and the only
// way out was for the wrong trainer to delete it and ask the other to re-add
// them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/models/relationship_request_target.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/home/friends_tab.dart';

const _phone = Size(360, 640);

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Scaffold(body: child),
    );

Widget _tab({
  required bool iAmTrainer,
  required ValueChanged<bool> onRoleChanged,
  List<dynamic> students = const [],
  List<dynamic> trainers = const [],
  ValueChanged<Map<String, dynamic>>? onOpenProgress,
  ValueChanged<int>? onDeleteStudent,
  Future<void> Function()? onRefresh,
  VoidCallback? onFixParentEmail,
}) =>
    HomeFriendsTab(
      studentEmailController: TextEditingController(),
      isLoadingStudents: false,
      students: students,
      trainers: trainers,
      onAddStudent: () {},
      onDeleteStudent: onDeleteStudent ?? (_) {},
      onOpenProgress: onOpenProgress ?? (_) {},
      iAmTrainerInRequest: iAmTrainer,
      onRoleChanged: onRoleChanged,
      onRefresh: onRefresh ?? () async {},
      onFixParentEmail: onFixParentEmail ?? () {},
      onEnterLesson: (_) {},
      onOpenPanelAssignment: (_) {},
    );

void main() {
  group('where a request is sent', () {
    test('claiming to be the trainer enrols the other side', () {
      final target = RelationshipRequestTarget.forRole(iAmTrainer: true);
      expect(target.path, '/trainer/students/add');
      expect(target.emailField, 'studentEmail');
    });

    test('claiming to be the student asks the other side to teach', () {
      final target = RelationshipRequestTarget.forRole(iAmTrainer: false);
      expect(target.path, '/students/trainers/request');
      expect(target.emailField, 'trainerEmail');
    });

    test('the two directions are genuinely different requests', () {
      // Pinned because the field names differ by one word and the routes look
      // alike: a copy-paste that reused the other's key fails with "email je
      // obavezan", which says nothing about roles.
      expect(
        RelationshipRequestTarget.asTrainer.path,
        isNot(RelationshipRequestTarget.asStudent.path),
      );
      expect(
        RelationshipRequestTarget.asTrainer.emailField,
        isNot(RelationshipRequestTarget.asStudent.emailField),
      );
    });
  });

  group('choosing the direction in the Prijatelji tab', () {
    testWidgets('offers both capacities', (tester) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester
          .pumpWidget(_host(_tab(iAmTrainer: true, onRoleChanged: (_) {})));

      expect(find.text('Ja sam trener'), findsOneWidget);
      expect(find.text('Ja sam učenik'), findsOneWidget);
    });

    testWidgets('picking the student side reports it to the caller',
        (tester) async {
      bool? chosen;
      await tester.pumpWidget(
        _host(_tab(iAmTrainer: true, onRoleChanged: (v) => chosen = v)),
      );

      await tester.tap(find.text('Ja sam učenik'));
      await tester.pump();

      expect(chosen, isFalse, reason: 'the tap must set the sender to student');
    });

    testWidgets('the address field says whose address it wants',
        (tester) async {
      // The same email means opposite things in the two directions, so a label
      // that stays "Email prijatelja" is the whole ambiguity restated.
      await tester
          .pumpWidget(_host(_tab(iAmTrainer: true, onRoleChanged: (_) {})));
      expect(find.text('Email učenika'), findsOneWidget);
      expect(find.text('Email trenera'), findsNothing);

      await tester
          .pumpWidget(_host(_tab(iAmTrainer: false, onRoleChanged: (_) {})));
      expect(find.text('Email trenera'), findsOneWidget);
      expect(find.text('Email učenika'), findsNothing);
    });

    testWidgets('an unanswered row offers no homework', (tester) async {
      // The server refuses this anyway — `trainerOwnsStudent` requires an
      // accepted edge — but a button that fails on tap teaches the user that
      // the app is broken rather than that consent is missing. And a server
      // check being the only thing left standing is exactly the situation this
      // whole change came out of.
      var opened = 0;
      var deleted = 0;
      await tester.pumpWidget(_host(_tab(
        iAmTrainer: true,
        onRoleChanged: (_) {},
        students: const [
          // i_asked: I sent this invitation, so it is mine to wait on and it
          // belongs in the list. Had they asked me, it would be a card above.
          {
            'id': 1,
            'name': 'Vladan',
            'email': 'v@example.com',
            'status': 'pending',
            'i_asked': true
          },
        ],
        onOpenProgress: (_) => opened++,
        onDeleteStudent: (_) => deleted++,
      )));

      expect(find.textContaining('Čeka potvrdu'), findsOneWidget);
      // The address used to stand in this row. It does not travel any more:
      // most of the people in these lists are children, and a list of people is
      // not the place for their emails. The field for *inviting* somebody by
      // address is a different thing and stays — hence the fixture's own
      // address rather than any '@'.
      expect(find.textContaining('v@example.com'), findsNothing);

      await tester.tap(find.byIcon(Icons.insights));
      await tester.tap(find.text('Vladan'));
      await tester.pump();
      expect(opened, 0,
          reason: 'progress must stay shut until the edge is accepted');

      // Withdrawing the invitation stays possible on purpose: the sender must
      // be able to take back a request the other side has not answered.
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pump();
      expect(deleted, 1);
    });

    testWidgets('an accepted row opens progress', (tester) async {
      var opened = 0;
      await tester.pumpWidget(_host(_tab(
        iAmTrainer: true,
        onRoleChanged: (_) {},
        students: const [
          {
            'id': 2,
            'name': 'Pavle',
            'email': 'p@example.com',
            'status': 'accepted'
          },
        ],
        onOpenProgress: (_) => opened++,
      )));

      await tester.tap(find.byIcon(Icons.insights));
      await tester.pump();
      expect(opened, 1,
          reason: 'the guard must not disable the normal case too');
    });

    testWidgets('a user with only a trainer is not told they have nobody',
        (tester) async {
      // The relationship is one row read from two ends. Drawing only one end
      // made the app deny a relationship that existed and worked: the student
      // saw "Nemate još uvek dodatih prijatelja" while their trainer saw them
      // listed.
      await tester.pumpWidget(_host(_tab(
        iAmTrainer: true,
        onRoleChanged: (_) {},
        students: const [],
        trainers: const [
          {
            'id': 5,
            'name': 'pavle',
            'email': 'p@example.com',
            'status': 'accepted',
            'i_asked': false
          },
        ],
      )));

      expect(find.text('Moji treneri'), findsOneWidget);
      expect(find.text('pavle'), findsOneWidget);
      expect(find.textContaining('Još nemate'), findsNothing);
    });

    testWidgets('a trainer row offers no homework buttons', (tester) async {
      // Progress and assignments belong to the teaching side only. Breaking the
      // relationship stays available: consent that cannot be withdrawn from one
      // side is not consent.
      var deleted = 0;
      await tester.pumpWidget(_host(_tab(
        iAmTrainer: true,
        onRoleChanged: (_) {},
        trainers: const [
          {
            'id': 5,
            'name': 'pavle',
            'email': 'p@example.com',
            'status': 'accepted',
            'i_asked': false
          },
        ],
        onDeleteStudent: (_) => deleted++,
      )));

      expect(find.byIcon(Icons.insights), findsNothing);

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pump();
      expect(deleted, 1);
    });

    testWidgets('a request waiting on me is listed, and says where to answer',
        (tester) async {
      // It used to be hidden here, because the same request was also an
      // answerable card above and the person would have appeared twice. The
      // answer moved to the bell, so there is nothing to hide from — and a
      // person who vanishes from the list until they answer is worse than a
      // greyed row that points at the bell.
      await tester.pumpWidget(_host(_tab(
        iAmTrainer: true,
        onRoleChanged: (_) {},
        trainers: const [
          {
            'id': 5,
            'name': 'pavle',
            'email': 'p@example.com',
            'status': 'pending',
            'i_asked': false
          },
        ],
      )));

      expect(find.text('Moji treneri'), findsOneWidget);
      expect(find.text('pavle'), findsOneWidget);
      expect(find.textContaining('Odgovorite u zvoncetu'), findsOneWidget);
      // And no buttons: two places to answer one thing is what this removed.
      expect(find.byTooltip('Prihvati'), findsNothing);
    });

    testWidgets('a request I sent says it is the other side being waited on',
        (tester) async {
      await tester.pumpWidget(_host(_tab(
        iAmTrainer: true,
        onRoleChanged: (_) {},
        students: const [
          {
            'id': 5,
            'name': 'pavle',
            'email': 'p@example.com',
            'status': 'pending',
            'i_asked': true
          },
        ],
      )));

      expect(find.textContaining('Čeka potvrdu'), findsOneWidget);
      expect(find.textContaining('zvoncetu'), findsNothing);
    });

    testWidgets('a request I sent stays visible while it waits',
        (tester) async {
      await tester.pumpWidget(_host(_tab(
        iAmTrainer: true,
        onRoleChanged: (_) {},
        trainers: const [
          {
            'id': 5,
            'name': 'pavle',
            'email': 'p@example.com',
            'status': 'pending',
            'i_asked': true
          },
        ],
      )));

      expect(find.text('Moji treneri'), findsOneWidget);
      expect(find.textContaining('Čeka potvrdu'), findsOneWidget);
    });

    testWidgets('pulling down asks for fresh data', (tester) async {
      // The other side answers on their own device. Without a way to ask again,
      // a trainer whose student had just accepted still saw "čeka potvrdu" and
      // the only way out was restarting the app.
      var refreshed = 0;
      await tester.pumpWidget(_host(_tab(
        iAmTrainer: true,
        onRoleChanged: (_) {},
        onRefresh: () async => refreshed++,
      )));

      await tester.fling(
          find.text('Moji Prijatelji & Kontakti'), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(refreshed, 1, reason: 'the pull gesture must reach the callback');
    });

    testWidgets('states in words which side teaches', (tester) async {
      await tester
          .pumpWidget(_host(_tab(iAmTrainer: false, onRoleChanged: (_) {})));
      expect(find.text('Druga strana predaje, vi ste učenik.'), findsOneWidget);
    });
  });
}
