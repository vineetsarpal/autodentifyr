import 'package:autodentifyr/presentation/controllers/assessment_finding_review_controller.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

Future<AssessmentFindingReviewController> openAssessmentFindingReviewController(
  String assessmentId,
) async {
  final repository = await openDeviceLocalAssessmentRepository();
  var sequence = 0;
  String nextId() {
    sequence++;
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}-$sequence';
  }

  return AssessmentFindingReviewController(
    assessmentId: assessmentId,
    repository: repository,
    idGenerator: nextId,
    now: DateTime.now,
  );
}
