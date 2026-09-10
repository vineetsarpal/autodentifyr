import 'dart:io';
import 'dart:typed_data';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_evidence_controller.dart';
import 'package:autodentifyr/services/assessment_evidence_service.dart';
import 'package:autodentifyr/services/assessment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssessmentEvidenceController', () {
    test(
      'camera evidence remains transient until the Appraiser accepts it',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_draft());
        final fileStore = _MemoryEvidenceFileStore();
        final controller = AssessmentEvidenceController(
          assessmentId: 'assessment-1',
          repository: repository,
          acquisitionService: _FakeAcquisitionService(),
          inferenceService: _FakeInferenceService(),
          fileStore: fileStore,
          idGenerator: _IdGenerator(['capture-1', 'observation-1']).next,
          now: () => DateTime.utc(2026, 9, 6, 18, 2),
        );

        await controller.load();
        await controller.stageCameraCapture();

        expect(controller.state.phase, AssessmentEvidencePhase.staged);
        expect(controller.state.pendingEvidence!.source, CaptureSource.camera);
        expect((await repository.findById('assessment-1'))!.captures, isEmpty);

        await controller.accept();

        final saved = await repository.findById('assessment-1');
        expect(controller.state.phase, AssessmentEvidencePhase.ready);
        expect(saved!.captures.single.id, 'capture-1');
        expect(saved.captures.single.source, CaptureSource.camera);
        expect(saved.captures.single.orientation, CaptureOrientation.landscape);
        expect(
          saved.captures.single.capturedAt,
          DateTime.utc(2026, 9, 6, 18, 1),
        );
        expect(
          saved.captures.single.acceptedAt,
          DateTime.utc(2026, 9, 6, 18, 2),
        );
        expect(saved.captures.single.localPath, '/evidence/capture-1.jpg');
        expect(saved.observations.single.captureId, 'capture-1');
        expect(saved.observations.single.rawClass, 'doorouter-dent');
        expect(saved.observations.single.modelIdentifier, 'test-model');
        expect(saved.observations.single.runtimeIdentifier, 'test-runtime');
        expect(fileStore.savedIds, ['capture-1']);
      },
    );

    test(
      'import cancellation returns to the Draft without staging evidence',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_draft());
        final controller = AssessmentEvidenceController(
          assessmentId: 'assessment-1',
          repository: repository,
          acquisitionService: _ResultAcquisitionService(
            const EvidenceAcquisitionCancelled(),
          ),
          inferenceService: _FakeInferenceService(),
          fileStore: _MemoryEvidenceFileStore(),
          idGenerator: _IdGenerator([]).next,
          now: DateTime.now,
        );

        await controller.load();
        await controller.importImage();

        expect(controller.state.phase, AssessmentEvidencePhase.ready);
        expect(controller.state.pendingEvidence, isNull);
        expect(controller.state.message, 'Image import cancelled.');
        expect((await repository.findById('assessment-1'))!.captures, isEmpty);
      },
    );

    test('camera permission denial is explicit and persists nothing', () async {
      final repository = InMemoryAssessmentRepository();
      await repository.save(_draft());
      final controller = AssessmentEvidenceController(
        assessmentId: 'assessment-1',
        repository: repository,
        acquisitionService: _ResultAcquisitionService(
          const EvidencePermissionDenied('Camera permission was denied.'),
        ),
        inferenceService: _FakeInferenceService(),
        fileStore: _MemoryEvidenceFileStore(),
        idGenerator: _IdGenerator([]).next,
        now: DateTime.now,
      );

      await controller.load();
      await controller.stageCameraCapture();

      expect(controller.state.phase, AssessmentEvidencePhase.permissionDenied);
      expect(controller.state.message, 'Camera permission was denied.');
      expect(controller.state.pendingEvidence, isNull);
      expect((await repository.findById('assessment-1'))!.captures, isEmpty);
    });

    test(
      'inference failure keeps evidence reviewable without suggestions',
      () async {
        final repository = InMemoryAssessmentRepository();
        await repository.save(_draft());
        final controller = AssessmentEvidenceController(
          assessmentId: 'assessment-1',
          repository: repository,
          acquisitionService: _FakeAcquisitionService(),
          inferenceService: _ThrowingInferenceService(),
          fileStore: _MemoryEvidenceFileStore(),
          idGenerator: _IdGenerator(['capture-1']).next,
          now: () => DateTime.utc(2026, 9, 6, 18, 2),
        );

        await controller.load();
        await controller.importImage();

        expect(controller.state.phase, AssessmentEvidencePhase.inferenceFailed);
        expect(controller.state.pendingEvidence!.observations, isEmpty);
        expect(controller.state.message, contains('Inference unavailable'));

        await controller.accept();

        final saved = await repository.findById('assessment-1');
        expect(saved!.captures, hasLength(1));
        expect(saved.observations, isEmpty);
      },
    );

    test('save failure rolls back the image and retry persists once', () async {
      final stored = InMemoryAssessmentRepository();
      await stored.save(_draft());
      final repository = _FailOnceAssessmentRepository(stored);
      final fileStore = _MemoryEvidenceFileStore();
      final controller = AssessmentEvidenceController(
        assessmentId: 'assessment-1',
        repository: repository,
        acquisitionService: _FakeAcquisitionService(),
        inferenceService: _FakeInferenceService(),
        fileStore: fileStore,
        idGenerator: _IdGenerator(['capture-1', 'observation-1']).next,
        now: () => DateTime.utc(2026, 9, 6, 18, 2),
      );

      await controller.load();
      await controller.stageCameraCapture();
      await controller.accept();

      expect(controller.state.phase, AssessmentEvidencePhase.saveFailed);
      expect(controller.state.pendingEvidence!.captureId, 'capture-1');
      expect((await stored.findById('assessment-1'))!.captures, isEmpty);
      expect(fileStore.deletedPaths, ['/evidence/capture-1.jpg']);

      await controller.retrySave();

      expect(controller.state.phase, AssessmentEvidencePhase.ready);
      expect((await stored.findById('assessment-1'))!.captures, hasLength(1));
      expect(fileStore.savedIds, ['capture-1', 'capture-1']);
    });

    test('rejecting a staged still leaves the Draft unchanged', () async {
      final repository = InMemoryAssessmentRepository();
      await repository.save(_draft());
      final fileStore = _MemoryEvidenceFileStore();
      final controller = AssessmentEvidenceController(
        assessmentId: 'assessment-1',
        repository: repository,
        acquisitionService: _FakeAcquisitionService(),
        inferenceService: _FakeInferenceService(),
        fileStore: fileStore,
        idGenerator: _IdGenerator(['capture-1', 'observation-1']).next,
        now: DateTime.now,
      );

      await controller.load();
      await controller.stageCameraCapture();
      controller.reject();

      expect(controller.state.phase, AssessmentEvidencePhase.ready);
      expect(controller.state.pendingEvidence, isNull);
      expect(fileStore.savedIds, isEmpty);
      expect((await repository.findById('assessment-1'))!.captures, isEmpty);
    });

    test('accepted evidence reloads in a new controller session', () async {
      final repository = InMemoryAssessmentRepository();
      await repository.save(_draft());
      final firstSession = AssessmentEvidenceController(
        assessmentId: 'assessment-1',
        repository: repository,
        acquisitionService: _FakeAcquisitionService(),
        inferenceService: _FakeInferenceService(),
        fileStore: _MemoryEvidenceFileStore(),
        idGenerator: _IdGenerator(['capture-1', 'observation-1']).next,
        now: () => DateTime.utc(2026, 9, 6, 18, 2),
      );
      await firstSession.load();
      await firstSession.importImage();
      await firstSession.accept();

      final reopened = AssessmentEvidenceController(
        assessmentId: 'assessment-1',
        repository: repository,
        acquisitionService: _ResultAcquisitionService(
          const EvidenceAcquisitionCancelled(),
        ),
        inferenceService: _FakeInferenceService(),
        fileStore: _MemoryEvidenceFileStore(),
        idGenerator: _IdGenerator([]).next,
        now: DateTime.now,
      );
      await reopened.load();

      expect(reopened.state.phase, AssessmentEvidencePhase.ready);
      expect(reopened.state.assessment!.captures.single.id, 'capture-1');
      expect(
        reopened.state.assessment!.observations.single.id,
        'observation-1',
      );
    });

    test('Appraiser can retry inference before accepting evidence', () async {
      final repository = InMemoryAssessmentRepository();
      await repository.save(_draft());
      final controller = AssessmentEvidenceController(
        assessmentId: 'assessment-1',
        repository: repository,
        acquisitionService: _FakeAcquisitionService(),
        inferenceService: _FailOnceInferenceService(),
        fileStore: _MemoryEvidenceFileStore(),
        idGenerator: _IdGenerator(['capture-1', 'observation-1']).next,
        now: DateTime.now,
      );

      await controller.load();
      await controller.stageCameraCapture();
      expect(controller.state.phase, AssessmentEvidencePhase.inferenceFailed);

      await controller.retryInference();

      expect(controller.state.phase, AssessmentEvidencePhase.staged);
      expect(controller.state.pendingEvidence!.observations, hasLength(1));
    });

    test('cleanup failure does not hide a failed assessment save', () async {
      final stored = InMemoryAssessmentRepository();
      await stored.save(_draft());
      final controller = AssessmentEvidenceController(
        assessmentId: 'assessment-1',
        repository: _FailOnceAssessmentRepository(stored),
        acquisitionService: _FakeAcquisitionService(),
        inferenceService: _FakeInferenceService(),
        fileStore: _CleanupFailingFileStore(),
        idGenerator: _IdGenerator(['capture-1', 'observation-1']).next,
        now: DateTime.now,
      );
      await controller.load();
      await controller.stageCameraCapture();

      await controller.accept();

      expect(controller.state.phase, AssessmentEvidencePhase.saveFailed);
      expect(controller.state.message, 'Storage unavailable.');
      expect((await stored.findById('assessment-1'))!.captures, isEmpty);
    });

    test(
      'load failure is exposed without leaving the screen loading',
      () async {
        final controller = AssessmentEvidenceController(
          assessmentId: 'assessment-1',
          repository: _ReadFailingAssessmentRepository(),
          acquisitionService: _FakeAcquisitionService(),
          inferenceService: _FakeInferenceService(),
          fileStore: _MemoryEvidenceFileStore(),
          idGenerator: _IdGenerator([]).next,
          now: DateTime.now,
        );

        await controller.load();

        expect(
          controller.state.phase,
          AssessmentEvidencePhase.acquisitionFailed,
        );
        expect(
          controller.state.message,
          contains('Assessment store unavailable'),
        );
      },
    );
  });
}

