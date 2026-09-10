import 'dart:convert';
import 'dart:io';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssessmentRepository', () {
    test('saves a Draft and reloads it after the repository reopens', () async {
      final directory = await Directory.systemTemp.createTemp(
        'autodentifyr-assessment-repository-',
      );
      addTearDown(() => directory.delete(recursive: true));

      final assessment = IntakeAssessment.create(
        id: 'assessment-1',
        vehicle: const Vehicle(id: 'vehicle-1'),
        appraiserProfile: const AppraiserProfile(
          id: 'appraiser-1',
          displayName: 'Alex Appraiser',
        ),
        createdAt: DateTime.utc(2026, 9, 6, 18),
      );

      final firstSession = FileAssessmentRepository(directory: directory);
      final saveResult = await firstSession.save(assessment);

      expect(saveResult, isA<AssessmentSaved>());

      final reopenedSession = FileAssessmentRepository(directory: directory);
      final reloaded = await reopenedSession.findById(assessment.id);

      expect(reloaded, assessment);
      expect(await reopenedSession.list(), [assessment]);
    });

    test(
      'persists accepted evidence and rejects an orphan observation',
      () async {
        final assessment = _draft().acceptCapture(
          Capture(
            id: 'capture-1',
            source: CaptureSource.camera,
            localPath: '/evidence/capture-1.jpg',
            acceptedByProfileId: 'appraiser-1',
            acceptedAt: DateTime.utc(2026, 9, 6, 18, 1),
          ),
        );
        const observation = DamageObservation(
          id: 'observation-1',
          captureId: 'capture-1',
          rawClass: 'doorouter-dent',
          confidence: 0.87,
          bounds: ObservationBounds(
            left: 0.1,
            top: 0.2,
            width: 0.3,
            height: 0.4,
          ),
          modelIdentifier: 'best.tflite',
        );

        final withObservation = assessment.recordObservation(observation);
        final repository = InMemoryAssessmentRepository();
        await repository.save(withObservation);

        expect(await repository.findById(assessment.id), withObservation);
        expect(
          () => _draft().recordObservation(observation),
          throwsA(isA<AssessmentInvariantViolation>()),
        );
      },
    );

    test(
      'preserves a finding correction without rewriting its source',
      () async {
        final observed = _draft()
            .acceptCapture(_capture())
            .recordObservation(_observation());
        final proposed = DamageFinding.proposed(
          id: 'finding-1',
          observationIds: const ['observation-1'],
          supportingCaptureIds: const ['capture-1'],
        );
        final withProposal = observed.addFinding(proposed);
        final confirmed = proposed.reviewed(
          state: FindingReviewState.confirmed,
          vehicleComponent: 'left-front-door',
          damageType: 'dent',
        );
        final corrected = withProposal.correctFinding(
          replacement: confirmed,
          correction: AssessmentCorrection(
            id: 'correction-1',
            findingId: proposed.id,
            kind: AssessmentCorrectionKind.confirm,
            authorProfileId: 'appraiser-1',
            occurredAt: DateTime.utc(2026, 9, 6, 18, 2),
            reason: 'Visible dent confirmed on the left-front door.',
            original: proposed,
            replacement: confirmed,
          ),
        );

        final repository = InMemoryAssessmentRepository();
        await repository.save(corrected);
        final reloaded = await repository.findById(corrected.id);

        expect(reloaded!.findings, [confirmed]);
        expect(reloaded.corrections.single.original, proposed);
        expect(reloaded.corrections.single.replacement, confirmed);
        expect(
          () => _draft().addFinding(proposed),
          throwsA(isA<AssessmentInvariantViolation>()),
        );
      },
    );

    test(
      'reports a retryable save failure without replacing stored data',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'autodentifyr-assessment-rollback-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final repository = FileAssessmentRepository(directory: directory);
        await repository.save(_draft());

        final failingRepository = FileAssessmentRepository(
          directory: directory,
          writeStore: (_, _) async =>
              throw const FileSystemException('Simulated full storage'),
        );
        final changed = _draft().acceptCapture(_capture());

        final result = await failingRepository.save(changed);

        expect(result, isA<AssessmentSaveFailed>());
        expect((result as AssessmentSaveFailed).retryable, isTrue);
        expect(await repository.findById(changed.id), _draft());
      },
    );

    test(
      'loads schema version 1 and rewrites it at the current version',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'autodentifyr-assessment-migration-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final store = File('${directory.path}/assessments.json');
        final legacyRecord = _draft().toJson()
          ..remove('captures')
          ..remove('observations')
          ..remove('findings')
          ..remove('corrections');
        await store.writeAsString(
          jsonEncode({
            'schemaVersion': 1,
            'assessments': [legacyRecord],
          }),
        );
        final repository = FileAssessmentRepository(directory: directory);

        final migrated = await repository.findById('assessment-1');
        await repository.save(migrated!);
        final rewritten = jsonDecode(await store.readAsString()) as Map;

        expect(migrated, _draft());
        expect(
          rewritten['schemaVersion'],
          FileAssessmentRepository.currentSchemaVersion,
        );
      },
    );

    test(
      'migrates capture and runtime provenance from schema version 4',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'autodentifyr-assessment-v4-migration-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final store = File('${directory.path}/assessments.json');
        final legacyRecord = _draft()
            .acceptCapture(_capture())
            .recordObservation(_observation())
            .toJson();
        final capture = (legacyRecord['captures']! as List).single as Map;
        capture.remove('capturedAt');
        capture.remove('orientation');
        final observation =
            (legacyRecord['observations']! as List).single as Map;
        observation.remove('runtimeIdentifier');
        await store.writeAsString(
          jsonEncode({
            'schemaVersion': 4,
            'assessments': [legacyRecord],
          }),
        );

        final migrated = await FileAssessmentRepository(
          directory: directory,
        ).findById('assessment-1');

        expect(migrated!.captures.single.capturedAt, _capture().acceptedAt);
        expect(
          migrated.captures.single.orientation,
          CaptureOrientation.unknown,
        );
        expect(migrated.observations.single.runtimeIdentifier, 'unknown');
      },
    );

    test(
      'migrates Partial Estimate acknowledgment provenance from schema 6',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'autodentifyr-assessment-v6-migration-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final store = File('${directory.path}/assessments.json');
        final proposed = DamageFinding.proposed(
          id: 'finding-1',
          observationIds: const ['observation-1'],
          supportingCaptureIds: const ['capture-1'],
        );
        final assessment = _draft()
            .acceptCapture(_capture())
            .recordObservation(_observation())
            .addFinding(
              proposed.reviewed(
                state: FindingReviewState.confirmed,
                vehicleComponent: 'left-front-door',
                damageType: 'dent',
              ),
            )
            .recordEstimate(
              AssessmentEstimate(
                operations: const [
                  RepairOperation(
                    id: 'operation-1',
                    findingIds: ['finding-1'],
                    description: 'Repair left-front door dent',
                  ),
                ],
                assumptions: const ['Pricing unavailable.'],
                reviewedByProfileId: 'appraiser-1',
                reviewedAt: DateTime.utc(2026, 9, 6, 18, 3),
                missingPricingAcknowledgedAt: DateTime.utc(2026, 9, 6, 18, 3),
                missingPricingAcknowledgedByProfileId: 'appraiser-1',
              ),
            );
        final legacyRecord = assessment.toJson();
        final legacyEstimate = legacyRecord['estimate']! as Map;
        legacyEstimate.remove('sourceVersion');
        legacyEstimate.remove('overrides');
        legacyEstimate.remove('missingPricingAcknowledgedByProfileId');
        await store.writeAsString(
          jsonEncode({
            'schemaVersion': 6,
            'assessments': [legacyRecord],
          }),
        );

        final migrated = await FileAssessmentRepository(
          directory: directory,
        ).findById('assessment-1');

        expect(migrated!.estimate!.sourceVersion, 'unknown');
        expect(
          migrated.estimate!.missingPricingAcknowledgedByProfileId,
          'appraiser-1',
        );
      },
    );

    test(
      'persists estimate and severity records with explicit unknowns',
      () async {
        final proposed = DamageFinding.proposed(
          id: 'finding-1',
          observationIds: const ['observation-1'],
          supportingCaptureIds: const ['capture-1'],
        );
        final confirmed = proposed.reviewed(
          state: FindingReviewState.confirmed,
          vehicleComponent: 'left-front-door',
          damageType: 'dent',
        );
        final assessment = _draft()
            .acceptCapture(_capture())
            .recordObservation(_observation())
            .addFinding(confirmed)
            .recordEstimate(
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
                reviewedAt: DateTime.utc(2026, 9, 6, 18, 3),
                sourceVersion: 'unsupported-pricing-v1',
                overrides: [
                  EstimateOverride(
                    id: 'override-1',
                    operationId: 'operation-1',
                    authorProfileId: 'appraiser-1',
                    occurredAt: DateTime.utc(2026, 9, 6, 18, 2),
                    reason: 'Clarified the operation description.',
                    original: const RepairOperation(
                      id: 'operation-1',
                      findingIds: ['finding-1'],
                      description: 'Review left-front door dent',
                    ),
                    replacement: const RepairOperation(
                      id: 'operation-1',
                      findingIds: ['finding-1'],
                      description: 'Repair left-front door dent',
                    ),
                  ),
                ],
                missingPricingAcknowledgedAt: DateTime.utc(2026, 9, 6, 18, 3),
                missingPricingAcknowledgedByProfileId: 'appraiser-1',
              ),
            )
            .recordSeverity(
              SeverityAssessment(
                findingId: 'finding-1',
                reviewedLevel: SeverityLevel.undetermined,
                evidenceCaptureIds: const ['capture-1'],
                reviewerProfileId: 'appraiser-1',
                reviewedAt: DateTime.utc(2026, 9, 6, 18, 4),
                reason: 'Another view is required.',
                uncertainty: 'The component edge is obscured.',
                followUpNeed: 'Capture an oblique view of the door.',
              ),
            );
        final directory = await Directory.systemTemp.createTemp(
          'autodentifyr-assessment-records-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final repository = FileAssessmentRepository(directory: directory);

        await repository.save(assessment);
        final reloaded = await repository.findById(assessment.id);

        expect(reloaded, assessment);
        expect(reloaded!.estimate!.operations.single.hasPricing, isFalse);
        expect(reloaded.estimate!.overrides, hasLength(1));
        expect(
          reloaded.estimate!.missingPricingAcknowledgedByProfileId,
          'appraiser-1',
        );
        expect(
          reloaded.severityAssessments.single.reviewedLevel,
          SeverityLevel.undetermined,
        );
        expect(reloaded.completedRevisions, isEmpty);
      },
    );

    test(
      'reloads a complete immutable revision after repository restart',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'autodentifyr-completed-revision-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final completed = _completedNoVisibleDamage();
        await FileAssessmentRepository(directory: directory).save(completed);

        final reloaded = await FileAssessmentRepository(
          directory: directory,
        ).findById(completed.id);

        expect(reloaded, completed);
        expect(
          reloaded!.completedRevisions.single.vehicleSnapshot,
          completed.vehicle,
        );
        expect(reloaded.completedRevisions.single.captures, completed.captures);
      },
    );

    test(
      'rejects a completed revision whose frozen evidence is incomplete',
      () async {
        final completed = _completedNoVisibleDamage();
        final malformedJson = completed.toJson();
        final revision =
            (malformedJson['completedRevisions']! as List).single as Map;
        revision['captures'] = <Object?>[];
        final malformed = IntakeAssessment.fromJson(malformedJson);
        final repository = InMemoryAssessmentRepository();

        final result = await repository.save(malformed);

        expect(result, isA<AssessmentSaveFailed>());
        expect(await repository.list(), isEmpty);
      },
    );

    test('rejects incomplete Confirmed and manual Findings', () {
      final proposed = DamageFinding.proposed(
        id: 'finding-1',
        observationIds: const ['observation-1'],
        supportingCaptureIds: const ['capture-1'],
      );

      expect(
        () => proposed.reviewed(
          state: FindingReviewState.confirmed,
          vehicleComponent: 'left-front-door',
        ),
        throwsA(isA<AssessmentInvariantViolation>()),
      );
      expect(
        () => DamageFinding.manual(
          id: 'finding-2',
          vehicleComponent: 'left-front-door',
          damageType: 'dent',
          supportingCaptureIds: const ['capture-1'],
          evidenceNote: '   ',
        ),
        throwsA(isA<AssessmentInvariantViolation>()),
      );
    });

    test(
      'rejects persisted Severity evidence not linked to its Finding',
      () async {
        final proposed = DamageFinding.proposed(
          id: 'finding-1',
          observationIds: const ['observation-1'],
          supportingCaptureIds: const ['capture-1'],
        );
        final valid = _draft()
            .acceptCapture(_capture())
            .acceptCapture(
              Capture(
                id: 'capture-2',
                source: CaptureSource.import,
                localPath: '/evidence/capture-2.jpg',
                acceptedByProfileId: 'appraiser-1',
                acceptedAt: DateTime.utc(2026, 9, 6, 18, 2),
              ),
            )
            .recordObservation(_observation())
            .addFinding(
              proposed.reviewed(
                state: FindingReviewState.confirmed,
                vehicleComponent: 'left-front-door',
                damageType: 'dent',
              ),
            )
            .recordSeverity(
              SeverityAssessment(
                findingId: 'finding-1',
                reviewedLevel: SeverityLevel.minor,
                evidenceCaptureIds: const ['capture-1'],
                reviewerProfileId: 'appraiser-1',
                reviewedAt: DateTime.utc(2026, 9, 6, 18, 3),
                reason: 'Localized visible extent.',
              ),
            );
        final malformedJson = valid.toJson();
        final severity =
            (malformedJson['severityAssessments']! as List).single
                as Map<String, Object?>;
        severity['evidenceCaptureIds'] = ['capture-2'];
        final malformed = IntakeAssessment.fromJson(malformedJson);
        final repository = InMemoryAssessmentRepository();

        final result = await repository.save(malformed);

        expect(result, isA<AssessmentSaveFailed>());
      },
    );

    test(
      'rejects an invalid aggregate without changing stored records',
      () async {
        final repository = InMemoryAssessmentRepository();
        final invalid = IntakeAssessment.fromJson({
          ..._draft().toJson(),
          'vehicle': {'id': ''},
        });

        final result = await repository.save(invalid);

        expect(result, isA<AssessmentSaveFailed>());
        expect((result as AssessmentSaveFailed).retryable, isFalse);
        expect(await repository.list(), isEmpty);
      },
    );

    test(
      'updates one assessment without duplicating or dropping another',
      () async {
        final repository = InMemoryAssessmentRepository();
        final other = IntakeAssessment.create(
          id: 'assessment-2',
          vehicle: const Vehicle(id: 'vehicle-2'),
          appraiserProfile: const AppraiserProfile(
            id: 'appraiser-1',
            displayName: 'Alex Appraiser',
          ),
          createdAt: DateTime.utc(2026, 9, 6, 17),
        );
        await repository.save(_draft());
        await repository.save(other);
        final updated = _draft().acceptCapture(_capture());

        await repository.save(updated);

        expect(await repository.findById(updated.id), updated);
        expect(await repository.findById(other.id), other);
        expect(await repository.list(), [updated, other]);
      },
    );

    test(
      'refuses to overwrite a store containing a malformed record',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'autodentifyr-assessment-corrupt-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final store = File('${directory.path}/assessments.json');
        final originalContents = jsonEncode({
          'schemaVersion': FileAssessmentRepository.currentSchemaVersion,
          'assessments': [_draft().toJson(), 'malformed-record'],
        });
        await store.writeAsString(originalContents);
        final repository = FileAssessmentRepository(directory: directory);
        final other = IntakeAssessment.create(
          id: 'assessment-2',
          vehicle: const Vehicle(id: 'vehicle-2'),
          appraiserProfile: const AppraiserProfile(
            id: 'appraiser-1',
            displayName: 'Alex Appraiser',
          ),
          createdAt: DateTime.utc(2026, 9, 6, 17),
        );

        final result = await repository.save(other);

        expect(result, isA<AssessmentSaveFailed>());
        expect((result as AssessmentSaveFailed).retryable, isFalse);
        expect(await store.readAsString(), originalContents);
      },
    );

    test('serializes overlapping saves without dropping a Draft', () async {
      final directory = await Directory.systemTemp.createTemp(
        'autodentifyr-assessment-concurrent-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = FileAssessmentRepository(directory: directory);
      final other = IntakeAssessment.create(
        id: 'assessment-2',
        vehicle: const Vehicle(id: 'vehicle-2'),
        appraiserProfile: const AppraiserProfile(
          id: 'appraiser-1',
          displayName: 'Alex Appraiser',
        ),
        createdAt: DateTime.utc(2026, 9, 6, 17),
      );

      final results = await Future.wait([
        repository.save(_draft()),
        repository.save(other),
      ]);

      expect(results, everyElement(isA<AssessmentSaved>()));
      expect(await repository.list(), [_draft(), other]);
    });

    test(
      'rejects a stale save instead of erasing a completed revision',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'autodentifyr-assessment-conflict-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final firstSession = FileAssessmentRepository(directory: directory);
        final secondSession = FileAssessmentRepository(directory: directory);
        await firstSession.save(_draft());
        final staleDraft = await secondSession.findById('assessment-1');

        final completed = _completedNoVisibleDamage();
        expect(
          await firstSession.save(
            completed,
            expectedUpdatedAt: staleDraft!.updatedAt,
          ),
          isA<AssessmentSaved>(),
        );
        final staleUpdate = staleDraft.acceptCapture(
          Capture(
            id: 'capture-stale',
            source: CaptureSource.import,
            localPath: '/evidence/capture-stale.jpg',
            acceptedByProfileId: 'appraiser-1',
            acceptedAt: DateTime.utc(2026, 9, 6, 18, 4),
          ),
        );

        final result = await secondSession.save(
          staleUpdate,
          expectedUpdatedAt: staleDraft.updatedAt,
        );

        expect(result, isA<AssessmentSaveFailed>());
        expect((result as AssessmentSaveFailed).retryable, isTrue);
        expect(result.message, contains('changed in another session'));
        expect(
          (await firstSession.findById('assessment-1'))!.completedRevisions,
          completed.completedRevisions,
        );
      },
    );
  });
}

