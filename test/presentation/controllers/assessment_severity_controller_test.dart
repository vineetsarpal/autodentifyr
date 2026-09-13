import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_severity_controller.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:autodentifyr/services/assessment_severity_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssessmentSeverityController', () {
    test(
      'unavailable automation permits a supported manual Minor review',
      () async {
        final repository = InMemoryAssessmentRepository();
        final original = _assessment().recordEstimate(
          AssessmentEstimate(
            operations: const [
              RepairOperation(
                id: 'repair-door',
                findingIds: ['finding-1'],
                description: 'Repair left-front door',
              ),
            ],
            assumptions: const ['Pricing unavailable.'],
            reviewedByProfileId: 'appraiser-1',
            reviewedAt: DateTime.utc(2026, 9, 7, 15, 30),
            sourceVersion: 'unsupported-pricing-v1',
          ),
        );
        await repository.save(original);
        final controller = AssessmentSeverityController(
          assessmentId: original.id,
          repository: repository,
          source: const UnavailableSeveritySuggestionSource(),
          now: () => DateTime.utc(2026, 9, 7, 16),
        );
        await controller.load();

        await controller.submit(
          const ReviewSeverityAction(
            findingId: 'finding-1',
            reviewedLevel: SeverityLevel.minor,
            evidenceCaptureIds: ['capture-1'],
            reason: 'Visible damage is localized on the component.',
          ),
        );

        final updated = controller.state.assessment!;
        final severity = updated.severityAssessments.single;
        expect(controller.state.phase, AssessmentSeverityPhase.ready);
        expect(controller.state.suggestionBatch!.isSupported, isFalse);
        expect(severity.reviewedLevel, SeverityLevel.minor);
        expect(severity.originalSuggestion, isNull);
        expect(severity.automationSourceVersion, 'unsupported-severity-v1');
        expect(severity.automationLimitation, contains('not supported'));
        expect(severity.evidenceCaptureIds, ['capture-1']);
        expect(severity.reviewerProfileId, 'appraiser-1');
        expect(severity.reviewedAt, DateTime.utc(2026, 9, 7, 16));
        expect(updated.estimate, original.estimate);
        expect((await repository.findById(original.id))!.severityAssessments, [
          severity,
        ]);
      },
    );

    test(
      'Appraiser override preserves a synthetic suggestion separately',
      () async {
        final repository = InMemoryAssessmentRepository();
        final original = _assessment();
        await repository.save(original);
        final controller = AssessmentSeverityController(
          assessmentId: original.id,
          repository: repository,
          source: const _SyntheticSeveritySuggestionSource(),
          now: () => DateTime.utc(2026, 9, 7, 16, 5),
        );
        await controller.load();

        await controller.submit(
          const ReviewSeverityAction(
            findingId: 'finding-1',
            reviewedLevel: SeverityLevel.severe,
            evidenceCaptureIds: ['capture-1'],
            reason: 'The visible extent is widespread across the component.',
            uncertainty: 'The lower edge remains partially obscured.',
          ),
        );

        final severity =
            controller.state.assessment!.severityAssessments.single;
        expect(severity.reviewedLevel, SeverityLevel.severe);
        expect(severity.originalSuggestion, SeverityLevel.moderate);
        expect(severity.automationSourceVersion, 'synthetic-workflow-only-v1');
        expect(severity.suggestionEvidenceCaptureIds, ['capture-1']);
        expect(severity.suggestionIsSynthetic, isTrue);
        expect(
          severity.reason,
          'The visible extent is widespread across the component.',
        );
      },
    );

    test(
      'Undetermined requires stated uncertainty and a specific additional view',
      () async {
        final repository = InMemoryAssessmentRepository();
        final original = _assessment();
        await repository.save(original);
        final controller = AssessmentSeverityController(
          assessmentId: original.id,
          repository: repository,
          source: const UnavailableSeveritySuggestionSource(),
          now: () => DateTime.utc(2026, 9, 7, 16, 10),
        );
        await controller.load();

        await controller.submit(
          const ReviewSeverityAction(
            findingId: 'finding-1',
            reviewedLevel: SeverityLevel.undetermined,
            evidenceCaptureIds: ['capture-1'],
            reason: 'The visible extent cannot yet be concluded.',
          ),
        );

        expect(controller.state.phase, AssessmentSeverityPhase.failed);
        expect(controller.state.assessment!.severityAssessments, isEmpty);

        await controller.submit(
          const ReviewSeverityAction(
            findingId: 'finding-1',
            reviewedLevel: SeverityLevel.undetermined,
            evidenceCaptureIds: ['capture-1'],
            reason: 'The visible extent cannot yet be concluded.',
            uncertainty: 'The component edge is obscured.',
            additionalViewRequest:
                'Capture an oblique view of the left-front door lower edge.',
          ),
        );

        final severity =
            controller.state.assessment!.severityAssessments.single;
        expect(severity.reviewedLevel, SeverityLevel.undetermined);
        expect(severity.uncertainty, 'The component edge is obscured.');
        expect(
          severity.followUpNeed,
          'Capture an oblique view of the left-front door lower edge.',
        );
      },
    );

    test(
      'Moderate review requires evidence linked to its Confirmed Finding',
      () async {
        final repository = InMemoryAssessmentRepository();
        final original = _assessment().acceptCapture(
          Capture(
            id: 'capture-2',
            source: CaptureSource.import,
            localPath: '/evidence/capture-2.jpg',
            acceptedByProfileId: 'appraiser-1',
            acceptedAt: DateTime.utc(2026, 9, 7, 15, 2),
          ),
        );
        await repository.save(original);
        final controller = AssessmentSeverityController(
          assessmentId: original.id,
          repository: repository,
          source: const UnavailableSeveritySuggestionSource(),
          now: () => DateTime.utc(2026, 9, 7, 16, 15),
        );
        await controller.load();

        await controller.submit(
          const ReviewSeverityAction(
            findingId: 'finding-1',
            reviewedLevel: SeverityLevel.moderate,
            evidenceCaptureIds: ['capture-2'],
            reason: 'Intermediate visible extent.',
          ),
        );

        expect(controller.state.phase, AssessmentSeverityPhase.failed);
        expect(controller.state.assessment!.severityAssessments, isEmpty);

        await controller.submit(
          const ReviewSeverityAction(
            findingId: 'finding-1',
            reviewedLevel: SeverityLevel.moderate,
            evidenceCaptureIds: ['capture-1'],
            reason:
                'Visible damage has intermediate component-relative extent.',
          ),
        );

        expect(
          controller.state.assessment!.severityAssessments.single.reviewedLevel,
          SeverityLevel.moderate,
        );
      },
    );

    test(
      'conflicting captures remain visible and a determined review explains an unmet view',
      () async {
        final repository = InMemoryAssessmentRepository();
        final original = _assessment(conflictingViews: true);
        await repository.save(original);
        final controller = AssessmentSeverityController(
          assessmentId: original.id,
          repository: repository,
          source: const UnavailableSeveritySuggestionSource(),
          now: () => DateTime.utc(2026, 9, 7, 16, 20),
        );
        await controller.load();

        const request =
            'Capture a perpendicular view of the left-front door lower edge.';
        await controller.submit(
          const ReviewSeverityAction(
            findingId: 'finding-1',
            reviewedLevel: SeverityLevel.moderate,
            evidenceCaptureIds: ['capture-1'],
            reason: 'The retained view supports intermediate visible extent.',
            uncertainty: 'Reflections conflict near the lower edge.',
            additionalViewRequest: request,
          ),
        );

        expect(controller.state.phase, AssessmentSeverityPhase.failed);
        expect(controller.state.assessment!.severityAssessments, isEmpty);

        await controller.submit(
          const ReviewSeverityAction(
            findingId: 'finding-1',
            reviewedLevel: SeverityLevel.moderate,
            evidenceCaptureIds: ['capture-1'],
            reason: 'The retained view supports intermediate visible extent.',
            uncertainty: 'Reflections conflict near the lower edge.',
            additionalViewRequest: request,
            additionalViewOverrideReason:
                'The accepted overview still shows the component-relative extent.',
          ),
        );

        final updated = controller.state.assessment!;
        final severity = updated.severityAssessments.single;
        expect(updated.findings.single.hasConflictingViews, isTrue);
        expect(severity.followUpNeed, request);
        expect(
          severity.followUpOverrideReason,
          'The accepted overview still shows the component-relative extent.',
        );
      },
    );

    test(
      're-review preserves every earlier severity conclusion and reason',
      () async {
        final repository = InMemoryAssessmentRepository();
        final original = _assessment();
        await repository.save(original);
        final times = [
          DateTime.utc(2026, 9, 7, 16, 25),
          DateTime.utc(2026, 9, 7, 16, 30),
        ].iterator;
        final controller = AssessmentSeverityController(
          assessmentId: original.id,
          repository: repository,
          source: const UnavailableSeveritySuggestionSource(),
          now: () {
            times.moveNext();
            return times.current;
          },
        );
        await controller.load();

        await controller.submit(
          const ReviewSeverityAction(
            findingId: 'finding-1',
            reviewedLevel: SeverityLevel.minor,
            evidenceCaptureIds: ['capture-1'],
            reason: 'Initially assessed as localized visible extent.',
          ),
        );
        await controller.submit(
          const ReviewSeverityAction(
            findingId: 'finding-1',
            reviewedLevel: SeverityLevel.moderate,
            evidenceCaptureIds: ['capture-1'],
            reason: 'Closer review shows intermediate visible extent.',
          ),
        );

        final severity =
            controller.state.assessment!.severityAssessments.single;
        expect(severity.reviewedLevel, SeverityLevel.moderate);
        expect(severity.reviewedAt, DateTime.utc(2026, 9, 7, 16, 30));
        expect(severity.reviewHistory, hasLength(1));
        expect(
          severity.reviewHistory.single.reviewedLevel,
          SeverityLevel.minor,
        );
        expect(
          severity.reviewHistory.single.reason,
          'Initially assessed as localized visible extent.',
        );
        expect(
          severity.reviewHistory.single.reviewedAt,
          DateTime.utc(2026, 9, 7, 16, 25),
        );
        expect(
          (await repository.findById(
            original.id,
          ))!.severityAssessments.single.reviewHistory,
          severity.reviewHistory,
        );
      },
    );

    test(
      'automation failure degrades to unavailable without blocking review',
      () async {
        final repository = InMemoryAssessmentRepository();
        final original = _assessment();
        await repository.save(original);
        final controller = AssessmentSeverityController(
          assessmentId: original.id,
          repository: repository,
          source: const _ThrowingSeveritySuggestionSource(),
          now: () => DateTime.utc(2026, 9, 7, 16, 35),
        );

        await controller.load();

        expect(controller.state.phase, AssessmentSeverityPhase.ready);
        expect(controller.state.suggestionBatch!.isSupported, isFalse);
        expect(
          controller.state.suggestionBatch!.limitation,
          contains('unavailable'),
        );

        await controller.submit(
          const ReviewSeverityAction(
            findingId: 'finding-1',
            reviewedLevel: SeverityLevel.minor,
            evidenceCaptureIds: ['capture-1'],
            reason: 'Manual review remains supported.',
          ),
        );
        expect(controller.state.phase, AssessmentSeverityPhase.ready);
        expect(
          controller.state.assessment!.severityAssessments.single.reviewedLevel,
          SeverityLevel.minor,
        );
      },
    );
  });
}

