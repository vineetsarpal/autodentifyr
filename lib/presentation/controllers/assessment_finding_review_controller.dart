import 'package:flutter/foundation.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

enum FindingReviewPhase { idle, loading, ready, saving, loadFailed, saveFailed }

class FindingReviewControllerState {
  const FindingReviewControllerState({
    this.phase = FindingReviewPhase.idle,
    this.assessment,
    this.message,
  });

  final FindingReviewPhase phase;
  final IntakeAssessment? assessment;
  final String? message;
}

sealed class FindingReviewAction {
  const FindingReviewAction({required this.reason});

  final String reason;
}

class ConfirmFindingAction extends FindingReviewAction {
  const ConfirmFindingAction({
    required this.findingId,
    required this.vehicleComponent,
    required this.damageType,
    required super.reason,
    this.additionalViewOverrideReason,
  });

  final String findingId;
  final String vehicleComponent;
  final String damageType;
  final String? additionalViewOverrideReason;
}

class DismissFindingAction extends FindingReviewAction {
  const DismissFindingAction({
    required this.findingId,
    required super.reason,
    this.additionalViewOverrideReason,
  });

  final String findingId;
  final String? additionalViewOverrideReason;
}

class EditFindingAction extends FindingReviewAction {
  const EditFindingAction({
    required this.findingId,
    required this.vehicleComponent,
    required this.damageType,
    required this.supportingCaptureIds,
    required super.reason,
  });

  final String findingId;
  final String vehicleComponent;
  final String damageType;
  final List<String> supportingCaptureIds;
}

class AddManualFindingAction extends FindingReviewAction {
  const AddManualFindingAction({
    required this.vehicleComponent,
    required this.damageType,
    required this.supportingCaptureIds,
    required this.evidenceNote,
    required super.reason,
    this.observationIds = const [],
  });

  final String vehicleComponent;
  final String damageType;
  final List<String> supportingCaptureIds;
  final String evidenceNote;
  final List<String> observationIds;
}

class RecordFindingUncertaintyAction extends FindingReviewAction {
  const RecordFindingUncertaintyAction({
    required this.findingId,
    required this.hasConflictingViews,
    required this.additionalViewRequests,
    required super.reason,
  });

  final String findingId;
  final bool hasConflictingViews;
  final List<String> additionalViewRequests;
}

class MarkFindingUndeterminedAction extends FindingReviewAction {
  const MarkFindingUndeterminedAction({
    required this.findingId,
    required super.reason,
    this.additionalViewOverrideReason,
  });

  final String findingId;
  final String? additionalViewOverrideReason;
}

class MergeFindingsAction extends FindingReviewAction {
  const MergeFindingsAction({
    required this.findingIds,
    required this.vehicleComponent,
    required this.damageType,
    required super.reason,
    this.additionalViewOverrideReason,
  });

  final List<String> findingIds;
  final String vehicleComponent;
  final String damageType;
  final String? additionalViewOverrideReason;
}

class SplitFindingPart {
  const SplitFindingPart({
    required this.vehicleComponent,
    required this.damageType,
    required this.observationIds,
    required this.supportingCaptureIds,
  });

  final String vehicleComponent;
  final String damageType;
  final List<String> observationIds;
  final List<String> supportingCaptureIds;
}

class SplitFindingAction extends FindingReviewAction {
  const SplitFindingAction({
    required this.findingId,
    required this.parts,
    required super.reason,
    this.additionalViewOverrideReason,
  });

  final String findingId;
  final List<SplitFindingPart> parts;
  final String? additionalViewOverrideReason;
}

