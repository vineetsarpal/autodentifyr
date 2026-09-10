import 'dart:io';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/services/assessment_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'screen, PDF, and shared-image artifacts use one revision document',
    () async {
      final completed = _reportReadyAssessment().complete(
        revisionId: 'revision-1',
        completedAt: DateTime.utc(2026, 9, 8, 20),
        noVisibleDamageConfirmed: false,
      );
      final voided = completed.voidAssessment(
        voidedAt: DateTime.utc(2026, 9, 8, 21),
        reason: 'Duplicate intake record.',
      );
      final document = AssessmentReportService().build(
        assessment: voided,
        revisionId: 'revision-1',
      );

      final pdf = await const AssessmentPdfReportRenderer().render(document);
      final sharedImage = const AssessmentSharedImageReportRenderer().render(
        document,
      );

      expect(document.canonicalText, contains('Preliminary Damage Assessment'));
      expect(document.canonicalText, contains('Revision 1'));
      expect(document.canonicalText, contains('VOIDED'));
      expect(document.canonicalText, contains('Partial Estimate'));
      expect(document.canonicalText, contains('Pricing unavailable'));
      expect(document.canonicalText, contains('Undetermined'));
      expect(
        document.canonicalText,
        contains('Automation limitation: Automated severity unavailable.'),
      );
      expect(document.canonicalText, contains('Visible exterior damage only.'));
      expect(pdf.revisionId, document.revisionId);
      expect(sharedImage.revisionId, document.revisionId);
      expect(pdf.canonicalText, document.canonicalText);
      expect(sharedImage.canonicalText, document.canonicalText);
      expect(pdf.mimeType, 'application/pdf');
      expect(String.fromCharCodes(pdf.bytes.take(5)), '%PDF-');
      expect(sharedImage.mimeType, 'image/png');
      expect(sharedImage.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);

      final exportDirectory = await Directory.systemTemp.createTemp(
        'autodentifyr-report-export-',
      );
      addTearDown(() => exportDirectory.delete(recursive: true));
      final exported = await AssessmentReportFileStore(
        directory: exportDirectory,
      ).save(pdf);
      expect(await exported.readAsBytes(), pdf.bytes);
      expect(exported.path, endsWith('revision-1.pdf'));

      final qaDirectoryPath = Platform.environment['ATD31_REPORT_QA_DIRECTORY'];
      if (qaDirectoryPath != null) {
        final qaDirectory = Directory(qaDirectoryPath);
        await qaDirectory.create(recursive: true);
        await File(
          '${qaDirectory.path}/revision-1.pdf',
        ).writeAsBytes(pdf.bytes);
        await File(
          '${qaDirectory.path}/revision-1.png',
        ).writeAsBytes(sharedImage.bytes);
      }
    },
  );
}

IntakeAssessment _reportReadyAssessment() {
  final capture = Capture(
    id: 'capture-1',
    source: CaptureSource.camera,
    localPath: '/evidence/capture-1.jpg',
    acceptedByProfileId: 'appraiser-1',
    acceptedAt: DateTime.utc(2026, 9, 8, 19, 1),
  );
  const observation = DamageObservation(
    id: 'observation-1',
    captureId: 'capture-1',
    rawClass: 'doorouter-dent',
    confidence: 0.87,
    bounds: ObservationBounds(left: 0.1, top: 0.2, width: 0.3, height: 0.4),
    modelIdentifier: 'best.tflite',
    runtimeIdentifier: 'ultralytics-yolo-0.6.3',
  );
  final finding =
      DamageFinding.proposed(
        id: 'finding-1',
        observationIds: const ['observation-1'],
        supportingCaptureIds: const ['capture-1'],
      ).reviewed(
        state: FindingReviewState.confirmed,
        vehicleComponent: 'left-front-door',
        damageType: 'dent',
      );
  final assessment =
      IntakeAssessment.create(
            id: 'assessment-1',
            vehicle: const Vehicle(
              id: 'vehicle-1',
              vin: '1A2B3C4D5E6F7G8H9',
              licencePlate: 'ABC123',
            ),
            appraiserProfile: const AppraiserProfile(
              id: 'appraiser-1',
              displayName: 'Alex Appraiser',
            ),
            createdAt: DateTime.utc(2026, 9, 8, 19),
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
                  description: 'Repair left-front door dent',
                ),
              ],
              assumptions: const ['Pricing evidence is unavailable.'],
              reviewedByProfileId: 'appraiser-1',
              reviewedAt: DateTime.utc(2026, 9, 8, 19, 2),
              sourceVersion: 'unsupported-pricing-v1',
              missingPricingAcknowledgedAt: DateTime.utc(2026, 9, 8, 19, 3),
              missingPricingAcknowledgedByProfileId: 'appraiser-1',
            ),
          )
          .recordSeverity(
            SeverityAssessment(
              findingId: 'finding-1',
              reviewedLevel: SeverityLevel.undetermined,
              evidenceCaptureIds: const ['capture-1'],
              reviewerProfileId: 'appraiser-1',
              reviewedAt: DateTime.utc(2026, 9, 8, 19, 4),
              reason: 'The lower edge remains obscured.',
              uncertainty: 'Damage extent cannot be concluded.',
              followUpNeed: 'Capture an oblique lower-edge view.',
              followUpOverrideReason:
                  'The Vehicle Owner declined another Capture.',
              automationLimitation: 'Automated severity unavailable.',
            ),
          );
  return IntakeAssessment.fromJson({
    ...assessment.toJson(),
    'limitations': ['Visible exterior damage only.'],
  });
}
