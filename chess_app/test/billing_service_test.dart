import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/services/billing_service.dart';

void main() {
  group('EntitlementState', () {
    test('parses the server payload', () {
      final state = EntitlementState.fromJson({
        'tier': 'premium',
        'entitlements': ['ai_comments', 'mp4_export', 'unlimited_sessions'],
        'quotas': {
          'ai_comments': {'limit': 500, 'used': 42},
        },
      });

      expect(state.tier, 'premium');
      expect(state.isPaid, isTrue);
      expect(state.has(Entitlements.mp4Export), isTrue);
      expect(state.quota(Entitlements.aiComments)!.remaining, 458);
    });

    test('a free account holds no paid entitlements', () {
      final state = EntitlementState.fromJson({
        'tier': 'free',
        'entitlements': ['ai_comments'],
        'quotas': {
          'ai_comments': {'limit': 10, 'used': 10},
        },
      });

      expect(state.isPaid, isFalse);
      expect(state.has(Entitlements.mp4Export), isFalse);
      expect(state.quota(Entitlements.aiComments)!.remaining, 0);
    });

    test('a malformed or empty payload degrades to free rather than throwing',
        () {
      // A truncated response must never be read as "everything is unlocked".
      final state = EntitlementState.fromJson({});
      expect(state.tier, 'free');
      expect(state.isPaid, isFalse);
      expect(state.entitlements, isEmpty);
      expect(state.has(Entitlements.mp4Export), isFalse);
    });

    test('an unmetered quota reports as unlimited', () {
      final state = EntitlementState.fromJson({
        'tier': 'club',
        'entitlements': ['ai_comments'],
        'quotas': {
          'ai_comments': {'limit': -1, 'used': 900},
        },
      });

      final quota = state.quota(Entitlements.aiComments)!;
      expect(quota.isUnlimited, isTrue);
      expect(quota.remaining, -1);
    });

    test('used above limit clamps at zero remaining instead of going negative',
        () {
      const quota = QuotaInfo(limit: 10, used: 13);
      expect(quota.remaining, 0);
    });
  });

  group('displayTitle', () {
    test('strips the app name Play appends to product titles', () {
      expect(BillingService.displayTitle('Trener Pro (Šahovski trener)'),
          'Trener Pro');
      expect(BillingService.displayTitle('Trener Pro'), 'Trener Pro');
    });

    test('keeps parentheses that are part of the name itself', () {
      // Only a trailing parenthetical is removed, and only one.
      expect(
        BillingService.displayTitle('Klub (do 5 trenera) (Šahovski trener)'),
        'Klub (do 5 trenera)',
      );
    });
  });
}
