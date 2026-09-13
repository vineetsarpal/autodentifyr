import 'package:autodentifyr/presentation/controllers/assessment_evidence_controller.dart';
import 'package:autodentifyr/services/assessment_evidence_service.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

Future<AssessmentEvidenceController> openAssessmentEvidenceController(
  String assessmentId,
) async {
  final repository = await openDeviceLocalAssessmentRepository();
  final fileStore = await openDeviceEvidenceFileStore();
  var sequence = 0;
  String nextId() {
    sequence++;
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}-$sequence';
  }

  return AssessmentEvidenceController(
    assessmentId: assessmentId,
    repository: repository,
    acquisitionService: ImagePickerEvidenceAcquisitionService(),
    inferenceService: YoloEvidenceInferenceService(),
    fileStore: fileStore,
    idGenerator: nextId,
    now: DateTime.now,
  );
}
