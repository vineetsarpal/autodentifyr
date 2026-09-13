import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_estimate_controller.dart';
import 'package:autodentifyr/services/assessment_estimate_source.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssessmentEstimateController', () {
    test(
      'recalculation deduplicates shared work and keeps missing pricing explicit',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_assessment());
        final controller = AssessmentEstimateController(
          assessmentId: 'assessment-1',
          repository: repository,
          source: const _Source([
            SuggestedRepairOperation(
              operationId: 'refinish-door',
              findingId: 'finding-1',
              description: 'Refinish left-front door',
            ),
            SuggestedRepairOperation(
              operationId: 'refinish-door',
              findingId: 'finding-2',
              description: 'Refinish left-front door',
            ),
          ]),
          idGenerator: () => 'override-1',
          now: () => DateTime.utc(2026, 9, 7, 13),
        );
        await controller.load();

        await controller.submit(const RecalculateEstimateAction());

        final estimate = controller.state.assessment!.estimate!;
        expect(estimate.operations, hasLength(1));
        expect(estimate.operations.single.findingIds, [
          'finding-1',
          'finding-2',
        ]);
        expect(estimate.operations.single.hasPricing, isFalse);
        expect(estimate.isPartial, isTrue);
        expect(estimate.knownMinimumTotalCents, isNull);
        expect(estimate.knownMaximumTotalCents, isNull);
        expect(estimate.sourceVersion, 'test-source-v1');
        expect(estimate.reviewedByProfileId, 'appraiser-1');
        expect((await repository.findById('assessment-1'))!.estimate, estimate);
      },
    );

    test('override provenance survives explicit recalculation', () async {
      final repository = InMemoryAssessmentRepository();
      await repository.save(_assessment());
      final controller = _controller(
        repository,
        const _Source([
          SuggestedRepairOperation(
            operationId: 'repair-door',
            findingId: 'finding-1',
            description: 'Repair left-front door',
          ),
          SuggestedRepairOperation(
            operationId: 'repair-door',
            findingId: 'finding-2',
            description: 'Repair left-front door',
          ),
        ]),
      );
      await controller.load();
      await controller.submit(const RecalculateEstimateAction());

      expect(controller.state.assessment!.estimate!.operations, hasLength(1));
      expect(
        controller.state.assessment!.estimate!.operations.single.findingIds,
        ['finding-1', 'finding-2'],
      );

      await controller.submit(
        const OverrideRepairOperationAction(
          operationId: 'repair-door',
          description: 'Repair and refinish left-front door',
          minimumCents: 10000,
          maximumCents: 20000,
          currency: 'CAD',
          pricingSourceVersion: 'appraiser-source-v1',
          reason: 'Appraiser entered a supported shop range.',
        ),
      );

      var estimate = controller.state.assessment!.estimate!;
      expect(estimate.operations.single.minimumCents, 10000);
      expect(estimate.overrides.single.original.hasPricing, isFalse);
      expect(estimate.overrides.single.original.findingIds, [
        'finding-1',
        'finding-2',
      ]);
      expect(estimate.overrides.single.replacement, estimate.operations.single);
      expect(estimate.overrides.single.authorProfileId, 'appraiser-1');
      expect(
        estimate.overrides.single.reason,
        'Appraiser entered a supported shop range.',
      );

      await controller.submit(const RecalculateEstimateAction());
      estimate = controller.state.assessment!.estimate!;
      expect(estimate.operations.single.minimumCents, 10000);
      expect(estimate.operations.single.findingIds, ['finding-1', 'finding-2']);
      expect(estimate.overrides, hasLength(1));
    });

    test(
      'known subtotal excludes unavailable work and Partial acknowledgment persists',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_assessment());
        final controller = _controller(
          repository,
          const _Source([
            SuggestedRepairOperation(
              operationId: 'priced-work',
              findingId: 'finding-1',
              description: 'Supported repair work',
              minimumCents: 12000,
              maximumCents: 18000,
              currency: 'CAD',
              pricingSourceVersion: 'validated-fixture-v1',
            ),
            SuggestedRepairOperation(
              operationId: 'unpriced-work',
              findingId: 'finding-2',
              description: 'Pricing unavailable',
            ),
          ]),
        );
        await controller.load();
        await controller.submit(const RecalculateEstimateAction());

        expect(
          controller.state.assessment!.estimate!.knownMinimumTotalCents,
          12000,
        );
        expect(
          controller.state.assessment!.estimate!.knownMaximumTotalCents,
          18000,
        );
        expect(controller.state.assessment!.estimate!.isPartial, isTrue);

        await controller.submit(const AcknowledgePartialEstimateAction());
        final estimate = (await repository.findById('assessment-1'))!.estimate!;
        expect(estimate.missingPricingAcknowledgedByProfileId, 'appraiser-1');
        expect(
          estimate.missingPricingAcknowledgedAt,
          DateTime.utc(2026, 9, 7, 13),
        );
      },
    );

    test(
      'edited assumptions persist and recalculation is deterministic',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_assessment());
        final controller = _controller(
          repository,
          const _Source([
            SuggestedRepairOperation(
              operationId: 'repair-door',
              findingId: 'finding-1',
              description: 'Repair left-front door',
            ),
            SuggestedRepairOperation(
              operationId: 'repair-door',
              findingId: 'finding-2',
              description: 'Repair left-front door',
            ),
          ]),
        );
        await controller.load();
        await controller.submit(const RecalculateEstimateAction());
        await controller.submit(
          const EditEstimateAssumptionsAction([
            'Pricing remains unavailable pending an authorized source.',
          ]),
        );

        final first = controller.state.assessment!.estimate!;
        await controller.submit(const RecalculateEstimateAction());
        final second = controller.state.assessment!.estimate!;

        expect(second.operations, first.operations);
        expect(second.assumptions, first.assumptions);
        expect(
          (await repository.findById('assessment-1'))!.estimate!.assumptions,
          first.assumptions,
        );
      },
    );

    test(
      'invalid override is rejected without replacing the Draft Estimate',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_assessment());
        final controller = _controller(
          repository,
          const _Source([
            SuggestedRepairOperation(
              operationId: 'repair-door',
              findingId: 'finding-1',
              description: 'Repair left-front door',
            ),
          ]),
        );
        await controller.load();
        await controller.submit(const RecalculateEstimateAction());
        final original = controller.state.assessment!.estimate;

        await controller.submit(
          const OverrideRepairOperationAction(
            operationId: 'repair-door',
            description: 'Repair left-front door',
            minimumCents: 20000,
            maximumCents: 10000,
            currency: 'CAD',
            pricingSourceVersion: 'appraiser-source-v1',
            reason: 'Invalid range for regression coverage.',
          ),
        );

        expect(controller.state.phase, AssessmentEstimatePhase.failed);
        expect(controller.state.assessment!.estimate, original);
        expect((await repository.findById('assessment-1'))!.estimate, original);
      },
    );

    test('unsupported pricing source rejects a numeric override', () async {
      final repository = InMemoryAssessmentRepository();
      await repository.save(_assessment());
      final controller = _controller(
        repository,
        const UnavailableAssessmentEstimateSource(),
      );
      await controller.load();
      await controller.submit(const RecalculateEstimateAction());

      final unavailableEstimate = controller.state.assessment!.estimate!;
      expect(unavailableEstimate.operations, hasLength(1));
      expect(unavailableEstimate.operations.single.findingIds, [
        'finding-1',
        'finding-2',
      ]);

      await controller.submit(
        const OverrideRepairOperationAction(
          operationId: 'review-left-front-door',
          description: 'Repair left-front door',
          minimumCents: 10000,
          maximumCents: 20000,
          currency: 'CAD',
          pricingSourceVersion: 'typed-by-appraiser',
          reason: 'Unvalidated manual range.',
        ),
      );

      expect(controller.state.phase, AssessmentEstimatePhase.failed);
      expect(controller.state.message, contains('Pricing remains unavailable'));
      expect(
        controller.state.assessment!.estimate!.operations.first.hasPricing,
        isFalse,
      );
    });
  });
}

