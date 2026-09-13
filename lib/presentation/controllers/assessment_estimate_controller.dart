import 'package:flutter/foundation.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/services/assessment_estimate_source.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

enum AssessmentEstimatePhase { idle, loading, ready, calculating, failed }

class AssessmentEstimateControllerState {
  const AssessmentEstimateControllerState({
    this.phase = AssessmentEstimatePhase.idle,
    this.assessment,
    this.message,
  });

  final AssessmentEstimatePhase phase;
  final IntakeAssessment? assessment;
  final String? message;
}

sealed class AssessmentEstimateAction {
  const AssessmentEstimateAction();
}

class RecalculateEstimateAction extends AssessmentEstimateAction {
  const RecalculateEstimateAction();
}

class OverrideRepairOperationAction extends AssessmentEstimateAction {
  const OverrideRepairOperationAction({
    required this.operationId,
    required this.description,
    required this.reason,
    this.minimumCents,
    this.maximumCents,
    this.currency,
    this.pricingSourceVersion,
  });

  final String operationId;
  final String description;
  final String reason;
  final int? minimumCents;
  final int? maximumCents;
  final String? currency;
  final String? pricingSourceVersion;
}

class EditEstimateAssumptionsAction extends AssessmentEstimateAction {
  const EditEstimateAssumptionsAction(this.assumptions);

  final List<String> assumptions;
}

class AcknowledgePartialEstimateAction extends AssessmentEstimateAction {
  const AcknowledgePartialEstimateAction();
}

class AssessmentEstimateController extends ChangeNotifier {
  AssessmentEstimateController({
    required this.assessmentId,
    required AssessmentRepository repository,
    required AssessmentEstimateSource source,
    required String Function() idGenerator,
    required DateTime Function() now,
  }) : _repository = repository,
       _source = source,
       _idGenerator = idGenerator,
       _now = now;

  final String assessmentId;
  final AssessmentRepository _repository;
  final AssessmentEstimateSource _source;
  final String Function() _idGenerator;
  final DateTime Function() _now;

  AssessmentEstimateControllerState _state =
      const AssessmentEstimateControllerState();

  AssessmentEstimateControllerState get state => _state;