IntakeAssessment _draft() => IntakeAssessment.create(
  id: 'assessment-1',
  vehicle: const Vehicle(id: 'vehicle-1'),
  appraiserProfile: const AppraiserProfile(
    id: 'appraiser-1',
    displayName: 'Alex Appraiser',
  ),
  createdAt: DateTime.utc(2026, 9, 6, 18),
);

class _FakeAcquisitionService implements EvidenceAcquisitionService {
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

class _ResultAcquisitionService implements EvidenceAcquisitionService {
  _ResultAcquisitionService(this.result);

  final EvidenceAcquisitionResult result;

  @override
  Future<EvidenceAcquisitionResult> acquire(CaptureSource source) async =>
      result;
}

class _FakeInferenceService implements EvidenceInferenceService {
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

class _ThrowingInferenceService implements EvidenceInferenceService {
  @override
  Future<List<UnlinkedDamageObservation>> analyze(Uint8List bytes) async =>
      throw StateError('Inference unavailable');
}

class _FailOnceInferenceService implements EvidenceInferenceService {
  bool _shouldFail = true;

  @override
  Future<List<UnlinkedDamageObservation>> analyze(Uint8List bytes) {
    if (_shouldFail) {
      _shouldFail = false;
      throw StateError('Inference unavailable');
    }
    return _FakeInferenceService().analyze(bytes);
  }
}

class _MemoryEvidenceFileStore implements EvidenceFileStore {
  final List<String> savedIds = [];
  final List<String> deletedPaths = [];

