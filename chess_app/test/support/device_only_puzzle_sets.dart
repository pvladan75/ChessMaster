// A `PuzzleSetRepository` whose server is not there.
//
// Phase of 21.9.2026: a puzzle set moved from the device to the account, and
// both dialogs now take a repository rather than reaching for
// `LocalPuzzleSetStorageService` themselves. The tests that were written
// before that seed the **device's** store and assert on what it holds, and
// that is still exactly what they mean — so they are handed a repository
// whose server refuses every request, which is the documented fallback:
// a server that cannot be reached is not an empty account, and the device's
// own sets are the answer.
//
// Shared rather than copied into each file, because the next test that builds
// one of those dialogs should not have to work this out again (rule 12).

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/core/services/puzzle_set_api_service.dart';
import 'package:chess_app/core/services/puzzle_set_repository.dart';

PuzzleSetRepository deviceOnlyPuzzleSets() => PuzzleSetRepository(
      api: PuzzleSetApiService(
        authToken: '',
        client: MockClient((_) async => http.Response('{}', 503)),
      ),
    );
