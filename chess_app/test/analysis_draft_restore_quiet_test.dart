// The Analysis Studio brings the last analysis back without announcing it.
//
// Asked for by the owner on 16.9.2026: the „Your latest analysis has been
// restored" notice, with its „Start over", came up on every visit.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';

void main() {
  testWidgets('a restored analysis comes back without a notice',
      (tester) async {
    final root = AnalysisNode(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    root.addChild(
      childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
      san: 'e4',
      uci: 'e2e4',
    );
    SharedPreferences.setMockInitialValues({
      'analysis_studio_draft': jsonEncode({
        'tree': root.toJson(),
        'path': [0],
        'blackOrientation': false,
        'savedAt': DateTime(2026, 9, 16).toIso8601String(),
      }),
    });

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: AnalysisStudioScreen(
        userSession: UserSession(
            token: 't', id: 1, email: 'a@b.c', name: 'N', role: 'korisnik'),
      ),
    ));
    await tester.pumpAndSettle();

    // Restored: the tree holds the move the draft was left on, which a fresh
    // board would not.
    expect(find.text('1. e4'), findsWidgets);
    // And nothing said about it.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('has been restored'), findsNothing);
  });
}
