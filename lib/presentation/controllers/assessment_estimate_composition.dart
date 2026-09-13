import 'package:autodentifyr/presentation/controllers/assessment_estimate_controller.dart';
import 'package:autodentifyr/services/assessment_estimate_source.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

Future<AssessmentEstimateController> openAssessmentEstimateController(
  String assessmentId,
) async {
  final repository = await openDeviceLocalAssessmentRepository();
  var sequence = 0;
  String nextId() {
    sequence++;
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}-$sequence';
  }

  return AssessmentEstimateController(
    assessmentId: assessmentId,
    repository: repository,
    source: const UnavailableAssessmentEstimateSource(),
    idGenerator: nextId,
    now: DateTime.now,
  );
}
