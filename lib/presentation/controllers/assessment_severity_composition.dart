import 'package:autodentifyr/presentation/controllers/assessment_severity_controller.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:autodentifyr/services/assessment_severity_source.dart';

Future<AssessmentSeverityController> openAssessmentSeverityController(
  String assessmentId,
) async => AssessmentSeverityController(
  assessmentId: assessmentId,
  repository: await openDeviceLocalAssessmentRepository(),
  source: const UnavailableSeveritySuggestionSource(),
  now: DateTime.now,
);
