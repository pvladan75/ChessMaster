import 'package:flutter/material.dart';

import 'package:chess_app/features/groups/screens/groups_screen.dart';
import 'package:chess_app/features/trainer_panel/models/trainer_panel.dart';
import 'package:chess_app/features/trainer_panel/widgets/trainer_panel_view.dart';

/// The "Prijatelji" tab: add-by-email form plus the current friends list.
class HomeFriendsTab extends StatelessWidget {
  final TextEditingController studentEmailController;
  final bool isLoadingStudents;

  /// People I teach. The tab used to draw only these, so someone who had a
  /// trainer but no students was told they had nobody at all.
  final List<dynamic> students;

  /// People who teach me — the same relationships read from the other end.
  final List<dynamic> trainers;

  /// Requests waiting for *this* user to answer, in either direction — a
  /// trainer who enrolled them, or a student asking them to coach.

  final VoidCallback onAddStudent;
  final ValueChanged<int> onDeleteStudent;

  /// Which side the sender is claiming for the request they are about to send.
  /// Sending one is not "adding a student": it says who teaches whom, and the
  /// other person answers that exact claim.
  final bool iAmTrainerInRequest;
  final ValueChanged<bool> onRoleChanged;

  /// Pull to refresh. The other side answers on their own device, so this
  /// screen can be out of date without anything having gone wrong.
  final Future<void> Function() onRefresh;

  /// Opens the student's progress report. Receives the raw row so the caller
  /// keeps the id and the display name together.
  final void Function(Map<String, dynamic> student) onOpenProgress;

  /// Opens the place where a missing parent address is filled in. Handed in
  /// rather than opened here so the tab stays a tab: the dialog belongs to the
  /// screen that owns the session.
  final VoidCallback onFixParentEmail;

  /// The trainer's day, drawn above the list of people.
  ///
  /// It lives here rather than in a fifth tab because teaching is a position in
  /// a relationship, not a property of an account: a destination of its own
  /// would be empty for everybody who teaches nobody. This tab is already the
  /// one that exists because of a relationship, and it already knows how to
  /// draw nothing when there is none.
  final TrainerPanel panel;

  /// Enters a lesson this trainer is hosting.
  final void Function(String roomCode) onEnterLesson;

  /// Opens one piece of homework from the panel.
  final void Function(PanelAssignment assignment) onOpenPanelAssignment;

  const HomeFriendsTab({
    super.key,
    required this.studentEmailController,
    required this.isLoadingStudents,
    required this.students,
    required this.trainers,
    required this.onAddStudent,
    required this.onDeleteStudent,
    required this.iAmTrainerInRequest,
    required this.onRoleChanged,
    required this.onRefresh,
    required this.onOpenProgress,
    required this.onFixParentEmail,
    this.panel = TrainerPanel.empty,
    required this.onEnterLesson,
    required this.onOpenPanelAssignment,
  });

  /// Everyone, in whatever state the relationship is.
  ///
  /// This used to hide requests waiting on *me*, because they were also shown
  /// as an answerable card above and the same person would have appeared twice.
  /// The answer moved to the bell, so the card is gone and there is nothing to
  /// hide from: a pending row here says somebody is waiting, and says which of
  /// us is being waited on.
  List<dynamic> get myStudents => students;
  List<dynamic> get myTrainers => trainers;

