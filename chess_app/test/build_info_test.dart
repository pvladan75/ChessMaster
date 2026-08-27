import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/build_info.dart';

/// What the line at the bottom of Settings is allowed to claim.
///
/// It replaced a hardcoded "v2.0 • Pro Edition" that was wrong in both halves,
/// and it exists for one reader: someone filing a bug report who has to say
/// which build they saw it in.
void main() {
  test('an unstamped build says so instead of naming a version', () {
    // `flutter run`, a test, and a CI artifact built without the defines all
    // land here. Printing "1.1.0+2" would be worse than printing nothing: that
    // string is identical across every APK made in a week of testing.
    expect(
      buildLabel(version: '1.1.0+2', commit: '', mode: '', time: ''),
      'Mislisha • build nije označen',
    );
  });

  test('a stamped build names the commit it was built from', () {
    expect(
      buildLabel(
        version: '1.1.0+2',
        commit: '0fe3bc0',
        mode: 'release',
        time: '2026-08-27T22:38',
      ),
      'Mislisha 1.1.0+2 • 0fe3bc0 • release • 2026-08-27T22:38',
    );
  });

  test('parts that were not stamped are left out, not printed empty', () {
    expect(
      buildLabel(version: '', commit: '0fe3bc0', mode: '', time: ''),
      'Mislisha 0fe3bc0',
    );
  });

  test('a build from a dirty working tree is marked with +', () {
    // The commit alone would describe code that was never on the phone.
    expect(isDirtyBuild(commit: '0fe3bc0+'), isTrue);
    expect(isDirtyBuild(commit: '0fe3bc0'), isFalse);
    expect(isDirtyBuild(commit: ''), isFalse);
  });
}