  @override
  Future<void> delete(String localPath) async {
    deletedPaths.add(localPath);
  }

  @override
  Future<String> save({
    required String assessmentId,
    required String captureId,
    required String fileExtension,
    required Uint8List bytes,
  }) async {
    savedIds.add(captureId);
    return '/evidence/$captureId.$fileExtension';
  }
}

class _CleanupFailingFileStore extends _MemoryEvidenceFileStore {
  @override
  Future<void> delete(String localPath) async {
    throw const FileSystemException('Cleanup unavailable');
  }
}

class _FailOnceAssessmentRepository implements AssessmentRepository {
  _FailOnceAssessmentRepository(this.delegate);

  final AssessmentRepository delegate;
  bool _shouldFail = true;

  @override
  Future<IntakeAssessment?> findById(String id) => delegate.findById(id);

  @override
  Future<List<IntakeAssessment>> list() => delegate.list();

  @override
  Future<SaveAssessmentResult> save(
    IntakeAssessment assessment, {
    DateTime? expectedUpdatedAt,
  }) {
    if (_shouldFail) {
      _shouldFail = false;
      return Future.value(
        const AssessmentSaveFailed(message: 'Storage unavailable.'),
      );
    }
    return delegate.save(assessment, expectedUpdatedAt: expectedUpdatedAt);
  }
}

class _ReadFailingAssessmentRepository implements AssessmentRepository {
  @override
  Future<IntakeAssessment?> findById(String id) =>
      Future.error(const FileSystemException('Assessment store unavailable'));

  @override
  Future<List<IntakeAssessment>> list() => Future.value(const []);

  @override
  Future<SaveAssessmentResult> save(
    IntakeAssessment assessment, {
    DateTime? expectedUpdatedAt,
  }) => Future.value(const AssessmentSaveFailed(message: 'Unavailable'));
}

class _IdGenerator {
  _IdGenerator(this._ids);

  final List<String> _ids;

  String next() => _ids.removeAt(0);
}