  Future<void> load() async {
    _emit(
      const AssessmentEstimateControllerState(
        phase: AssessmentEstimatePhase.loading,
      ),
    );
    try {
      final assessment = await _repository.findById(assessmentId);
      _emit(
        AssessmentEstimateControllerState(
          phase: assessment == null
              ? AssessmentEstimatePhase.failed
              : AssessmentEstimatePhase.ready,
          assessment: assessment,
          message: assessment == null ? 'Intake Assessment not found.' : null,
        ),
      );
    } catch (error) {
      _emit(
        AssessmentEstimateControllerState(
          phase: AssessmentEstimatePhase.failed,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> submit(AssessmentEstimateAction action) async {
    final assessment = _state.assessment;
    if (assessment == null) return;
    _emit(
      AssessmentEstimateControllerState(
        phase: AssessmentEstimatePhase.calculating,
        assessment: assessment,
      ),
    );
    try {
      final updated = switch (action) {
        RecalculateEstimateAction() => await _recalculate(assessment),
        OverrideRepairOperationAction() => _overrideOperation(
          assessment,
          action,
        ),
        EditEstimateAssumptionsAction() => _editAssumptions(assessment, action),
        AcknowledgePartialEstimateAction() => _acknowledgePartial(assessment),
      };
      final result = await _repository.save(
        updated,
        expectedUpdatedAt: assessment.updatedAt,
      );
      if (result is AssessmentSaveFailed) {
        throw AssessmentInvariantViolation(result.message);
      }
      _emit(
        AssessmentEstimateControllerState(
          phase: AssessmentEstimatePhase.ready,
          assessment: updated,
        ),
      );
    } catch (error) {
      _emit(
        AssessmentEstimateControllerState(
          phase: AssessmentEstimatePhase.failed,
          assessment: assessment,
          message: error is AssessmentInvariantViolation
              ? error.message
              : error.toString(),
        ),
      );
    }
  }

  Future<IntakeAssessment> _recalculate(IntakeAssessment assessment) async {
    final confirmed = assessment.findings
        .where((finding) => finding.reviewState == FindingReviewState.confirmed)
        .toList();
    final suggestions = await _source.suggestOperations(confirmed);
    final operations = <String, RepairOperation>{};
    for (final suggestion in suggestions) {
      if (!confirmed.any((finding) => finding.id == suggestion.findingId)) {
        throw const AssessmentInvariantViolation(
          'A suggested Repair Operation requires a Confirmed Finding.',
        );
      }
      final hasAnySuggestedPrice =
          suggestion.minimumCents != null ||
          suggestion.maximumCents != null ||
          suggestion.currency != null ||
          suggestion.pricingSourceVersion != null;
      if (!_source.supportsNumericPricing && hasAnySuggestedPrice) {
        throw const AssessmentInvariantViolation(
          'Pricing remains unavailable until a supported source is configured.',
        );
      }
      final existing = operations[suggestion.operationId];
      if (existing == null) {
        operations[suggestion.operationId] = RepairOperation(
          id: suggestion.operationId,
          findingIds: [suggestion.findingId],
          description: suggestion.description,
          minimumCents: suggestion.minimumCents,
          maximumCents: suggestion.maximumCents,
          currency: suggestion.currency,
          pricingSourceVersion: suggestion.pricingSourceVersion,
        );
      } else {
        if (existing.description != suggestion.description ||
            existing.minimumCents != suggestion.minimumCents ||
            existing.maximumCents != suggestion.maximumCents ||
            existing.currency != suggestion.currency ||
            existing.pricingSourceVersion != suggestion.pricingSourceVersion) {
          throw const AssessmentInvariantViolation(
            'Shared Repair Operation suggestions must agree before deduplication.',
          );
        }
        operations[suggestion.operationId] = RepairOperation(
          id: existing.id,
          findingIds: {...existing.findingIds, suggestion.findingId}.toList()
            ..sort(),
          description: existing.description,
          minimumCents: existing.minimumCents,
          maximumCents: existing.maximumCents,
          currency: existing.currency,
          pricingSourceVersion: existing.pricingSourceVersion,
        );
      }
    }
    final previous = assessment.estimate;
    final previousOverrides = previous?.overrides ?? const <EstimateOverride>[];
    final recalculated = operations.values.map((operation) {
      EstimateOverride? applicableOverride;
      for (final override in previousOverrides.reversed) {
        if (override.operationId == operation.id) {
          applicableOverride = override;
          break;
        }
      }
      final replacement = applicableOverride?.replacement;
      if (replacement == null) return operation;
      return RepairOperation(
        id: operation.id,
        findingIds: operation.findingIds,
        description: replacement.description,
        minimumCents: replacement.minimumCents,
        maximumCents: replacement.maximumCents,
        currency: replacement.currency,
        pricingSourceVersion: replacement.pricingSourceVersion,
      );
    }).toList();
    return assessment.recordEstimate(
      AssessmentEstimate(
        operations: recalculated,
        assumptions:
            previous?.assumptions ??
            const [
              'Pricing is unavailable unless a versioned source is recorded.',
            ],
        reviewedByProfileId: assessment.appraiserProfile.id,
        reviewedAt: _now().toUtc(),
        sourceVersion: _source.version,
        overrides: previous?.overrides ?? const [],
      ),
    );
  }

  IntakeAssessment _overrideOperation(
    IntakeAssessment assessment,
    OverrideRepairOperationAction action,
  ) {
    final estimate = _requireEstimate(assessment);
    if (action.reason.trim().isEmpty) {
      throw const AssessmentInvariantViolation(
        'An Estimate Override requires a reason.',
      );
    }
    final hasAnyReplacementPrice =
        action.minimumCents != null ||
        action.maximumCents != null ||
        action.currency != null ||
        action.pricingSourceVersion != null;
    if (!_source.supportsNumericPricing && hasAnyReplacementPrice) {
      throw const AssessmentInvariantViolation(
        'Pricing remains unavailable until a supported source is configured.',
      );
    }
    final index = estimate.operations.indexWhere(
      (operation) => operation.id == action.operationId,
    );
    if (index < 0) {
      throw const AssessmentInvariantViolation(
        'An Estimate Override requires a known Repair Operation.',
      );
    }
    final original = estimate.operations[index];
    final replacement = RepairOperation(
      id: original.id,
      findingIds: original.findingIds,
      description: action.description,
      minimumCents: action.minimumCents,
      maximumCents: action.maximumCents,
      currency: action.currency,
      pricingSourceVersion: action.pricingSourceVersion,
    );
    final operations = [...estimate.operations];
    operations[index] = replacement;
    final occurredAt = _now().toUtc();
    return assessment.recordEstimate(
      AssessmentEstimate(
        operations: operations,
        assumptions: estimate.assumptions,
        reviewedByProfileId: assessment.appraiserProfile.id,
        reviewedAt: occurredAt,
        sourceVersion: estimate.sourceVersion,
        overrides: [
          ...estimate.overrides,
          EstimateOverride(
            id: _idGenerator(),
            operationId: original.id,
            authorProfileId: assessment.appraiserProfile.id,
            occurredAt: occurredAt,
            reason: action.reason,
            original: original,
            replacement: replacement,
          ),
        ],
      ),
    );
  }

  IntakeAssessment _editAssumptions(
    IntakeAssessment assessment,
    EditEstimateAssumptionsAction action,
  ) {
    final estimate = _requireEstimate(assessment);
    if (action.assumptions.any((assumption) => assumption.trim().isEmpty)) {
      throw const AssessmentInvariantViolation(
        'Estimate assumptions cannot be blank.',
      );
    }
    return assessment.recordEstimate(
      AssessmentEstimate(
        operations: estimate.operations,
        assumptions: List.unmodifiable(action.assumptions),
        reviewedByProfileId: assessment.appraiserProfile.id,
        reviewedAt: _now().toUtc(),
        sourceVersion: estimate.sourceVersion,
        overrides: estimate.overrides,
      ),
    );
  }

  IntakeAssessment _acknowledgePartial(IntakeAssessment assessment) {
    final estimate = _requireEstimate(assessment);
    if (!estimate.isPartial) {
      throw const AssessmentInvariantViolation(
        'Only a Partial Estimate can acknowledge missing pricing.',
      );
    }
    return assessment.recordEstimate(
      AssessmentEstimate(
        operations: estimate.operations,
        assumptions: estimate.assumptions,
        reviewedByProfileId: assessment.appraiserProfile.id,
        reviewedAt: _now().toUtc(),
        sourceVersion: estimate.sourceVersion,
        overrides: estimate.overrides,
        missingPricingAcknowledgedAt: _now().toUtc(),
        missingPricingAcknowledgedByProfileId: assessment.appraiserProfile.id,
      ),
    );
  }

  AssessmentEstimate _requireEstimate(IntakeAssessment assessment) {
    final estimate = assessment.estimate;
    if (estimate == null) {
      throw const AssessmentInvariantViolation(
        'Recalculate the Draft Estimate before reviewing it.',
      );
    }
    return estimate;
  }

  void _emit(AssessmentEstimateControllerState state) {
    _state = state;
    notifyListeners();
  }
}
