import 'package:flutter/foundation.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:autodentifyr/services/assessment_severity_source.dart';

enum AssessmentSeverityPhase { idle, loading, ready, saving, failed }

class AssessmentSeverityControllerState {
  const AssessmentSeverityControllerState({
    this.phase = AssessmentSeverityPhase.idle,
    this.assessment,
    this.suggestionBatch,
    this.message,
  });

  final AssessmentSeverityPhase phase;
  final IntakeAssessment? assessment;
  final SeveritySuggestionBatch? suggestionBatch;
  final String? message;
}

class ReviewSeverityAction {
  const ReviewSeverityAction({
    required this.findingId,
    required this.reviewedLevel,
    required this.evidenceCaptureIds,
    required this.reason,
    this.uncertainty,
    this.additionalViewRequest,
    this.additionalViewOverrideReason,
    this.limitation,
  });

  final String findingId;
  final SeverityLevel reviewedLevel;
  final List<String> evidenceCaptureIds;
  final String reason;
  final String? uncertainty;
  final String? additionalViewRequest;
  final String? additionalViewOverrideReason;
  final String? limitation;
}

class AssessmentSeverityController extends ChangeNotifier {
  AssessmentSeverityController({
    required this.assessmentId,
    required AssessmentRepository repository,
    required SeveritySuggestionSource source,
    required DateTime Function() now,
  }) : _repository = repository,
       _source = source,
       _now = now;

  final String assessmentId;
  final AssessmentRepository _repository;
  final SeveritySuggestionSource _source;
  final DateTime Function() _now;

  AssessmentSeverityControllerState _state =
      const AssessmentSeverityControllerState();

  AssessmentSeverityControllerState get state => _state;

  Future<void> load() async {
    _emit(
      const AssessmentSeverityControllerState(
        phase: AssessmentSeverityPhase.loading,
      ),
    );
    try {
      final assessment = await _repository.findById(assessmentId);
      if (assessment == null) {
        _emit(
          const AssessmentSeverityControllerState(
            phase: AssessmentSeverityPhase.failed,
            message: 'Intake Assessment not found.',
          ),
        );
        return;
      }
      final confirmed = assessment.findings
          .where(
            (finding) => finding.reviewState == FindingReviewState.confirmed,
          )
          .toList();
      SeveritySuggestionBatch batch;
      try {
        batch = _validateBatch(
          await _source.suggest(confirmed, assessment.captures),
          confirmed,
        );
      } catch (_) {
        batch = const SeveritySuggestionBatch.unavailable(
          sourceVersion: 'severity-automation-unavailable-v1',
          limitation:
              'Automated severity review is unavailable; Appraiser review remains supported.',
        );
      }
      _emit(
        AssessmentSeverityControllerState(
          phase: AssessmentSeverityPhase.ready,
          assessment: assessment,
          suggestionBatch: batch,
        ),
      );
    } catch (error) {
      _emit(
        AssessmentSeverityControllerState(
          phase: AssessmentSeverityPhase.failed,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> submit(ReviewSeverityAction action) async {
    final assessment = _state.assessment;
    final batch = _state.suggestionBatch;
    if (assessment == null || batch == null) return;
    _emit(
      AssessmentSeverityControllerState(
        phase: AssessmentSeverityPhase.saving,
        assessment: assessment,
        suggestionBatch: batch,
      ),
    );
    try {
      SeveritySuggestion? suggestion;
      for (final candidate in batch.suggestions) {
        if (candidate.findingId == action.findingId) {
          suggestion = candidate;
          break;
        }
      }
      final previous = assessment.severityAssessments
          .where((value) => value.findingId == action.findingId)
          .firstOrNull;
      final preservedSuggestion = previous?.originalSuggestion;
      final severity = SeverityAssessment(
        findingId: action.findingId,
        reviewedLevel: action.reviewedLevel,
        originalSuggestion: preservedSuggestion ?? suggestion?.level,
        evidenceCaptureIds: List.unmodifiable(action.evidenceCaptureIds),
        reviewerProfileId: assessment.appraiserProfile.id,
        reviewedAt: _now().toUtc(),
        reason: action.reason,
        uncertainty: action.uncertainty,
        followUpNeed: action.additionalViewRequest,
        followUpOverrideReason: action.additionalViewOverrideReason,
        limitation: action.limitation,
        automationSourceVersion: preservedSuggestion != null
            ? previous!.automationSourceVersion
            : batch.sourceVersion,
        automationLimitation: preservedSuggestion != null
            ? previous!.automationLimitation
            : batch.limitation,
        suggestionEvidenceCaptureIds: preservedSuggestion != null
            ? previous!.suggestionEvidenceCaptureIds
            : suggestion?.evidenceCaptureIds ?? const [],
        suggestionIsSynthetic: preservedSuggestion != null
            ? previous!.suggestionIsSynthetic
            : suggestion != null && batch.isSynthetic,
        reviewHistory: [
          ...?previous?.reviewHistory,
          if (previous != null)
            SeverityReviewProvenance.fromAssessment(previous),
        ],
      );
      final updated = assessment.recordSeverity(severity);
      final result = await _repository.save(
        updated,
        expectedUpdatedAt: assessment.updatedAt,
      );
      if (result is AssessmentSaveFailed) {
        throw AssessmentInvariantViolation(result.message);
      }
      _emit(
        AssessmentSeverityControllerState(
          phase: AssessmentSeverityPhase.ready,
          assessment: updated,
          suggestionBatch: batch,
        ),
      );
    } catch (error) {
      _emit(
        AssessmentSeverityControllerState(
          phase: AssessmentSeverityPhase.failed,
          assessment: assessment,
          suggestionBatch: batch,
          message: error is AssessmentInvariantViolation
              ? error.message
              : error.toString(),
        ),
      );
    }
  }

  SeveritySuggestionBatch _validateBatch(
    SeveritySuggestionBatch batch,
    List<DamageFinding> confirmed,
  ) {
    if (batch.sourceVersion.trim().isEmpty ||
        (!batch.isSupported &&
            (batch.suggestions.isNotEmpty ||
                (batch.limitation?.trim().isEmpty ?? true)))) {
      throw const FormatException('Invalid severity automation provenance.');
    }
    final findingById = {for (final finding in confirmed) finding.id: finding};
    final suggestedFindingIds = <String>{};
    for (final suggestion in batch.suggestions) {
      final finding = findingById[suggestion.findingId];
      if (!batch.isSupported ||
          finding == null ||
          !suggestedFindingIds.add(suggestion.findingId) ||
          suggestion.level == SeverityLevel.undetermined ||
          suggestion.evidenceCaptureIds.isEmpty ||
          suggestion.evidenceCaptureIds.toSet().length !=
              suggestion.evidenceCaptureIds.length ||
          !finding.supportingCaptureIds.toSet().containsAll(
            suggestion.evidenceCaptureIds,
          )) {
        throw const FormatException('Invalid severity suggestion.');
      }
    }
    return batch;
  }

  void _emit(AssessmentSeverityControllerState state) {
    _state = state;
    notifyListeners();
  }
}
