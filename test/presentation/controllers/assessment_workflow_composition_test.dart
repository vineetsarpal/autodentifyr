import 'dart:io';
import 'dart:typed_data';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/models/models.dart';
import 'package:autodentifyr/presentation/controllers/assessment_progress.dart';
import 'package:autodentifyr/presentation/controllers/assessment_workflow_composition.dart';
import 'package:autodentifyr/presentation/screens/assessment_evidence_screen.dart';
import 'package:autodentifyr/presentation/screens/assessment_workflow_screen.dart';
import 'package:autodentifyr/services/assessment_evidence_service.dart';
import 'package:autodentifyr/services/assessment_report_service.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:autodentifyr/services/model_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ultralytics_yolo/yolo.dart';

void main() {
  group('workflow inference ownership', () {
    testWidgets(
      'evidence and guided route re-entry share one lazy engine until workflow exit',
      (tester) async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(
          IntakeAssessment.create(
            id: 'assessment-1',
            vehicle: const Vehicle(id: 'vehicle-1'),
            appraiserProfile: const AppraiserProfile(
              id: 'appraiser-1',
              displayName: 'Alex',
            ),
            createdAt: DateTime.utc(2026),
          ),
        );
        final engines = <_Yolo>[];
        Future<AssessmentWorkflowScreen> workflow() =>
            openAssessmentWorkflowScreen(
              repository: repository,
              evidenceFileStore: _FileStore(),
              reportFileStore: AssessmentReportFileStore(
                directory: Directory.systemTemp,
              ),
              acquisitionService: _Acquisition(),
              inferenceService: YoloEvidenceInferenceService(
                modelManager: _ModelManager(),
                createYolo: (_) {
                  final engine = _Yolo();
                  engines.add(engine);
                  return engine;
                },
              ),
            );
        final screen = await workflow();
        await tester.pumpWidget(MaterialApp(home: screen));
        await tester.pumpAndSettle();
        expect(engines, isEmpty);
        final context = tester.element(find.byType(AssessmentWorkflowScreen));
        var navigation = screen.openEvidence(context, 'assessment-1');
        await tester.pumpAndSettle();
        var evidence = tester.widget<AssessmentEvidenceScreen>(
          find.byType(AssessmentEvidenceScreen),
        );
        await evidence.controller.importImage();
        await tester.pump();
        expect(engines.single.loads, 1);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await navigation;
        expect(engines.single.disposals, 0);
        expect(evidence.controller.state.pendingEvidence, isNull);

        final guidedNavigation = screen.openGuidedStage!(
          context,
          'assessment-1',
          AssessmentStage.evidence,
        );
        await tester.pumpAndSettle();
        evidence = tester.widget<AssessmentEvidenceScreen>(
          find.byType(AssessmentEvidenceScreen),
        );
        await evidence.controller.importImage();
        await tester.pump();
        await tester.pageBack();
        await tester.pumpAndSettle();
        await guidedNavigation;
        expect(engines, hasLength(1));
        expect(engines.single.loads, 1);
        expect(engines.single.predictions, 2);
        expect(engines.single.disposals, 0);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(engines.single.disposals, 1);

        final reopened = await workflow();
        await tester.pumpWidget(MaterialApp(home: reopened));
        await tester.pumpAndSettle();
        expect(engines, hasLength(1));
        navigation = reopened.openEvidence(
          tester.element(find.byType(AssessmentWorkflowScreen)),
          'assessment-1',
        );
        await tester.pumpAndSettle();
        evidence = tester.widget<AssessmentEvidenceScreen>(
          find.byType(AssessmentEvidenceScreen),
        );
        await evidence.controller.importImage();
        await tester.pump();
        expect(engines, hasLength(2));
        expect(engines.last.loads, 1);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await navigation;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(engines.last.disposals, 1);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _Acquisition implements EvidenceAcquisitionService {
  @override
  Future<EvidenceAcquisitionResult> acquire(CaptureSource source) async =>
      EvidenceAcquired(
        AcquiredEvidence(
          bytes: Uint8List.fromList([1]),
          source: source,
          orientation: CaptureOrientation.portrait,
          capturedAt: DateTime.utc(2026),
          fileExtension: 'jpg',
        ),
      );
}

class _ModelManager extends ModelManager {
  @override
  Future<String?> getModelPath(ModelType type) async => '/models/damage.tflite';
}

class _Yolo extends YOLO {
  _Yolo() : super(modelPath: '/models/damage.tflite');
  int loads = 0;
  int predictions = 0;
  int disposals = 0;
  @override
  Future<bool> loadModel() async {
    loads++;
    return true;
  }

  @override
  Future<void> predictorInstance() async {}
  @override
  Future<Map<String, dynamic>> predict(
    Uint8List bytes, {
    double? confidenceThreshold,
    double? iouThreshold,
  }) async {
    predictions++;
    return {};
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class _FileStore implements EvidenceFileStore {
  @override
  Future<void> delete(String path) async {}
  @override
  Future<String> save({
    required String assessmentId,
    required String captureId,
    required String fileExtension,
    required Uint8List bytes,
  }) async => '/evidence/$captureId.$fileExtension';
}
