import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/lessons/widgets/lesson_step_editor_panel.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    return AppSettingsService.instance.init();
  });

  const fenA = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
  const fenB = '4k3/8/8/8/8/8/4P3/4K3 w - - 0 1';
  const fenC = '8/8/8/3k4/8/8/3PK3/8 w - - 0 1';

  final session = UserSession(
    token: 'test-token',
    id: 1,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  Map<String, dynamic> lesson() => {
        'id': 7,
        'title': 'Završnice',
        'position_list': [
          {
            'id': 'aaaa1111',
            'fen': fenA,
            'title': 'Prvi',
            'instruction': 'Nađi mat u jednom potezu.',
            'kind': 'ask_move',
            'solutionSan': 'Ra8#',
          },
          {'id': 'bbbb2222', 'fen': fenB, 'title': 'Drugi'},
          {'id': 'cccc3333', 'fen': fenC, 'title': 'Treći'},
        ],
      };

  testWidgets(
      'real transport: reordering steps sends PUT with exact positionList body',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    http.Request? capturedRequest;
    final mockClient = MockClient((request) async {
      capturedRequest = request;
      return http.Response('{"id": 7}', 200);
    });

    final realApi = LessonApiService(
      authToken: 'test-token',
      client: mockClient,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LessonStepEditorPanel(
          session: session,
          api: realApi,
          lesson: lesson(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Select Treći, move up
    await tester.tap(find.text('Treći'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pomeri gore'));
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('Sačuvaj korak'));
    await tester.pumpAndSettle();

    expect(capturedRequest, isNotNull);
    expect(capturedRequest!.method, 'PUT');
    expect(capturedRequest!.url.path, endsWith('/lessons/7'));
    expect(capturedRequest!.headers['authorization'], 'Bearer test-token');
    expect(
        capturedRequest!.headers['content-type'], contains('application/json'));

    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    expect(body['title'], 'Završnice');
    expect(body['positionList'], isNotNull);

    final positionList = (body['positionList'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    expect(positionList, hasLength(3));
    expect(positionList.map((s) => s['id']).toList(),
        ['aaaa1111', 'cccc3333', 'bbbb2222']);
    expect(positionList.map((s) => s['fen']).toList(), [fenA, fenC, fenB]);

    // Print positionList JSON so it can be verified and copied into report
    debugPrint('POSITION_LIST_JSON: ${jsonEncode(positionList)}');
  });

  testWidgets(
      'real transport: added step goes out with no id key in HTTP payload',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    http.Request? capturedRequest;
    final mockClient = MockClient((request) async {
      capturedRequest = request;
      return http.Response('{"id": 7}', 200);
    });

    final realApi = LessonApiService(
      authToken: 'test-token',
      client: mockClient,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LessonStepEditorPanel(
          session: session,
          api: realApi,
          lesson: lesson(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Add step after initial selected step ('Prvi')
    await tester.tap(find.text('Dodaj korak').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('step-title')), 'Novi ubačeni korak');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sačuvaj korak'));
    await tester.pumpAndSettle();

    expect(capturedRequest, isNotNull);
    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    final positionList = (body['positionList'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    expect(positionList, hasLength(4));
    final newStep = positionList[1];
    expect(newStep.containsKey('id'), isFalse,
        reason:
            'a new step must omit the id key so the server can generate one');
    expect(newStep['title'], 'Novi ubačeni korak');
    expect(newStep['fen'], fenA);
  });

  testWidgets('responsive layout check at Size(360, 640)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mockClient = MockClient((request) async {
      return http.Response(jsonEncode({'id': 7}), 200);
    });
    final realApi = LessonApiService(
      authToken: 'test-token',
      client: mockClient,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LessonStepEditorPanel(
          session: session,
          api: realApi,
          lesson: lesson(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(LessonStepEditorPanel), findsOneWidget);
    expect(find.text('Dodaj korak'), findsWidgets);
    expect(find.text('Obriši korak'), findsWidgets);
  });
}
