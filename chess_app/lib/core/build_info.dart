/// Which build this is, stamped in from outside at build time.
///
/// `version:` in pubspec cannot answer it. `1.1.0+2` is the same string on
/// every APK made this week, so a bug report that quotes it says nothing about
/// which code was running — and during a testing campaign that is the only
/// thing the report needs to say. The commit does answer it, and the app has
/// no way to know its own commit: `build_and_deploy.ps1` passes it in with
/// `--dart-define`.
///
/// A trailing `+` on the commit means the working tree had uncommitted changes
/// when the APK was built, so the commit alone does not describe it. That is
/// worth seeing on the screen rather than inferring later from a timestamp.
///
/// Nothing here is fetched or computed at runtime: these are compile-time
/// constants, empty in `flutter run`, in tests, and in a CI-built artifact
/// that was not given them.
library;

const String _commit = String.fromEnvironment('BUILD_COMMIT');
const String _mode = String.fromEnvironment('BUILD_MODE');
const String _time = String.fromEnvironment('BUILD_TIME');
const String _version = String.fromEnvironment('BUILD_VERSION');

/// The product name, which is not a build fact and so is not stamped.
const String appName = 'Mislisha';

/// The line to show, and the line to paste into a bug report.
///
/// Kept as a free function taking its parts so the shape can be tested; the
/// constants above are only its arguments in the app.
String buildLabel({
  String version = _version,
  String commit = _commit,
  String mode = _mode,
  String time = _time,
}) {
  // The commit is what identifies a build, so without it the line says
  // nothing rather than something. A bare "1.1.0+2" would look like an answer
  // while naming a week's worth of different APKs - which is the whole reason
  // this line exists.
  if (commit.isEmpty) return '$appName • build nije označen';

  final parts = [
    if (version.isNotEmpty) version,
    commit,
    if (mode.isNotEmpty) mode,
    if (time.isNotEmpty) time,
  ];

  return '$appName ${parts.join(' • ')}';
}

/// True when the working tree had uncommitted changes at build time.
bool isDirtyBuild({String commit = _commit}) => commit.endsWith('+');
