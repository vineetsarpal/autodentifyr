import 'package:flutter/foundation.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

enum AssessmentCompletionPhase { idle, loading, ready, saving, failed }

enum CompletionBlockerCode {
  acceptedCaptureRequired,
  unreviewedFinding,
  estimateReviewRequired,
  estimateFindingCoverageRequired,
  partialEstimateAcknowledgmentRequired,
  severityReviewRequired,
  findingEvidenceOverrideRequired,
  severityEvidenceOverrideRequired,
  noVisibleDamageConfirmationRequired,
}

class CompletionBlocker {
  const CompletionBlocker({required this.code, required this.message});

  final CompletionBlockerCode code;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is CompletionBlocker &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(code, message);
}

class AssessmentCompletionState {
  const AssessmentCompletionState({
    this.phase = AssessmentCompletionPhase.idle,
    this.assessment,
    this.completionBlockers = const [],
    this.message,
  });

  final AssessmentCompletionPhase phase;
  final IntakeAssessment? assessment;
  final List<CompletionBlocker> completionBlockers;
  final String? message;

  PreliminaryDamageAssessmentRevision? get latestRevision {
    final revisions = assessment?.completedRevisions;
    return revisions == null || revisions.isEmpty ? null : revisions.last;
  }
}

class AssessmentCompletionController extends ChangeNotifier {
  AssessmentCompletionController({
    required this.assessmentId,
    required AssessmentRepository repository,
    required String Function() idGenerator,
    required DateTime Function() now,
  }) : _repository = repository,
       _idGenerator = idGenerator,
       _now = now;

  final String assessmentId;
  final AssessmentRepository _repository;
  final String Function() _idGenerator;
  final DateTime Function() _now;

  AssessmentCompletionState _state = const AssessmentCompletionState();

  AssessmentCompletionState get state => _state;

