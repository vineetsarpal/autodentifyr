import 'dart:io';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_completion_controller.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssessmentCompletionController', () {
    test(
      'completion exposes an actionable blocker when no Capture is accepted',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_draft());
        final controller = AssessmentCompletionController(
          assessmentId: 'assessment-1',
          repository: repository,
          idGenerator: () => 'revision-1',
          now: () => DateTime.utc(2026, 9, 8, 20),
        );

        await controller.load();

        expect(controller.state.phase, AssessmentCompletionPhase.ready);
        expect(
          controller.state.completionBlockers,
          contains(
            const CompletionBlocker(
              code: CompletionBlockerCode.acceptedCaptureRequired,
              message: 'Accept at least one Capture before completing.',
            ),
          ),
        );
      },
    );

    test('completion identifies each unreviewed Proposed Finding', () async {
      final repository = InMemoryAssessmentRepository();
      final assessment = _draft()
          .acceptCapture(_capture())
          .recordObservation(_observation())
          .addFinding(
            DamageFinding.proposed(
              id: 'finding-1',
              observationIds: const ['observation-1'],
              supportingCaptureIds: const ['capture-1'],
            ),
          );
      await repository.save(assessment);
      final controller = _controller(repository);

      await controller.load();

      expect(
        controller.state.completionBlockers,
        contains(
          const CompletionBlocker(
            code: CompletionBlockerCode.unreviewedFinding,
            message: 'Review Proposed Finding finding-1 before completing.',
          ),
        ),
      );
    });

    test(
      'No Visible Damage requires an Estimate review and explicit confirmation',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_draft().acceptCapture(_capture()));
        final controller = _controller(repository);

        await controller.load();

        expect(
          controller.state.completionBlockers.map((blocker) => blocker.code),
          containsAll([
            CompletionBlockerCode.estimateReviewRequired,
            CompletionBlockerCode.noVisibleDamageConfirmationRequired,
          ]),
        );
      },
    );

    test(
      'completion atomically freezes a No Visible Damage revision',
      () async {
        final repository = InMemoryAssessmentRepository();
        final assessment = _draft()
            .acceptCapture(_capture())
            .recordEstimate(
              AssessmentEstimate(
                operations: const [],
                assumptions: const [
                  'Only visible exterior damage was assessed.',
                ],
                reviewedByProfileId: 'appraiser-1',
                reviewedAt: DateTime.utc(2026, 9, 8, 19, 2),
                sourceVersion: 'unsupported-pricing-v1',
              ),
            );
        await repository.save(assessment);
        final controller = _controller(repository);
        await controller.load();

        await controller.complete(noVisibleDamageConfirmed: true);

        final completed = controller.state.assessment!;
        final revision = completed.completedRevisions.single;
        expect(controller.state.phase, AssessmentCompletionPhase.ready);
        expect(completed.status, IntakeAssessmentStatus.completed);
        expect(revision.id, 'revision-1');
        expect(revision.revisionNumber, 1);
        expect(revision.completedAt, DateTime.utc(2026, 9, 8, 20));
        expect(revision.completedByProfileId, 'appraiser-1');
        expect(revision.completedByName, 'Alex Appraiser');
        expect(revision.vehicleSnapshot, assessment.vehicle);
        expect(revision.captures, assessment.captures);
        expect(revision.observations, isEmpty);
        expect(revision.confirmedFindings, isEmpty);
        expect(revision.estimate, assessment.estimate);
        expect(revision.severityAssessments, isEmpty);
        expect(revision.limitations, assessment.limitations);
        expect(revision.isNoVisibleDamageOutcome, isTrue);
        expect(await repository.findById(assessment.id), completed);
      },
    );

    test(
      'completed content stays read-only until the assessment is reopened',
      () async {
        final repository = InMemoryAssessmentRepository();
        final assessment = _draft()
            .acceptCapture(_capture())
            .recordEstimate(
              AssessmentEstimate(
                operations: const [],
                assumptions: const [
                  'Only visible exterior damage was assessed.',
                ],
                reviewedByProfileId: 'appraiser-1',
                reviewedAt: DateTime.utc(2026, 9, 8, 19, 2),
                sourceVersion: 'unsupported-pricing-v1',
              ),
            );
        await repository.save(assessment);
        final controller = _controller(repository);
        await controller.load();
        await controller.complete(noVisibleDamageConfirmed: true);
        final completed = controller.state.assessment!;

        expect(
          () => completed.recordObservation(
            const DamageObservation(
              id: 'observation-2',
              captureId: 'capture-1',
              rawClass: 'doorouter-scratch',
              confidence: 0.6,
              bounds: ObservationBounds(
                left: 0.2,
                top: 0.2,
                width: 0.2,
                height: 0.2,
              ),
              modelIdentifier: 'best.tflite',
              runtimeIdentifier: 'ultralytics-yolo-0.6.3',
            ),
          ),
          throwsA(isA<AssessmentInvariantViolation>()),
        );
        expect(
          () => completed.addFinding(
            DamageFinding.manual(
              id: 'finding-2',
              vehicleComponent: 'left-front-door',
              damageType: 'scratch',
              supportingCaptureIds: const ['capture-1'],
              evidenceNote: 'Visible scratch in Capture capture-1.',
            ),
          ),
          throwsA(isA<AssessmentInvariantViolation>()),
        );
      },
    );

    test(
      'failed persistence leaves the Draft and its revision history unchanged',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'autodentifyr-completion-rollback-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final assessment = _draft()
            .acceptCapture(_capture())
            .recordEstimate(
              AssessmentEstimate(
                operations: const [],
                assumptions: const [
                  'Only visible exterior damage was assessed.',
                ],
                reviewedByProfileId: 'appraiser-1',
                reviewedAt: DateTime.utc(2026, 9, 8, 19, 2),
                sourceVersion: 'unsupported-pricing-v1',
              ),
            );
        final readableRepository = FileAssessmentRepository(
          directory: directory,
        );
        await readableRepository.save(assessment);
        final failingRepository = FileAssessmentRepository(
          directory: directory,
          writeStore: (_, _) async =>
              throw const FileSystemException('Simulated full storage'),
        );
        final controller = _controller(failingRepository);
        await controller.load();

        await controller.complete(noVisibleDamageConfirmed: true);

        expect(controller.state.phase, AssessmentCompletionPhase.failed);
        expect(controller.state.assessment, assessment);
        expect(controller.state.assessment!.completedRevisions, isEmpty);
        expect(await readableRepository.findById(assessment.id), assessment);
      },
    );

    test(
      'completion blocks an unacknowledged Partial Estimate and missing Severity',
      () async {
        final repository = InMemoryAssessmentRepository();
        final assessment = _confirmedAssessment().recordEstimate(
          AssessmentEstimate(
            operations: const [
              RepairOperation(
                id: 'operation-1',
                findingIds: ['finding-1'],
                description: 'Repair left-front door dent',
              ),
            ],
            assumptions: const ['Pricing evidence is unavailable.'],
            reviewedByProfileId: 'appraiser-1',
            reviewedAt: DateTime.utc(2026, 9, 8, 19, 2),
            sourceVersion: 'unsupported-pricing-v1',
          ),
        );
        await repository.save(assessment);
        final controller = _controller(repository);

        await controller.load();

        expect(
          controller.state.completionBlockers.map((blocker) => blocker.code),
          containsAll([
            CompletionBlockerCode.partialEstimateAcknowledgmentRequired,
            CompletionBlockerCode.severityReviewRequired,
          ]),
        );
      },
    );

    test('finding changes require Estimate and Severity re-review', () async {
      final original = _confirmedAssessment();
      final reviewed = original
          .recordEstimate(_acknowledgedPartialEstimate())
          .recordSeverity(
            SeverityAssessment(
              findingId: 'finding-1',
              reviewedLevel: SeverityLevel.minor,
              evidenceCaptureIds: const ['capture-1'],
              reviewerProfileId: 'appraiser-1',
              reviewedAt: DateTime.utc(2026, 9, 8, 19, 4),
              reason: 'Localized visible extent.',
            ),
          );
      final finding = reviewed.findings.single;
      final changed = finding.edited(
        vehicleComponent: 'left-rear-door',
        damageType: 'dent',
        supportingCaptureIds: finding.supportingCaptureIds,
      );
      final corrected = reviewed.correctFinding(
        replacement: changed,
        correction: AssessmentCorrection(
          id: 'correction-2',
          findingId: finding.id,
          kind: AssessmentCorrectionKind.edit,
          authorProfileId: 'appraiser-1',
          occurredAt: DateTime.utc(2026, 9, 8, 19, 5),
          reason: 'The rear door is the supported component.',
          original: finding,
          replacement: changed,
        ),
      );
      final repository = InMemoryAssessmentRepository();
      await repository.save(corrected);
      final controller = _controller(repository);

      await controller.load();

      expect(
        controller.state.completionBlockers.map((value) => value.code),
        containsAll([
          CompletionBlockerCode.estimateReviewRequired,
          CompletionBlockerCode.severityReviewRequired,
        ]),
      );
    });

    test(
      'Appraiser records assessment limitations before completion',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_draft());
        final controller = _controller(repository);
        await controller.load();

        await controller.updateLimitations(const [
          'The right-rear quarter panel was obscured.',
        ]);

        expect(controller.state.phase, AssessmentCompletionPhase.ready);
        expect(controller.state.assessment!.limitations, [
          'The right-rear quarter panel was obscured.',
        ]);
        expect((await repository.findById('assessment-1'))!.limitations, [
          'The right-rear quarter panel was obscured.',
        ]);
      },
    );

    test(
      'completion requires Estimate coverage for every Confirmed Finding',
      () async {
        final assessment = _confirmedAssessment()
            .recordEstimate(
              AssessmentEstimate(
                operations: const [],
                assumptions: const ['No Repair Operations reviewed.'],
                reviewedByProfileId: 'appraiser-1',
                reviewedAt: DateTime.utc(2026, 9, 8, 19, 2),
                sourceVersion: 'unsupported-pricing-v1',
              ),
            )
            .recordSeverity(
              SeverityAssessment(
                findingId: 'finding-1',
                reviewedLevel: SeverityLevel.minor,
                evidenceCaptureIds: const ['capture-1'],
                reviewerProfileId: 'appraiser-1',
                reviewedAt: DateTime.utc(2026, 9, 8, 19, 3),
                reason: 'Visible damage is localized.',
              ),
            );
        final repository = InMemoryAssessmentRepository();
        await repository.save(assessment);
        final controller = _controller(repository);

        await controller.load();

        expect(
          controller.state.completionBlockers.map((blocker) => blocker.code),
          contains(CompletionBlockerCode.estimateFindingCoverageRequired),
        );
      },
    );

    test(
      'completion reports unmet Finding and Severity evidence requests',
      () async {
        final unresolved =
            DamageFinding.proposed(
                  id: 'finding-2',
                  observationIds: const ['observation-1'],
                  supportingCaptureIds: const ['capture-1'],
                )
                .withUncertainty(
                  hasConflictingViews: true,
                  additionalViewRequests: const [
                    'Capture the lower door edge.',
                  ],
                )
                .markUndetermined();
        final assessment = _confirmedAssessment()
            .addFinding(unresolved)
            .recordEstimate(_acknowledgedPartialEstimate())
            .recordSeverity(
              SeverityAssessment(
                findingId: 'finding-1',
                reviewedLevel: SeverityLevel.undetermined,
                evidenceCaptureIds: const ['capture-1'],
                reviewerProfileId: 'appraiser-1',
                reviewedAt: DateTime.utc(2026, 9, 8, 19, 4),
                reason: 'The visible extent cannot yet be concluded.',
                uncertainty: 'The component edge is obscured.',
                followUpNeed: 'Capture an oblique view of the lower edge.',
              ),
            );
        final repository = InMemoryAssessmentRepository();
        await repository.save(assessment);
        final controller = _controller(repository);

        await controller.load();

        expect(
          controller.state.completionBlockers.map((blocker) => blocker.code),
          containsAll([
            CompletionBlockerCode.findingEvidenceOverrideRequired,
            CompletionBlockerCode.severityEvidenceOverrideRequired,
          ]),
        );
      },
    );

    test(
      'acknowledged Partial Estimate and overridden Undetermined paths complete',
      () async {
        final unresolved =
            DamageFinding.proposed(
                  id: 'finding-2',
                  observationIds: const ['observation-1'],
                  supportingCaptureIds: const ['capture-1'],
                )
                .withUncertainty(
                  hasConflictingViews: true,
                  additionalViewRequests: const [
                    'Capture the lower door edge.',
                  ],
                )
                .markUndetermined(
                  additionalViewOverrideReason:
                      'The Vehicle Owner declined another Capture during intake.',
                );
        final assessment = _confirmedAssessment()
            .addFinding(unresolved)
            .recordEstimate(_acknowledgedPartialEstimate())
            .recordSeverity(
              SeverityAssessment(
                findingId: 'finding-1',
                reviewedLevel: SeverityLevel.undetermined,
                evidenceCaptureIds: const ['capture-1'],
                reviewerProfileId: 'appraiser-1',
                reviewedAt: DateTime.utc(2026, 9, 8, 19, 4),
                reason: 'The visible extent cannot yet be concluded.',
                uncertainty: 'The component edge is obscured.',
                followUpNeed: 'Capture an oblique view of the lower edge.',
                followUpOverrideReason:
                    'The Vehicle Owner declined another Capture during intake.',
              ),
            );
        final repository = InMemoryAssessmentRepository();
        await repository.save(assessment);
        final controller = _controller(repository);
        await controller.load();

        await controller.complete(noVisibleDamageConfirmed: false);

        final revision = controller.state.assessment!.completedRevisions.single;
        expect(controller.state.phase, AssessmentCompletionPhase.ready);
        expect(revision.confirmedFindings.map((finding) => finding.id), [
          'finding-1',
        ]);
        expect(revision.estimate.isPartial, isTrue);
        expect(
          revision.severityAssessments.single.reviewedLevel,
          SeverityLevel.undetermined,
        );
        expect(revision.isNoVisibleDamageOutcome, isFalse);
      },
    );

    test(
      'reopening preserves revision one and recompletion creates revision two',
      () async {
        final repository = InMemoryAssessmentRepository();
        final assessment = _draft()
            .acceptCapture(_capture())
            .recordEstimate(
              AssessmentEstimate(
                operations: const [],
                assumptions: const [
                  'Only visible exterior damage was assessed.',
                ],
                reviewedByProfileId: 'appraiser-1',
                reviewedAt: DateTime.utc(2026, 9, 8, 19, 2),
                sourceVersion: 'unsupported-pricing-v1',
              ),
            );
        await repository.save(assessment);
        var sequence = 0;
        final controller = AssessmentCompletionController(
          assessmentId: assessment.id,
          repository: repository,
          idGenerator: () => 'revision-${++sequence}',
          now: () => DateTime.utc(2026, 9, 8, 20, sequence),
        );
        await controller.load();
        await controller.complete(noVisibleDamageConfirmed: true);
        final firstRevisionJson = controller
            .state
            .assessment!
            .completedRevisions
            .single
            .toJson();

        expect(
          () => controller.state.assessment!.acceptCapture(_secondCapture()),
          throwsA(isA<AssessmentInvariantViolation>()),
        );
        await controller.reopen();
        final revisedDraft = controller.state.assessment!.acceptCapture(
          _secondCapture(),
        );
        await repository.save(revisedDraft);
        await controller.load();
        await controller.complete(noVisibleDamageConfirmed: true);

        final recompleted = controller.state.assessment!;
        expect(recompleted.completedRevisions, hasLength(2));
        expect(
          recompleted.completedRevisions.first.toJson(),
          firstRevisionJson,
        );
        expect(recompleted.completedRevisions.first.captures, hasLength(1));
        expect(recompleted.completedRevisions.last.revisionNumber, 2);
        expect(recompleted.completedRevisions.last.captures, hasLength(2));
      },
    );

    test(
      'voiding records provenance, preserves revisions, and prevents reopening',
      () async {
        final repository = InMemoryAssessmentRepository();
        final assessment = _draft()
            .acceptCapture(_capture())
            .recordEstimate(
              AssessmentEstimate(
                operations: const [],
                assumptions: const [
                  'Only visible exterior damage was assessed.',
                ],
                reviewedByProfileId: 'appraiser-1',
                reviewedAt: DateTime.utc(2026, 9, 8, 19, 2),
                sourceVersion: 'unsupported-pricing-v1',
              ),
            );
        await repository.save(assessment);
        final controller = _controller(repository);
        await controller.load();
        await controller.complete(noVisibleDamageConfirmed: true);
        final revisionJson = controller
            .state
            .assessment!
            .completedRevisions
            .single
            .toJson();

        await controller.voidAssessment(reason: 'Duplicate intake record.');

        final voided = controller.state.assessment!;
        expect(voided.status, IntakeAssessmentStatus.voided);
        expect(voided.voidRecord!.reason, 'Duplicate intake record.');
        expect(voided.voidRecord!.voidedByProfileId, 'appraiser-1');
        expect(voided.voidRecord!.voidedByName, 'Alex Appraiser');
        expect(voided.voidRecord!.voidedAt, DateTime.utc(2026, 9, 8, 20));
        expect(voided.completedRevisions.single.toJson(), revisionJson);

        await controller.reopen();

        expect(controller.state.phase, AssessmentCompletionPhase.failed);
        expect(controller.state.assessment, voided);
        expect(controller.state.message, contains('Completed'));
      },
    );
  });
}

