import 'package:flutter_test/flutter_test.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_workflow_controller.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

void main() {
  group('AssessmentWorkflowController', () {
    test('loads history and starts another assessment for a Vehicle', () async {
      final repository = InMemoryAssessmentRepository();
      final existing = IntakeAssessment.create(
        id: 'assessment-1',
        vehicle: const Vehicle(
          id: 'vehicle-1',
          vin: '1HGCM82633A004352',
          licencePlate: 'ABC123',
        ),
        appraiserProfile: const AppraiserProfile(
          id: 'appraiser-1',
          displayName: 'Alex Appraiser',
        ),
        createdAt: DateTime.utc(2026, 9, 8),
      );
      await repository.save(existing);
      final controller = AssessmentWorkflowController(
        repository: repository,
        idGenerator: () => 'assessment-2',
        now: () => DateTime.utc(2026, 9, 9),
      );

      await controller.load();

      expect(controller.state.phase, AssessmentWorkflowPhase.ready);
      expect(controller.state.assessments, [existing]);
      expect(controller.state.vehicles, [existing.vehicle]);

      final createdId = await controller.startAssessment(
        vehicle: existing.vehicle,
        appraiserProfile: const AppraiserProfile(
          id: 'appraiser-2',
          displayName: 'Bailey Appraiser',
        ),
      );

      expect(createdId, 'assessment-2');
      expect(controller.state.phase, AssessmentWorkflowPhase.ready);
      expect(controller.state.assessments.map((value) => value.id), [
        'assessment-2',
        'assessment-1',
      ]);
      final created = await repository.findById('assessment-2');
      expect(created?.vehicle, existing.vehicle);
      expect(created?.status, IntakeAssessmentStatus.draft);
      expect(created?.appraiserProfile.displayName, 'Bailey Appraiser');
    });

    test('deletes a Draft and updates the workspace immediately', () async {
      final repository = InMemoryAssessmentRepository();
      final assessment = IntakeAssessment.create(
        id: 'assessment-1',
        vehicle: const Vehicle(id: 'vehicle-1'),
        appraiserProfile: const AppraiserProfile(
          id: 'appraiser-1',
          displayName: 'Alex Appraiser',
        ),
        createdAt: DateTime.utc(2026, 9, 8),
      );
      await repository.save(assessment);
      final controller = AssessmentWorkflowController(
        repository: repository,
        idGenerator: () => 'unused',
        now: () => DateTime.utc(2026, 9, 9),
      );
      await controller.load();

      final result = await controller.deleteAssessment(assessment.id);

      expect(result, isA<AssessmentDeleted>());
      expect(controller.state.phase, AssessmentWorkflowPhase.ready);
      expect(controller.state.assessments, isEmpty);
      expect(await repository.findById(assessment.id), isNull);
    });

    test('returns an actionable failure for a stale Draft workspace', () async {
      final repository = InMemoryAssessmentRepository();
      final assessment = IntakeAssessment.create(
        id: 'assessment-1',
        vehicle: const Vehicle(id: 'vehicle-1'),
        appraiserProfile: const AppraiserProfile(
          id: 'appraiser-1',
          displayName: 'Alex Appraiser',
        ),
        createdAt: DateTime.utc(2026, 9, 8),
      );
      await repository.save(assessment);
      final controller = AssessmentWorkflowController(
        repository: repository,
        idGenerator: () => 'unused',
        now: () => DateTime.utc(2026, 9, 9),
      );
      await controller.load();
      await repository.save(
        assessment.acceptCapture(
          Capture(
            id: 'capture-1',
            source: CaptureSource.import,
            localPath: '/evidence/capture-1.jpg',
            acceptedByProfileId: 'appraiser-1',
            acceptedAt: DateTime.utc(2026, 9, 9),
          ),
        ),
      );

      final result = await controller.deleteAssessment(assessment.id);

      expect(result, isA<AssessmentDeleteFailed>());
      expect((result as AssessmentDeleteFailed).message, contains('changed'));
      expect(controller.state.phase, AssessmentWorkflowPhase.failed);
      expect(controller.state.assessments, hasLength(1));
    });
  });
}
