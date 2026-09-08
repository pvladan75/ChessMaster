import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/assignments/models/assignment.dart';

class PreviewAssignmentApiService extends AssignmentApiService {
  PreviewAssignmentApiService() : super(authToken: '');

  @override
  Future<void> markLessonStep(
      {required int assignmentId, required int position}) async {
    return; // no-op
  }

  @override
  Future<StepAnswerResult?> answerLessonStep({
    required int assignmentId,
    required int position,
    String? moveSan,
    int? choiceIndex,
  }) async {
    // Return a dummy incorrect verdict so it doesn't try to send to network
    // and doesn't trigger the "Tačno." condition in the UI.
    return const StepAnswerResult(
      correct: false,
      reason:
          'This is a preview of the assignment. The move was not sent to be checked.',
    );
  }

  @override
  Future<StepRevealResult?> revealLessonStep({
    required int assignmentId,
    required int position,
  }) async {
    return const StepRevealResult(solutionSan: 'Pregled');
  }
}
