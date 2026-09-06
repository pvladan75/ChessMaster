import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

/// Whether the tutorial authoring screen exists on this device.
///
/// Decision 5 of `docs/PLAN-TUTORIJAL.md`: `TutorialStudioScreen` carries a
/// board, a move tree, the fields for one node **and** a running list of
/// examples, and Android is 360–410 dp. So it is Windows-only for now, and the
/// Studio simply does not draw the door to it anywhere else.
///
/// Nothing is removed from Android by this. Which other screens stop making
/// sense on a phone is a separate decision the owner takes later, with the
/// screen in front of them — and it stays a one-line change only while this
/// predicate has exactly one home. Read it; do not write `Platform.isWindows`
/// a second time.
///
/// The shape is the one `engine_settings_dialog.dart` already uses: `kIsWeb`
/// first, because `Platform` throws on the web.
bool get isTutorialStudioAvailable =>
    debugTutorialStudioAvailable ?? (!kIsWeb && Platform.isWindows);

/// Forces the answer, for tests that have to see both sides of it.
///
/// Null — the default — means "ask the platform". It exists because `flutter
/// test` runs on whatever machine it runs on: a test that asserted the door is
/// drawn would pass here and fail on CI's Linux runner, which is the
/// local-versus-CI shape this project has already paid for once.
@visibleForTesting
bool? debugTutorialStudioAvailable;
