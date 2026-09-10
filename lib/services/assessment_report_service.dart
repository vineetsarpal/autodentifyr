import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import 'package:autodentifyr/models/assessment.dart';

class AssessmentReportSection {
  AssessmentReportSection({required this.heading, required List<String> lines})
    : lines = List.unmodifiable(lines);

  final String heading;
  final List<String> lines;
}

class AssessmentReportDocument {
  AssessmentReportDocument({
    required this.revisionId,
    required this.revisionNumber,
    required this.title,
    required List<AssessmentReportSection> sections,
  }) : sections = List.unmodifiable(sections);

  final String revisionId;
  final int revisionNumber;
  final String title;
  final List<AssessmentReportSection> sections;

  String get canonicalText => [
    title,
    for (final section in sections) ...['', section.heading, ...section.lines],
  ].join('\n');
}

class AssessmentReportArtifact {
  const AssessmentReportArtifact({
    required this.revisionId,
    required this.canonicalText,
    required this.mimeType,
    required this.bytes,
  });

  final String revisionId;
  final String canonicalText;
  final String mimeType;
  final Uint8List bytes;
}

class AssessmentReportFileStore {
  const AssessmentReportFileStore({required Directory directory})
    : _directory = directory;

  final Directory _directory;

  Future<File> save(AssessmentReportArtifact artifact) async {
    final extension = switch (artifact.mimeType) {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      _ => throw const AssessmentInvariantViolation(
        'Unsupported Report artifact type.',
      ),
    };
    final safeRevisionId = artifact.revisionId.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    if (safeRevisionId.isEmpty) {
      throw const AssessmentInvariantViolation(
        'A Report artifact requires a revision identity.',
      );
    }
    await _directory.create(recursive: true);
    final destination = File('${_directory.path}/$safeRevisionId.$extension');
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsBytes(artifact.bytes, flush: true);
    return temporary.rename(destination.path);
  }
}

Future<AssessmentReportFileStore> openDeviceLocalAssessmentReportStore() async {
  final supportDirectory = await getApplicationSupportDirectory();
  return AssessmentReportFileStore(
    directory: Directory('${supportDirectory.path}/assessment_reports'),
  );
}

