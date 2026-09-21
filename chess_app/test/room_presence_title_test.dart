// The room says who is here — phase 2 of docs/PLAN-SESIJA.md.
//
// On 21.9.2026 two people sat alone in two different rooms, and neither screen
// said so. The roster was a card far down the right column.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/room_presence_title.dart';

import 'support/landscape.dart' show loadRoboto;

Map<String, Object> _m(int id, String name, String role) =>
    {'userId': id, 'name': name, 'role': role, 'socketId': 's$id'};

final _trainer = _m(1, 'Vladan', 'trener');
final _ana = _m(2, 'Ana', 'ucenik');
final _marko = _m(3, 'Marko', 'ucenik');

void main() {
  // Real font (rule 8): whether a sentence is cut is a measurement.
  setUpAll(loadRoboto);

  group('the sentence', () {
    test('before a roster arrives there is nothing to say', () {
      expect(presenceLine(const [], 1), isNull);
    });

    test('a trainer alone is told nobody has joined', () {
      final p = presenceLine([_trainer], 1)!;
      expect(p.text, 'Nobody has joined yet');
      expect(p.alone, isTrue);
    });

    test('a student alone is told the trainer is not here — the report', () {
      final p = presenceLine([_ana], 2)!;
      expect(p.text, 'Waiting for the trainer');
      expect(p.alone, isTrue);
    });

    test('students together without the trainer are still waiting', () {
      final p = presenceLine([_ana, _marko], 2)!;
      expect(p.text, 'Waiting for the trainer · with Marko');
      expect(p.alone, isTrue);
    });

    test('with the trainer in, a student reads who is here', () {
      final p = presenceLine([_trainer, _ana, _marko], 2)!;
      expect(p.text, 'With Vladan, Marko');
      expect(p.alone, isFalse);
    });

    test('the trainer reads the students, and never themselves', () {
      final p = presenceLine([_trainer, _ana], 1)!;
      expect(p.text, 'With Ana');
      expect(p.alone, isFalse);
    });

    test('an id that arrives as text is still me', () {
      // Guests are keyed by socket id, so ids are not all numbers.
      final p = presenceLine([_trainer, _ana], '1')!;
      expect(p.text, 'With Ana');
    });
  });

  group('the bar', () {
    Future<void> pump(WidgetTester tester, Size size,
        {required List<dynamic> members,
        required int myId,
        required bool compact}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto')
            .copyWith(extensions: const [AppColorTokens.light]),
        home: Scaffold(
          appBar: AppBar(
            toolbarHeight: compact ? 44 : null,
            // The room's ☰, placed by hand 8 px in.
            leading: const Icon(Icons.menu),
            leadingWidth: 64,
            titleSpacing:
                size.width < RoomPresenceTitle.uprightBelow && !compact
                    ? RoomPresenceTitle.uprightTitleSpacing
                    : null,
            title: RoomPresenceTitle(
              status: 'Room: 923337',
              members: members,
              myId: myId,
              compact: compact,
            ),
            centerTitle: true,
            // As many as the room draws for a trainer since phase 6: voice,
            // Session, ⋮ and End, 48 each, and 4 at the end.
            actions: const [
              SizedBox(width: 48),
              SizedBox(width: 48),
              SizedBox(width: 48),
              SizedBox(width: 48),
              SizedBox(width: 4),
            ],
          ),
        ),
      ));
      await tester.pump();
    }

    final crowd = [
      _trainer,
      _m(2, 'Aleksandra Đorđević-Petrović', 'ucenik'),
      _m(3, 'Maksimilijan Stojanović', 'ucenik'),
      _m(4, 'Konstantin Milovanović', 'ucenik'),
    ];

    testWidgets('a full room fits the bar of a 360 dp phone', (tester) async {
      await pump(tester, const Size(360, 640),
          members: crowd, myId: 1, compact: false);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('room-presence-line')), findsOneWidget);
    });

    // Phase 6. „Fits" above was only „nothing throws": with four buttons and a
    // ☰ the title is about 90 px wide, and „Room: 923337" over „Nobody has
    // joined yet" came out as „Room: 92…" over „Nobody h…". On an upright
    // phone the code gives way — the trainer reads it in the Session panel —
    // and the sentence gets two lines.
    for (final (label, members, myId) in [
      ('a trainer alone', [_trainer], 1),
      ('a student alone', [_ana], 2),
      ('a student with the trainer', [_trainer, _ana], 2),
    ]) {
      testWidgets('on an upright phone the sentence is read whole — $label',
          (tester) async {
        await pump(tester, const Size(360, 640),
            members: members, myId: myId, compact: false);
        expect(tester.takeException(), isNull);
        final line = tester.renderObject<RenderParagraph>(find.descendant(
            of: find.byKey(const Key('room-presence-line')),
            matching: find.byType(RichText)));
        expect(line.didExceedMaxLines, isFalse,
            reason: '„${line.text.toPlainText()}" is cut in '
                '${tester.getSize(find.byKey(const Key('room-presence-line')))}');
      });
    }

    testWidgets('a desktop keeps the code above the sentence', (tester) async {
      await pump(tester, const Size(1200, 800),
          members: [_trainer], myId: 1, compact: false);
      expect(find.text('Room: 923337'), findsOneWidget);
      expect(find.byKey(const Key('room-presence-line')), findsOneWidget);
    });

    testWidgets('on its side the two lines are one, inside 44 px',
        (tester) async {
      await pump(tester, const Size(760, 360),
          members: crowd, myId: 1, compact: true);
      expect(tester.takeException(), isNull);
      final status = tester.getRect(find.text('Room: 923337'));
      final line = tester.getRect(find.byKey(const Key('room-presence-line')));
      expect((status.center.dy - line.center.dy).abs(), lessThan(4),
          reason: 'stacked, the pair is taller than the compact bar');
      expect(line.bottom, lessThanOrEqualTo(44));
    });

    testWidgets('being alone is a shape, not only a colour', (tester) async {
      await pump(tester, const Size(360, 640),
          members: [_ana], myId: 2, compact: false);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      expect(find.byIcon(Icons.people), findsNothing);
    });

    testWidgets('Preparation has no roster and draws only its name',
        (tester) async {
      await pump(tester, const Size(360, 640),
          members: const [], myId: 1, compact: false);
      expect(find.byKey(const Key('room-presence-line')), findsNothing);
      expect(find.text('Room: 923337'), findsOneWidget);
    });
  });
}
