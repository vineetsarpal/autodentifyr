import 'dart:io';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/models/models.dart';
import 'package:autodentifyr/services/model_manager.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ultralytics_yolo/utils/map_converter.dart';
import 'package:ultralytics_yolo/yolo.dart';

class AcquiredEvidence {
  AcquiredEvidence({
    required Uint8List bytes,
    required this.source,
    required this.orientation,
    required this.capturedAt,
    required this.fileExtension,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final Uint8List bytes;
  final CaptureSource source;
  final CaptureOrientation orientation;
  final DateTime capturedAt;
  final String fileExtension;
}

sealed class EvidenceAcquisitionResult {
  const EvidenceAcquisitionResult();
}

class EvidenceAcquired extends EvidenceAcquisitionResult {
  const EvidenceAcquired(this.evidence);

  final AcquiredEvidence evidence;
}

class EvidenceAcquisitionCancelled extends EvidenceAcquisitionResult {
  const EvidenceAcquisitionCancelled();
}

class EvidencePermissionDenied extends EvidenceAcquisitionResult {
  const EvidencePermissionDenied(this.message);

  final String message;
}

class EvidenceAcquisitionFailed extends EvidenceAcquisitionResult {
  const EvidenceAcquisitionFailed(this.message);

  final String message;
}

abstract interface class EvidenceAcquisitionService {
  Future<EvidenceAcquisitionResult> acquire(CaptureSource source);
}

class UnlinkedDamageObservation {
  const UnlinkedDamageObservation({
    required this.rawClass,
    required this.confidence,
    required this.bounds,
    required this.modelIdentifier,
    required this.runtimeIdentifier,
  });

  final String rawClass;
  final double confidence;
  final ObservationBounds bounds;
  final String modelIdentifier;
  final String runtimeIdentifier;
}

abstract interface class EvidenceInferenceService {
  Future<List<UnlinkedDamageObservation>> analyze(Uint8List bytes);
}

abstract interface class EvidenceFileStore {
  Future<String> save({
    required String assessmentId,
    required String captureId,
    required String fileExtension,
    required Uint8List bytes,
  });

  Future<void> delete(String localPath);
}

class ImagePickerEvidenceAcquisitionService
    implements EvidenceAcquisitionService {
  ImagePickerEvidenceAcquisitionService({
    ImagePicker? picker,
    DateTime Function()? now,
  }) : _picker = picker ?? ImagePicker(),
       _now = now ?? DateTime.now;

  final ImagePicker _picker;
  final DateTime Function() _now;

  @override
  Future<EvidenceAcquisitionResult> acquire(CaptureSource source) async {
    try {
      final selected = await _picker.pickImage(
        source: source == CaptureSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
      if (selected == null) return const EvidenceAcquisitionCancelled();
      final bytes = await selected.readAsBytes();
      if (bytes.isEmpty) {
        return const EvidenceAcquisitionFailed(
          'The selected image could not be read.',
        );
      }
      return EvidenceAcquired(
        AcquiredEvidence(
          bytes: bytes,
          source: source,
          orientation: _orientationOf(bytes),
          capturedAt: _now().toUtc(),
          fileExtension: _safeExtension(selected.path),
        ),
      );
    } on PlatformException catch (error) {
      if (_isPermissionError(error)) {
        return EvidencePermissionDenied(
          source == CaptureSource.camera
              ? 'Camera permission was denied.'
              : 'Photo access was denied.',
        );
      }
      return EvidenceAcquisitionFailed(
        error.message ?? 'Image acquisition failed.',
      );
    } catch (error) {
      return EvidenceAcquisitionFailed('Image acquisition failed: $error');
    }
  }

  static CaptureOrientation _orientationOf(Uint8List bytes) {
    final decoded = image.decodeImage(bytes);
    if (decoded == null) return CaptureOrientation.unknown;
    if (decoded.width == decoded.height) return CaptureOrientation.square;
    return decoded.width > decoded.height
        ? CaptureOrientation.landscape
        : CaptureOrientation.portrait;
  }

  static String _safeExtension(String path) {
    final separator = path.lastIndexOf('.');
    final extension = separator == -1
        ? 'jpg'
        : path.substring(separator + 1).toLowerCase();
    return switch (extension) {
      'jpeg' => 'jpg',
      'jpg' || 'png' || 'webp' || 'heic' || 'heif' => extension,
      _ => 'jpg',
    };
  }

  static bool _isPermissionError(PlatformException error) {
    final detail = '${error.code} ${error.message}'.toLowerCase();
    return detail.contains('denied') ||
        detail.contains('permission') ||
        detail.contains('access');
  }
}

class YoloEvidenceInferenceService implements EvidenceInferenceService {
  YoloEvidenceInferenceService({ModelManager? modelManager})
    : _modelManager = modelManager ?? ModelManager();

  static const runtimeIdentifier = 'ultralytics_yolo-0.6.14/android';

  final ModelManager _modelManager;
  Future<({YOLO yolo, String modelIdentifier})>? _loadedModel;

  @override
  Future<List<UnlinkedDamageObservation>> analyze(Uint8List bytes) async {
    final loaded = await (_loadedModel ??= _loadModel());
    final result = await loaded.yolo.predict(bytes);
    final rawDetections = result['detections'] ?? result['boxes'];
    final detections = rawDetections is List
        ? MapConverter.convertMapsList(rawDetections)
        : <Map<String, dynamic>>[];
    return List.unmodifiable(
      detections.map((detection) {
        final normalized = detection['normalizedBox'] is Map
            ? MapConverter.convertToTypedMap(detection['normalizedBox'] as Map)
            : detection;
        final left = _number(normalized, 'left', 'x1_norm');
        final top = _number(normalized, 'top', 'y1_norm');
        final right = _number(normalized, 'right', 'x2_norm');
        final bottom = _number(normalized, 'bottom', 'y2_norm');
        return UnlinkedDamageObservation(
          rawClass:
              detection['className'] as String? ??
              detection['class'] as String? ??
              'unknown',
          confidence: _number(detection, 'confidence', 'conf').clamp(0.0, 1.0),
          bounds: ObservationBounds(
            left: left,
            top: top,
            width: (right - left).clamp(0.0, 1.0),
            height: (bottom - top).clamp(0.0, 1.0),
          ),
          modelIdentifier: loaded.modelIdentifier,
          runtimeIdentifier: runtimeIdentifier,
        );
      }),
    );
  }

  Future<({YOLO yolo, String modelIdentifier})> _loadModel() async {
    final modelPath = await _modelManager.getModelPath(ModelType.detect);
    if (modelPath == null) throw StateError('Damage model is unavailable.');
    final yolo = YOLO(modelPath: modelPath, task: ModelType.detect.task);
    await yolo.loadModel();
    await yolo.predictorInstance();
    return (
      yolo: yolo,
      modelIdentifier: modelPath.split(Platform.pathSeparator).last,
    );
  }

  static double _number(
    Map<String, dynamic> values,
    String preferred,
    String fallback,
  ) => (values[preferred] as num? ?? values[fallback] as num? ?? 0).toDouble();
}

Future<DeviceEvidenceFileStore> openDeviceEvidenceFileStore() async {
  final supportDirectory = await getApplicationSupportDirectory();
  return DeviceEvidenceFileStore(
    rootDirectory: Directory('${supportDirectory.path}/assessment_evidence'),
  );
}

class DeviceEvidenceFileStore implements EvidenceFileStore {
  DeviceEvidenceFileStore({required Directory rootDirectory})
    : _rootDirectory = rootDirectory.absolute;

  final Directory _rootDirectory;

  @override
  Future<String> save({
    required String assessmentId,
    required String captureId,
    required String fileExtension,
    required Uint8List bytes,
  }) async {
    _requireSafeSegment(assessmentId, 'assessment');
    _requireSafeSegment(captureId, 'capture');
    _requireSafeSegment(fileExtension, 'extension');
    final directory = Directory('${_rootDirectory.path}/$assessmentId');
    await directory.create(recursive: true);
    final destination = File(
      '${directory.path}/$captureId.${fileExtension.toLowerCase()}',
    );
    final temporary = File('${destination.path}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(destination.path);
      return destination.path;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @override
  Future<void> delete(String localPath) async {
    final file = File(localPath).absolute;
    final rootPrefix = '${_rootDirectory.path}${Platform.pathSeparator}';
    if (!file.path.startsWith(rootPrefix)) {
      throw const FileSystemException(
        'Refusing to delete evidence outside the evidence store.',
      );
    }
    if (await file.exists()) await file.delete();
  }

  static void _requireSafeSegment(String value, String name) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
      throw FormatException('Invalid $name identifier.');
    }
  }
}