class _ThrowingSeveritySuggestionSource implements SeveritySuggestionSource {
  const _ThrowingSeveritySuggestionSource();

  @override
  Future<SeveritySuggestionBatch> suggest(
    List<DamageFinding> confirmedFindings,
    List<Capture> captures,
  ) => throw StateError('Synthetic automation failure.');
}

class _SyntheticSeveritySuggestionSource implements SeveritySuggestionSource {
  const _SyntheticSeveritySuggestionSource();

  @override
  Future<SeveritySuggestionBatch> suggest(
    List<DamageFinding> confirmedFindings,
    List<Capture> captures,
  ) async => const SeveritySuggestionBatch.supported(
    sourceVersion: 'synthetic-workflow-only-v1',
    isSynthetic: true,
    suggestions: [
      SeveritySuggestion(
        findingId: 'finding-1',
        level: SeverityLevel.moderate,
        evidenceCaptureIds: ['capture-1'],
      ),
    ],
  );
}

IntakeAssessment _assessment({bool conflictingViews = false}) {
  var proposed = DamageFinding.proposed(
    id: 'finding-1',
    observationIds: const ['observation-1'],
    supportingCaptureIds: const ['capture-1'],
    suggestedVehicleComponent: 'left-front door',
    suggestedDamageType: 'dent',
  );
  if (conflictingViews) {
    proposed = proposed.withUncertainty(
      hasConflictingViews: true,
      additionalViewRequests: const [],
    );
  }
  final confirmed = proposed.reviewed(
    state: FindingReviewState.confirmed,
    vehicleComponent: 'left-front door',
    damageType: 'dent',
  );
  return IntakeAssessment.create(
        id: 'assessment-1',
        vehicle: const Vehicle(id: 'vehicle-1'),
        appraiserProfile: const AppraiserProfile(
          id: 'appraiser-1',
          displayName: 'Alex Appraiser',
        ),
        createdAt: DateTime.utc(2026, 9, 7, 15),
      )
      .acceptCapture(
        Capture(
          id: 'capture-1',
          source: CaptureSource.camera,
          localPath: '/evidence/capture-1.jpg',
          acceptedByProfileId: 'appraiser-1',
          acceptedAt: DateTime.utc(2026, 9, 7, 15, 1),
        ),
      )
      .recordObservation(
        const DamageObservation(
          id: 'observation-1',
          captureId: 'capture-1',
          rawClass: 'dent',
          confidence: 0.8,
          bounds: ObservationBounds(
            left: 0.1,
            top: 0.2,
            width: 0.3,
            height: 0.4,
          ),
          modelIdentifier: 'test-model',
          runtimeIdentifier: 'test-runtime',
        ),
      )
      .addFinding(confirmed);
}