AssessmentCompletionController _controller(AssessmentRepository repository) =>
    AssessmentCompletionController(
      assessmentId: 'assessment-1',
      repository: repository,
      idGenerator: () => 'revision-1',
      now: () => DateTime.utc(2026, 9, 8, 20),
    );

IntakeAssessment _draft() => IntakeAssessment.create(
  id: 'assessment-1',
  vehicle: const Vehicle(id: 'vehicle-1', vin: '1A2B3C4D5E6F7G8H9'),
  appraiserProfile: const AppraiserProfile(
    id: 'appraiser-1',
    displayName: 'Alex Appraiser',
  ),
  createdAt: DateTime.utc(2026, 9, 8, 19),
);

Capture _capture() => Capture(
  id: 'capture-1',
  source: CaptureSource.camera,
  localPath: '/evidence/capture-1.jpg',
  acceptedByProfileId: 'appraiser-1',
  acceptedAt: DateTime.utc(2026, 9, 8, 19, 1),
);

Capture _secondCapture() => Capture(
  id: 'capture-2',
  source: CaptureSource.import,
  localPath: '/evidence/capture-2.jpg',
  acceptedByProfileId: 'appraiser-1',
  acceptedAt: DateTime.utc(2026, 9, 8, 20, 2),
);

DamageObservation _observation() => const DamageObservation(
  id: 'observation-1',
  captureId: 'capture-1',
  rawClass: 'doorouter-dent',
  confidence: 0.87,
  bounds: ObservationBounds(left: 0.1, top: 0.2, width: 0.3, height: 0.4),
  modelIdentifier: 'best.tflite',
  runtimeIdentifier: 'ultralytics-yolo-0.6.3',
);

IntakeAssessment _confirmedAssessment() {
  final proposed = DamageFinding.proposed(
    id: 'finding-1',
    observationIds: const ['observation-1'],
    supportingCaptureIds: const ['capture-1'],
  );
  return _draft()
      .acceptCapture(_capture())
      .recordObservation(_observation())
      .addFinding(
        proposed.reviewed(
          state: FindingReviewState.confirmed,
          vehicleComponent: 'left-front-door',
          damageType: 'dent',
        ),
      );
}

AssessmentEstimate _acknowledgedPartialEstimate() => AssessmentEstimate(
  operations: const [
    RepairOperation(
      id: 'operation-1',
      findingIds: ['finding-1'],
      description: 'Repair left-front door dent',
    ),
  ],
  assumptions: const ['Pricing evidence is unavailable.'],
  reviewedByProfileId: 'appraiser-1',
  reviewedAt: DateTime.utc(2026, 9, 8, 19, 2),
  sourceVersion: 'unsupported-pricing-v1',
  missingPricingAcknowledgedAt: DateTime.utc(2026, 9, 8, 19, 3),
  missingPricingAcknowledgedByProfileId: 'appraiser-1',
);
