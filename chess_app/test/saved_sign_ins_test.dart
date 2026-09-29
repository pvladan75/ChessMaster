import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/saved_sign_ins.dart';
import 'package:chess_app/services/session_service.dart';

import 'support/fake_password_store.dart';

/// „Remember me" keeps the address and — where the platform has a safe place
/// for it — the password (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md` §4.1). These
/// are the rules below the screen: what is kept, where, and what makes it go.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePasswordStore store;
  final saved = SavedSignIns.instance;

  const password = 'kept-Secret-7';

  UserSession user(String email, {int id = 11}) => UserSession(
        token: 'token-$id',
        id: id,
        email: email,
        name: 'Test',
        role: 'korisnik',
      );

  /// Every value `SharedPreferences` holds, flattened to strings — the
  /// password must be in none of them.
  Future<List<String>> everythingInPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      for (final key in prefs.getKeys()) ...[
        key,
        if (prefs.get(key) is List)
          ...(prefs.get(key) as List).map((e) => '$e')
        else
          '${prefs.get(key)}',
      ],
    ];
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = FakePasswordStore();
    saved.debugUseStore(store);
    await SessionService.instance.signOut();
    await SessionService.instance.init();
  });

  tearDown(() => saved.debugUseStore(null));

  group('the list of addresses', () {
    test('the one address kept before the list moves into it, once', () async {
      SharedPreferences.setMockInitialValues({'last_email': 'ana@example.com'});
      await saved.load();

      expect(saved.addresses, ['ana@example.com']);
      expect(SessionService.instance.lastEmail, 'ana@example.com');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_email'), isNull,
          reason: 'moved, not copied: two homes for one address drift');
      expect(prefs.getStringList('remembered_emails'), ['ana@example.com']);
    });

    test('the latest sign-in comes first, and one address is one entry',
        () async {
      await saved.remember('ana@example.com', password: password);
      await saved.remember('ivan@example.com', password: 'other-1');
      await saved.remember('Ana@Example.com', password: password);

      expect(saved.addresses, ['Ana@Example.com', 'ivan@example.com']);
      expect(saved.last, 'Ana@Example.com');
    });

    test('a password is only ever read for an address on the list', () async {
      store.kept['stranger@example.com'] = 'not-ours';
      expect(saved.passwordFor('stranger@example.com'), isNull);
    });
  });

  group('the password', () {
    test('kept in the store, never in SharedPreferences', () async {
      final keeping =
          await saved.remember('ana@example.com', password: password);

      expect(keeping, PasswordKeeping.kept);
      expect(saved.passwordFor('ana@example.com'), password);
      expect(await everythingInPrefs(), isNot(contains(password)));
      expect((await everythingInPrefs()).any((v) => v.contains(password)),
          isFalse);
    });

    test('a Google sign-in leaves a kept password where it is', () async {
      await saved.remember('ana@example.com', password: password);
      final keeping = await saved.remember('ana@example.com');

      expect(keeping, PasswordKeeping.notOffered);
      expect(saved.passwordFor('ana@example.com'), password);
    });

    test('a store that refuses to write fails loudly, and the address stays',
        () async {
      store.refuseWrite = true;
      final keeping =
          await saved.remember('ana@example.com', password: password);

      expect(keeping, PasswordKeeping.failed);
      expect(saved.addresses, ['ana@example.com']);
    });

    test('forget takes the address and the password', () async {
      await saved.remember('ana@example.com', password: password);

      expect(await saved.forget('ana@example.com'), isTrue);
      expect(saved.addresses, isEmpty);
      expect(store.kept, isEmpty);
    });

    test('forgetting only the password keeps the address', () async {
      await saved.remember('ana@example.com', password: password);

      expect(saved.forgetPassword('ana@example.com'), isTrue);
      expect(saved.addresses, ['ana@example.com']);
      expect(saved.passwordFor('ana@example.com'), isNull);
    });

    test('a store that will not let go says so', () async {
      await saved.remember('ana@example.com', password: password);
      store.refuseDelete = true;

      expect(await saved.forget('ana@example.com'), isFalse);
      expect(saved.addresses, isEmpty);
      expect(saved.forgetPassword('ana@example.com'), isFalse);
    });

    test('where the platform keeps no passwords, none is kept or read',
        () async {
      saved.debugUseStore(null);

      expect(saved.keepsPasswords, isFalse);
      final keeping =
          await saved.remember('ana@example.com', password: password);
      expect(keeping, PasswordKeeping.notOffered);
      expect(saved.passwordFor('ana@example.com'), isNull);
      expect(saved.addresses, ['ana@example.com']);
      expect((await everythingInPrefs()).any((v) => v.contains(password)),
          isFalse);
    });
  });

  group('the session decides', () {
    test('ticked: the address and the accepted password are kept', () async {
      final keeping = await SessionService.instance.signIn(
          user('ana@example.com'),
          rememberMe: true,
          password: password);

      expect(keeping, PasswordKeeping.kept);
      expect(saved.addresses, ['ana@example.com']);
      expect(store.kept['ana@example.com'], password);
    });

    test('unticked: the address and any kept password are forgotten', () async {
      await saved.remember('ana@example.com', password: password);

      final keeping = await SessionService.instance.signIn(
          user('ana@example.com'),
          rememberMe: false,
          password: password);

      expect(keeping, PasswordKeeping.notOffered);
      expect(saved.addresses, isEmpty);
      expect(store.kept, isEmpty);
      expect(store.writes, hasLength(1),
          reason: 'only the earlier, ticked sign-in wrote');
    });

    test('signing out keeps both — that is the point of the feature', () async {
      await SessionService.instance.signIn(user('ana@example.com'),
          rememberMe: true, password: password);
      await SessionService.instance.signOut();

      expect(saved.addresses, ['ana@example.com']);
      expect(saved.passwordFor('ana@example.com'), password);
    });

    test('an expired session keeps both: the same person is expected back',
        () async {
      await SessionService.instance.signIn(user('ana@example.com'),
          rememberMe: true, password: password);
      await SessionService.instance.expire();

      expect(saved.addresses, ['ana@example.com']);
      expect(saved.passwordFor('ana@example.com'), password);
    });

    test('an account that is gone takes its address and password with it',
        () async {
      await SessionService.instance.signIn(user('ivan@example.com', id: 12),
          rememberMe: true, password: 'other-1');
      await SessionService.instance.signIn(user('ana@example.com'),
          rememberMe: true, password: password);
      await SessionService.instance.expire(reason: 'account-gone');

      expect(saved.addresses, ['ivan@example.com'],
          reason: 'only the account that ended');
      expect(store.kept.keys, ['ivan@example.com']);
    });
  });
}
