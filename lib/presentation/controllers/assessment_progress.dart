import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_completion_controller.dart';

enum AssessmentStage { evidence, findings, severity, estimate, finalReview }

extension AssessmentStageOrder on AssessmentStage {
  AssessmentStage? get next => switch (this) {
    AssessmentStage.evidence => AssessmentStage.findings,
    AssessmentStage.findings => AssessmentStage.severity,
    AssessmentStage.severity => AssessmentStage.estimate,
    AssessmentStage.estimate => AssessmentStage.finalReview,
    AssessmentStage.finalReview => null,
  };
}

class AssessmentProgress {
  AssessmentProgress._(this.assessment, this.blockers);

  factory AssessmentProgress.fromAssessment(IntakeAssessment assessment) =>
      AssessmentProgress._(assessment, completionBlockersFor(assessment));

  final IntakeAssessment assessment;
  final List<CompletionBlocker> blockers;

  int get outstandingCount => blockers.length;

  int outstandingFor(AssessmentStage stage) => blockers.where((blocker) {
    return switch (stage) {
      AssessmentStage.evidence =>
        blocker.code == CompletionBlockerCode.acceptedCaptureRequired,
      AssessmentStage.findings =>
        blocker.code == CompletionBlockerCode.unreviewedFinding ||
            blocker.code ==
                CompletionBlockerCode.findingEvidenceOverrideRequired,
      AssessmentStage.severity =>
        blocker.code == CompletionBlockerCode.severityReviewRequired ||
            blocker.code ==
                CompletionBlockerCode.severityEvidenceOverrideRequired,
      AssessmentStage.estimate =>
        blocker.code == CompletionBlockerCode.estimateReviewRequired ||
            blocker.code ==
                CompletionBlockerCode.estimateFindingCoverageRequired ||
            blocker.code ==
                CompletionBlockerCode.partialEstimateAcknowledgmentRequired,
      AssessmentStage.finalReview => true,
    };
  }).length;

  String? prerequisiteFor(AssessmentStage stage) {
    if (stage != AssessmentStage.evidence &&
        stage != AssessmentStage.finalReview &&
        assessment.captures.isEmpty) {
      return 'Add evidence first';
    }
    if (stage == AssessmentStage.severity &&
        outstandingFor(AssessmentStage.findings) > 0) {
      return 'Review findings first';
    }
    return null;
  }

  bool readyFor(AssessmentStage stage) =>
      prerequisiteFor(stage) == null && outstandingFor(stage) == 0;

  int get readyStageCount => AssessmentStage.values.where(readyFor).length;

  int get acceptedCaptureCount => assessment.captures.length;

  int get proposedDecisionCount => assessment.findings
      .where(
        (finding) =>
            finding.reviewState == FindingReviewState.proposed &&
            finding.reviewOutcome == null,
      )
      .length;

  int get confirmedFindingCount => assessment.findings
      .where((finding) => finding.reviewState == FindingReviewState.confirmed)
      .length;

  int get currentSeverityReviewCount => assessment.findings
      .where(
        (finding) =>
            finding.reviewState == FindingReviewState.confirmed &&
            assessment.isSeverityReviewCurrentFor(finding),
      )
      .length;

  int get currentEstimateReviewCount => assessment.findings
      .where(
        (finding) =>
            finding.reviewState == FindingReviewState.confirmed &&
            assessment.isEstimateReviewCurrentFor(finding),
      )
      .length;
}
