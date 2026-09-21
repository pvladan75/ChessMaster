// The room's voice panel — phase 6 of docs/PLAN-SESIJA.md.
//
// Pumped with its states directly, because the room gets them from Agora and
// over Socket.IO, which a widget test has none of. Two rules from the plan's
// §3 and F12: a raised hand can be lowered, and the trainer mutes students one
// at a time — „Mute all students" is gone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/room_voice_panel.dart';

const _me = 7;

final _users = [
  {'userId': 1, 'userName': 'Vladan', 'role': 'trener', 'maySpeak': true},
  {
    'userId': _me,
    'userName': 'Mila',
    'role': 'ucenik',
    'maySpeak': true,
    'isMuted': true,
  },
];

Future<List<bool>> _pump(
  WidgetTester tester, {
  bool isLeader = false,
  bool isHandRaised = false,
  bool isMuted = true,
  bool isVoiceOn = true,
  List<String>? calls,
}) async {
  final hands = <bool>[];
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData().copyWith(extensions: const [AppColorTokens.light]),
    home: Scaffold(
      body: SingleChildScrollView(
        child: RoomVoicePanel(
          isVoiceOn: isVoiceOn,
          isConnecting: false,
          error: null,
          micProblem: null,
          mayUseMic: true,
          isMuted: isMuted,
          othersInCall: const ['Vladan'],
          users: _users,
          activeSpeakers: const {},
          myId: isLeader ? 1 : _me,
          isLeader: isLeader,
          isStudentSeat: !isLeader,
          isHandRaised: isHandRaised,
          onJoin: () => calls?.add('join'),
          onLeave: () => calls?.add('leave'),
          onToggleMute: () {},
          onSetHand: hands.add,
          onSetStudentVoice: (_, __) {},
          onMuteUser: (_, __) {},
        ),
      ),
    ),
  ));
  return hands;
}

void main() {
  testWidgets('a muted student raises a hand', (tester) async {
    final hands = await _pump(tester);
    await tester.tap(find.text('Raise hand to speak'));
    expect(hands, [true]);
    expect(find.text('Lower hand'), findsNothing);
  });

  testWidgets('a raised hand can be lowered', (tester) async {
    final hands = await _pump(tester, isHandRaised: true);
    expect(find.text('Raise hand to speak'), findsNothing);
    await tester.tap(find.text('Lower hand'));
    expect(hands, [false]);
  });

  testWidgets('a student who is not muted has no hand to raise',
      (tester) async {
    await _pump(tester, isMuted: false);
    expect(find.text('Raise hand to speak'), findsNothing);
    expect(find.text('Lower hand'), findsNothing);
  });

  testWidgets('the trainer mutes students one at a time', (tester) async {
    await _pump(tester, isLeader: true, isMuted: false);
    expect(
        find.byTooltip('Revoke microphone (remains listening)'), findsOneWidget,
        reason: 'the per-student control has to be there for its absence '
            'beside it to mean anything');
    expect(find.text('Mute all students'), findsNothing);
  });

  testWidgets('the join button is the door the room hands in', (tester) async {
    final calls = <String>[];
    await _pump(tester, isVoiceOn: false, calls: calls);
    await tester.tap(find.text('Join conversation'));
    expect(calls, ['join']);
  });

  testWidgets('what is switched on can be switched off', (tester) async {
    final calls = <String>[];
    await _pump(tester, calls: calls);
    await tester.tap(find.text('Leave voice'));
    expect(calls, ['leave']);
  });
}
