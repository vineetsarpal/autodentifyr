import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_finding_review_controller.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssessmentFindingReviewController', () {
    test(
      'retained observations load as reviewable Proposed Findings',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_assessmentWithObservations());
        final controller = AssessmentFindingReviewController(
          assessmentId: 'assessment-1',
          repository: repository,
          idGenerator: _IdGenerator(['correction-1']).next,
          now: () => DateTime.utc(2026, 9, 7, 1),
        );

        await controller.load();

        expect(controller.state.phase, FindingReviewPhase.ready);
        expect(controller.state.assessment!.findings, hasLength(2));
        expect(
          controller.state.assessment!.findings.map(
            (finding) => finding.reviewState,
          ),
          everyElement(FindingReviewState.proposed),
        );
        expect(controller.state.assessment!.findings.first.observationIds, [
          'observation-1',
        ]);
        expect(
          controller.state.assessment!.findings.first.supportingCaptureIds,
          ['capture-1'],
        );
        expect(controller.state.assessment!.findings.first.damageType, 'dent');
        expect(
          (await repository.findById('assessment-1'))!.findings,
          controller.state.assessment!.findings,
        );
      },
    );

    test('confirm records required values and complete provenance', () async {
      final repository = InMemoryAssessmentRepository();
      await repository.save(_assessmentWithObservations());
      final controller = AssessmentFindingReviewController(
        assessmentId: 'assessment-1',
        repository: repository,
        idGenerator: _IdGenerator(['correction-1']).next,
        now: () => DateTime.utc(2026, 9, 7, 1, 2),
      );
      await controller.load();
      final original = controller.state.assessment!.findings.first;

      await controller.submit(
        const ConfirmFindingAction(
          findingId: 'proposed-observation-1',
          vehicleComponent: 'left-front door',
          damageType: 'crease',
          reason: 'Visible crease corrects the model suggestion.',
        ),
      );

      final saved = await repository.findById('assessment-1');
      final confirmed = saved!.findings.first;
      expect(controller.state.phase, FindingReviewPhase.ready);
      expect(confirmed.reviewState, FindingReviewState.confirmed);
      expect(confirmed.vehicleComponent, 'left-front door');
      expect(confirmed.damageType, 'crease');
      expect(confirmed.supportingCaptureIds, ['capture-1']);
      expect(confirmed.observationIds, ['observation-1']);
      final correction = saved.corrections.single;
      expect(correction.kind, AssessmentCorrectionKind.confirm);
      expect(correction.original, original);
      expect(correction.original.damageType, 'dent');
      expect(correction.replacement, confirmed);
      expect(correction.authorProfileId, 'appraiser-1');
      expect(correction.occurredAt, DateTime.utc(2026, 9, 7, 1, 2));
      expect(
        correction.reason,
        'Visible crease corrects the model suggestion.',
      );
    });

    test(
      'dismiss preserves the original proposal and source observation',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_assessmentWithObservations());
        final controller = _controller(repository, ['correction-1']);
        await controller.load();
        final original = controller.state.assessment!.findings.first;

        await controller.submit(
          const DismissFindingAction(
            findingId: 'proposed-observation-1',
            reason: 'The mark is a reflection, not visible damage.',
          ),
        );

        final saved = (await repository.findById('assessment-1'))!;
        expect(saved.findings.first.reviewState, FindingReviewState.dismissed);
        expect(
          saved.observations.map((item) => item.id),
          contains('observation-1'),
        );
        expect(saved.corrections.single.original, original);
        expect(saved.corrections.single.kind, AssessmentCorrectionKind.dismiss);
      },
    );

    test('edit replaces values while keeping a proposal reviewable', () async {
      final repository = InMemoryAssessmentRepository();
      await repository.save(_assessmentWithObservations());
      final controller = _controller(repository, ['correction-1']);
      await controller.load();

      await controller.submit(
        const EditFindingAction(
          findingId: 'proposed-observation-1',
          vehicleComponent: 'left-front fender',
          damageType: 'crease',
          supportingCaptureIds: ['capture-1'],
          reason: 'The Appraiser corrected the suggested classification.',
        ),
      );

      final saved = (await repository.findById('assessment-1'))!;
      final edited = saved.findings.first;
      expect(edited.reviewState, FindingReviewState.proposed);
      expect(edited.vehicleComponent, 'left-front fender');
      expect(edited.damageType, 'crease');
      expect(edited.observationIds, ['observation-1']);
      expect(saved.corrections.single.kind, AssessmentCorrectionKind.edit);
    });

    test(
      'manual Finding requires evidence note when no observation matches',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_assessmentWithObservations());
        final controller = _controller(repository, [
          'manual-1',
          'correction-1',
          'manual-2',
        ]);
        await controller.load();

        await controller.submit(
          const AddManualFindingAction(
            vehicleComponent: 'right-rear quarter panel',
            damageType: 'scratch',
            supportingCaptureIds: ['capture-2'],
            evidenceNote: 'A scratch is visible below the model region.',
            reason: 'The model did not produce a matching observation.',
          ),
        );

        final saved = (await repository.findById('assessment-1'))!;
        final manual = saved.findings.last;
        expect(manual.reviewState, FindingReviewState.confirmed);
        expect(manual.observationIds, isEmpty);
        expect(
          manual.manualEvidenceNote,
          'A scratch is visible below the model region.',
        );
        expect(saved.corrections.single.kind, AssessmentCorrectionKind.add);
        expect(saved.corrections.single.originals, isEmpty);
        expect(saved.corrections.single.replacements, [manual]);

        await controller.submit(
          const AddManualFindingAction(
            vehicleComponent: 'hood',
            damageType: 'dent',
            supportingCaptureIds: ['capture-1'],
            evidenceNote: '',
            reason: 'Attempt without an evidence note.',
          ),
        );
        expect(controller.state.phase, FindingReviewPhase.saveFailed);
        expect(controller.state.message, contains('evidence note'));
        expect(
          (await repository.findById('assessment-1'))!.findings,
          hasLength(3),
        );
      },
    );

    test(
      'conflicting views and specific requests support explicit Undetermined',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_assessmentWithObservations());
        final controller = _controller(repository, [
          'correction-1',
          'correction-2',
        ]);
        await controller.load();

        await controller.submit(
          const RecordFindingUncertaintyAction(
            findingId: 'proposed-observation-1',
            hasConflictingViews: true,
            additionalViewRequests: [
              'Capture an oblique view of the left-front door.',
            ],
            reason: 'The straight-on and side views conflict.',
          ),
        );
        var finding = controller.state.assessment!.findings.first;
        expect(finding.reviewState, FindingReviewState.proposed);
        expect(finding.hasConflictingViews, isTrue);
        expect(finding.additionalViewRequests, [
          'Capture an oblique view of the left-front door.',
        ]);
        expect(
          controller.state.assessment!.corrections.single.kind,
          AssessmentCorrectionKind.uncertainty,
        );

        await controller.submit(
          const MarkFindingUndeterminedAction(
            findingId: 'proposed-observation-1',
            reason: 'Available Captures do not support a conclusion.',
            additionalViewOverrideReason:
                'The Vehicle Owner declined another Capture during intake.',
          ),
        );

        finding = controller.state.assessment!.findings.first;
        expect(finding.reviewState, FindingReviewState.proposed);
        expect(finding.reviewOutcome, FindingReviewOutcome.undetermined);
        expect(finding.hasConflictingViews, isTrue);
        expect(finding.additionalViewRequests, isNotEmpty);
        expect(
          finding.additionalViewOverrideReason,
          'The Vehicle Owner declined another Capture during intake.',
        );
        expect(
          controller.state.assessment!.corrections.last.kind,
          AssessmentCorrectionKind.undetermined,
        );
      },
    );

    test(
      'conclusion over an unmet view request records an override reason',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_assessmentWithObservations());
        final controller = _controller(repository, [
          'correction-1',
          'correction-2',
        ]);
        await controller.load();
        await controller.submit(
          const RecordFindingUncertaintyAction(
            findingId: 'proposed-observation-1',
            hasConflictingViews: false,
            additionalViewRequests: ['Capture the lower door edge.'],
            reason: 'The edge is occluded.',
          ),
        );

        await controller.submit(
          const ConfirmFindingAction(
            findingId: 'proposed-observation-1',
            vehicleComponent: 'left-front door',
            damageType: 'dent',
            reason: 'Confirming from other retained evidence.',
          ),
        );
        expect(controller.state.phase, FindingReviewPhase.saveFailed);
        expect(controller.state.message, contains('override reason'));

        await controller.submit(
          const ConfirmFindingAction(
            findingId: 'proposed-observation-1',
            vehicleComponent: 'left-front door',
            damageType: 'dent',
            reason: 'Confirming from other retained evidence.',
            additionalViewOverrideReason: 'The second Capture shows the edge.',
          ),
        );
        final finding = controller.state.assessment!.findings.first;
        expect(finding.reviewState, FindingReviewState.confirmed);
        expect(
          finding.additionalViewOverrideReason,
          'The second Capture shows the edge.',
        );
      },
    );

    test(
      'merge requires an Appraiser action and unions every evidence link',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_assessmentWithObservations());
        final controller = _controller(repository, [
          'merged-1',
          'correction-1',
        ]);
        await controller.load();
        final originals = List<DamageFinding>.from(
          controller.state.assessment!.findings,
        );

        await controller.submit(
          const MergeFindingsAction(
            findingIds: ['proposed-observation-1', 'proposed-observation-2'],
            vehicleComponent: 'left-front door',
            damageType: 'surface damage',
            reason: 'Both observations describe one damaged area.',
          ),
        );

        final saved = (await repository.findById('assessment-1'))!;
        expect(saved.findings, hasLength(1));
        expect(saved.findings.single.reviewState, FindingReviewState.confirmed);
        expect(saved.findings.single.observationIds, [
          'observation-1',
          'observation-2',
        ]);
        expect(saved.findings.single.supportingCaptureIds, [
          'capture-1',
          'capture-2',
        ]);
        expect(saved.corrections.single.kind, AssessmentCorrectionKind.merge);
        expect(saved.corrections.single.originals, originals);
        expect(saved.corrections.single.replacements, [saved.findings.single]);
      },
    );

    test(
      'split requires explicit parts and preserves all source evidence',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_assessmentWithObservations());
        final controller = _controller(repository, [
          'merged-1',
          'correction-1',
          'split-1',
          'split-2',
          'correction-2',
        ]);
        await controller.load();
        await controller.submit(
          const MergeFindingsAction(
            findingIds: ['proposed-observation-1', 'proposed-observation-2'],
            vehicleComponent: 'left-front door',
            damageType: 'surface damage',
            reason: 'Reviewing the candidate merge.',
          ),
        );

        await controller.submit(
          const SplitFindingAction(
            findingId: 'merged-1',
            parts: [
              SplitFindingPart(
                vehicleComponent: 'left-front door',
                damageType: 'dent',
                observationIds: ['observation-1'],
                supportingCaptureIds: ['capture-1'],
              ),
              SplitFindingPart(
                vehicleComponent: 'left-front door',
                damageType: 'scratch',
                observationIds: ['observation-2'],
                supportingCaptureIds: ['capture-2'],
              ),
            ],
            reason:
                'The Captures show two separately reviewable damaged areas.',
          ),
        );

        final saved = (await repository.findById('assessment-1'))!;
        expect(saved.findings.map((finding) => finding.id), [
          'split-1',
          'split-2',
        ]);
        expect(
          saved.findings.map((finding) => finding.reviewState),
          everyElement(FindingReviewState.confirmed),
        );
        expect(saved.corrections.last.kind, AssessmentCorrectionKind.split);
        expect(saved.corrections.last.originals.single.id, 'merged-1');
        expect(saved.corrections.last.replacements, saved.findings);
      },
    );

    test(
      'incomplete conclusions and evidence-dropping splits are rejected',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_assessmentWithObservations());
        final controller = _controller(repository, [
          'merged-1',
          'correction-1',
        ]);
        await controller.load();

        await controller.submit(
          const ConfirmFindingAction(
            findingId: 'proposed-observation-1',
            vehicleComponent: '',
            damageType: 'dent',
            reason: 'Missing a position-specific component.',
          ),
        );
        expect(controller.state.phase, FindingReviewPhase.saveFailed);
        expect(controller.state.message, contains('Vehicle Component'));
        expect(
          (await repository.findById(
            'assessment-1',
          ))!.findings.first.reviewState,
          FindingReviewState.proposed,
        );

        await controller.submit(
          const MergeFindingsAction(
            findingIds: ['proposed-observation-1', 'proposed-observation-2'],
            vehicleComponent: 'left-front door',
            damageType: 'surface damage',
            reason: 'Create a source for the split check.',
          ),
        );
        await controller.submit(
          const SplitFindingAction(
            findingId: 'merged-1',
            parts: [
              SplitFindingPart(
                vehicleComponent: 'left-front door',
                damageType: 'dent',
                observationIds: ['observation-1'],
                supportingCaptureIds: ['capture-1'],
              ),
              SplitFindingPart(
                vehicleComponent: 'left-front door',
                damageType: 'scratch',
                observationIds: [],
                supportingCaptureIds: ['capture-1'],
              ),
            ],
            reason: 'This attempted split drops the second Capture.',
          ),
        );
        expect(controller.state.phase, FindingReviewPhase.saveFailed);
        expect(
          controller.state.message,
          contains('preserve every source evidence'),
        );
        expect(
          (await repository.findById('assessment-1'))!.findings.single.id,
          'merged-1',
        );
      },
    );
  });
}

