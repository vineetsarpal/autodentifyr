import 'package:flutter/material.dart';

import 'package:autodentifyr/presentation/controllers/assessment_completion_controller.dart';
import 'package:autodentifyr/presentation/controllers/assessment_estimate_controller.dart';
import 'package:autodentifyr/presentation/controllers/assessment_evidence_controller.dart';
import 'package:autodentifyr/presentation/controllers/assessment_finding_review_controller.dart';
import 'package:autodentifyr/presentation/controllers/assessment_severity_controller.dart';
import 'package:autodentifyr/presentation/controllers/assessment_workflow_controller.dart';
import 'package:autodentifyr/presentation/controllers/assessment_progress.dart';
import 'package:autodentifyr/presentation/screens/assessment_completion_screen.dart';
import 'package:autodentifyr/presentation/screens/assessment_estimate_screen.dart';
import 'package:autodentifyr/presentation/screens/assessment_evidence_screen.dart';
import 'package:autodentifyr/presentation/screens/assessment_finding_review_screen.dart';
import 'package:autodentifyr/presentation/screens/assessment_severity_screen.dart';
import 'package:autodentifyr/presentation/screens/assessment_workflow_screen.dart';
import 'package:autodentifyr/services/assessment_estimate_source.dart';
import 'package:autodentifyr/services/assessment_evidence_service.dart';
import 'package:autodentifyr/services/assessment_report_service.dart';
import 'package:autodentifyr/services/assessment_report_delivery.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:autodentifyr/services/assessment_severity_source.dart';

/// Creates a workflow route that owns its lazy still-image inference service.
/// An injected [inferenceService] is also released when the route is disposed.
Future<AssessmentWorkflowScreen> openAssessmentWorkflowScreen({
  AssessmentRepository? repository,
  EvidenceFileStore? evidenceFileStore,
  AssessmentReportFileStore? reportFileStore,
  YoloEvidenceInferenceService? inferenceService,
  EvidenceAcquisitionService? acquisitionService,
}) async {
  final resolvedRepository =
      repository ?? await openDeviceLocalAssessmentRepository();
  final resolvedEvidenceFileStore =
      evidenceFileStore ?? await openDeviceEvidenceFileStore();
  final resolvedReportFileStore =
      reportFileStore ?? await openDeviceLocalAssessmentReportStore();
  final workflowInference = inferenceService ?? YoloEvidenceInferenceService();
  var sequence = 0;
  String nextId() {
    sequence++;
    return '${DateTime.now().toUtc().microsecondsSinceEpoch}-$sequence';
  }

  Future<T?> push<T>(BuildContext context, Widget screen) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));

  Widget stageScreen(
    BuildContext context,
    String assessmentId,
    AssessmentStage stage, {
    bool guided = false,
  }) {
    final onContinue = guided
        ? () => Navigator.of(context).pop<bool>(true)
        : null;
    return switch (stage) {
      AssessmentStage.evidence => AssessmentEvidenceScreen(
        controller: AssessmentEvidenceController(
          assessmentId: assessmentId,
          repository: resolvedRepository,
          acquisitionService:
              acquisitionService ?? ImagePickerEvidenceAcquisitionService(),
          inferenceService: workflowInference,
          fileStore: resolvedEvidenceFileStore,
          idGenerator: nextId,
          now: DateTime.now,
        ),
        onContinue: onContinue,
      ),
      AssessmentStage.findings => AssessmentFindingReviewScreen(
        controller: AssessmentFindingReviewController(
          assessmentId: assessmentId,
          repository: resolvedRepository,
          idGenerator: nextId,
          now: DateTime.now,
        ),
        onContinue: onContinue,
      ),
      AssessmentStage.severity => AssessmentSeverityScreen(
        controller: AssessmentSeverityController(
          assessmentId: assessmentId,
          repository: resolvedRepository,
          source: const UnavailableSeveritySuggestionSource(),
          now: DateTime.now,
        ),
        onContinue: onContinue,
      ),
      AssessmentStage.estimate => AssessmentEstimateScreen(
        controller: AssessmentEstimateController(
          assessmentId: assessmentId,
          repository: resolvedRepository,
          source: const UnavailableAssessmentEstimateSource(),
          idGenerator: nextId,
          now: DateTime.now,
        ),
        onContinue: onContinue,
      ),
      AssessmentStage.finalReview => AssessmentCompletionScreen(
        controller: AssessmentCompletionController(
          assessmentId: assessmentId,
          repository: resolvedRepository,
          idGenerator: nextId,
          now: DateTime.now,
        ),
        reportDelivery: DeviceAssessmentReportDelivery(resolvedReportFileStore),
      ),
    };
  }

  return AssessmentWorkflowScreen(
    onDispose: workflowInference.dispose,
    controller: AssessmentWorkflowController(
      repository: resolvedRepository,
      idGenerator: nextId,
      now: DateTime.now,
    ),
    openEvidence: (context, id) async =>
        push<void>(context, stageScreen(context, id, AssessmentStage.evidence)),
    openFindings: (context, id) async =>
        push<void>(context, stageScreen(context, id, AssessmentStage.findings)),
    openSeverity: (context, id) async =>
        push<void>(context, stageScreen(context, id, AssessmentStage.severity)),
    openEstimate: (context, id) async =>
        push<void>(context, stageScreen(context, id, AssessmentStage.estimate)),
    openCompletion: (context, id) async => push<void>(
      context,
      stageScreen(context, id, AssessmentStage.finalReview),
    ),
    openGuidedStage: (context, id, stage) =>
        push<bool>(context, stageScreen(context, id, stage, guided: true)),
  );
}