  Future<void> load() async {
    _emit(
      const AssessmentCompletionState(phase: AssessmentCompletionPhase.loading),
    );
    try {
      final assessment = await _repository.findById(assessmentId);
      if (assessment == null) {
        _emit(
          const AssessmentCompletionState(
            phase: AssessmentCompletionPhase.failed,
            message: 'Intake Assessment not found.',
          ),
        );
        return;
      }
      _emit(
        AssessmentCompletionState(
          phase: AssessmentCompletionPhase.ready,
          assessment: assessment,
          completionBlockers: _completionBlockers(assessment),
        ),
      );
    } catch (error) {
      _emit(
        AssessmentCompletionState(
          phase: AssessmentCompletionPhase.failed,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> complete({required bool noVisibleDamageConfirmed}) async {
    final assessment = _state.assessment;
    if (assessment == null) return;
    final blockers = _completionBlockers(assessment)
        .where(
          (blocker) =>
              blocker.code !=
                  CompletionBlockerCode.noVisibleDamageConfirmationRequired ||
              !noVisibleDamageConfirmed,
        )
        .toList();
    if (blockers.isNotEmpty) {
      _emit(
        AssessmentCompletionState(
          phase: AssessmentCompletionPhase.failed,
          assessment: assessment,
          completionBlockers: blockers,
          message: blockers.first.message,
        ),
      );
      return;
    }
    _emit(
      AssessmentCompletionState(
        phase: AssessmentCompletionPhase.saving,
        assessment: assessment,
      ),
    );
    try {
      final completed = assessment.complete(
        revisionId: _idGenerator(),
        completedAt: _now(),
        noVisibleDamageConfirmed: noVisibleDamageConfirmed,
      );
      final result = await _repository.save(
        completed,
        expectedUpdatedAt: assessment.updatedAt,
      );
      if (result is AssessmentSaveFailed) {
        throw AssessmentInvariantViolation(result.message);
      }
      _emit(
        AssessmentCompletionState(
          phase: AssessmentCompletionPhase.ready,
          assessment: completed,
        ),
      );
    } catch (error) {
      _emit(
        AssessmentCompletionState(
          phase: AssessmentCompletionPhase.failed,
          assessment: assessment,
          completionBlockers: _completionBlockers(assessment),
          message: error is AssessmentInvariantViolation
              ? error.message
              : error.toString(),
        ),
      );
    }
  }

  Future<void> updateLimitations(List<String> limitations) async {
    final assessment = _state.assessment;
    if (assessment == null) return;
    _emit(
      AssessmentCompletionState(
        phase: AssessmentCompletionPhase.saving,
        assessment: assessment,
      ),
    );
    try {
      final updated = assessment.recordLimitations(
        limitations: limitations,
        reviewedAt: _now(),
      );
      final result = await _repository.save(
        updated,
        expectedUpdatedAt: assessment.updatedAt,
      );
      if (result is AssessmentSaveFailed) {
        throw AssessmentInvariantViolation(result.message);
      }
      _emit(
        AssessmentCompletionState(
          phase: AssessmentCompletionPhase.ready,
          assessment: updated,
          completionBlockers: _completionBlockers(updated),
        ),
      );
    } catch (error) {
      _emit(
        AssessmentCompletionState(
          phase: AssessmentCompletionPhase.failed,
          assessment: assessment,
          completionBlockers: _completionBlockers(assessment),
          message: error is AssessmentInvariantViolation
              ? error.message
              : error.toString(),
        ),
      );
    }
  }

  Future<void> reopen() async {
    final assessment = _state.assessment;
    if (assessment == null) return;
    _emit(
      AssessmentCompletionState(
        phase: AssessmentCompletionPhase.saving,
        assessment: assessment,
      ),
    );
    try {
      final reopened = assessment.reopen(reopenedAt: _now());
      final result = await _repository.save(
        reopened,
        expectedUpdatedAt: assessment.updatedAt,
      );
      if (result is AssessmentSaveFailed) {
        throw AssessmentInvariantViolation(result.message);
      }
      _emit(
        AssessmentCompletionState(
          phase: AssessmentCompletionPhase.ready,
          assessment: reopened,
          completionBlockers: _completionBlockers(reopened),
        ),
      );
    } catch (error) {
      _emit(
        AssessmentCompletionState(
          phase: AssessmentCompletionPhase.failed,
          assessment: assessment,
          message: error is AssessmentInvariantViolation
              ? error.message
              : error.toString(),
        ),
      );
    }
  }

  Future<void> voidAssessment({required String reason}) async {
    final assessment = _state.assessment;
    if (assessment == null) return;
    _emit(
      AssessmentCompletionState(
        phase: AssessmentCompletionPhase.saving,
        assessment: assessment,
      ),
    );
    try {
      final voided = assessment.voidAssessment(
        voidedAt: _now(),
        reason: reason,
      );
      final result = await _repository.save(
        voided,
        expectedUpdatedAt: assessment.updatedAt,
      );
      if (result is AssessmentSaveFailed) {
        throw AssessmentInvariantViolation(result.message);
      }
      _emit(
        AssessmentCompletionState(
          phase: AssessmentCompletionPhase.ready,
          assessment: voided,
        ),
      );
    } catch (error) {
      _emit(
        AssessmentCompletionState(
          phase: AssessmentCompletionPhase.failed,
          assessment: assessment,
          message: error is AssessmentInvariantViolation
              ? error.message
              : error.toString(),
        ),
      );
    }
  }

  List<CompletionBlocker> _completionBlockers(
    IntakeAssessment assessment,
  ) => List.unmodifiable([
    if (assessment.status != IntakeAssessmentStatus.draft)
      ...const <CompletionBlocker>[]
    else ...[
      if (assessment.captures.isEmpty)
        const CompletionBlocker(
          code: CompletionBlockerCode.acceptedCaptureRequired,
          message: 'Accept at least one Capture before completing.',
        ),
      for (final finding in assessment.findings)
        if (finding.reviewState == FindingReviewState.proposed &&
            finding.reviewOutcome == null)
          CompletionBlocker(
            code: CompletionBlockerCode.unreviewedFinding,
            message: 'Review Proposed Finding ${finding.id} before completing.',
          ),
      for (final finding in assessment.findings)
        if (finding.reviewOutcome == FindingReviewOutcome.undetermined &&
            finding.additionalViewRequests.isNotEmpty &&
            (finding.additionalViewOverrideReason?.trim().isEmpty ?? true))
          CompletionBlocker(
            code: CompletionBlockerCode.findingEvidenceOverrideRequired,
            message:
                'Explain why the additional-view request for Finding ${finding.id} is being overridden.',
          ),
      if (assessment.estimate == null)
        const CompletionBlocker(
          code: CompletionBlockerCode.estimateReviewRequired,
          message: 'Review the Assessment Estimate before completing.',
        ),
      if (assessment.estimate case final estimate?)
        for (final finding in assessment.findings)
          if (finding.reviewState == FindingReviewState.confirmed &&
              !estimate.operations.any(
                (operation) => operation.findingIds.contains(finding.id),
              ))
            CompletionBlocker(
              code: CompletionBlockerCode.estimateFindingCoverageRequired,
              message:
                  'Review a Repair Operation or explicit missing pricing for Confirmed Finding ${finding.id}.',
            ),
      if (assessment.estimate != null)
        for (final finding in assessment.findings)
          if (finding.reviewState == FindingReviewState.confirmed &&
              !assessment.isEstimateReviewCurrentFor(finding))
            CompletionBlocker(
              code: CompletionBlockerCode.estimateReviewRequired,
              message:
                  'Review the Assessment Estimate after changing Confirmed Finding ${finding.id}.',
            ),
      if (assessment.estimate case final estimate?
          when estimate.isPartial &&
              estimate.missingPricingAcknowledgedAt == null)
        const CompletionBlocker(
          code: CompletionBlockerCode.partialEstimateAcknowledgmentRequired,
          message:
              'Acknowledge the Partial Estimate\'s missing pricing before completing.',
        ),
      for (final finding in assessment.findings)
        if (finding.reviewState == FindingReviewState.confirmed &&
            !assessment.isSeverityReviewCurrentFor(finding))
          CompletionBlocker(
            code: CompletionBlockerCode.severityReviewRequired,
            message:
                'Review Severity for Confirmed Finding ${finding.id} before completing.',
          ),
      for (final severity in assessment.severityAssessments)
        if (severity.followUpNeed != null &&
            (severity.followUpOverrideReason?.trim().isEmpty ?? true))
          CompletionBlocker(
            code: CompletionBlockerCode.severityEvidenceOverrideRequired,
            message:
                'Explain why the Severity additional-view request for Finding ${severity.findingId} is being overridden.',
          ),
      if (!assessment.findings.any(
        (finding) => finding.reviewState == FindingReviewState.confirmed,
      ))
        const CompletionBlocker(
          code: CompletionBlockerCode.noVisibleDamageConfirmationRequired,
          message:
              'Confirm that no supported visible exterior damage was found.',
        ),
    ],
  ]);

  void _emit(AssessmentCompletionState state) {
    _state = state;
    notifyListeners();
  }
}
