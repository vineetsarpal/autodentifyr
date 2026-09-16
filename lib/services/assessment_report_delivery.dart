import 'dart:io';
import 'dart:ui';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import 'package:autodentifyr/services/assessment_report_service.dart';

/// A generated report remains in the private store even when an export is canceled.
class PreparedAssessmentReport {
  const PreparedAssessmentReport({required this.artifact, required this.file});

  final AssessmentReportArtifact artifact;
  final File file;

  String get fileName => file.uri.pathSegments.last;
}

enum ReportDeliveryResult { completed, canceled }

abstract class AssessmentReportDelivery {
  Future<PreparedAssessmentReport> prepare(AssessmentReportArtifact artifact);

  Future<ReportDeliveryResult> open(PreparedAssessmentReport report);

  Future<ReportDeliveryResult> saveToFiles(PreparedAssessmentReport report);

  Future<ReportDeliveryResult> share(
    PreparedAssessmentReport report, {
    required Rect sharePositionOrigin,
  });
}

class DeviceAssessmentReportDelivery implements AssessmentReportDelivery {
  const DeviceAssessmentReportDelivery(this._privateStore);

  final AssessmentReportFileStore _privateStore;

  @override
  Future<PreparedAssessmentReport> prepare(
    AssessmentReportArtifact artifact,
  ) async => PreparedAssessmentReport(
    artifact: artifact,
    file: await _privateStore.save(artifact),
  );

  @override
  Future<ReportDeliveryResult> open(PreparedAssessmentReport report) async {
    final result = await OpenFilex.open(
      report.file.path,
      type: report.artifact.mimeType,
    );
    if (result.type == ResultType.done) return ReportDeliveryResult.completed;
    if (result.type == ResultType.noAppToOpen) {
      throw StateError(
        'No app can open this ${report.artifact.mimeType} report.',
      );
    }
    throw StateError('Could not open ${report.fileName}: ${result.message}');
  }

  @override
  Future<ReportDeliveryResult> saveToFiles(
    PreparedAssessmentReport report,
  ) async {
    final destination = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        sourceFilePath: report.file.path,
        fileName: report.fileName,
        mimeTypesFilter: [report.artifact.mimeType],
      ),
    );
    return destination == null
        ? ReportDeliveryResult.canceled
        : ReportDeliveryResult.completed;
  }

  @override
  Future<ReportDeliveryResult> share(
    PreparedAssessmentReport report, {
    required Rect sharePositionOrigin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(report.file.path, mimeType: report.artifact.mimeType)],
        title: 'Preliminary Damage Assessment',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    return result.status == ShareResultStatus.dismissed
        ? ReportDeliveryResult.canceled
        : ReportDeliveryResult.completed;
  }
}
