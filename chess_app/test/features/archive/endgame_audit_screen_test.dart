import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/models/archive_subject.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/features/archive/screens/endgame_audit_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/features/archive/models/endgame_audit.dart';
import 'package:chess_app/features/archive/models/endgame_mistake.dart';
import 'package:chess_app/theme/app_theme.dart';

class MockArchiveApiService extends Fake implements ArchiveApiService {
  @override
  Future<List<ArchiveSubject>> getSubjects() async => [];
  @override
  Future<List<ArchiveRun>> listImports() async => [];

  bool throw409 = false;

  MockArchiveApiService();

  @override
  Future<String> startEndgameAudit(String username) async {
    if (throw409) {
      throw EndgameAuditAlreadyRunningException('456', 'other_guy');
    }
    return '123';
  }

  @override
  Future<EndgameAudit> getEndgameAudit(String id) async {
    if (id == '456') {
      return EndgameAudit(
        id: '456',
        subject: 'other_guy',
        status: 'running',
        gamesTotal: 471,
        gamesDone: 100,
        positionsProbed: 1000,
        cacheHits: 500,
        positionsUnknown: 0,
        mistakesFound: 5,
      );
    }
    return EndgameAudit(
      id: '123',
      subject: 'tester',
      status: 'done',
      gamesTotal: 471,
      gamesDone: 471,
      positionsProbed: 4255,
      cacheHits: 3980,
      positionsUnknown: 0,
      mistakesFound: 27,
    );
  }

  @override
  Future<List<EndgameMistake>> getEndgameMistakes({int limit = 50}) async {
    return [
      EndgameMistake(
        id: '1',
        gameId: '10',
        ply: 20,
        fenBefore: '8/8/4k3/8/4P3/4K3/8/8 w - - 0 40',
        playedUci: 'e3d3',
        bestUci: 'e4e5',
        wdlBefore: 2,
        wdlAfter: 0,
        opponent: 'Player 2',
      ),
      EndgameMistake(
        id: '2',
        gameId: '10',
        ply: 21,
        fenBefore: '8/8/4k3/8/8/4K3/8/8 w - - 0 41',
        playedUci: 'e3e2',
        bestUci: null,
        wdlBefore: 0,
        wdlAfter: -2,
        opponent: 'Player 2',
      )
    ];
  }
}

void main() {
  final session = UserSession(
    token: 'test-token',
    id: 1,
    email: 'test@example.com',
    name: 'Tester',
    role: 'user',
  );

  Widget createSubject() {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: EndgameAuditScreen(session: session, username: 'tester'),
      ),
    );
  }

  setUp(() {
    ArchiveApiService.setMock(MockArchiveApiService());
  });

  testWidgets('renders counters and mistakes correctly', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('partije 471/471'), findsOneWidget);
    expect(find.text('pozicije 4255'), findsOneWidget);
    expect(find.text('iz keša 3980'), findsOneWidget);
    expect(find.text('nalaza 27'), findsOneWidget);

    expect(find.text('Pešačka završnica'), findsOneWidget);
    expect(find.text('Bacio dobitak'), findsOneWidget);
    expect(find.text('Odigraj poziciju'), findsOneWidget);
    expect(find.text('Bacio remi'),
        findsNothing); // This is from the mistake with bestUci == null

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets(
      '409 with a different subject attaches and names the other handle',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;

    final mockApi = MockArchiveApiService();
    mockApi.throw409 = true;
    ArchiveApiService.setMock(mockApi);

    await tester.pumpWidget(createSubject());
    await tester
        .pump(); // Start audit fails with 409, sets errorMsg or polls. Wait, we need to pump and wait for the message to appear.
    await tester.pump(const Duration(milliseconds: 500));
    // Now it should be polling and rendering running state
    expect(find.textContaining('Provera je već u toku za korisnika other_guy'),
        findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
