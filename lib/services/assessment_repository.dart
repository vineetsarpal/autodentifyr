import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:autodentifyr/models/assessment.dart';
import 'package:path_provider/path_provider.dart';

typedef AssessmentStoreWriter =
    Future<void> Function(File temporaryFile, String contents);

abstract interface class AssessmentRepository {
  Future<SaveAssessmentResult> save(
    IntakeAssessment assessment, {
    DateTime? expectedUpdatedAt,
  });

  Future<IntakeAssessment?> findById(String id);

  Future<List<IntakeAssessment>> list();
}

Future<FileAssessmentRepository> openDeviceLocalAssessmentRepository() async {
  final supportDirectory = await getApplicationSupportDirectory();
  return FileAssessmentRepository(
    directory: Directory('${supportDirectory.path}/assessment_records'),
  );
}

sealed class SaveAssessmentResult {
  const SaveAssessmentResult();
}

class AssessmentSaved extends SaveAssessmentResult {
  const AssessmentSaved(this.assessment);

  final IntakeAssessment assessment;
}

class AssessmentSaveFailed extends SaveAssessmentResult {
  const AssessmentSaveFailed({required this.message, this.retryable = true});

  final String message;
  final bool retryable;
}

class FileAssessmentRepository implements AssessmentRepository {
  FileAssessmentRepository({
    required Directory directory,
    this.fileName = 'assessments.json',
    AssessmentStoreWriter? writeStore,
  }) : _directory = directory,
       _writeStore = writeStore ?? _writeStoreFile;

  static const currentSchemaVersion = 10;

  final Directory _directory;
  final String fileName;
  final AssessmentStoreWriter _writeStore;
  Future<void> _pendingSave = Future.value();

  File get _storeFile => File('${_directory.path}/$fileName');

  @override
  Future<SaveAssessmentResult> save(
    IntakeAssessment assessment, {
    DateTime? expectedUpdatedAt,
  }) async {
    final previousSave = _pendingSave;
    final completion = Completer<void>();
    _pendingSave = completion.future;
    await previousSave;
    try {
      assessment.validateForPersistence();
      final assessments = await _readAll();
      final conflict = _saveConflict(
        existing: assessments[assessment.id],
        replacement: assessment,
        expectedUpdatedAt: expectedUpdatedAt,
      );
      if (conflict != null) return conflict;
      assessments[assessment.id] = assessment;
      await _commit(assessments.values);
      return AssessmentSaved(assessment);
    } on FileSystemException catch (error) {
      return AssessmentSaveFailed(message: error.message);
    } on FormatException catch (error) {
      return AssessmentSaveFailed(message: error.message, retryable: false);
    } on AssessmentInvariantViolation catch (error) {
      return AssessmentSaveFailed(message: error.message, retryable: false);
    } finally {
      completion.complete();
    }
  }

  @override
  Future<IntakeAssessment?> findById(String id) async => (await _readAll())[id];

  @override
  Future<List<IntakeAssessment>> list() async {
    final assessments = (await _readAll()).values.toList();
    assessments.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(assessments);
  }

  Future<Map<String, IntakeAssessment>> _readAll() async {
    if (!await _storeFile.exists()) return {};

    final decoded = jsonDecode(await _storeFile.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Assessment store must be a JSON object.');
    }
    final store = _migrate(Map<String, Object?>.from(decoded));
    if (store['schemaVersion'] != currentSchemaVersion) {
      throw FormatException(
        'Unsupported assessment schema version: ${store['schemaVersion']}.',
      );
    }
    final records = store['assessments'];
    if (records is! List) {
      throw const FormatException('Assessment store records are missing.');
    }

    final assessments = <String, IntakeAssessment>{};
    for (final record in records) {
      if (record is! Map) {
        throw const FormatException(
          'Assessment store contains a malformed record.',
        );
      }
      try {
        final assessment = IntakeAssessment.fromJson(
          Map<String, Object?>.from(record),
        );
        assessment.validateForPersistence();
        if (assessments.containsKey(assessment.id)) {
          throw FormatException(
            'Assessment store contains duplicate id ${assessment.id}.',
          );
        }
        assessments[assessment.id] = assessment;
      } on AssessmentInvariantViolation catch (error) {
        throw FormatException(
          'Assessment store contains an invalid record: ${error.message}',
        );
      } on TypeError catch (error) {
        throw FormatException(
          'Assessment store contains a malformed record: $error',
        );
      } on ArgumentError catch (error) {
        throw FormatException(
          'Assessment store contains a malformed record: $error',
        );
      }
    }
    return assessments;
  }

