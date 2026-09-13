import 'package:autodentifyr/presentation/controllers/assessment_completion_controller.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

Future<AssessmentCompletionController> openAssessmentCompletionController(
  String assessmentId,
) async {
  final repository = await openDeviceLocalAssessmentRepository();
  var sequence = 0;
  String nextId() {
    sequence++;
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}-$sequence';
  }

  return AssessmentCompletionController(
    assessmentId: assessmentId,
    repository: repository,
    idGenerator: nextId,
    now: DateTime.now,
  );
}
