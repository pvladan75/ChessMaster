// A live room as the person who started it sees it.
//
// Until phase 4 of `docs/PLAN-PRIPREMA.md` a test that wanted the room's
// column, its arrows or its doors pumped the room as `STUDIO` — the code
// Preparation was entered by — because that seat led the room and taught in it
// without a server saying so. Preparation is a screen of its own now and the
// room has no such code, so those tests ask for what that code gave them by
// name: the seat of whoever opened the room, and an account that teaches
// somebody.
//
// What a widget test still cannot give the room is its socket. The seat here
// is the one the room was **entered** with, which stands in until the server
// answers — and in a test it never does.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';

/// A code as the server mints them: six digits.
const trainerRoomCode = '482913';

/// The seat the server gives whoever opened the room.
const trainerSeat = 'trener';

/// An account with one accepted student, which is what makes whoever opened
/// a room its teacher before anybody has come (`mayTeachInRoom`).
GroupApiService teachingSomebody() => GroupApiService(
      client: MockClient((req) async {
        if (req.url.path == '/trainer/students') {
          return http.Response(
              jsonEncode({
                'students': [
                  {'id': 2, 'name': 'Ana', 'status': 'accepted'},
                ],
              }),
              200);
        }
        return http.Response('{}', 200);
      }),
    );