AssessmentFindingReviewController _controller(
  AssessmentRepository repository,
  List<String> ids,
) => AssessmentFindingReviewController(
  assessmentId: 'assessment-1',
  repository: repository,
  idGenerator: _IdGenerator(ids).next,
  now: () => DateTime.utc(2026, 9, 7, 1, 2),
);

IntakeAssessment _assessmentWithObservations() {
  var assessment = IntakeAssessment.create(
    id: 'assessment-1',
    vehicle: const Vehicle(id: 'vehicle-1'),
    appraiserProfile: const AppraiserProfile(
      id: 'appraiser-1',
      displayName: 'Alex Appraiser',
    ),
    createdAt: DateTime.utc(2026, 9, 6, 18),
  );
  for (final captureId in ['capture-1', 'capture-2']) {
    assessment = assessment.acceptCapture(
      Capture(
        id: captureId,
        source: CaptureSource.camera,
        localPath: '/evidence/$captureId.jpg',
        acceptedByProfileId: 'appraiser-1',
        acceptedAt: DateTime.utc(2026, 9, 6, 18, 1),
      ),
    );
  }
  for (final entry in const [
    ('observation-1', 'capture-1', 'dent'),
    ('observation-2', 'capture-2', 'scratch'),
  ]) {
    assessment = assessment.recordObservation(
      DamageObservation(
        id: entry.$1,
        captureId: entry.$2,
        rawClass: entry.$3,
        confidence: 0.8,
        bounds: const ObservationBounds(
          left: 0.1,
          top: 0.2,
          width: 0.3,
          height: 0.4,
        ),
        modelIdentifier: 'test-model',
        runtimeIdentifier: 'test-runtime',
      ),
    );
  }
  return assessment;
}

class _IdGenerator {
  _IdGenerator(this._ids);

  final List<String> _ids;

  String next() => _ids.removeAt(0);
}
