import 'dart:io';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/services/assessment_report_service.dart';
import 'package:image/image.dart' as img;

Future<AssessmentReportDocument> largePhotoReportFixture(
  Directory directory, {
  required int photoCount,
  bool includeUnavailable = false,
}) async {
  final photo = img.Image(width: 2400, height: 1600);
  for (var y = 0; y < photo.height; y++) {
    for (var x = 0; x < photo.width; x++) {
      photo.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
    }
  }
  final photoFile = File('${directory.path}/large.png');
  await photoFile.writeAsBytes(img.encodePng(photo));
  final invalid = File('${directory.path}/invalid.jpg');
  await invalid.writeAsString('Invalid photo content');
  return AssessmentReportDocument(
    revisionId: 'parity-$photoCount',
    revisionNumber: 2,
    title: 'Preliminary Damage Assessment',
    captures: [
      for (var index = 1; index <= photoCount; index++)
        Capture(
          id: 'capture-$index',
          source: CaptureSource.import,
          localPath: photoFile.path,
          acceptedByProfileId: 'appraiser-1',
          acceptedAt: DateTime.utc(2026, 9, 8, 19, index),
        ),
      if (includeUnavailable) ...[
        Capture(
          id: 'missing',
          source: CaptureSource.camera,
          localPath: '${directory.path}/missing.jpg',
          acceptedByProfileId: 'appraiser-1',
          acceptedAt: DateTime.utc(2026),
        ),
        Capture(
          id: 'invalid',
          source: CaptureSource.import,
          localPath: invalid.path,
          acceptedByProfileId: 'appraiser-1',
          acceptedAt: DateTime.utc(2026),
        ),
      ],
    ],
    sections: [
      AssessmentReportSection(
        heading: 'VOIDED',
        lines: ['Reason: Duplicate intake record.'],
      ),
      AssessmentReportSection(
        heading: 'Vehicle',
        lines: [
          'Blue Corolla',
          'VIN: 1A2B3C4D5E6F7G8H9',
          'Licence plate: ABC123',
        ],
      ),
      AssessmentReportSection(
        heading: 'Photos',
        lines: [
          for (var index = 1; index <= photoCount; index++)
            'Photo capture-$index: import',
        ],
      ),
      AssessmentReportSection(
        heading: 'Confirmed Findings',
        lines: ['Left front door - dent; photos capture-1'],
      ),
      AssessmentReportSection(
        heading: 'Partial Estimate',
        lines: [
          'Pricing unavailable',
          'Assumption: Pricing evidence is unavailable.',
        ],
      ),
      AssessmentReportSection(
        heading: 'Severity Assessments',
        lines: [
          'finding-1: Undetermined',
          'Follow-up need: Capture an oblique lower-edge view.',
        ],
      ),
      AssessmentReportSection(
        heading: 'Limitations',
        lines: [List.filled(8, 'Visible exterior damage only.').join(' ')],
      ),
      AssessmentReportSection(
        heading: 'Revision 2 - audit details',
        lines: [
          'Revision ID: parity-$photoCount',
          'Completed by: Alex Appraiser',
          'Completed at: 2026-09-08T20:00:00.000Z',
        ],
      ),
      AssessmentReportSection(
        heading: 'Accepted evidence history',
        lines: [
          for (var index = 1; index <= photoCount; index++)
            'Capture capture-$index: import, accepted by appraiser-1 at 2026-09-08T19:01:00.000Z',
        ],
      ),
      AssessmentReportSection(
        heading: 'Correction provenance',
        lines: ['No Assessment Corrections recorded.'],
      ),
    ],
  );
}