  /// One person, from whichever end. `iTeachThem` decides only what the row
  /// offers: homework and progress belong to the teaching side, and breaking
  /// the relationship belongs to both — consent that cannot be withdrawn from
  /// one side is not consent.
  List<Widget> _rows(List<dynamic> rows, {required bool iTeachThem}) {
    return rows.map((r) {
      // Three states, not two. `awaiting_parent` is a relationship both people
      // agreed to that still does not exist, because a parent has not answered
      // — and a row that drew it as "Vaš učenik" would say a trainer may teach
      // a child they may not.
      final status = r['status'];
      final awaitingParent = status == 'awaiting_parent';
      final isPending = status == 'pending';
      final notYet = isPending || awaitingParent;
      // The child's own side of a wait on their parent is the one row here
      // that has something to do, so it stays enabled: `ListTile` drops
      // `onTap` entirely when it is not, which would have made the tap target
      // look right and do nothing.
      final actionable = awaitingParent && !iTeachThem;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        enabled: !notYet || actionable,
        leading: CircleAvatar(
          backgroundColor: notYet ? Colors.grey.shade700 : null,
          child: Icon(awaitingParent
              ? Icons.family_restroom
              : (isPending
                  ? Icons.hourglass_empty
                  : (iTeachThem ? Icons.person : Icons.school))),
        ),
        title: Text(r['name'] ?? 'Korisnik',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          // Which of the two is being waited on decides what this row is for:
          // one is a reminder, the other is something to go and do.
          //
          // The address used to stand here and no longer arrives: a list of
          // people, most of them children, is not the place for their emails.
          // What is left is what the row is actually about.
          awaitingParent
              ? (iTeachThem
                  ? 'Čeka saglasnost roditelja'
                  : 'Čeka saglasnost roditelja — dodirnite')
              : (isPending
                  ? (r['i_asked'] == true
                      ? 'Čeka potvrdu'
                      : 'Odgovorite u zvoncetu')
                  : (iTeachThem ? 'Vaš učenik' : 'Vaš trener')),
        ),
        // The student's own side of a row waiting on a parent is the one place
        // where the wait can be ended: without an address on the account
        // nobody was ever written to, and Settings is not where a child would
        // think to look.
        onTap: awaitingParent
            ? (iTeachThem ? null : () => onFixParentEmail())
            : ((isPending || !iTeachThem)
                ? null
                : () => onOpenProgress(Map<String, dynamic>.from(r))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iTeachThem)
              IconButton(
                icon: const Icon(Icons.insights, size: 20),
                tooltip: awaitingParent
                    ? 'Dostupno kad roditelj potvrdi'
                    : (isPending
                        ? 'Dostupno kad učenik prihvati'
                        : 'Napredak i zadaci'),
                onPressed: notYet
                    ? null
                    : () => onOpenProgress(Map<String, dynamic>.from(r)),
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
              tooltip:
                  iTeachThem ? 'Raskini odnos' : 'Raskini odnos sa trenerom',
              onPressed: () => onDeleteStudent(r['id']),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    return SingleChildScrollView(
      // Always scrollable so the pull gesture exists even when the list is
      // short enough to fit — which is exactly when there is nothing on screen
      // to explain why it looks stale.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Above the list, because it is what the trainer came for: the
              // list answers "who", the panel answers "what now".
              TrainerPanelView(
                panel: panel,
                onEnterLesson: onEnterLesson,
                onOpenAssignment: onOpenPanelAssignment,
                onOpenStudent: (id, name) =>
                    onOpenProgress({'id': id, 'name': name}),
              ),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people,
                              color: Colors.purpleAccent, size: 28),
                          const SizedBox(width: 12),
                          // Expanded, not a bare Text: at 360 px this title is
                          // wider than the card and overflowed off the right
                          // edge. Only the phone shows it, and the tab had
                          // never been rendered at that width.
                          const Expanded(
                            child: Text('Moji Prijatelji & Kontakti',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          // Groups live here because they are lists of the
                          // people on this very screen. Shown only to somebody
                          // who teaches: a group is a list of *your* students,
                          // and a student has none.
                          if (myStudents.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.groups,
                                  color: Colors.purpleAccent),
                              tooltip: 'Grupe učenika',
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GroupsScreen(students: students),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // The direction is stated before the address, because it
                      // changes what the address means: the same email is a
                      // student in one reading and a trainer in the other.
                      // Chips rather than a segmented button so the pair wraps
                      // instead of overflowing on a ~360 px screen.
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: const Text('Ja sam trener'),
                            selected: iAmTrainerInRequest,
                            onSelected: (_) => onRoleChanged(true),
                          ),
                          ChoiceChip(
                            label: const Text('Ja sam učenik'),
                            selected: !iAmTrainerInRequest,
                            onSelected: (_) => onRoleChanged(false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        iAmTrainerInRequest
                            ? 'Vi predajete, druga strana je učenik.'
                            : 'Druga strana predaje, vi ste učenik.',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: studentEmailController,
                              decoration: InputDecoration(
                                labelText: iAmTrainerInRequest
                                    ? 'Email učenika'
                                    : 'Email trenera',
                                hintText: 'osoba@example.com',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: onAddStudent,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            child: const Text('Pošalji zahtev'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      const Divider(),
                      const SizedBox(height: 8),
                      if (isLoadingStudents)
                        const Center(child: CircularProgressIndicator())
                      else if (myStudents.isEmpty && myTrainers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                              child: Text('Još nemate ni učenika ni trenera.',
                                  style: TextStyle(color: Colors.grey))),
                        )
                      else ...[
                        if (myStudents.isNotEmpty) ...[
                          const Text('Moji učenici',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          ..._rows(myStudents, iTeachThem: true),
                        ],
                        if (myStudents.isNotEmpty && myTrainers.isNotEmpty)
                          const SizedBox(height: 16),
                        if (myTrainers.isNotEmpty) ...[
                          const Text('Moji treneri',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          ..._rows(myTrainers, iTeachThem: false),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
