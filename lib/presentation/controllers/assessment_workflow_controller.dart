import 'package:flutter/foundation.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

enum AssessmentWorkflowPhase { idle, loading, ready, saving, failed }

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

  Future<void> startAssessment({
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
      await load();
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
    }
  }

  void _emit(AssessmentWorkflowState state) {
    _state = state;
    notifyListeners();
  }
}