class AssessmentReportService {
  AssessmentReportDocument build({
    required IntakeAssessment assessment,
    required String revisionId,
  }) {
    final revision = assessment.completedRevisions
        .where((candidate) => candidate.id == revisionId)
        .firstOrNull;
    if (revision == null) {
      throw AssessmentInvariantViolation(
        'Preliminary Damage Assessment revision $revisionId was not found.',
      );
    }
    final voidRecord = assessment.voidRecord;
    return AssessmentReportDocument(
      revisionId: revision.id,
      revisionNumber: revision.revisionNumber,
      title: 'Preliminary Damage Assessment',
      sections: [
        if (voidRecord != null)
          AssessmentReportSection(
            heading: 'VOIDED',
            lines: [
              'Reason: ${voidRecord.reason}',
              'Voided by: ${voidRecord.voidedByName}',
              'Voided at: ${_time(voidRecord.voidedAt)}',
            ],
          ),
        AssessmentReportSection(
          heading: 'Revision ${revision.revisionNumber}',
          lines: [
            'Revision ID: ${revision.id}',
            'Completed by: ${revision.completedByName} (${revision.completedByProfileId})',
            'Completed at: ${_time(revision.completedAt)}',
          ],
        ),
        AssessmentReportSection(
          heading: 'Vehicle',
          lines: [
            'Vehicle ID: ${revision.vehicleSnapshot.id}',
            if (revision.vehicleSnapshot.vin != null)
              'VIN: ${revision.vehicleSnapshot.vin}',
            if (revision.vehicleSnapshot.licencePlate != null)
              'Licence plate: ${revision.vehicleSnapshot.licencePlate}',
          ],
        ),
        AssessmentReportSection(
          heading: 'Outcome',
          lines: [
            revision.isNoVisibleDamageOutcome
                ? 'No Visible Damage Outcome'
                : '${revision.confirmedFindings.length} Confirmed Finding(s)',
          ],
        ),
        AssessmentReportSection(
          heading: 'Accepted evidence',
          lines: [
            for (final capture in revision.captures)
              'Capture ${capture.id}: ${capture.source.name}, accepted by ${capture.acceptedByProfileId} at ${_time(capture.acceptedAt)}',
            for (final observation in revision.observations)
              'Observation ${observation.id}: ${observation.rawClass}, confidence ${observation.confidence.toStringAsFixed(2)}, model ${observation.modelIdentifier}, runtime ${observation.runtimeIdentifier}',
          ],
        ),
        AssessmentReportSection(
          heading: 'Confirmed Findings',
          lines: revision.confirmedFindings.isEmpty
              ? ['None']
              : [
                  for (final finding in revision.confirmedFindings)
                    '${finding.id}: ${finding.vehicleComponent} - ${finding.damageType}; evidence ${finding.supportingCaptureIds.join(', ')}${finding.manualEvidenceNote == null ? '' : '; Appraiser note: ${finding.manualEvidenceNote}'}',
                ],
        ),
        AssessmentReportSection(
          heading: 'Correction provenance',
          lines: revision.corrections.isEmpty
              ? ['No Assessment Corrections recorded.']
              : [
                  for (final correction in revision.corrections)
                    '${correction.id}: ${correction.kind.name}; Finding ${correction.findingId}; by ${correction.authorProfileId} at ${_time(correction.occurredAt)}; reason: ${correction.reason}; originals ${correction.originals.map((value) => value.id).join(', ')}; replacements ${correction.replacements.map((value) => value.id).join(', ')}',
                ],
        ),
        _estimateSection(revision.estimate),
        _severitySection(revision.severityAssessments),
        AssessmentReportSection(
          heading: 'Limitations',
          lines: revision.limitations.isEmpty
              ? ['No additional limitations recorded.']
              : revision.limitations,
        ),
        AssessmentReportSection(
          heading: 'Important',
          lines: const [
            'This preliminary assessment is not a Formal Repair Estimate or repair authorization.',
          ],
        ),
      ],
    );
  }

  AssessmentReportSection _estimateSection(
    AssessmentEstimate estimate,
  ) => AssessmentReportSection(
    heading: estimate.isPartial ? 'Partial Estimate' : 'Assessment Estimate',
    lines: [
      'Source version: ${estimate.sourceVersion}',
      for (final operation in estimate.operations)
        '${operation.description}: ${_price(operation)}; Findings ${operation.findingIds.join(', ')}',
      if (estimate.operations.isEmpty) 'No Repair Operations.',
      for (final assumption in estimate.assumptions) 'Assumption: $assumption',
      if (estimate.isPartial)
        'Missing pricing acknowledged by ${estimate.missingPricingAcknowledgedByProfileId} at ${_time(estimate.missingPricingAcknowledgedAt!)}',
      for (final override in estimate.overrides)
        'Override ${override.id}: ${override.reason}; by ${override.authorProfileId} at ${_time(override.occurredAt)}',
    ],
  );

  AssessmentReportSection _severitySection(
    List<SeverityAssessment> severities,
  ) => AssessmentReportSection(
    heading: 'Severity Assessments',
    lines: severities.isEmpty
        ? ['Not applicable.']
        : [
            for (final severity in severities) ...[
              '${severity.findingId}: ${_level(severity.reviewedLevel)}; evidence ${severity.evidenceCaptureIds.join(', ')}; reviewed by ${severity.reviewerProfileId} at ${_time(severity.reviewedAt)}',
              'Reason: ${severity.reason}',
              if (severity.uncertainty != null)
                'Uncertainty: ${severity.uncertainty}',
              if (severity.followUpNeed != null)
                'Follow-up need: ${severity.followUpNeed}',
              if (severity.followUpOverrideReason != null)
                'Follow-up override: ${severity.followUpOverrideReason}',
              if (severity.limitation != null)
                'Limitation: ${severity.limitation}',
              if (severity.automationLimitation != null)
                'Automation limitation: ${severity.automationLimitation}',
              if (severity.originalSuggestion != null)
                'Original suggestion: ${_level(severity.originalSuggestion!)}; source ${severity.automationSourceVersion}; evidence ${severity.suggestionEvidenceCaptureIds.join(', ')}${severity.suggestionIsSynthetic ? '; synthetic workflow only' : ''}',
            ],
          ],
  );