IntakeAssessment _draft() => IntakeAssessment.create(
  id: 'assessment-1',
  vehicle: const Vehicle(id: 'vehicle-1'),
  appraiserProfile: const AppraiserProfile(
    id: 'appraiser-1',
    displayName: 'Alex Appraiser',
  ),
  createdAt: DateTime.utc(2026, 9, 6, 18),
);

Capture _capture() => Capture(
  id: 'capture-1',
  source: CaptureSource.camera,
  localPath: '/evidence/capture-1.jpg',
  acceptedByProfileId: 'appraiser-1',
  acceptedAt: DateTime.utc(2026, 9, 6, 18, 1),
);

DamageObservation _observation() => const DamageObservation(
  id: 'observation-1',
  captureId: 'capture-1',
  rawClass: 'doorouter-dent',
  confidence: 0.87,
  bounds: ObservationBounds(left: 0.1, top: 0.2, width: 0.3, height: 0.4),
  modelIdentifier: 'best.tflite',
);

IntakeAssessment _completedNoVisibleDamage() => _draft()
    .acceptCapture(_capture())
    .recordEstimate(
      AssessmentEstimate(
        operations: const [],
        assumptions: const ['Only visible exterior damage was assessed.'],
        reviewedByProfileId: 'appraiser-1',
        reviewedAt: DateTime.utc(2026, 9, 6, 18, 2),
        sourceVersion: 'unsupported-pricing-v1',
      ),
    )
    .complete(
      revisionId: 'revision-1',
      completedAt: DateTime.utc(2026, 9, 6, 18, 3),
      noVisibleDamageConfirmed: true,
    );
