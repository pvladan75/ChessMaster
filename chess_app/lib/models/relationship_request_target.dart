/// Where a teaching request goes, and under which key.
///
/// The relationship has always had two directions on the server — the same
/// request, differing only in who ends up as the trainer — but the app could
/// only ever send one of them, so whoever typed the other's email became the
/// trainer by accident of who clicked first. The direction is now the sender's
/// choice, and this is the one place that knows what each choice means on the
/// wire.
///
/// The two endpoints spell the email field differently. That is not a detail
/// worth hiding: sending `studentEmail` to the trainer-request route fails with
/// "email je obavezan", which says nothing about roles and has already cost one
/// debugging session in this codebase.
class RelationshipRequestTarget {
  final String path;
  final String emailField;

  const RelationshipRequestTarget(
      {required this.path, required this.emailField});

  /// I am the trainer; the other person would be my student.
  static const asTrainer = RelationshipRequestTarget(
    path: '/trainer/students/add',
    emailField: 'studentEmail',
  );

  /// I am the student; the other person would be my trainer.
  static const asStudent = RelationshipRequestTarget(
    path: '/students/trainers/request',
    emailField: 'trainerEmail',
  );

  static RelationshipRequestTarget forRole({required bool iAmTrainer}) =>
      iAmTrainer ? asTrainer : asStudent;
}