  String _price(RepairOperation operation) {
    if (!operation.hasPricing) return 'Pricing unavailable';
    return '${operation.currency} ${_money(operation.minimumCents!)} - ${_money(operation.maximumCents!)} (${operation.pricingSourceVersion})';
  }

  String _money(int cents) => (cents / 100).toStringAsFixed(2);

  String _level(SeverityLevel level) => switch (level) {
    SeverityLevel.minor => 'Minor',
    SeverityLevel.moderate => 'Moderate',
    SeverityLevel.severe => 'Severe',
    SeverityLevel.undetermined => 'Undetermined',
  };

  String _time(DateTime value) => value.toUtc().toIso8601String();
}

class AssessmentPdfReportRenderer {
  const AssessmentPdfReportRenderer();

  Future<AssessmentReportArtifact> render(
    AssessmentReportDocument document,
  ) async {
    final pdf = pw.Document(
      title: '${document.title} - Revision ${document.revisionNumber}',
      author: 'AutoDentifyr',
      subject: 'Immutable Preliminary Damage Assessment revision',
    );
    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
          ),
          child: pw.Text(
            document.title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
        ),
        build: (context) => [
          for (final section in document.sections)
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 14),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    section.heading,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  for (final line in section.lines)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Text(
                        line,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
    return AssessmentReportArtifact(
      revisionId: document.revisionId,
      canonicalText: document.canonicalText,
      mimeType: 'application/pdf',
      bytes: await pdf.save(),
    );
  }
}

class AssessmentSharedImageReportRenderer {
  const AssessmentSharedImageReportRenderer();

  AssessmentReportArtifact render(AssessmentReportDocument document) {
    final displayLines = <_ImageLine>[
      _ImageLine(document.title, heading: true),
      for (final section in document.sections) ...[
        const _ImageLine(''),
        _ImageLine(section.heading, heading: true),
        for (final line in section.lines)
          for (final wrapped in _wrap(line, 92)) _ImageLine(wrapped),
      ],
    ];
    final image = img.Image(width: 1200, height: 64 + displayLines.length * 30);
    img.fill(image, color: img.ColorRgb8(248, 250, 252));
    var y = 30;
    for (final line in displayLines) {
      img.drawString(
        image,
        line.text,
        font: line.heading ? img.arial24 : img.arial14,
        x: 36,
        y: y,
        color: line.text == 'VOIDED'
            ? img.ColorRgb8(185, 28, 28)
            : img.ColorRgb8(13, 38, 61),
      );
      y += 30;
    }
    return AssessmentReportArtifact(
      revisionId: document.revisionId,
      canonicalText: document.canonicalText,
      mimeType: 'image/png',
      bytes: Uint8List.fromList(img.encodePng(image)),
    );
  }

  static List<String> _wrap(String value, int width) {
    if (value.length <= width) return [value];
    final output = <String>[];
    var current = '';
    for (final word in value.split(' ')) {
      if (current.isEmpty) {
        current = word;
      } else if (current.length + word.length + 1 <= width) {
        current = '$current $word';
      } else {
        output.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) output.add(current);
    return output;
  }
}

class _ImageLine {
  const _ImageLine(this.text, {this.heading = false});

  final String text;
  final bool heading;
}
