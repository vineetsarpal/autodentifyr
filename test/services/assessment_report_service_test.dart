import 'dart:io';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/services/assessment_report_service.dart';
import 'package:image/image.dart' as img;
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
      expect(document.canonicalText, contains('Blue Corolla'));
      expect(
        document.sections
            .firstWhere((section) => section.heading == 'Vehicle')
            .lines
            .last,
        'Internal Vehicle ID: vehicle-1',
      );
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

  test(
    'both exports embed a reduced accepted photo from the revision',
    () async {
      final directory = await Directory.systemTemp.createTemp('atd39-photo-');
      addTearDown(() => directory.delete(recursive: true));
      final photoPath = '${directory.path}/photo.jpg';
      final source = img.Image(width: 80, height: 80);
      img.fill(source, color: img.ColorRgb8(240, 20, 20));
      await File(photoPath).writeAsBytes(img.encodeJpg(source));
      final completed = _reportReadyAssessment(capturePath: photoPath).complete(
        revisionId: 'revision-photo',
        completedAt: DateTime.utc(2026, 9, 8, 20),
        noVisibleDamageConfirmed: false,
      );
      final document = AssessmentReportService().build(
        assessment: completed,
        revisionId: 'revision-photo',
      );
      final pdf = await const AssessmentPdfReportRenderer().render(document);
      final png = const AssessmentSharedImageReportRenderer().render(document);
      final image = img.decodePng(png.bytes)!;

      expect(document.captures.single.localPath, photoPath);
      expect(pdf.bytes.length, greaterThan(3000));
      expect(
        Iterable.generate(
          image.height,
          (y) => image.getPixel(50, y),
        ).any((pixel) => pixel.r > 180 && pixel.g < 80),
        isTrue,
      );
    },
  );

  test(
    'PDF paginates five accepted photos without dropping audit text',
    () async {
      final directory = await Directory.systemTemp.createTemp('atd39-pages-');
      addTearDown(() => directory.delete(recursive: true));
      final photoPath = '${directory.path}/photo.jpg';
      final source = img.Image(width: 80, height: 80);
      img.fill(source, color: img.ColorRgb8(20, 80, 200));
      await File(photoPath).writeAsBytes(img.encodeJpg(source));
      var assessment = _reportReadyAssessment(capturePath: photoPath);
      for (var index = 2; index <= 5; index++) {
        assessment = assessment.acceptCapture(
          Capture(
            id: 'capture-$index',
            source: CaptureSource.import,
            localPath: photoPath,
            acceptedByProfileId: 'appraiser-1',
            acceptedAt: DateTime.utc(2026, 9, 8, 19, index),
          ),
        );
      }
      final completed = assessment.complete(
        revisionId: 'revision-five',
        completedAt: DateTime.utc(2026, 9, 8, 20),
        noVisibleDamageConfirmed: false,
      );
      final document = AssessmentReportService().build(
        assessment: completed,
        revisionId: 'revision-five',
      );
      final pdf = await const AssessmentPdfReportRenderer().render(document);

      expect(document.captures, hasLength(5));
      expect(document.canonicalText, contains('Correction provenance'));
      expect(pdf.bytes.length, greaterThan(5000));
    },
  );
}

IntakeAssessment _reportReadyAssessment({String? capturePath}) {
  final capture = Capture(
    id: 'capture-1',
    source: CaptureSource.camera,
    localPath: capturePath ?? '/evidence/capture-1.jpg',
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
              displayLabel: 'Blue Corolla',
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
