import 'package:flutter/material.dart';

import 'package:chess_app/models/user_session.dart';

import '../models/assignment.dart';
import '../services/assignment_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';

/// Turns an assignment id into the assignment, for screens that need the whole
/// thing.
///
/// Two of the assignment screens are built from an `AssignmentDetail` rather
/// than from an id, which is fine when they are opened from the list that
/// already has one and useless from a link, a restored session or a test. A
/// route that only works when somebody hands it an object is a route in name
/// only.
///
/// So the id is the contract and the object is the shortcut: pass [detail] when
/// it is already in hand and nothing is fetched; leave it out and it is
/// fetched here. One place does that for both screens, and neither of them had
/// to learn about loading states to get a path.
class AssignmentDetailGate extends StatefulWidget {
  const AssignmentDetailGate({
    super.key,
    required this.session,
    required this.assignmentId,
    required this.builder,
    this.detail,
    this.api,
  });

  final UserSession session;
  final int assignmentId;

  /// Already in hand, from the list that was tapped. Skips the request.
  final AssignmentDetail? detail;

  final Widget Function(AssignmentDetail detail) builder;

  /// For tests, which have no server to answer.
  final AssignmentApiService? api;

  @override
  State<AssignmentDetailGate> createState() => _AssignmentDetailGateState();
}

class _AssignmentDetailGateState extends State<AssignmentDetailGate> {
  late final AssignmentApiService _api =
      widget.api ?? AssignmentApiService(authToken: widget.session.token);

  AssignmentDetail? _detail;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _detail = widget.detail;
    if (_detail == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final detail = await _api.fetchDetail(widget.assignmentId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _detail = detail;
      // Said out loud rather than shown as an empty screen. A blank assignment
      // reads as an assignment with nothing in it, which is a different thing
      // from one that could not be fetched.
      _error = detail == null ? 'Zadatak nije moguće učitati.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail != null) return widget.builder(detail);

    return Scaffold(
      appBar: AppBar(title: const Text('Zadatak')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off,
                      size: 40, color: context.colors.textMuted),
                  const SizedBox(height: AppSpacing.md),
                  Text(_error ?? 'Zadatak nije pronađen.'),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Pokušaj ponovo'),
                  ),
                ],
              ),
      ),
    );
  }
}
