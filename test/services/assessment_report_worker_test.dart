import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:autodentifyr/services/assessment_report_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'report_render_test_fixtures.dart';

void main() {
  group('report workers', () {
    for (final count in [1, 5]) {
      test(
        'real workers preserve baseline output for $count large captures and unavailable photos',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'report-worker-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final document = await largePhotoReportFixture(
            directory,
            photoCount: count,
            includeUnavailable: true,
          );
          final originals = await File(
            '${directory.path}/large.png',
          ).readAsBytes();
          final png = await const AssessmentSharedImageReportRenderer().render(
            document,
          );
          final expectedBytes = await File(
            'test/fixtures/reports/large-$count.png',
          ).readAsBytes();
          final actual = img.decodePng(png.bytes)!;
          final expected = img.decodePng(expectedBytes)!;
          expect(
            (actual.width, actual.height),
            (expected.width, expected.height),
          );
          expect(actual.getBytes(), expected.getBytes());
          expect(png.bytes, expectedBytes);
          expect(png.canonicalText, document.canonicalText);
          expect(png.revisionId, document.revisionId);
          final pdf = await const AssessmentPdfReportRenderer().render(
            document,
          );
          final baseline =
              jsonDecode(
                    await File(
                      'test/fixtures/reports/pdf_layout_baseline.json',
                    ).readAsString(),
                  )
                  as Map;
          final expectedPdf = baseline['$count'] as Map;
          final text = latin1.decode(pdf.bytes);
          expect(
            RegExp(r'/Type/Page\b').allMatches(text).length,
            expectedPdf['pageCount'],
          );
          expect(_pageContentStreams(pdf.bytes), expectedPdf['contentStreams']);
          expect(RegExp(r'/Subtype/Image\b').allMatches(text).length, count);
          expect(
            text,
            contains('/Title(Preliminary Damage Assessment - Revision 2)'),
          );
          expect(text, contains('/Author(AutoDentifyr)'));
          expect(
            text,
            contains(
              '/Subject(Immutable Preliminary Damage Assessment revision)',
            ),
          );
          expect(pdf.canonicalText, document.canonicalText);
          expect(
            await File('${directory.path}/large.png').readAsBytes(),
            originals,
          );
        },
      );
    }

    for (final format in ['png', 'pdf']) {
      test(
        '$format worker lets caller isolate timers run during rendering',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'report-timer-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final document = await largePhotoReportFixture(
            directory,
            photoCount: 5,
          );
          var ticks = 0;
          final timer = Timer.periodic(
            const Duration(milliseconds: 1),
            (_) => ticks++,
          );
          try {
            await (format == 'pdf'
                ? const AssessmentPdfReportRenderer().render(document)
                : const AssessmentSharedImageReportRenderer().render(document));
          } finally {
            timer.cancel();
          }
          expect(ticks, greaterThan(0));
        },
      );
    }

    test(
      'PDF layout failure crosses the real isolate boundary asynchronously',
      () async {
        final document = AssessmentReportDocument(
          revisionId: 'oversized',
          revisionNumber: 1,
          title: 'Layout failure',
          captures: const [],
          sections: [
            AssessmentReportSection(
              heading: 'Oversized unbreakable section',
              lines: [List.filled(2000, 'Oversized report text.').join(' ')],
            ),
          ],
        );
        Future<AssessmentReportArtifact>? pending;
        expect(
          () => pending = const AssessmentPdfReportRenderer().render(document),
          returnsNormally,
        );
        await expectLater(pending!, throwsA(isA<Exception>()));
        final valid = AssessmentReportDocument(
          revisionId: 'next',
          revisionNumber: 1,
          title: 'Next report',
          captures: const [],
          sections: const [],
        );
        final next = await const AssessmentPdfReportRenderer().render(valid);
        expect(next.mimeType, 'application/pdf');
        expect(next.revisionId, 'next');
      },
    );
  });
}

// Compare decoded page drawing/text commands with the pre-change renderer.
// The PDF trailer's generated IDs and creation date are intentionally excluded.
List<String> _pageContentStreams(List<int> bytes) {
  final text = latin1.decode(bytes);
  final result = <String>[];
  for (final match in RegExp(
    r'(<<[^<>]*>>)\s*stream\r?\n([\s\S]*?)\r?\nendstream',
  ).allMatches(text)) {
    final dictionary = match.group(1)!;
    if (!dictionary.contains('/Filter/FlateDecode') ||
        dictionary.contains('/Type/XRef')) {
      continue;
    }
    final data = ZLibDecoder().convert(latin1.encode(match.group(2)!));
    result.add(base64Encode(data));
  }
  return result;
}
