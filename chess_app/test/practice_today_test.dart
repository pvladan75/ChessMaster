import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/services/app_settings_service.dart';

/// The client half of the daily target: what it asks for, and what it does with
/// an answer it did not get.
class _Api extends RepertoireApiService {
  _Api(this.body, {this.status = 200})
      : super(
          client: MockClient((req) async {
            seen = req.url;
            return http.Response(body, status);
          }),
        );

  static Uri? seen;
  final String body;
  final int status;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _Api.seen = null;
  });

  test('the day it counts is the one the client names', () async {
    final api = _Api(jsonEncode(
        {'positions': 12, 'answers': 19, 'scored': 7, 'practice': 12}));
    final since = DateTime(2026, 9, 3, 0, 0);

    final out = await api.practiceToday(since: since, color: 'w');

    expect(out!.positions, 12);
    // The two kinds arrive apart and stay apart.
    expect(out.scored, 7);
    expect(out.practice, 12);

    final asked = _Api.seen!;
    expect(asked.queryParameters['since'], since.toUtc().toIso8601String());
    expect(asked.queryParameters['color'], 'w');
    // Absolute, not a bare path: the defect that shipped four endpoints once.
    expect(asked.isAbsolute, isTrue);
  });

  test('a server that did not answer is null, never zero', () async {
    // "You have practised nothing today" is a hard enough sentence to be told
    // when it is true. A failed request must not be able to say it.
    final api = _Api('{}', status: 500);
    expect(await api.practiceToday(since: DateTime.now()), isNull);
  });

  test('the target is a number somebody can finish, and can be switched off',
      () async {
    final settings = AppSettingsService.instance;
    await settings.init();

    expect(settings.dailyTarget, 10);

    await settings.setDailyTarget(25);
    expect(settings.dailyTarget, 25);

    // Zero is off, not "target of nothing".
    await settings.setDailyTarget(0);
    expect(settings.dailyTarget, 0);

    // And nothing absurd survives a bad caller.
    await settings.setDailyTarget(100000);
    expect(settings.dailyTarget, 200);
  });
}