  Future<void> _commit(Iterable<IntakeAssessment> assessments) async {
    await _directory.create(recursive: true);
    final temporary = File('${_storeFile.path}.tmp');
    final contents = jsonEncode({
      'schemaVersion': currentSchemaVersion,
      'assessments': assessments
          .map((assessment) => assessment.toJson())
          .toList(),
    });
    await _writeStore(temporary, contents);
    await temporary.rename(_storeFile.path);
  }

  static Future<void> _writeStoreFile(File file, String contents) =>
      file.writeAsString(contents, flush: true);

  Map<String, Object?> _migrate(Map<String, Object?> store) {
    final version = store['schemaVersion'];
    if (version == currentSchemaVersion) return store;
    if (version != 1 &&
        version != 2 &&
        version != 3 &&
        version != 4 &&
        version != 5 &&
        version != 6 &&
        version != 7 &&
        version != 8 &&
        version != 9) {
      return store;
    }

    final records = store['assessments'];
    if (records is! List) return store;
    for (final record in records.whereType<Map>()) {
      record.putIfAbsent('captures', () => <Object?>[]);
      record.putIfAbsent('observations', () => <Object?>[]);
      record.putIfAbsent('findings', () => <Object?>[]);
      record.putIfAbsent('corrections', () => <Object?>[]);
      record.putIfAbsent('estimate', () => null);
      record.putIfAbsent('severityAssessments', () => <Object?>[]);
      record.putIfAbsent('completedRevisions', () => <Object?>[]);
      record.putIfAbsent('limitations', () => <Object?>[]);
      record.putIfAbsent('voidRecord', () => null);
      final estimate = record['estimate'];
      final findings = record['findings'];
      String? findingSignature(String? findingId) {
        if (findingId == null || findings is! List) return null;
        for (final value in findings.whereType<Map>()) {
          if (value['id'] == findingId) {
            return jsonEncode(
              DamageFinding.fromJson(Map<String, Object?>.from(value)).toJson(),
            );
          }
        }
        return null;
      }

      if (estimate is Map) {
        estimate.putIfAbsent('sourceVersion', () => 'unknown');
        estimate.putIfAbsent('overrides', () => <Object?>[]);
        estimate.putIfAbsent(
          'missingPricingAcknowledgedByProfileId',
          () => estimate['missingPricingAcknowledgedAt'] == null
              ? null
              : estimate['reviewedByProfileId'],
        );
        estimate.putIfAbsent('reviewedFindingSignatures', () {
          final signatures = <String, String>{};
          if (findings is List) {
            for (final value in findings.whereType<Map>()) {
              if (value['reviewState'] == FindingReviewState.confirmed.name) {
                final id = value['id'] as String?;
                final signature = findingSignature(id);
                if (id != null && signature != null) signatures[id] = signature;
              }
            }
          }
          return signatures;
        });
      }
      final severityAssessments = record['severityAssessments'];
      if (severityAssessments is List) {
        for (final severity in severityAssessments.whereType<Map>()) {
          severity.putIfAbsent('followUpOverrideReason', () => null);
          severity.putIfAbsent('automationSourceVersion', () => null);
          severity.putIfAbsent('automationLimitation', () => null);
          severity.putIfAbsent(
            'suggestionEvidenceCaptureIds',
            () => <Object?>[],
          );
          severity.putIfAbsent('suggestionIsSynthetic', () => false);
          severity.putIfAbsent('reviewHistory', () => <Object?>[]);
          severity.putIfAbsent(
            'reviewedFindingSignature',
            () => findingSignature(severity['findingId'] as String?),
          );
        }
      }
      final completedRevisions = record['completedRevisions'];
      if (completedRevisions is List) {
        for (final revision in completedRevisions.whereType<Map>()) {
          final frozenFindings = revision['confirmedFindings'];
          String? frozenFindingSignature(String? findingId) {
            if (findingId == null || frozenFindings is! List) return null;
            for (final value in frozenFindings.whereType<Map>()) {
              if (value['id'] == findingId) {
                return jsonEncode(
                  DamageFinding.fromJson(
                    Map<String, Object?>.from(value),
                  ).toJson(),
                );
              }
            }
            return null;
          }

          final frozenEstimate = revision['estimate'];
          if (frozenEstimate is Map) {
            frozenEstimate.putIfAbsent('reviewedFindingSignatures', () {
              final signatures = <String, String>{};
              if (frozenFindings is List) {
                for (final value in frozenFindings.whereType<Map>()) {
                  final id = value['id'] as String?;
                  final signature = frozenFindingSignature(id);
                  if (id != null && signature != null) {
                    signatures[id] = signature;
                  }
                }
              }
              return signatures;
            });
          }
          final frozenSeverities = revision['severityAssessments'];
          if (frozenSeverities is List) {
            for (final severity in frozenSeverities.whereType<Map>()) {
              severity.putIfAbsent(
                'reviewedFindingSignature',
                () => frozenFindingSignature(severity['findingId'] as String?),
              );
            }
          }
        }
      }
      final appraiserProfile = record['appraiserProfile'];
      final defaultAppraiserId = appraiserProfile is Map
          ? appraiserProfile['id']
          : null;
      final captures = record['captures'];
      if (captures is List) {
        for (final capture in captures.whereType<Map>()) {
          capture.putIfAbsent('acceptedByProfileId', () => defaultAppraiserId);
          capture.putIfAbsent('capturedAt', () => capture['acceptedAt']);
          capture.putIfAbsent(
            'orientation',
            () => CaptureOrientation.unknown.name,
          );
        }
      }
      final observations = record['observations'];
      if (observations is List) {
        for (final observation in observations.whereType<Map>()) {
          observation.putIfAbsent('runtimeIdentifier', () => 'unknown');
        }
      }
    }
    store['schemaVersion'] = currentSchemaVersion;
    return store;
  }
}

