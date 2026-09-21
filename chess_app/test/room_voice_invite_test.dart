import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/widgets/game_screen/room_voice_invite.dart';

/// **Somebody is talking and I am not hearing it** — phase 4 of
/// `docs/PLAN-SESIJA.md`, item 2.
///
/// The voice is entered on a button, by whoever wants the conversation
/// (`voice_on_request_test.dart`). What that rule cost: the button lives far
/// down the right column, and on a phone behind a tab — so a student could sit
/// through a spoken lesson looking at a silent board. The room's bar now says
/// it, and only while it is true.
void main() {
  Map<String, dynamic> inVoice(Object id, String name,
          {String role = 'ucenik'}) =>
      {'userId': id, 'userName': name, 'role': role};

  group('voiceInviteLine', () {
    test('nobody in voice: nothing is said', () {
      expect(voiceInviteLine(const [], myId: 7, voiceOn: false), isNull);
    });

    test('only me in voice is nobody to join', () {
      // The roster lists me a moment before `voiceOn` is set, and after a
      // failed join a moment longer — and "Ana is in voice", said to Ana, is
      // the line lying.
      expect(
        voiceInviteLine([inVoice(7, 'Ana')], myId: 7, voiceOn: false),
        isNull,
      );
    });

    test('my own voice is on: nothing is said, whoever else is there', () {
      expect(
        voiceInviteLine(
            [inVoice(1, 'Vladan', role: 'trener'), inVoice(7, 'Ana')],
            myId: 7, voiceOn: true),
        isNull,
      );
    });

    test('one person in voice is named', () {
      expect(
        voiceInviteLine([inVoice(1, 'Vladan', role: 'trener')],
            myId: 7, voiceOn: false),
        'Vladan is in voice',
      );
    });

    test('the trainer is the name said, wherever the roster put them', () {
      // The roster is in the order people pressed the button. A student is
      // told about the person they came to hear.
      expect(
        voiceInviteLine([
          inVoice(8, 'Boris'),
          inVoice(9, 'Ceca'),
          inVoice(1, 'Vladan', role: 'trener'),
        ], myId: 7, voiceOn: false),
        'Vladan and 2 others are in voice',
      );
      expect(
        voiceInviteLine(
            [inVoice(8, 'Boris'), inVoice(1, 'Vladan', role: 'trener')],
            myId: 7, voiceOn: false),
        'Vladan and 1 other are in voice',
      );
    });

    test('an id that arrives as text is still me', () {
      // Socket.IO hands back whatever the server stored, and a guest's id is a
      // socket id — a string. Compared as text, like the presence line.
      expect(
        voiceInviteLine([inVoice('7', 'Ana')], myId: 7, voiceOn: false),
        isNull,
      );
    });

    test('a roster entry that is not a map is skipped, not thrown on', () {
      expect(
        voiceInviteLine([null, 'x', inVoice(1, 'Vladan')],
            myId: 7, voiceOn: false),
        'Vladan is in voice',
      );
    });
  });

  group('RoomVoiceInvite', () {
    Future<void> pumpBar(WidgetTester tester, Size size, Widget? bottom) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Room: 123456'),
            bottom: bottom as PreferredSizeWidget?,
          ),
          body: const SizedBox.expand(),
        ),
      ));
    }

    for (final size in const [Size(360, 640), Size(760, 360)]) {
      testWidgets(
          'fits the bar at ${size.width.toInt()} x '
          '${size.height.toInt()} with a name too long for it', (tester) async {
        var joined = 0;
        await pumpBar(
          tester,
          size,
          RoomVoiceInvite(
            line: 'Aleksandar-Konstantin Petrović-Njegoš the Third and '
                '12 others are in voice',
            onJoin: () => joined++,
          ),
        );

        expect(tester.takeException(), isNull);

        final button =
            tester.getRect(find.byKey(const Key('voice-invite-join')));
        final text = tester.getRect(find.byKey(const Key('voice-invite-line')));
        expect(button.right, lessThanOrEqualTo(size.width));
        expect(button.left, greaterThanOrEqualTo(text.right),
            reason: 'the sentence gives way, the button does not');
        expect(text.width, greaterThan(80),
            reason: 'a sentence squeezed to nothing says nothing');
        // A target a thumb can hit, on the one control this strip exists for.
        expect(button.height, greaterThanOrEqualTo(32));

        await tester.tap(find.byKey(const Key('voice-invite-join')));
        expect(joined, 1);
        // Both, because a desktop theme is compact by default and takes 8 px
        // off a button's height — Android alone cannot see that.
      },
          variant: const TargetPlatformVariant(
              {TargetPlatform.android, TargetPlatform.windows}));
    }

    testWidgets('the button says what it does', (tester) async {
      await pumpBar(tester, const Size(360, 640),
          RoomVoiceInvite(line: 'Vladan is in voice', onJoin: () {}));

      expect(find.text('Vladan is in voice'), findsOneWidget);
      expect(find.text('Join voice'), findsOneWidget);
    });
  });
}