class AssessmentFindingReviewController extends ChangeNotifier {
  AssessmentFindingReviewController({
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

  FindingReviewControllerState _state = const FindingReviewControllerState();

  FindingReviewControllerState get state => _state;

  Future<void> load() async {
    _emit(
      const FindingReviewControllerState(phase: FindingReviewPhase.loading),
    );
    try {
      final loaded = await _repository.findById(assessmentId);
      if (loaded == null) {
        _emit(
          const FindingReviewControllerState(
            phase: FindingReviewPhase.loadFailed,
            message: 'Intake Assessment not found.',
          ),
        );
        return;
      }
      var assessment = loaded;
      final representedObservationIds = assessment.findings
          .expand((finding) => finding.observationIds)
          .toSet();
      for (final observation in assessment.observations.where(
        (observation) => !representedObservationIds.contains(observation.id),
      )) {
        assessment = assessment.addFinding(
          DamageFinding.proposed(
            id: 'proposed-${observation.id}',
            observationIds: [observation.id],
            supportingCaptureIds: [observation.captureId],
            suggestedDamageType: observation.rawClass,
          ),
        );
      }
      final result = await _repository.save(assessment);
      if (result is AssessmentSaveFailed) {
        _emit(
          FindingReviewControllerState(
            phase: FindingReviewPhase.saveFailed,
            assessment: assessment,
            message: result.message,
          ),
        );
        return;
      }
      _emit(
        FindingReviewControllerState(
          phase: FindingReviewPhase.ready,
          assessment: assessment,
        ),
      );
    } catch (error) {
      _emit(
        FindingReviewControllerState(
          phase: FindingReviewPhase.loadFailed,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> submit(FindingReviewAction action) async {
    final assessment = _state.assessment;
    if (assessment == null) return;
    _emit(
      FindingReviewControllerState(
        phase: FindingReviewPhase.saving,
        assessment: assessment,
      ),
    );
    try {
      final updated = switch (action) {
        ConfirmFindingAction action => _confirm(assessment, action),
        DismissFindingAction action => _dismiss(assessment, action),
        EditFindingAction action => _edit(assessment, action),
        AddManualFindingAction action => _addManual(assessment, action),
        RecordFindingUncertaintyAction action => _recordUncertainty(
          assessment,
          action,
        ),
        MarkFindingUndeterminedAction action => _markUndetermined(
          assessment,
          action,
        ),
        MergeFindingsAction action => _merge(assessment, action),
        SplitFindingAction action => _split(assessment, action),
      };
      final result = await _repository.save(
        updated,
        expectedUpdatedAt: assessment.updatedAt,
      );
      if (result is AssessmentSaveFailed) {
        _emit(
          FindingReviewControllerState(
            phase: FindingReviewPhase.saveFailed,
            assessment: assessment,
            message: result.message,
          ),
        );
        return;
      }
      _emit(
        FindingReviewControllerState(
          phase: FindingReviewPhase.ready,
          assessment: updated,
        ),
      );
    } on AssessmentInvariantViolation catch (error) {
      _emit(
        FindingReviewControllerState(
          phase: FindingReviewPhase.saveFailed,
          assessment: assessment,
          message: error.message,
        ),
      );
    }
  }

  IntakeAssessment _merge(
    IntakeAssessment assessment,
    MergeFindingsAction action,
  ) {
    if (action.findingIds.length < 2 ||
        action.findingIds.toSet().length != action.findingIds.length) {
      throw const AssessmentInvariantViolation(
        'A merge requires at least two distinct Findings.',
      );
    }
    final originals = action.findingIds
        .map((id) => _finding(assessment, id))
        .toList();
    final observationIds = <String>[];
    final captureIds = <String>[];
    for (final original in originals) {
      for (final id in original.observationIds) {
        if (!observationIds.contains(id)) observationIds.add(id);
      }
      for (final id in original.supportingCaptureIds) {
        if (!captureIds.contains(id)) captureIds.add(id);
      }
    }
    var replacement = DamageFinding.proposed(
      id: _idGenerator(),
      observationIds: observationIds,
      supportingCaptureIds: captureIds,
    );
    if (originals.any((finding) => finding.additionalViewRequests.isNotEmpty)) {
      replacement = replacement.withUncertainty(
        hasConflictingViews: originals.any(
          (finding) => finding.hasConflictingViews,
        ),
        additionalViewRequests: [
          for (final original in originals)
            for (final request in original.additionalViewRequests) request,
        ],
      );
    }
    replacement = replacement.reviewed(
      state: FindingReviewState.confirmed,
      vehicleComponent: action.vehicleComponent,
      damageType: action.damageType,
      additionalViewOverrideReason: action.additionalViewOverrideReason,
    );
    return assessment.applyFindingCorrection(
      AssessmentCorrection.multiple(
        id: _idGenerator(),
        findingId: replacement.id,
        kind: AssessmentCorrectionKind.merge,
        authorProfileId: assessment.appraiserProfile.id,
        occurredAt: _now().toUtc(),
        reason: action.reason,
        originals: originals,
        replacements: [replacement],
      ),
    );
  }

  IntakeAssessment _split(
    IntakeAssessment assessment,
    SplitFindingAction action,
  ) {
    if (action.parts.length < 2) {
      throw const AssessmentInvariantViolation(
        'A split requires at least two replacement Findings.',
      );
    }
    final original = _finding(assessment, action.findingId);
    final outputObservationIds = action.parts
        .expand((part) => part.observationIds)
        .toSet();
    final outputCaptureIds = action.parts
        .expand((part) => part.supportingCaptureIds)
        .toSet();
    if (!outputObservationIds.containsAll(original.observationIds) ||
        !outputCaptureIds.containsAll(original.supportingCaptureIds)) {
      throw const AssessmentInvariantViolation(
        'Split Findings must preserve every source evidence link.',
      );
    }
    final replacements = action.parts
        .map(
          (part) =>
              DamageFinding.proposed(
                id: _idGenerator(),
                observationIds: part.observationIds,
                supportingCaptureIds: part.supportingCaptureIds,
              ).reviewed(
                state: FindingReviewState.confirmed,
                vehicleComponent: part.vehicleComponent,
                damageType: part.damageType,
                additionalViewOverrideReason:
                    action.additionalViewOverrideReason,
              ),
        )
        .toList();
    return assessment.applyFindingCorrection(
      AssessmentCorrection.multiple(
        id: _idGenerator(),
        findingId: original.id,
        kind: AssessmentCorrectionKind.split,
        authorProfileId: assessment.appraiserProfile.id,
        occurredAt: _now().toUtc(),
        reason: action.reason,
        originals: [original],
        replacements: replacements,
      ),
    );
  }

  IntakeAssessment _recordUncertainty(
    IntakeAssessment assessment,
    RecordFindingUncertaintyAction action,
  ) {
    final original = _finding(assessment, action.findingId);
    final replacement = original.withUncertainty(
      hasConflictingViews: action.hasConflictingViews,
      additionalViewRequests: action.additionalViewRequests,
    );
    return _correctOne(
      assessment: assessment,
      original: original,
      replacement: replacement,
      kind: AssessmentCorrectionKind.uncertainty,
      reason: action.reason,
    );
  }

  IntakeAssessment _markUndetermined(
    IntakeAssessment assessment,
    MarkFindingUndeterminedAction action,
  ) {
    final original = _finding(assessment, action.findingId);
    return _correctOne(
      assessment: assessment,
      original: original,
      replacement: original.markUndetermined(
        additionalViewOverrideReason: action.additionalViewOverrideReason,
      ),
      kind: AssessmentCorrectionKind.undetermined,
      reason: action.reason,
    );
  }

  IntakeAssessment _correctOne({
    required IntakeAssessment assessment,
    required DamageFinding original,
    required DamageFinding replacement,
    required AssessmentCorrectionKind kind,
    required String reason,
  }) => assessment.correctFinding(
    replacement: replacement,
    correction: AssessmentCorrection(
      id: _idGenerator(),
      findingId: original.id,
      kind: kind,
      authorProfileId: assessment.appraiserProfile.id,
      occurredAt: _now().toUtc(),
      reason: reason,
      original: original,
      replacement: replacement,
    ),
  );

  IntakeAssessment _addManual(
    IntakeAssessment assessment,
    AddManualFindingAction action,
  ) {
    final findingId = _idGenerator();
    final replacement = action.observationIds.isEmpty
        ? DamageFinding.manual(
            id: findingId,
            vehicleComponent: action.vehicleComponent,
            damageType: action.damageType,
            supportingCaptureIds: action.supportingCaptureIds,
            evidenceNote: action.evidenceNote,
          )
        : DamageFinding.proposed(
            id: findingId,
            observationIds: action.observationIds,
            supportingCaptureIds: action.supportingCaptureIds,
          ).reviewed(
            state: FindingReviewState.confirmed,
            vehicleComponent: action.vehicleComponent,
            damageType: action.damageType,
          );
    return assessment.applyFindingCorrection(
      AssessmentCorrection.multiple(
        id: _idGenerator(),
        findingId: replacement.id,
        kind: AssessmentCorrectionKind.add,
        authorProfileId: assessment.appraiserProfile.id,
        occurredAt: _now().toUtc(),
        reason: action.reason,
        originals: const [],
        replacements: [replacement],
      ),
    );
  }

  IntakeAssessment _edit(
    IntakeAssessment assessment,
    EditFindingAction action,
  ) {
    final original = _finding(assessment, action.findingId);
    final replacement = original.edited(
      vehicleComponent: action.vehicleComponent,
      damageType: action.damageType,
      supportingCaptureIds: action.supportingCaptureIds,
    );
    return assessment.correctFinding(
      replacement: replacement,
      correction: AssessmentCorrection(
        id: _idGenerator(),
        findingId: original.id,
        kind: AssessmentCorrectionKind.edit,
        authorProfileId: assessment.appraiserProfile.id,
        occurredAt: _now().toUtc(),
        reason: action.reason,
        original: original,
        replacement: replacement,
      ),
    );
  }

  IntakeAssessment _dismiss(
    IntakeAssessment assessment,
    DismissFindingAction action,
  ) {
    final original = _finding(assessment, action.findingId);
    final replacement = original.reviewed(
      state: FindingReviewState.dismissed,
      additionalViewOverrideReason: action.additionalViewOverrideReason,
    );
    return assessment.correctFinding(
      replacement: replacement,
      correction: AssessmentCorrection(
        id: _idGenerator(),
        findingId: original.id,
        kind: AssessmentCorrectionKind.dismiss,
        authorProfileId: assessment.appraiserProfile.id,
        occurredAt: _now().toUtc(),
        reason: action.reason,
        original: original,
        replacement: replacement,
      ),
    );
  }

  IntakeAssessment _confirm(
    IntakeAssessment assessment,
    ConfirmFindingAction action,
  ) {
    final original = _finding(assessment, action.findingId);
    final replacement = original.reviewed(
      state: FindingReviewState.confirmed,
      vehicleComponent: action.vehicleComponent,
      damageType: action.damageType,
      additionalViewOverrideReason: action.additionalViewOverrideReason,
    );
    return assessment.correctFinding(
      replacement: replacement,
      correction: AssessmentCorrection(
        id: _idGenerator(),
        findingId: original.id,
        kind: AssessmentCorrectionKind.confirm,
        authorProfileId: assessment.appraiserProfile.id,
        occurredAt: _now().toUtc(),
        reason: action.reason,
        original: original,
        replacement: replacement,
      ),
    );
  }

  DamageFinding _finding(IntakeAssessment assessment, String id) {
    for (final finding in assessment.findings) {
      if (finding.id == id) return finding;
    }
    throw AssessmentInvariantViolation('Finding $id was not found.');
  }

  void _emit(FindingReviewControllerState state) {
    _state = state;
    notifyListeners();
  }
}