AssessmentEstimateController _controller(
  AssessmentRepository repository,
  AssessmentEstimateSource source,
) => AssessmentEstimateController(
  assessmentId: 'assessment-1',
  repository: repository,
  source: source,
  idGenerator: () => 'override-1',
  now: () => DateTime.utc(2026, 9, 7, 13),
);

class _Source implements AssessmentEstimateSource {
  const _Source(this.suggestions);

  final List<SuggestedRepairOperation> suggestions;

  @override
  String get version => 'test-source-v1';

  @override
  bool get supportsNumericPricing => true;

  @override
  Future<List<SuggestedRepairOperation>> suggestOperations(
    List<DamageFinding> confirmedFindings,
  ) async => suggestions;
}

IntakeAssessment _assessment() {
  var assessment =
      IntakeAssessment.create(
        id: 'assessment-1',
        vehicle: const Vehicle(id: 'vehicle-1'),
        appraiserProfile: const AppraiserProfile(
          id: 'appraiser-1',
          displayName: 'Alex Appraiser',
        ),
        createdAt: DateTime.utc(2026, 9, 7, 12),
      ).acceptCapture(
        Capture(
          id: 'capture-1',
          source: CaptureSource.camera,
          localPath: '/evidence/capture-1.jpg',
          acceptedByProfileId: 'appraiser-1',
          acceptedAt: DateTime.utc(2026, 9, 7, 12, 1),
        ),
      );
  for (final id in ['finding-1', 'finding-2']) {
    assessment = assessment.addFinding(
      DamageFinding.manual(
        id: id,
        vehicleComponent: 'left-front door',
        damageType: id == 'finding-1' ? 'dent' : 'scratch',
        supportingCaptureIds: const ['capture-1'],
        evidenceNote: 'Visible damage supported by the Capture.',
      ),
    );
  }
  return assessment;
}
