import 'dart:io';

import 'package:autodentifyr/services/assessment_report_delivery.dart';
import 'package:autodentifyr/services/assessment_report_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Files picker receives the private revision PDF and exact MIME',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'atd36-delivery-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final delivery = DeviceAssessmentReportDelivery(
        AssessmentReportFileStore(directory: directory),
      );
      final prepared = await delivery.prepare(
        AssessmentReportArtifact(
          revisionId: 'revision-1',
          canonicalText: 'Preliminary Damage Assessment',
          mimeType: 'application/pdf',
          bytes: Uint8List.fromList('%PDF-'.codeUnits),
        ),
      );
      expect(await prepared.file.readAsBytes(), prepared.artifact.bytes);

      MethodCall? pickerCall;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter_file_dialog'),
        (call) async {
          pickerCall = call;
          return null;
        },
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('flutter_file_dialog'),
          null,
        ),
      );

      expect(
        await delivery.saveToFiles(prepared),
        ReportDeliveryResult.canceled,
      );
      expect(pickerCall!.method, 'saveFile');
      expect(pickerCall!.arguments, {
        'sourceFilePath': prepared.file.path,
        'data': null,
        'fileName': 'revision-1.pdf',
        'mimeTypesFilter': ['application/pdf'],
        'localOnly': false,
      });
      expect(await prepared.file.exists(), isTrue);
    },
  );
}
