import 'package:flutter/foundation.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/services/assessment_evidence_service.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

enum AssessmentEvidencePhase {
  idle,
  loading,
  ready,
  acquiring,
  staged,
  permissionDenied,
  acquisitionFailed,
  inferenceFailed,
  saving,
  saveFailed,
}

class PendingAssessmentEvidence {
  const PendingAssessmentEvidence({
    required this.captureId,
    required this.evidence,
    required this.observations,
  });

  final String captureId;
  final AcquiredEvidence evidence;
  final List<DamageObservation> observations;

  CaptureSource get source => evidence.source;
}

class AssessmentEvidenceState {
  const AssessmentEvidenceState({
    this.phase = AssessmentEvidencePhase.idle,
    this.assessment,
    this.pendingEvidence,
    this.message,
  });

  final AssessmentEvidencePhase phase;
  final IntakeAssessment? assessment;
  final PendingAssessmentEvidence? pendingEvidence;
  final String? message;
}

class AssessmentEvidenceController extends ChangeNotifier {
  AssessmentEvidenceController({
    required this.assessmentId,
    required AssessmentRepository repository,
    required EvidenceAcquisitionService acquisitionService,
    required EvidenceInferenceService inferenceService,
    required EvidenceFileStore fileStore,
    required String Function() idGenerator,
    required DateTime Function() now,
  }) : _repository = repository,
       _acquisitionService = acquisitionService,
       _inferenceService = inferenceService,
       _fileStore = fileStore,
       _idGenerator = idGenerator,
       _now = now;

  final String assessmentId;
  final AssessmentRepository _repository;
  final EvidenceAcquisitionService _acquisitionService;
  final EvidenceInferenceService _inferenceService;
  final EvidenceFileStore _fileStore;
  final String Function() _idGenerator;
  final DateTime Function() _now;

  AssessmentEvidenceState _state = const AssessmentEvidenceState();

  AssessmentEvidenceState get state => _state;