class InMemoryAssessmentRepository implements AssessmentRepository {
  final Map<String, IntakeAssessment> _assessments = {};

  @override
  Future<SaveAssessmentResult> save(
    IntakeAssessment assessment, {
    DateTime? expectedUpdatedAt,
  }) async {
    try {
      assessment.validateForPersistence();
      final conflict = _saveConflict(
        existing: _assessments[assessment.id],
        replacement: assessment,
        expectedUpdatedAt: expectedUpdatedAt,
      );
      if (conflict != null) return conflict;
      _assessments[assessment.id] = IntakeAssessment.fromJson(
        assessment.toJson(),
      );
      return AssessmentSaved(assessment);
    } on AssessmentInvariantViolation catch (error) {
      return AssessmentSaveFailed(message: error.message, retryable: false);
    }
  }

  @override
  Future<IntakeAssessment?> findById(String id) async => _assessments[id];

  @override
  Future<List<IntakeAssessment>> list() async {
    final assessments = _assessments.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(assessments);
  }
}

AssessmentSaveFailed? _saveConflict({
  required IntakeAssessment? existing,
  required IntakeAssessment replacement,
  required DateTime? expectedUpdatedAt,
}) {
  if (existing == null) {
    if (expectedUpdatedAt == null) return null;
    return const AssessmentSaveFailed(
      message: 'The Intake Assessment no longer exists.',
      retryable: false,
    );
  }
  if (expectedUpdatedAt != null && existing.updatedAt != expectedUpdatedAt) {
    return const AssessmentSaveFailed(
      message:
          'The Intake Assessment changed in another session. Reload it before retrying.',
    );
  }
  if (replacement.completedRevisions.length <
          existing.completedRevisions.length ||
      !_revisionPrefixMatches(existing, replacement)) {
    return const AssessmentSaveFailed(
      message: 'A save cannot replace immutable completed revision history.',
      retryable: false,
    );
  }
  if (existing.status == IntakeAssessmentStatus.voided &&
      replacement != existing) {
    return const AssessmentSaveFailed(
      message: 'A Voided Intake Assessment cannot be changed.',
      retryable: false,
    );
  }
  return null;
}

bool _revisionPrefixMatches(
  IntakeAssessment existing,
  IntakeAssessment replacement,
) {
  for (var index = 0; index < existing.completedRevisions.length; index++) {
    if (replacement.completedRevisions[index] !=
        existing.completedRevisions[index]) {
      return false;
    }
  }
  return true;
}
