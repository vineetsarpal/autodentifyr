import 'dart:typed_data';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_evidence_controller.dart';
import 'package:autodentifyr/presentation/screens/assessment_evidence_screen.dart';
import 'package:autodentifyr/services/assessment_evidence_service.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Appraiser accepts camera and imported evidence on one Draft', (
    tester,
  ) async {
    final repository = InMemoryAssessmentRepository();
    await repository.save(
      IntakeAssessment.create(
        id: 'assessment-1',
        vehicle: const Vehicle(id: 'vehicle-1'),
        appraiserProfile: const AppraiserProfile(
          id: 'appraiser-1',
          displayName: 'Alex Appraiser',
        ),
        createdAt: DateTime.utc(2026, 9, 6, 18),
      ),
    );
    final ids = ['capture-1', 'observation-1', 'capture-2', 'observation-2'];
    final controller = AssessmentEvidenceController(
      assessmentId: 'assessment-1',
      repository: repository,
      acquisitionService: _AcquisitionService(),
      inferenceService: _InferenceService(),
      fileStore: _FileStore(),
      idGenerator: () => ids.removeAt(0),
      now: () => DateTime.utc(2026, 9, 6, 18, 2),
    );

    await tester.pumpWidget(
      MaterialApp(home: AssessmentEvidenceScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('take-photo')));
    await tester.pumpAndSettle();
    expect(find.text('Review evidence'), findsOneWidget);
    expect(find.text('Camera still'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('accept-evidence')),
      300,
    );
    await tester.tap(find.byKey(const Key('accept-evidence')));
    await tester.pumpAndSettle();
    expect(find.text('1 accepted Capture'), findsOneWidget);
    expect(find.text('Camera still'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-image')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('accept-evidence')),
      300,
    );
    await tester.tap(find.byKey(const Key('accept-evidence')));
    await tester.pumpAndSettle();

    expect(find.text('2 accepted Captures'), findsOneWidget);
    expect(find.text('Camera still'), findsOneWidget);
    expect(find.text('Imported image'), findsOneWidget);
    expect((await repository.findById('assessment-1'))!.captures, hasLength(2));
  });
}

class _AcquisitionService implements EvidenceAcquisitionService {
  @override
  Future<EvidenceAcquisitionResult> acquire(CaptureSource source) async =>
      EvidenceAcquired(
        AcquiredEvidence(
          bytes: Uint8List.fromList([1, 2, 3]),
          source: source,
          orientation: CaptureOrientation.landscape,
          capturedAt: DateTime.utc(2026, 9, 6, 18, 1),
          fileExtension: 'jpg',
        ),
      );
}

class _InferenceService implements EvidenceInferenceService {
  @override
  Future<List<UnlinkedDamageObservation>> analyze(Uint8List bytes) async => [
    const UnlinkedDamageObservation(
      rawClass: 'doorouter-dent',
      confidence: 0.87,
      bounds: ObservationBounds(left: 0.1, top: 0.2, width: 0.3, height: 0.4),
      modelIdentifier: 'test-model',
      runtimeIdentifier: 'test-runtime',
    ),
  ];
}

class _FileStore implements EvidenceFileStore {
  @override
  Future<void> delete(String localPath) async {}

  @override
  Future<String> save({
    required String assessmentId,
    required String captureId,
    required String fileExtension,
    required Uint8List bytes,
  }) async => '/evidence/$captureId.$fileExtension';
}
