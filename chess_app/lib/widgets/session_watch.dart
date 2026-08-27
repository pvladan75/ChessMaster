import 'package:flutter/material.dart';

import 'package:chess_app/services/session_service.dart';

/// Ends a session that ran out while the app was not being looked at.
///
/// The other two ways a dead token is noticed both need something to happen: a
/// request has to be made, or the socket has to try to connect. Neither does
/// anything for a phone left on the desk overnight with the app open — the
/// first thing the user does in the morning would fail instead, one layer away
/// from the place that could explain it.
///
/// Costs nothing to ask: the token carries its own `exp`, so this is a
/// comparison rather than a round trip, and it says nothing when the answer is
/// "still good" or "cannot tell".
///
/// Sits above the router in `main.dart` for the reason everything else up there
/// does: a question asked on one screen is a question the other forty never
/// ask.
class SessionWatch extends StatefulWidget {
  const SessionWatch({super.key, required this.child});

  final Widget child;

  @override
  State<SessionWatch> createState() => _SessionWatchState();
}

class _SessionWatchState extends State<SessionWatch>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Not awaited, and nothing here reacts to the result: the service notifies,
    // the router listens, and this widget's only job was to ask.
    SessionService.instance.expireIfTokenRanOut();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
