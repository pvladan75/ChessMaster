/// Where the user's manual lives, and the one way the app opens it.
///
/// `docs/PLAN-PRIRUCNIK.md`: the manual is pages on the site, in the site's own
/// style, and the app links to them from Settings and from the F1 shortcuts
/// page — one copy, reachable from the app and from the store listing, rather
/// than a second one built into the app that every change to the manual would
/// need a new build for. `test/manual_labels_test.dart` asserts this address
/// is the contents page the site serves.
library;

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chess_app/widgets/app_feedback.dart';

const kUserManualUrl = 'https://chesstrainers.app/mislisha/manual/';

/// The seam a widget test opens the manual through. Opening a browser is a
/// plugin call, and in a widget test nothing answers it.
@visibleForTesting
Future<bool> Function(Uri uri)? debugOpenUserManual;

/// Opens the manual in the browser, and says so when it cannot.
///
/// A link that looks as if it worked and did nothing is the worst of the
/// outcomes, so a refusal names the address: the reader can still type it.
Future<void> openUserManual(BuildContext context) async {
  final uri = Uri.parse(kUserManualUrl);
  bool opened;
  try {
    opened = await (debugOpenUserManual ??
        (u) => launchUrl(u, mode: LaunchMode.externalApplication))(uri);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    AppFeedback.error(
      context,
      'Could not open the user manual. It is at '
      'chesstrainers.app/mislisha/manual.',
    );
  }
}
