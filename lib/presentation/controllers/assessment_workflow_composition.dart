import 'package:flutter/material.dart';

import 'package:autodentifyr/presentation/controllers/assessment_completion_controller.dart';
import 'package:autodentifyr/presentation/controllers/assessment_estimate_controller.dart';
import 'package:autodentifyr/presentation/controllers/assessment_evidence_controller.dart';
import 'package:autodentifyr/presentation/controllers/assessment_finding_review_controller.dart';
import 'package:autodentifyr/presentation/controllers/assessment_severity_controller.dart';
import 'package:autodentifyr/presentation/controllers/assessment_workflow_controller.dart';
import 'package:autodentifyr/presentation/screens/assessment_completion_screen.dart';
import 'package:autodentifyr/presentation/screens/assessment_estimate_screen.dart';
import 'package:autodentifyr/presentation/screens/assessment_evidence_screen.dart';
import 'package:autodentifyr/presentation/screens/assessment_finding_review_screen.dart';
import 'package:autodentifyr/presentation/screens/assessment_severity_screen.dart';
import 'package:autodentifyr/presentation/screens/assessment_workflow_screen.dart';
import 'package:autodentifyr/services/assessment_estimate_source.dart';
import 'package:autodentifyr/services/assessment_evidence_service.dart';
import 'package:autodentifyr/services/assessment_report_service.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:autodentifyr/services/assessment_severity_source.dart';

Future<AssessmentWorkflowScreen> openAssessmentWorkflowScreen() async {
  final repository = await openDeviceLocalAssessmentRepository();
  final evidenceFileStore = await openDeviceEvidenceFileStore();
  final reportFileStore = await openDeviceLocalAssessmentReportStore();
  var sequence = 0;
  String nextId() {
    sequence++;
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}-$sequence';
  }

  Future<void> push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  return AssessmentWorkflowScreen(
    controller: AssessmentWorkflowController(
      repository: repository,
      idGenerator: nextId,
      now: DateTime.now,
    ),
    openEvidence: (context, assessmentId) => push(
      context,
      AssessmentEvidenceScreen(
        controller: AssessmentEvidenceController(
          assessmentId: assessmentId,
          repository: repository,
          acquisitionService: ImagePickerEvidenceAcquisitionService(),
          inferenceService: YoloEvidenceInferenceService(),
          fileStore: evidenceFileStore,
          idGenerator: nextId,
          now: DateTime.now,
        ),
      ),
    ),
    openFindings: (context, assessmentId) => push(
      context,
      AssessmentFindingReviewScreen(
        controller: AssessmentFindingReviewController(
          assessmentId: assessmentId,
          repository: repository,
          idGenerator: nextId,
          now: DateTime.now,
        ),
      ),
    ),
    openEstimate: (context, assessmentId) => push(
      context,
      AssessmentEstimateScreen(
        controller: AssessmentEstimateController(
          assessmentId: assessmentId,
          repository: repository,
          source: const UnavailableAssessmentEstimateSource(),
          idGenerator: nextId,
          now: DateTime.now,
        ),
      ),
    ),
    openSeverity: (context, assessmentId) => push(
      context,
      AssessmentSeverityScreen(
        controller: AssessmentSeverityController(
          assessmentId: assessmentId,
          repository: repository,
          source: const UnavailableSeveritySuggestionSource(),
          now: DateTime.now,
        ),
      ),
    ),
    openCompletion: (context, assessmentId) => push(
      context,
      AssessmentCompletionScreen(
        controller: AssessmentCompletionController(
          assessmentId: assessmentId,
          repository: repository,
          idGenerator: nextId,
          now: DateTime.now,
        ),
        onReportArtifact: reportFileStore.save,
      ),
    ),
  );
}
