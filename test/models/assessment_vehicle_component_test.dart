import 'dart:convert';
import 'dart:io';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/services/assessment_report_service.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:autodentifyr/services/assessment_estimate_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DamageFinding vehicle component persistence', () {
    test('writes a canonical Vehicle Component ID without a display label', () {
      final finding = DamageFinding.manual(
        id: 'finding-1',
        vehicleComponentId: VehicleComponentId.leftFrontDoor,
        damageType: 'dent',
        supportingCaptureIds: const ['capture-1'],
        evidenceNote: 'Visible crease at the lower edge.',
      );

      expect(
        finding.toJson(),
        containsPair('vehicleComponentId', 'left_front_door'),
      );
      expect(finding.toJson(), isNot(contains('vehicleComponent')));
    });

    test('rejects legacy and unknown component fields when decoding', () {
      final base = <String, Object?>{
        'id': 'finding-1',
        'reviewState': 'confirmed',
        'observationIds': const <String>[],
        'supportingCaptureIds': const ['capture-1'],
        'damageType': 'dent',
        'manualEvidenceNote': 'Visible crease at the lower edge.',
      };

      expect(
        () => DamageFinding.fromJson({
          ...base,
          'vehicleComponent': 'left-front door',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => DamageFinding.fromJson({...base, 'vehicleComponentId': 'door'}),
        throwsA(isA<VehicleComponentWireFormatException>()),
      );
    });

    test(
      'freezes the completion label while identity signatures use the ID',
      () {
        final completed = _readyAssessment().complete(
          revisionId: 'revision-1',
          completedAt: DateTime.utc(2026, 9, 16, 14),
          noVisibleDamageConfirmed: false,
        );
        final frozen =
            completed.completedRevisions.single.confirmedFindings.single;
        final document = AssessmentReportService().build(
          assessment: completed,
          revisionId: 'revision-1',
        );

        expect(frozen.vehicleComponent.id, VehicleComponentId.leftFrontDoor);
        expect(frozen.vehicleComponent.label, 'Left front door');
        expect(
          completed.estimate!.reviewedFindingSignatures['finding-1'],
          isNot(contains('Left front door')),
        );
        expect(
          completed.estimate!.reviewedFindingSignatures['finding-1'],
          contains('left_front_door'),
        );
        expect(
          completed
              .reopen(reopenedAt: DateTime.utc(2026, 9, 16, 15))
              .findings
              .single
              .vehicleComponentId,
          VehicleComponentId.leftFrontDoor,
        );
        expect(document.canonicalText, contains('Left front door - dent'));
        expect(document.canonicalText, contains('component left_front_door'));
      },
    );

    test(
      'uses the canonical wire ID in unavailable-estimate operation keys',
      () async {
        final finding = DamageFinding.manual(
          id: 'finding-1',
          vehicleComponentId: VehicleComponentId.leftFrontDoor,
          damageType: 'dent',
          supportingCaptureIds: const ['capture-1'],
          evidenceNote: 'Visible crease at the lower edge.',
        );

        final suggestions = await const UnavailableAssessmentEstimateSource()
            .suggestOperations([finding]);

        expect(suggestions.single.operationId, 'review-left_front_door');
      },
    );
  });

  group('schema 11 cutover', () {
    test('rejects schema 10 rather than migrating it', () async {
      final directory = await Directory.systemTemp.createTemp('atd43-v10-');
      addTearDown(() => directory.delete(recursive: true));
      await File('${directory.path}/assessments.json').writeAsString(
        jsonEncode({'schemaVersion': 10, 'assessments': const []}),
      );

      expect(
        FileAssessmentRepository(directory: directory).list,
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'rejects an unknown canonical component ID in a schema 11 store',
      () async {
        final directory = await Directory.systemTemp.createTemp('atd43-id-');
        addTearDown(() => directory.delete(recursive: true));
        final record = _readyAssessment().toJson();
        final finding =
            (record['findings']! as List).single as Map<String, Object?>;
        finding['vehicleComponentId'] = 'unknown_component';
        await File('${directory.path}/assessments.json').writeAsString(
          jsonEncode({
            'schemaVersion': FileAssessmentRepository.currentSchemaVersion,
            'assessments': [record],
          }),
        );

        expect(
          FileAssessmentRepository(directory: directory).list,
          throwsA(isA<VehicleComponentWireFormatException>()),
        );
      },
    );
  });
}

IntakeAssessment _readyAssessment() {
  final capture = Capture(
    id: 'capture-1',
    source: CaptureSource.camera,
    localPath: '/evidence/capture-1.jpg',
    acceptedByProfileId: 'appraiser-1',
    acceptedAt: DateTime.utc(2026, 9, 16, 13),
  );
  const observation = DamageObservation(
    id: 'observation-1',
    captureId: 'capture-1',
    rawClass: 'doorouter-dent',
    confidence: 0.9,
    bounds: ObservationBounds(left: 0, top: 0, width: 1, height: 1),
    modelIdentifier: 'model-1',
    runtimeIdentifier: 'runtime-1',
  );
  final finding =
      DamageFinding.proposed(
        id: 'finding-1',
        observationIds: const ['observation-1'],
        supportingCaptureIds: const ['capture-1'],
      ).reviewed(
        state: FindingReviewState.confirmed,
        vehicleComponentId: VehicleComponentId.leftFrontDoor,
        damageType: 'dent',
      );
  return IntakeAssessment.create(
        id: 'assessment-1',
        vehicle: const Vehicle(id: 'vehicle-1'),
        appraiserProfile: const AppraiserProfile(
          id: 'appraiser-1',
          displayName: 'Alex Appraiser',
        ),
        createdAt: DateTime.utc(2026, 9, 16, 12),
      )
      .acceptCapture(capture)
      .recordObservation(observation)
      .addFinding(finding)
      .recordEstimate(
        AssessmentEstimate(
          operations: const [
            RepairOperation(
              id: 'operation-1',
              findingIds: ['finding-1'],
              description: 'Repair left front door dent',
            ),
          ],
          assumptions: const ['Pricing unavailable.'],
          reviewedByProfileId: 'appraiser-1',
          reviewedAt: DateTime.utc(2026, 9, 16, 13, 1),
          missingPricingAcknowledgedAt: DateTime.utc(2026, 9, 16, 13, 2),
          missingPricingAcknowledgedByProfileId: 'appraiser-1',
        ),
      )
      .recordSeverity(
        SeverityAssessment(
          findingId: 'finding-1',
          reviewedLevel: SeverityLevel.minor,
          evidenceCaptureIds: const ['capture-1'],
          reviewerProfileId: 'appraiser-1',
          reviewedAt: DateTime.utc(2026, 9, 16, 13, 3),
          reason: 'Small visible dent.',
        ),
      );
}