  Future<void> load() async {
    _emit(
      const AssessmentEvidenceState(phase: AssessmentEvidencePhase.loading),
    );
    try {
      final assessment = await _repository.findById(assessmentId);
      _emit(
        AssessmentEvidenceState(
          phase: assessment == null
              ? AssessmentEvidencePhase.acquisitionFailed
              : AssessmentEvidencePhase.ready,
          assessment: assessment,
          message: assessment == null ? 'Intake Assessment not found.' : null,
        ),
      );
    } catch (error) {
      _emit(
        AssessmentEvidenceState(
          phase: AssessmentEvidencePhase.acquisitionFailed,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> stageCameraCapture() => _stage(CaptureSource.camera);

  Future<void> importImage() => _stage(CaptureSource.import);

  Future<void> _stage(CaptureSource source) async {
    final assessment = _state.assessment;
    if (assessment == null) return;
    _emit(
      AssessmentEvidenceState(
        phase: AssessmentEvidencePhase.acquiring,
        assessment: assessment,
      ),
    );
    final acquisition = await _acquisitionService.acquire(source);
    if (acquisition is EvidenceAcquisitionCancelled) {
      _emit(
        AssessmentEvidenceState(
          phase: AssessmentEvidencePhase.ready,
          assessment: assessment,
          message: source == CaptureSource.import
              ? 'Image import cancelled.'
              : 'Camera capture cancelled.',
        ),
      );
      return;
    }
    if (acquisition is EvidencePermissionDenied) {
      _emit(
        AssessmentEvidenceState(
          phase: AssessmentEvidencePhase.permissionDenied,
          assessment: assessment,
          message: acquisition.message,
        ),
      );
      return;
    }
    if (acquisition is! EvidenceAcquired) {
      final message = acquisition is EvidenceAcquisitionFailed
          ? acquisition.message
          : 'Evidence was not acquired.';
      _emit(
        AssessmentEvidenceState(
          phase: AssessmentEvidencePhase.acquisitionFailed,
          assessment: assessment,
          message: message,
        ),
      );
      return;
    }

    final captureId = _idGenerator();
    late final List<DamageObservation> observations;
    try {
      final unlinked = await _inferenceService.analyze(
        acquisition.evidence.bytes,
      );
      observations = _linkObservations(captureId, unlinked);
    } catch (error) {
      _emit(
        AssessmentEvidenceState(
          phase: AssessmentEvidencePhase.inferenceFailed,
          assessment: assessment,
          pendingEvidence: PendingAssessmentEvidence(
            captureId: captureId,
            evidence: acquisition.evidence,
            observations: const [],
          ),
          message: error.toString(),
        ),
      );
      return;
    }
    _emit(
      AssessmentEvidenceState(
        phase: AssessmentEvidencePhase.staged,
        assessment: assessment,
        pendingEvidence: PendingAssessmentEvidence(
          captureId: captureId,
          evidence: acquisition.evidence,
          observations: observations,
        ),
      ),
    );
  }

  List<DamageObservation> _linkObservations(
    String captureId,
    List<UnlinkedDamageObservation> observations,
  ) => List<DamageObservation>.unmodifiable(
    observations.map(
      (observation) => DamageObservation(
        id: _idGenerator(),
        captureId: captureId,
        rawClass: observation.rawClass,
        confidence: observation.confidence,
        bounds: observation.bounds,
        modelIdentifier: observation.modelIdentifier,
        runtimeIdentifier: observation.runtimeIdentifier,
      ),
    ),
  );

  void reject() {
    final assessment = _state.assessment;
    if (assessment == null) return;
    _emit(
      AssessmentEvidenceState(
        phase: AssessmentEvidencePhase.ready,
        assessment: assessment,
      ),
    );
  }

  Future<void> accept() async {
    final assessment = _state.assessment;
    final pending = _state.pendingEvidence;
    if (assessment == null || pending == null) return;
    _emit(
      AssessmentEvidenceState(
        phase: AssessmentEvidencePhase.saving,
        assessment: assessment,
        pendingEvidence: pending,
      ),
    );
    String? localPath;
    try {
      localPath = await _fileStore.save(
        assessmentId: assessment.id,
        captureId: pending.captureId,
        fileExtension: pending.evidence.fileExtension,
        bytes: pending.evidence.bytes,
      );
      var updated = assessment.acceptCapture(
        Capture(
          id: pending.captureId,
          source: pending.evidence.source,
          localPath: localPath,
          acceptedByProfileId: assessment.appraiserProfile.id,
          acceptedAt: _now().toUtc(),
          capturedAt: pending.evidence.capturedAt.toUtc(),
          orientation: pending.evidence.orientation,
        ),
      );
      for (final observation in pending.observations) {
        updated = updated.recordObservation(observation);
      }
      final result = await _repository.save(
        updated,
        expectedUpdatedAt: assessment.updatedAt,
      );
      if (result is AssessmentSaved) {
        _emit(
          AssessmentEvidenceState(
            phase: AssessmentEvidencePhase.ready,
            assessment: updated,
          ),
        );
        return;
      }
      await _deleteBestEffort(localPath);
      final failure = result as AssessmentSaveFailed;
      _emit(
        AssessmentEvidenceState(
          phase: AssessmentEvidencePhase.saveFailed,
          assessment: assessment,
          pendingEvidence: pending,
          message: failure.message,
        ),
      );
    } catch (error) {
      if (localPath != null) await _deleteBestEffort(localPath);
      _emit(
        AssessmentEvidenceState(
          phase: AssessmentEvidencePhase.saveFailed,
          assessment: assessment,
          pendingEvidence: pending,
          message: error.toString(),
        ),
      );
    }
  }

  Future<void> retrySave() => accept();

  Future<void> _deleteBestEffort(String localPath) async {
    try {
      await _fileStore.delete(localPath);
    } catch (error) {
      debugPrint('Unable to clean up unsaved assessment evidence: $error');
    }
  }

  Future<void> retryInference() async {
    final assessment = _state.assessment;
    final pending = _state.pendingEvidence;
    if (assessment == null || pending == null) return;
    _emit(
      AssessmentEvidenceState(
        phase: AssessmentEvidencePhase.acquiring,
        assessment: assessment,
        pendingEvidence: pending,
      ),
    );
    try {
      final unlinked = await _inferenceService.analyze(pending.evidence.bytes);
      _emit(
        AssessmentEvidenceState(
          phase: AssessmentEvidencePhase.staged,
          assessment: assessment,
          pendingEvidence: PendingAssessmentEvidence(
            captureId: pending.captureId,
            evidence: pending.evidence,
            observations: _linkObservations(pending.captureId, unlinked),
          ),
        ),
      );
    } catch (error) {
      _emit(
        AssessmentEvidenceState(
          phase: AssessmentEvidencePhase.inferenceFailed,
          assessment: assessment,
          pendingEvidence: pending,
          message: error.toString(),
        ),
      );
    }
  }

  void _emit(AssessmentEvidenceState state) {
    _state = state;
    notifyListeners();
  }
}
