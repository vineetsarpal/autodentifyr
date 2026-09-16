import 'package:flutter/foundation.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

enum AssessmentWorkflowPhase { idle, loading, ready, saving, deleting, failed }

class AssessmentWorkflowState {
  const AssessmentWorkflowState({
    this.phase = AssessmentWorkflowPhase.idle,
    this.assessments = const [],
    this.message,
  });

  final AssessmentWorkflowPhase phase;
  final List<IntakeAssessment> assessments;
  final String? message;

  List<Vehicle> get vehicles {
    final byId = <String, Vehicle>{};
    for (final assessment in assessments) {
      byId.putIfAbsent(assessment.vehicle.id, () => assessment.vehicle);
    }
    return List.unmodifiable(byId.values);
  }

  List<AppraiserProfile> get appraiserProfiles {
    final byId = <String, AppraiserProfile>{};
    for (final assessment in assessments) {
      byId.putIfAbsent(
        assessment.appraiserProfile.id,
        () => assessment.appraiserProfile,
      );
    }
    return List.unmodifiable(byId.values);
  }
}

class AssessmentWorkflowController extends ChangeNotifier {
  AssessmentWorkflowController({
    required AssessmentRepository repository,
    required String Function() idGenerator,
    required DateTime Function() now,
  }) : _repository = repository,
       _idGenerator = idGenerator,
       _now = now;

  final AssessmentRepository _repository;
  final String Function() _idGenerator;
  final DateTime Function() _now;

  AssessmentWorkflowState _state = const AssessmentWorkflowState();

  AssessmentWorkflowState get state => _state;

  String generateVehicleId() => 'vehicle-${_idGenerator()}';

  String generateAppraiserProfileId() => 'appraiser-${_idGenerator()}';

  Future<void> load() async {
    _emit(
      AssessmentWorkflowState(
        phase: AssessmentWorkflowPhase.loading,
        assessments: _state.assessments,
      ),
    );
    try {
      _emit(
        AssessmentWorkflowState(
          phase: AssessmentWorkflowPhase.ready,
          assessments: await _repository.list(),
        ),
      );
    } catch (error) {
      _emit(
        AssessmentWorkflowState(
          phase: AssessmentWorkflowPhase.failed,
          assessments: _state.assessments,
          message: error.toString(),
        ),
      );
    }
  }

  Future<String?> startAssessment({
    required Vehicle vehicle,
    required AppraiserProfile appraiserProfile,
  }) async {
    _emit(
      AssessmentWorkflowState(
        phase: AssessmentWorkflowPhase.saving,
        assessments: _state.assessments,
      ),
    );
    try {
      final createdAt = _now().toUtc();
      final assessment = IntakeAssessment.create(
        id: _idGenerator(),
        vehicle: vehicle,
        appraiserProfile: appraiserProfile,
        createdAt: createdAt,
      );
      final result = await _repository.save(assessment);
      if (result is AssessmentSaveFailed) {
        throw AssessmentInvariantViolation(result.message);
      }
      _emit(
        AssessmentWorkflowState(
          phase: AssessmentWorkflowPhase.ready,
          assessments: [
            assessment,
            ..._state.assessments.where((value) => value.id != assessment.id),
          ],
        ),
      );
      return assessment.id;
    } catch (error) {
      _emit(
        AssessmentWorkflowState(
          phase: AssessmentWorkflowPhase.failed,
          assessments: _state.assessments,
          message: error is AssessmentInvariantViolation
              ? error.message
              : error.toString(),
        ),
      );
      return null;
    }
  }

  Future<AssessmentDeleteResult> deleteAssessment(String assessmentId) async {
    final assessment = _state.assessments
        .where((value) => value.id == assessmentId)
        .firstOrNull;
    if (assessment == null) {
      return const AssessmentDeleteNotFound();
    }
    _emit(
      AssessmentWorkflowState(
        phase: AssessmentWorkflowPhase.deleting,
        assessments: _state.assessments,
      ),
    );
    try {
      final result = await _repository.delete(
        assessmentId,
        expectedUpdatedAt: assessment.updatedAt,
      );
      if (result is AssessmentDeleted) {
        _emit(
          AssessmentWorkflowState(
            phase: AssessmentWorkflowPhase.ready,
            assessments: _state.assessments
                .where((value) => value.id != assessmentId)
                .toList(),
          ),
        );
      } else if (result is AssessmentDeleteNotFound) {
        await load();
      } else if (result is AssessmentDeleteFailed) {
        _emit(
          AssessmentWorkflowState(
            phase: AssessmentWorkflowPhase.failed,
            assessments: _state.assessments,
            message: result.message,
          ),
        );
      }
      return result;
    } catch (error) {
      final result = AssessmentDeleteFailed(message: error.toString());
      _emit(
        AssessmentWorkflowState(
          phase: AssessmentWorkflowPhase.failed,
          assessments: _state.assessments,
          message: result.message,
        ),
      );
      return result;
    }
  }

  void _emit(AssessmentWorkflowState state) {
    _state = state;
    notifyListeners();
  }
}
