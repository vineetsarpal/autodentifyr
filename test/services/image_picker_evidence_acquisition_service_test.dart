import 'dart:io';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/services/assessment_evidence_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImagePickerEvidenceAcquisitionService worker decoding', () {
    late Directory temporary;
    late _Picker picker;
    late ImagePickerEvidenceAcquisitionService service;
    late List<MethodCall> nativeCalls;
    var timestampCalls = 0;
    final capturedAt = DateTime(2026, 10, 3, 10, 20, 30);
    const modelChannels = [
      MethodChannel('yolo_single_image_channel'),
      MethodChannel('autodentifyr/model_assets'),
    ];

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp(
        'acquired_orientation_',
      );
      picker = _Picker();
      timestampCalls = 0;
      nativeCalls = [];
      for (final channel in modelChannels) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              nativeCalls.add(call);
              throw StateError('Acquisition must not call model plugins.');
            });
      }
      service = ImagePickerEvidenceAcquisitionService(
        picker: picker,
        now: () {
          timestampCalls++;
          return capturedAt;
        },
      );
    });

    tearDown(() async {
      for (final channel in modelChannels) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
      expect(nativeCalls, isEmpty);
      await temporary.delete(recursive: true);
    });

    Future<AcquiredEvidence> acquireBytes(
      Uint8List bytes, {
      String filename = 'evidence.png',
      CaptureSource source = CaptureSource.import,
    }) async {
      final file = await File(
        '${temporary.path}/$filename',
      ).writeAsBytes(bytes);
      picker.selected = XFile(file.path);
      final result = await service.acquire(source);
      expect(result, isA<EvidenceAcquired>());
      final evidence = (result as EvidenceAcquired).evidence;
      expect(evidence.bytes, orderedEquals(bytes));
      expect(evidence.source, source);
      expect(evidence.capturedAt, capturedAt.toUtc());
      expect(evidence.capturedAt.isUtc, isTrue);
      expect(timestampCalls, 1);
      expect(picker.calls.single, (
        source: source == CaptureSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: null,
        maxHeight: null,
        imageQuality: null,
        preferredCamera: CameraDevice.rear,
        fullMetadata: true,
      ));
      expect(() => evidence.bytes[0] = 0, throwsUnsupportedError);
      return evidence;
    }

    for (final fixture in [
      (width: 32, height: 16, expected: CaptureOrientation.landscape),
      (width: 16, height: 32, expected: CaptureOrientation.portrait),
      (width: 24, height: 24, expected: CaptureOrientation.square),
    ]) {
      test('decodes ${fixture.expected.name} PNG in the real worker', () async {
        final bytes = image.encodePng(
          image.Image(width: fixture.width, height: fixture.height),
        );
        final evidence = await acquireBytes(
          bytes,
          source: CaptureSource.camera,
        );
        expect(evidence.orientation, fixture.expected);
      });
    }

    for (final encoder in <String, Uint8List Function(image.Image)>{
      'jpeg': (value) => image.encodeJpg(value),
      'gif': (value) => image.encodeGif(value),
      'bmp': image.encodeBmp,
      'tiff': (value) => image.encodeTiff(value),
    }.entries) {
      test('retains decodeImage support for ${encoder.key}', () async {
        final bytes = encoder.value(image.Image(width: 30, height: 18));
        final evidence = await acquireBytes(
          bytes,
          filename: 'image.${encoder.key}',
        );
        expect(evidence.orientation, CaptureOrientation.landscape);
        expect(evidence.fileExtension, 'jpg');
      });
    }

    for (final exifOrientation in [1, 2, 3, 4, 5, 6, 7, 8]) {
      test('preserves decodeImage EXIF orientation $exifOrientation', () async {
        final original = image.Image(width: 40, height: 24)
          ..exif.imageIfd.orientation = exifOrientation;
        final bytes = image.encodeJpg(original);
        final baseline = image.decodeImage(bytes)!;
        final expected = baseline.width > baseline.height
            ? CaptureOrientation.landscape
            : CaptureOrientation.portrait;
        expect(
          expected,
          exifOrientation >= 5
              ? CaptureOrientation.portrait
              : CaptureOrientation.landscape,
        );
        final evidence = await acquireBytes(bytes, filename: 'original.JPG');
        expect(evidence.orientation, expected);
        expect(evidence.fileExtension, 'jpg');
      });
    }

    test('keeps undecodable nonempty bytes with unknown orientation', () async {
      final bytes = Uint8List(64);
      expect(image.decodeImage(bytes), isNull);
      final evidence = await acquireBytes(bytes, filename: 'unsupported.heic');
      expect(evidence.orientation, CaptureOrientation.unknown);
      expect(evidence.fileExtension, 'heic');
    });

    test(
      'worker decoder exceptions retain acquisition failure and timestamp order',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        expect(() => image.decodeImage(bytes), throwsRangeError);
        final file = await File(
          '${temporary.path}/malformed.jpg',
        ).writeAsBytes(bytes);
        picker.selected = XFile(file.path);
        final result = await service.acquire(CaptureSource.import);
        expect(result, isA<EvidenceAcquisitionFailed>());
        expect(
          (result as EvidenceAcquisitionFailed).message,
          contains('RangeError'),
        );
        expect(timestampCalls, 0);
      },
    );

    for (final filename in [
      'evidence.JPEG',
      'evidence.WEBP',
      'evidence.HEIF',
      'evidence',
      'evidence.xyz',
    ]) {
      test('keeps extension normalization for $filename', () async {
        final evidence = await acquireBytes(
          image.encodePng(image.Image(width: 12, height: 12)),
          filename: filename,
        );
        expect(evidence.fileExtension, switch (filename) {
          'evidence.WEBP' => 'webp',
          'evidence.HEIF' => 'heif',
          _ => 'jpg',
        });
      });
    }

    test('evidence remains independent of mutable acquisition bytes', () async {
      final bytes = image.encodePng(image.Image(width: 20, height: 12));
      final original = Uint8List.fromList(bytes);
      picker.selected = _BytesFile(bytes);
      final result =
          await service.acquire(CaptureSource.import) as EvidenceAcquired;
      bytes.fillRange(0, bytes.length, 0);
      expect(result.evidence.bytes, orderedEquals(original));
      expect(result.evidence.orientation, CaptureOrientation.landscape);
    });

    test(
      'cancellation avoids reading evidence and recording a timestamp',
      () async {
        final result = await service.acquire(CaptureSource.camera);
        expect(result, isA<EvidenceAcquisitionCancelled>());
        expect(timestampCalls, 0);
      },
    );

    test('empty file fails before decoding or recording a timestamp', () async {
      final file = await File('${temporary.path}/empty.jpg').writeAsBytes([]);
      picker.selected = XFile(file.path);
      final result = await service.acquire(CaptureSource.import);
      expect(result, isA<EvidenceAcquisitionFailed>());
      expect(
        (result as EvidenceAcquisitionFailed).message,
        'The selected image could not be read.',
      );
      expect(timestampCalls, 0);
    });

    test('unreadable file preserves acquisition failure', () async {
      picker.selected = XFile('${temporary.path}/missing.jpg');
      final result = await service.acquire(CaptureSource.import);
      expect(result, isA<EvidenceAcquisitionFailed>());
      expect(
        (result as EvidenceAcquisitionFailed).message,
        startsWith('Image acquisition failed:'),
      );
      expect(timestampCalls, 0);
    });

    for (final source in CaptureSource.values) {
      test('preserves ${source.name} permission errors', () async {
        picker.error = PlatformException(code: 'access_denied');
        final result = await service.acquire(source);
        expect(result, isA<EvidencePermissionDenied>());
        expect(
          (result as EvidencePermissionDenied).message,
          source == CaptureSource.camera
              ? 'Camera permission was denied.'
              : 'Photo access was denied.',
        );
        expect(timestampCalls, 0);
      });
    }

    test(
      'preserves non-permission platform and generic picker errors',
      () async {
        picker.error = PlatformException(
          code: 'camera_unavailable',
          message: 'Camera unavailable',
        );
        var result = await service.acquire(CaptureSource.camera);
        expect(
          (result as EvidenceAcquisitionFailed).message,
          'Camera unavailable',
        );
        picker.error = StateError('picker failed');
        result = await service.acquire(CaptureSource.import);
        expect(
          (result as EvidenceAcquisitionFailed).message,
          contains('picker failed'),
        );
        expect(timestampCalls, 0);
      },
    );
  });
}

class _Picker extends ImagePicker {
  XFile? selected;
  Object? error;
  final calls =
      <
        ({
          ImageSource source,
          double? maxWidth,
          double? maxHeight,
          int? imageQuality,
          CameraDevice preferredCamera,
          bool fullMetadata,
        })
      >[];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls.add((
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      preferredCamera: preferredCameraDevice,
      fullMetadata: requestFullMetadata,
    ));
    if (error != null) throw error!;
    return selected;
  }
}

class _BytesFile extends XFile {
  _BytesFile(this.bytes) : super('evidence.png');
  final Uint8List bytes;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
}
