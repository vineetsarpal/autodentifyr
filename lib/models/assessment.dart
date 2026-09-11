import 'dart:convert';

enum IntakeAssessmentStatus { draft, completed, voided }

enum CaptureSource { camera, import }

enum CaptureOrientation { portrait, landscape, square, unknown }

class AssessmentInvariantViolation implements Exception {
  const AssessmentInvariantViolation(this.message);

  final String message;

  @override
  String toString() => 'AssessmentInvariantViolation: $message';
}

class Vehicle {
  const Vehicle({required this.id, this.vin, this.licencePlate});

  final String id;
  final String? vin;
  final String? licencePlate;

  Map<String, Object?> toJson() => {
    'id': id,
    'vin': vin,
    'licencePlate': licencePlate,
  };

  factory Vehicle.fromJson(Map<String, Object?> json) => Vehicle(
    id: json['id']! as String,
    vin: json['vin'] as String?,
    licencePlate: json['licencePlate'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is Vehicle &&
      other.id == id &&
      other.vin == vin &&
      other.licencePlate == licencePlate;

  @override
  int get hashCode => Object.hash(id, vin, licencePlate);
}

class AppraiserProfile {
  const AppraiserProfile({required this.id, required this.displayName});

  final String id;
  final String displayName;

  Map<String, Object?> toJson() => {'id': id, 'displayName': displayName};

  factory AppraiserProfile.fromJson(Map<String, Object?> json) =>
      AppraiserProfile(
        id: json['id']! as String,
        displayName: json['displayName']! as String,
      );

  @override
  bool operator ==(Object other) =>
      other is AppraiserProfile &&
      other.id == id &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, displayName);
}

class Capture {
  const Capture({
    required this.id,
    required this.source,
    required this.localPath,
    required this.acceptedByProfileId,
    required this.acceptedAt,
    DateTime? capturedAt,
    this.orientation = CaptureOrientation.unknown,
  }) : capturedAt = capturedAt ?? acceptedAt;

  final String id;
  final CaptureSource source;
  final String localPath;
  final String acceptedByProfileId;
  final DateTime acceptedAt;
  final DateTime capturedAt;
  final CaptureOrientation orientation;

  Map<String, Object?> toJson() => {
    'id': id,
    'source': source.name,
    'localPath': localPath,
    'acceptedByProfileId': acceptedByProfileId,
    'acceptedAt': acceptedAt.toUtc().toIso8601String(),
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'orientation': orientation.name,
  };

  factory Capture.fromJson(Map<String, Object?> json) => Capture(
    id: json['id']! as String,
    source: CaptureSource.values.byName(json['source']! as String),
    localPath: json['localPath']! as String,
    acceptedByProfileId: json['acceptedByProfileId']! as String,
    acceptedAt: DateTime.parse(json['acceptedAt']! as String).toUtc(),
    capturedAt: DateTime.parse(
      (json['capturedAt'] ?? json['acceptedAt'])! as String,
    ).toUtc(),
    orientation: CaptureOrientation.values.byName(
      json['orientation'] as String? ?? CaptureOrientation.unknown.name,
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is Capture &&
      other.id == id &&
      other.source == source &&
      other.localPath == localPath &&
      other.acceptedByProfileId == acceptedByProfileId &&
      other.acceptedAt == acceptedAt &&
      other.capturedAt == capturedAt &&
      other.orientation == orientation;

  @override
  int get hashCode => Object.hash(
    id,
    source,
    localPath,
    acceptedByProfileId,
    acceptedAt,
    capturedAt,
    orientation,
  );
}

class ObservationBounds {
  const ObservationBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  Map<String, Object?> toJson() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  factory ObservationBounds.fromJson(Map<String, Object?> json) =>
      ObservationBounds(
        left: (json['left']! as num).toDouble(),
        top: (json['top']! as num).toDouble(),
        width: (json['width']! as num).toDouble(),
        height: (json['height']! as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is ObservationBounds &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

class DamageObservation {
  const DamageObservation({
    required this.id,
    required this.captureId,
    required this.rawClass,
    required this.confidence,
    required this.bounds,
    required this.modelIdentifier,
    this.runtimeIdentifier = 'unknown',
  });

  final String id;
  final String captureId;
  final String rawClass;
  final double confidence;
  final ObservationBounds bounds;
  final String modelIdentifier;
  final String runtimeIdentifier;

  Map<String, Object?> toJson() => {
    'id': id,
    'captureId': captureId,
    'rawClass': rawClass,
    'confidence': confidence,
    'bounds': bounds.toJson(),
    'modelIdentifier': modelIdentifier,
    'runtimeIdentifier': runtimeIdentifier,
  };

  factory DamageObservation.fromJson(Map<String, Object?> json) =>
      DamageObservation(
        id: json['id']! as String,
        captureId: json['captureId']! as String,
        rawClass: json['rawClass']! as String,
        confidence: (json['confidence']! as num).toDouble(),
        bounds: ObservationBounds.fromJson(
          Map<String, Object?>.from(json['bounds']! as Map),
        ),
        modelIdentifier: json['modelIdentifier']! as String,
        runtimeIdentifier: json['runtimeIdentifier'] as String? ?? 'unknown',
      );

  @override
  bool operator ==(Object other) =>
      other is DamageObservation &&
      other.id == id &&
      other.captureId == captureId &&
      other.rawClass == rawClass &&
      other.confidence == confidence &&
      other.bounds == bounds &&
      other.modelIdentifier == modelIdentifier &&
      other.runtimeIdentifier == runtimeIdentifier;

  @override
  int get hashCode => Object.hash(
    id,
    captureId,
    rawClass,
    confidence,
    bounds,
    modelIdentifier,
    runtimeIdentifier,
  );
}

enum FindingReviewState { proposed, confirmed, dismissed }

enum FindingReviewOutcome { undetermined }

enum AssessmentCorrectionKind {
  confirm,
  dismiss,
  edit,
  add,
  merge,
  split,
  uncertainty,
  undetermined,
}

class DamageFinding {
  const DamageFinding._({
    required this.id,
    required this.reviewState,
    required this.observationIds,
    required this.supportingCaptureIds,
    this.vehicleComponent,
    this.damageType,
    this.manualEvidenceNote,
    this.hasConflictingViews = false,
    this.additionalViewRequests = const [],
    this.additionalViewOverrideReason,
    this.reviewOutcome,
  });

  factory DamageFinding.proposed({
    required String id,
    required List<String> observationIds,
    required List<String> supportingCaptureIds,
    String? suggestedVehicleComponent,
    String? suggestedDamageType,
  }) => DamageFinding._(
    id: id,
    reviewState: FindingReviewState.proposed,
    observationIds: List.unmodifiable(observationIds),
    supportingCaptureIds: List.unmodifiable(supportingCaptureIds),
    vehicleComponent: suggestedVehicleComponent,
    damageType: suggestedDamageType,
  );

  factory DamageFinding.manual({
    required String id,
    required String vehicleComponent,
    required String damageType,
    required List<String> supportingCaptureIds,
    required String evidenceNote,
  }) {
    if (vehicleComponent.trim().isEmpty || damageType.trim().isEmpty) {
      throw const AssessmentInvariantViolation(
        'A Confirmed Finding requires a Vehicle Component and Damage Type.',
      );
    }
    if (supportingCaptureIds.isEmpty || evidenceNote.trim().isEmpty) {
      throw const AssessmentInvariantViolation(
        'A manual Confirmed Finding requires supporting evidence and an Appraiser evidence note.',
      );
    }
    return DamageFinding._(
      id: id,
      reviewState: FindingReviewState.confirmed,
      observationIds: const [],
      supportingCaptureIds: List.unmodifiable(supportingCaptureIds),
      vehicleComponent: vehicleComponent,
      damageType: damageType,
      manualEvidenceNote: evidenceNote,
    );
  }

  final String id;
  final FindingReviewState reviewState;
  final List<String> observationIds;
  final List<String> supportingCaptureIds;
  final String? vehicleComponent;
  final String? damageType;
  final String? manualEvidenceNote;
  final bool hasConflictingViews;
  final List<String> additionalViewRequests;
  final String? additionalViewOverrideReason;
  final FindingReviewOutcome? reviewOutcome;

  DamageFinding reviewed({
    required FindingReviewState state,
    String? vehicleComponent,
    String? damageType,
    String? additionalViewOverrideReason,
  }) {
    if (state == FindingReviewState.proposed) {
      throw const AssessmentInvariantViolation(
        'A review cannot return a Finding to Proposed.',
      );
    }
    final reviewedComponent = vehicleComponent ?? this.vehicleComponent;
    final reviewedDamageType = damageType ?? this.damageType;
    if (state == FindingReviewState.confirmed &&
        ((reviewedComponent?.trim().isEmpty ?? true) ||
            (reviewedDamageType?.trim().isEmpty ?? true))) {
      throw const AssessmentInvariantViolation(
        'A Confirmed Finding requires a Vehicle Component and Damage Type.',
      );
    }
    if (state != FindingReviewState.proposed &&
        additionalViewRequests.isNotEmpty &&
        (additionalViewOverrideReason?.trim().isEmpty ?? true)) {
      throw const AssessmentInvariantViolation(
        'A conclusion with an unmet additional-view request requires an override reason.',
      );
    }
    return DamageFinding._(
      id: id,
      reviewState: state,
      observationIds: observationIds,
      supportingCaptureIds: supportingCaptureIds,
      vehicleComponent: reviewedComponent,
      damageType: reviewedDamageType,
      manualEvidenceNote: manualEvidenceNote,
      hasConflictingViews: hasConflictingViews,
      additionalViewRequests: additionalViewRequests,
      additionalViewOverrideReason: additionalViewOverrideReason,
    );
  }

  DamageFinding edited({
    required String vehicleComponent,
    required String damageType,
    required List<String> supportingCaptureIds,
  }) => DamageFinding._(
    id: id,
    reviewState: reviewState,
    observationIds: observationIds,
    supportingCaptureIds: List.unmodifiable(supportingCaptureIds),
    vehicleComponent: vehicleComponent,
    damageType: damageType,
    manualEvidenceNote: manualEvidenceNote,
    hasConflictingViews: hasConflictingViews,
    additionalViewRequests: additionalViewRequests,
    additionalViewOverrideReason: additionalViewOverrideReason,
    reviewOutcome: reviewOutcome,
  );

  DamageFinding withUncertainty({
    required bool hasConflictingViews,
    required List<String> additionalViewRequests,
  }) {
    if (additionalViewRequests.any((request) => request.trim().isEmpty)) {
      throw const AssessmentInvariantViolation(
        'Additional-view requests must describe a specific view.',
      );
    }
    return DamageFinding._(
      id: id,
      reviewState: reviewState,
      observationIds: observationIds,
      supportingCaptureIds: supportingCaptureIds,
      vehicleComponent: vehicleComponent,
      damageType: damageType,
      manualEvidenceNote: manualEvidenceNote,
      hasConflictingViews: hasConflictingViews,
      additionalViewRequests: List.unmodifiable(additionalViewRequests),
      reviewOutcome: reviewOutcome,
    );
  }

  DamageFinding markUndetermined({String? additionalViewOverrideReason}) =>
      DamageFinding._(
        id: id,
        reviewState: FindingReviewState.proposed,
        observationIds: observationIds,
        supportingCaptureIds: supportingCaptureIds,
        vehicleComponent: vehicleComponent,
        damageType: damageType,
        manualEvidenceNote: manualEvidenceNote,
        hasConflictingViews: hasConflictingViews,
        additionalViewRequests: additionalViewRequests,
        additionalViewOverrideReason: additionalViewOverrideReason,
        reviewOutcome: FindingReviewOutcome.undetermined,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'reviewState': reviewState.name,
    'observationIds': observationIds,
    'supportingCaptureIds': supportingCaptureIds,
    'vehicleComponent': vehicleComponent,
    'damageType': damageType,
    'manualEvidenceNote': manualEvidenceNote,
    'hasConflictingViews': hasConflictingViews,
    'additionalViewRequests': additionalViewRequests,
    'additionalViewOverrideReason': additionalViewOverrideReason,
    'reviewOutcome': reviewOutcome?.name,
  };

  factory DamageFinding.fromJson(Map<String, Object?> json) => DamageFinding._(
    id: json['id']! as String,
    reviewState: FindingReviewState.values.byName(
      json['reviewState']! as String,
    ),
    observationIds: List.unmodifiable(
      (json['observationIds'] as List? ?? const []).cast<String>(),
    ),
    supportingCaptureIds: List.unmodifiable(
      (json['supportingCaptureIds'] as List? ?? const []).cast<String>(),
    ),
    vehicleComponent: json['vehicleComponent'] as String?,
    damageType: json['damageType'] as String?,
    manualEvidenceNote: json['manualEvidenceNote'] as String?,
    hasConflictingViews: json['hasConflictingViews'] as bool? ?? false,
    additionalViewRequests: List.unmodifiable(
      (json['additionalViewRequests'] as List? ?? const []).cast<String>(),
    ),
    additionalViewOverrideReason:
        json['additionalViewOverrideReason'] as String?,
    reviewOutcome: switch (json['reviewOutcome']) {
      final String value => FindingReviewOutcome.values.byName(value),
      _ => null,
    },
  );

  @override
  bool operator ==(Object other) =>
      other is DamageFinding &&
      other.id == id &&
      other.reviewState == reviewState &&
      _listEquals(other.observationIds, observationIds) &&
      _listEquals(other.supportingCaptureIds, supportingCaptureIds) &&
      other.vehicleComponent == vehicleComponent &&
      other.damageType == damageType &&
      other.manualEvidenceNote == manualEvidenceNote &&
      other.hasConflictingViews == hasConflictingViews &&
      _listEquals(other.additionalViewRequests, additionalViewRequests) &&
      other.additionalViewOverrideReason == additionalViewOverrideReason &&
      other.reviewOutcome == reviewOutcome;

  @override
  int get hashCode => Object.hash(
    id,
    reviewState,
    Object.hashAll(observationIds),
    Object.hashAll(supportingCaptureIds),
    vehicleComponent,
    damageType,
    manualEvidenceNote,
    hasConflictingViews,
    Object.hashAll(additionalViewRequests),
    additionalViewOverrideReason,
    reviewOutcome,
  );
}

class AssessmentCorrection {
  AssessmentCorrection({
    required this.id,
    required this.findingId,
    required this.kind,
    required this.authorProfileId,
    required this.occurredAt,
    required this.reason,
    required DamageFinding original,
    required DamageFinding replacement,
  }) : originals = List.unmodifiable([original]),
       replacements = List.unmodifiable([replacement]);

  AssessmentCorrection.multiple({
    required this.id,
    required this.findingId,
    required this.kind,
    required this.authorProfileId,
    required this.occurredAt,
    required this.reason,
    required List<DamageFinding> originals,
    required List<DamageFinding> replacements,
  }) : originals = List.unmodifiable(originals),
       replacements = List.unmodifiable(replacements);

  final String id;
  final String findingId;
  final AssessmentCorrectionKind kind;
  final String authorProfileId;
  final DateTime occurredAt;
  final String reason;
  final List<DamageFinding> originals;
  final List<DamageFinding> replacements;

  DamageFinding get original => originals.single;
  DamageFinding get replacement => replacements.single;

  Map<String, Object?> toJson() => {
    'id': id,
    'findingId': findingId,
    'kind': kind.name,
    'authorProfileId': authorProfileId,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'reason': reason,
    'originals': originals.map((finding) => finding.toJson()).toList(),
    'replacements': replacements.map((finding) => finding.toJson()).toList(),
  };

  factory AssessmentCorrection.fromJson(
    Map<String, Object?> json,
  ) => AssessmentCorrection.multiple(
    id: json['id']! as String,
    findingId: json['findingId']! as String,
    kind: AssessmentCorrectionKind.values.byName(json['kind']! as String),
    authorProfileId: json['authorProfileId']! as String,
    occurredAt: DateTime.parse(json['occurredAt']! as String).toUtc(),
    reason: json['reason']! as String,
    originals: switch (json['originals']) {
      final List values =>
        values
            .map(
              (value) => DamageFinding.fromJson(
                Map<String, Object?>.from(value as Map),
              ),
            )
            .toList(),
      _ => [
        DamageFinding.fromJson(
          Map<String, Object?>.from(json['original']! as Map),
        ),
      ],
    },
    replacements: switch (json['replacements']) {
      final List values =>
        values
            .map(
              (value) => DamageFinding.fromJson(
                Map<String, Object?>.from(value as Map),
              ),
            )
            .toList(),
      _ => [
        DamageFinding.fromJson(
          Map<String, Object?>.from(json['replacement']! as Map),
        ),
      ],
    },
  );

  @override
  bool operator ==(Object other) =>
      other is AssessmentCorrection &&
      other.id == id &&
      other.findingId == findingId &&
      other.kind == kind &&
      other.authorProfileId == authorProfileId &&
      other.occurredAt == occurredAt &&
      other.reason == reason &&
      _listEquals(other.originals, originals) &&
      _listEquals(other.replacements, replacements);

  @override
  int get hashCode => Object.hash(
    id,
    findingId,
    kind,
    authorProfileId,
    occurredAt,
    reason,
    Object.hashAll(originals),
    Object.hashAll(replacements),
  );
}

class RepairOperation {
  const RepairOperation({
    required this.id,
    required this.findingIds,
    required this.description,
    this.minimumCents,
    this.maximumCents,
    this.currency,
    this.pricingSourceVersion,
  });

  final String id;
  final List<String> findingIds;
  final String description;
  final int? minimumCents;
  final int? maximumCents;
  final String? currency;
  final String? pricingSourceVersion;

  bool get hasPricing =>
      minimumCents != null &&
      maximumCents != null &&
      currency != null &&
      pricingSourceVersion != null;

  Map<String, Object?> toJson() => {
    'id': id,
    'findingIds': findingIds,
    'description': description,
    'minimumCents': minimumCents,
    'maximumCents': maximumCents,
    'currency': currency,
    'pricingSourceVersion': pricingSourceVersion,
  };

  factory RepairOperation.fromJson(Map<String, Object?> json) =>
      RepairOperation(
        id: json['id']! as String,
        findingIds: List.unmodifiable(
          (json['findingIds']! as List).cast<String>(),
        ),
        description: json['description']! as String,
        minimumCents: json['minimumCents'] as int?,
        maximumCents: json['maximumCents'] as int?,
        currency: json['currency'] as String?,
        pricingSourceVersion: json['pricingSourceVersion'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is RepairOperation &&
      other.id == id &&
      _listEquals(other.findingIds, findingIds) &&
      other.description == description &&
      other.minimumCents == minimumCents &&
      other.maximumCents == maximumCents &&
      other.currency == currency &&
      other.pricingSourceVersion == pricingSourceVersion;

  @override
  int get hashCode => Object.hash(
    id,
    Object.hashAll(findingIds),
    description,
    minimumCents,
    maximumCents,
    currency,
    pricingSourceVersion,
  );
}

class EstimateOverride {
  const EstimateOverride({
    required this.id,
    required this.operationId,
    required this.authorProfileId,
    required this.occurredAt,
    required this.reason,
    required this.original,
    required this.replacement,
  });

  final String id;
  final String operationId;
  final String authorProfileId;
  final DateTime occurredAt;
  final String reason;
  final RepairOperation original;
  final RepairOperation replacement;

  Map<String, Object?> toJson() => {
    'id': id,
    'operationId': operationId,
    'authorProfileId': authorProfileId,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'reason': reason,
    'original': original.toJson(),
    'replacement': replacement.toJson(),
  };

  factory EstimateOverride.fromJson(Map<String, Object?> json) =>
      EstimateOverride(
        id: json['id']! as String,
        operationId: json['operationId']! as String,
        authorProfileId: json['authorProfileId']! as String,
        occurredAt: DateTime.parse(json['occurredAt']! as String).toUtc(),
        reason: json['reason']! as String,
        original: RepairOperation.fromJson(
          Map<String, Object?>.from(json['original']! as Map),
        ),
        replacement: RepairOperation.fromJson(
          Map<String, Object?>.from(json['replacement']! as Map),
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is EstimateOverride &&
      other.id == id &&
      other.operationId == operationId &&
      other.authorProfileId == authorProfileId &&
      other.occurredAt == occurredAt &&
      other.reason == reason &&
      other.original == original &&
      other.replacement == replacement;

  @override
  int get hashCode => Object.hash(
    id,
    operationId,
    authorProfileId,
    occurredAt,
    reason,
    original,
    replacement,
  );
}

class AssessmentEstimate {
  const AssessmentEstimate({
    required this.operations,
    required this.assumptions,
    required this.reviewedByProfileId,
    required this.reviewedAt,
    this.sourceVersion = 'unknown',
    this.overrides = const [],
    this.reviewedFindingSignatures = const {},
    this.missingPricingAcknowledgedAt,
    this.missingPricingAcknowledgedByProfileId,
  });

  final List<RepairOperation> operations;
  final List<String> assumptions;
  final String reviewedByProfileId;
  final DateTime reviewedAt;
  final String sourceVersion;
  final List<EstimateOverride> overrides;
  final Map<String, String> reviewedFindingSignatures;
  final DateTime? missingPricingAcknowledgedAt;
  final String? missingPricingAcknowledgedByProfileId;

  bool get isPartial => operations.any((operation) => !operation.hasPricing);

  int? get knownMinimumTotalCents {
    final priced = operations.where((operation) => operation.hasPricing);
    if (priced.isEmpty) return null;
    return priced.fold<int>(
      0,
      (total, operation) => total + operation.minimumCents!,
    );
  }

  int? get knownMaximumTotalCents {
    final priced = operations.where((operation) => operation.hasPricing);
    if (priced.isEmpty) return null;
    return priced.fold<int>(
      0,
      (total, operation) => total + operation.maximumCents!,
    );
  }

  Map<String, Object?> toJson() => {
    'operations': operations.map((operation) => operation.toJson()).toList(),
    'assumptions': assumptions,
    'reviewedByProfileId': reviewedByProfileId,
    'reviewedAt': reviewedAt.toUtc().toIso8601String(),
    'sourceVersion': sourceVersion,
    'overrides': overrides.map((value) => value.toJson()).toList(),
    'reviewedFindingSignatures': reviewedFindingSignatures,
    'missingPricingAcknowledgedAt': missingPricingAcknowledgedAt
        ?.toUtc()
        .toIso8601String(),
    'missingPricingAcknowledgedByProfileId':
        missingPricingAcknowledgedByProfileId,
  };

  factory AssessmentEstimate.fromJson(Map<String, Object?> json) =>
      AssessmentEstimate(
        operations: List.unmodifiable(
          (json['operations']! as List).map(
            (operation) => RepairOperation.fromJson(
              Map<String, Object?>.from(operation as Map),
            ),
          ),
        ),
        assumptions: List.unmodifiable(
          (json['assumptions']! as List).cast<String>(),
        ),
        reviewedByProfileId: json['reviewedByProfileId']! as String,
        reviewedAt: DateTime.parse(json['reviewedAt']! as String).toUtc(),
        sourceVersion: json['sourceVersion'] as String? ?? 'unknown',
        overrides: List.unmodifiable(
          (json['overrides'] as List? ?? const []).map(
            (value) => EstimateOverride.fromJson(
              Map<String, Object?>.from(value as Map),
            ),
          ),
        ),
        reviewedFindingSignatures: Map.unmodifiable(
          Map<String, String>.from(
            json['reviewedFindingSignatures'] as Map? ?? const {},
          ),
        ),
        missingPricingAcknowledgedAt:
            switch (json['missingPricingAcknowledgedAt']) {
              final String value => DateTime.parse(value).toUtc(),
              _ => null,
            },
        missingPricingAcknowledgedByProfileId:
            json['missingPricingAcknowledgedByProfileId'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is AssessmentEstimate &&
      _listEquals(other.operations, operations) &&
      _listEquals(other.assumptions, assumptions) &&
      other.reviewedByProfileId == reviewedByProfileId &&
      other.reviewedAt == reviewedAt &&
      other.sourceVersion == sourceVersion &&
      _listEquals(other.overrides, overrides) &&
      _mapEquals(other.reviewedFindingSignatures, reviewedFindingSignatures) &&
      other.missingPricingAcknowledgedAt == missingPricingAcknowledgedAt &&
      other.missingPricingAcknowledgedByProfileId ==
          missingPricingAcknowledgedByProfileId;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(operations),
    Object.hashAll(assumptions),
    reviewedByProfileId,
    reviewedAt,
    sourceVersion,
    Object.hashAll(overrides),
    Object.hashAll(
      reviewedFindingSignatures.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    missingPricingAcknowledgedAt,
    missingPricingAcknowledgedByProfileId,
  );
}

enum SeverityLevel { minor, moderate, severe, undetermined }

class SeverityReviewProvenance {
  const SeverityReviewProvenance({
    required this.reviewedLevel,
    required this.evidenceCaptureIds,
    required this.reviewerProfileId,
    required this.reviewedAt,
    required this.reason,
    this.uncertainty,
    this.followUpNeed,
    this.followUpOverrideReason,
    this.limitation,
  });

  factory SeverityReviewProvenance.fromAssessment(
    SeverityAssessment assessment,
  ) => SeverityReviewProvenance(
    reviewedLevel: assessment.reviewedLevel,
    evidenceCaptureIds: assessment.evidenceCaptureIds,
    reviewerProfileId: assessment.reviewerProfileId,
    reviewedAt: assessment.reviewedAt,
    reason: assessment.reason,
    uncertainty: assessment.uncertainty,
    followUpNeed: assessment.followUpNeed,
    followUpOverrideReason: assessment.followUpOverrideReason,
    limitation: assessment.limitation,
  );

  final SeverityLevel reviewedLevel;
  final List<String> evidenceCaptureIds;
  final String reviewerProfileId;
  final DateTime reviewedAt;
  final String reason;
  final String? uncertainty;
  final String? followUpNeed;
  final String? followUpOverrideReason;
  final String? limitation;

  Map<String, Object?> toJson() => {
    'reviewedLevel': reviewedLevel.name,
    'evidenceCaptureIds': evidenceCaptureIds,
    'reviewerProfileId': reviewerProfileId,
    'reviewedAt': reviewedAt.toUtc().toIso8601String(),
    'reason': reason,
    'uncertainty': uncertainty,
    'followUpNeed': followUpNeed,
    'followUpOverrideReason': followUpOverrideReason,
    'limitation': limitation,
  };

  factory SeverityReviewProvenance.fromJson(Map<String, Object?> json) =>
      SeverityReviewProvenance(
        reviewedLevel: SeverityLevel.values.byName(
          json['reviewedLevel']! as String,
        ),
        evidenceCaptureIds: List.unmodifiable(
          (json['evidenceCaptureIds']! as List).cast<String>(),
        ),
        reviewerProfileId: json['reviewerProfileId']! as String,
        reviewedAt: DateTime.parse(json['reviewedAt']! as String).toUtc(),
        reason: json['reason']! as String,
        uncertainty: json['uncertainty'] as String?,
        followUpNeed: json['followUpNeed'] as String?,
        followUpOverrideReason: json['followUpOverrideReason'] as String?,
        limitation: json['limitation'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is SeverityReviewProvenance &&
      other.reviewedLevel == reviewedLevel &&
      _listEquals(other.evidenceCaptureIds, evidenceCaptureIds) &&
      other.reviewerProfileId == reviewerProfileId &&
      other.reviewedAt == reviewedAt &&
      other.reason == reason &&
      other.uncertainty == uncertainty &&
      other.followUpNeed == followUpNeed &&
      other.followUpOverrideReason == followUpOverrideReason &&
      other.limitation == limitation;

  @override
  int get hashCode => Object.hash(
    reviewedLevel,
    Object.hashAll(evidenceCaptureIds),
    reviewerProfileId,
    reviewedAt,
    reason,
    uncertainty,
    followUpNeed,
    followUpOverrideReason,
    limitation,
  );
}

class SeverityAssessment {
  const SeverityAssessment({
    required this.findingId,
    required this.reviewedLevel,
    required this.evidenceCaptureIds,
    required this.reviewerProfileId,
    required this.reviewedAt,
    required this.reason,
    this.originalSuggestion,
    this.uncertainty,
    this.followUpNeed,
    this.followUpOverrideReason,
    this.limitation,
    this.automationSourceVersion,
    this.automationLimitation,
    this.suggestionEvidenceCaptureIds = const [],
    this.suggestionIsSynthetic = false,
    this.reviewHistory = const [],
    this.reviewedFindingSignature,
  });

  final String findingId;
  final SeverityLevel reviewedLevel;
  final SeverityLevel? originalSuggestion;
  final List<String> evidenceCaptureIds;
  final String reviewerProfileId;
  final DateTime reviewedAt;
  final String reason;
  final String? uncertainty;
  final String? followUpNeed;
  final String? followUpOverrideReason;
  final String? limitation;
  final String? automationSourceVersion;
  final String? automationLimitation;
  final List<String> suggestionEvidenceCaptureIds;
  final bool suggestionIsSynthetic;
  final List<SeverityReviewProvenance> reviewHistory;
  final String? reviewedFindingSignature;

  Map<String, Object?> toJson() => {
    'findingId': findingId,
    'reviewedLevel': reviewedLevel.name,
    'originalSuggestion': originalSuggestion?.name,
    'evidenceCaptureIds': evidenceCaptureIds,
    'reviewerProfileId': reviewerProfileId,
    'reviewedAt': reviewedAt.toUtc().toIso8601String(),
    'reason': reason,
    'uncertainty': uncertainty,
    'followUpNeed': followUpNeed,
    'followUpOverrideReason': followUpOverrideReason,
    'limitation': limitation,
    'automationSourceVersion': automationSourceVersion,
    'automationLimitation': automationLimitation,
    'suggestionEvidenceCaptureIds': suggestionEvidenceCaptureIds,
    'suggestionIsSynthetic': suggestionIsSynthetic,
    'reviewHistory': reviewHistory.map((value) => value.toJson()).toList(),
    'reviewedFindingSignature': reviewedFindingSignature,
  };

  factory SeverityAssessment.fromJson(Map<String, Object?> json) =>
      SeverityAssessment(
        findingId: json['findingId']! as String,
        reviewedLevel: SeverityLevel.values.byName(
          json['reviewedLevel']! as String,
        ),
        originalSuggestion: switch (json['originalSuggestion']) {
          final String value => SeverityLevel.values.byName(value),
          _ => null,
        },
        evidenceCaptureIds: List.unmodifiable(
          (json['evidenceCaptureIds']! as List).cast<String>(),
        ),
        reviewerProfileId: json['reviewerProfileId']! as String,
        reviewedAt: DateTime.parse(json['reviewedAt']! as String).toUtc(),
        reason: json['reason']! as String,
        uncertainty: json['uncertainty'] as String?,
        followUpNeed: json['followUpNeed'] as String?,
        followUpOverrideReason: json['followUpOverrideReason'] as String?,
        limitation: json['limitation'] as String?,
        automationSourceVersion: json['automationSourceVersion'] as String?,
        automationLimitation: json['automationLimitation'] as String?,
        suggestionEvidenceCaptureIds: List.unmodifiable(
          (json['suggestionEvidenceCaptureIds'] as List? ?? const [])
              .cast<String>(),
        ),
        suggestionIsSynthetic: json['suggestionIsSynthetic'] as bool? ?? false,
        reviewHistory: List.unmodifiable(
          (json['reviewHistory'] as List? ?? const []).map(
            (value) => SeverityReviewProvenance.fromJson(
              Map<String, Object?>.from(value as Map),
            ),
          ),
        ),
        reviewedFindingSignature: json['reviewedFindingSignature'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is SeverityAssessment &&
      other.findingId == findingId &&
      other.reviewedLevel == reviewedLevel &&
      other.originalSuggestion == originalSuggestion &&
      _listEquals(other.evidenceCaptureIds, evidenceCaptureIds) &&
      other.reviewerProfileId == reviewerProfileId &&
      other.reviewedAt == reviewedAt &&
      other.reason == reason &&
      other.uncertainty == uncertainty &&
      other.followUpNeed == followUpNeed &&
      other.followUpOverrideReason == followUpOverrideReason &&
      other.limitation == limitation &&
      other.automationSourceVersion == automationSourceVersion &&
      other.automationLimitation == automationLimitation &&
      _listEquals(
        other.suggestionEvidenceCaptureIds,
        suggestionEvidenceCaptureIds,
      ) &&
      other.suggestionIsSynthetic == suggestionIsSynthetic &&
      _listEquals(other.reviewHistory, reviewHistory) &&
      other.reviewedFindingSignature == reviewedFindingSignature;

  @override
  int get hashCode => Object.hash(
    findingId,
    reviewedLevel,
    originalSuggestion,
    Object.hashAll(evidenceCaptureIds),
    reviewerProfileId,
    reviewedAt,
    reason,
    uncertainty,
    followUpNeed,
    followUpOverrideReason,
    limitation,
    automationSourceVersion,
    automationLimitation,
    Object.hashAll(suggestionEvidenceCaptureIds),
    suggestionIsSynthetic,
    Object.hashAll(reviewHistory),
    reviewedFindingSignature,
  );
}

class PreliminaryDamageAssessmentRevision {
  PreliminaryDamageAssessmentRevision({
    required this.id,
    required this.revisionNumber,
    required this.completedAt,
    required this.completedByProfileId,
    required this.completedByName,
    required this.vehicleSnapshot,
    required List<Capture> captures,
    required List<DamageObservation> observations,
    required List<DamageFinding> confirmedFindings,
    required List<AssessmentCorrection> corrections,
    required this.estimate,
    required List<SeverityAssessment> severityAssessments,
    required List<String> limitations,
    required this.isNoVisibleDamageOutcome,
  }) : captures = List.unmodifiable(captures),
       observations = List.unmodifiable(observations),
       confirmedFindings = List.unmodifiable(confirmedFindings),
       corrections = List.unmodifiable(corrections),
       severityAssessments = List.unmodifiable(severityAssessments),
       limitations = List.unmodifiable(limitations);

  final String id;
  final int revisionNumber;
  final DateTime completedAt;
  final String completedByProfileId;
  final String completedByName;
  final Vehicle vehicleSnapshot;
  final List<Capture> captures;
  final List<DamageObservation> observations;
  final List<DamageFinding> confirmedFindings;
  final List<AssessmentCorrection> corrections;
  final AssessmentEstimate estimate;
  final List<SeverityAssessment> severityAssessments;
  final List<String> limitations;
  final bool isNoVisibleDamageOutcome;

  Map<String, Object?> toJson() => {
    'id': id,
    'revisionNumber': revisionNumber,
    'completedAt': completedAt.toUtc().toIso8601String(),
    'completedByProfileId': completedByProfileId,
    'completedByName': completedByName,
    'vehicleSnapshot': vehicleSnapshot.toJson(),
    'captures': captures.map((value) => value.toJson()).toList(),
    'observations': observations.map((value) => value.toJson()).toList(),
    'confirmedFindings': confirmedFindings
        .map((value) => value.toJson())
        .toList(),
    'corrections': corrections.map((value) => value.toJson()).toList(),
    'estimate': estimate.toJson(),
    'severityAssessments': severityAssessments
        .map((value) => value.toJson())
        .toList(),
    'limitations': limitations,
    'isNoVisibleDamageOutcome': isNoVisibleDamageOutcome,
  };

  factory PreliminaryDamageAssessmentRevision.fromJson(
    Map<String, Object?> json,
  ) => PreliminaryDamageAssessmentRevision(
    id: json['id']! as String,
    revisionNumber: json['revisionNumber']! as int,
    completedAt: DateTime.parse(json['completedAt']! as String).toUtc(),
    completedByProfileId: json['completedByProfileId']! as String,
    completedByName: json['completedByName']! as String,
    vehicleSnapshot: Vehicle.fromJson(
      Map<String, Object?>.from(json['vehicleSnapshot']! as Map),
    ),
    captures: (json['captures']! as List)
        .map(
          (value) => Capture.fromJson(Map<String, Object?>.from(value as Map)),
        )
        .toList(),
    observations: (json['observations']! as List)
        .map(
          (value) => DamageObservation.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
        )
        .toList(),
    confirmedFindings: (json['confirmedFindings']! as List)
        .map(
          (value) =>
              DamageFinding.fromJson(Map<String, Object?>.from(value as Map)),
        )
        .toList(),
    corrections: (json['corrections']! as List)
        .map(
          (value) => AssessmentCorrection.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
        )
        .toList(),
    estimate: AssessmentEstimate.fromJson(
      Map<String, Object?>.from(json['estimate']! as Map),
    ),
    severityAssessments: (json['severityAssessments']! as List)
        .map(
          (value) => SeverityAssessment.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
        )
        .toList(),
    limitations: (json['limitations']! as List).cast<String>(),
    isNoVisibleDamageOutcome: json['isNoVisibleDamageOutcome']! as bool,
  );

  @override
  bool operator ==(Object other) =>
      other is PreliminaryDamageAssessmentRevision &&
      other.id == id &&
      other.revisionNumber == revisionNumber &&
      other.completedAt == completedAt &&
      other.completedByProfileId == completedByProfileId &&
      other.completedByName == completedByName &&
      other.vehicleSnapshot == vehicleSnapshot &&
      _listEquals(other.captures, captures) &&
      _listEquals(other.observations, observations) &&
      _listEquals(other.confirmedFindings, confirmedFindings) &&
      _listEquals(other.corrections, corrections) &&
      other.estimate == estimate &&
      _listEquals(other.severityAssessments, severityAssessments) &&
      _listEquals(other.limitations, limitations) &&
      other.isNoVisibleDamageOutcome == isNoVisibleDamageOutcome;

  @override
  int get hashCode => Object.hash(
    id,
    revisionNumber,
    completedAt,
    completedByProfileId,
    completedByName,
    vehicleSnapshot,
    Object.hashAll(captures),
    Object.hashAll(observations),
    Object.hashAll(confirmedFindings),
    Object.hashAll(corrections),
    estimate,
    Object.hashAll(severityAssessments),
    Object.hashAll(limitations),
    isNoVisibleDamageOutcome,
  );
}

class AssessmentVoidRecord {
  const AssessmentVoidRecord({
    required this.voidedByProfileId,
    required this.voidedByName,
    required this.voidedAt,
    required this.reason,
  });

  final String voidedByProfileId;
  final String voidedByName;
  final DateTime voidedAt;
  final String reason;

  Map<String, Object?> toJson() => {
    'voidedByProfileId': voidedByProfileId,
    'voidedByName': voidedByName,
    'voidedAt': voidedAt.toUtc().toIso8601String(),
    'reason': reason,
  };

  factory AssessmentVoidRecord.fromJson(Map<String, Object?> json) =>
      AssessmentVoidRecord(
        voidedByProfileId: json['voidedByProfileId']! as String,
        voidedByName: json['voidedByName']! as String,
        voidedAt: DateTime.parse(json['voidedAt']! as String).toUtc(),
        reason: json['reason']! as String,
      );

  @override
  bool operator ==(Object other) =>
      other is AssessmentVoidRecord &&
      other.voidedByProfileId == voidedByProfileId &&
      other.voidedByName == voidedByName &&
      other.voidedAt == voidedAt &&
      other.reason == reason;

  @override
  int get hashCode =>
      Object.hash(voidedByProfileId, voidedByName, voidedAt, reason);
}

class IntakeAssessment {
  const IntakeAssessment._({
    required this.id,
    required this.vehicle,
    required this.appraiserProfile,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.captures,
    required this.observations,
    required this.findings,
    required this.corrections,
    required this.estimate,
    required this.severityAssessments,
    required this.completedRevisions,
    required this.limitations,
    required this.voidRecord,
  });

  factory IntakeAssessment.create({
    required String id,
    required Vehicle vehicle,
    required AppraiserProfile appraiserProfile,
    required DateTime createdAt,
  }) => IntakeAssessment._(
    id: id,
    vehicle: vehicle,
    appraiserProfile: appraiserProfile,
    createdAt: createdAt.toUtc(),
    updatedAt: createdAt.toUtc(),
    status: IntakeAssessmentStatus.draft,
    captures: const [],
    observations: const [],
    findings: const [],
    corrections: const [],
    estimate: null,
    severityAssessments: const [],
    completedRevisions: const [],
    limitations: const [],
    voidRecord: null,
  );

  final String id;
  final Vehicle vehicle;
  final AppraiserProfile appraiserProfile;
  final DateTime createdAt;
  final DateTime updatedAt;
  final IntakeAssessmentStatus status;
  final List<Capture> captures;
  final List<DamageObservation> observations;
  final List<DamageFinding> findings;
  final List<AssessmentCorrection> corrections;
  final AssessmentEstimate? estimate;
  final List<SeverityAssessment> severityAssessments;
  final List<PreliminaryDamageAssessmentRevision> completedRevisions;
  final List<String> limitations;
  final AssessmentVoidRecord? voidRecord;

  bool isEstimateReviewCurrentFor(DamageFinding finding) =>
      estimate?.reviewedFindingSignatures[finding.id] ==
      _findingReviewSignature(finding);

  bool isSeverityReviewCurrentFor(DamageFinding finding) {
    final severity = severityAssessments
        .where((value) => value.findingId == finding.id)
        .firstOrNull;
    return severity?.reviewedFindingSignature ==
        _findingReviewSignature(finding);
  }

  void validateForPersistence() {
    if (id.trim().isEmpty ||
        vehicle.id.trim().isEmpty ||
        appraiserProfile.id.trim().isEmpty ||
        appraiserProfile.displayName.trim().isEmpty) {
      throw const AssessmentInvariantViolation(
        'An Intake Assessment requires stable assessment, Vehicle, and Appraiser identities.',
      );
    }

    final captureIds = <String>{};
    for (final capture in captures) {
      if (capture.id.trim().isEmpty ||
          capture.localPath.trim().isEmpty ||
          capture.acceptedByProfileId.trim().isEmpty ||
          !captureIds.add(capture.id)) {
        throw const AssessmentInvariantViolation(
          'Captures require unique identities and local evidence paths.',
        );
      }
    }

    final observationIds = <String>{};
    for (final observation in observations) {
      if (observation.id.trim().isEmpty ||
          !observationIds.add(observation.id) ||
          !captureIds.contains(observation.captureId) ||
          observation.modelIdentifier.trim().isEmpty ||
          observation.runtimeIdentifier.trim().isEmpty) {
        throw const AssessmentInvariantViolation(
          'Damage Observations require unique identities, known Captures, and model provenance.',
        );
      }
    }

    final findingIds = <String>{};
    for (final finding in findings) {
      if (finding.id.trim().isEmpty ||
          !findingIds.add(finding.id) ||
          finding.supportingCaptureIds.isEmpty ||
          !captureIds.containsAll(finding.supportingCaptureIds) ||
          !observationIds.containsAll(finding.observationIds)) {
        throw const AssessmentInvariantViolation(
          'Damage Findings require unique identities and known evidence.',
        );
      }
      if (finding.reviewState == FindingReviewState.confirmed &&
          ((finding.vehicleComponent?.trim().isEmpty ?? true) ||
              (finding.damageType?.trim().isEmpty ?? true))) {
        throw const AssessmentInvariantViolation(
          'Confirmed Findings require a Vehicle Component and Damage Type.',
        );
      }
      if (finding.reviewState != FindingReviewState.proposed &&
          finding.additionalViewRequests.isNotEmpty &&
          (finding.additionalViewOverrideReason?.trim().isEmpty ?? true)) {
        throw const AssessmentInvariantViolation(
          'A concluded Finding with an unmet additional-view request requires an override reason.',
        );
      }
      if (finding.observationIds.isEmpty &&
          (finding.manualEvidenceNote?.trim().isEmpty ?? true)) {
        throw const AssessmentInvariantViolation(
          'Manual Findings require an Appraiser evidence note.',
        );
      }
    }

    final correctionIds = <String>{};
    for (final correction in corrections) {
      if (correction.id.trim().isEmpty ||
          !correctionIds.add(correction.id) ||
          correction.findingId.trim().isEmpty ||
          (correction.originals.isEmpty && correction.replacements.isEmpty) ||
          !_hasValidCorrectionShape(correction) ||
          correction.authorProfileId.trim().isEmpty ||
          correction.reason.trim().isEmpty) {
        throw const AssessmentInvariantViolation(
          'Assessment Corrections require unique identity and complete provenance.',
        );
      }
      for (final value in [
        ...correction.originals,
        ...correction.replacements,
      ]) {
        if (value.supportingCaptureIds.isEmpty ||
            !captureIds.containsAll(value.supportingCaptureIds) ||
            !observationIds.containsAll(value.observationIds)) {
          throw const AssessmentInvariantViolation(
            'Assessment Correction values require known evidence.',
          );
        }
      }
    }

    final currentEstimate = estimate;
    if (currentEstimate != null) {
      final confirmedFindingIds = findings
          .where(
            (finding) => finding.reviewState == FindingReviewState.confirmed,
          )
          .map((finding) => finding.id)
          .toSet();
      _validateEstimate(currentEstimate, confirmedFindingIds);
    }

    final severityFindingIds = <String>{};
    final findingById = {for (final finding in findings) finding.id: finding};
    for (final severity in severityAssessments) {
      if (!severityFindingIds.add(severity.findingId)) {
        throw const AssessmentInvariantViolation(
          'A Confirmed Finding can have only one current Severity Assessment.',
        );
      }
      _validateSeverity(severity, findingById, captureIds);
    }

    final revisionIds = <String>{};
    final revisionNumbers = <int>{};
    DateTime? previousCompletion;
    for (var index = 0; index < completedRevisions.length; index++) {
      final revision = completedRevisions[index];
      if (revision.id.trim().isEmpty ||
          revision.revisionNumber != index + 1 ||
          revision.completedByProfileId.trim().isEmpty ||
          revision.completedByName.trim().isEmpty ||
          !revisionIds.add(revision.id) ||
          !revisionNumbers.add(revision.revisionNumber) ||
          (previousCompletion != null &&
              !revision.completedAt.isAfter(previousCompletion))) {
        throw const AssessmentInvariantViolation(
          'Completed revisions require ordered unique identities, numbers, times, and authors.',
        );
      }
      _validateRevision(revision);
      previousCompletion = revision.completedAt;
    }
    if (status == IntakeAssessmentStatus.completed &&
        completedRevisions.isEmpty) {
      throw const AssessmentInvariantViolation(
        'A Completed Intake Assessment requires an immutable revision.',
      );
    }
    if ((status == IntakeAssessmentStatus.voided) != (voidRecord != null)) {
      throw const AssessmentInvariantViolation(
        'A Voided assessment requires exactly one void provenance record.',
      );
    }
    final currentVoidRecord = voidRecord;
    if (currentVoidRecord != null &&
        (currentVoidRecord.voidedByProfileId.trim().isEmpty ||
            currentVoidRecord.voidedByName.trim().isEmpty ||
            currentVoidRecord.reason.trim().isEmpty ||
            (completedRevisions.isNotEmpty &&
                currentVoidRecord.voidedAt.isBefore(
                  completedRevisions.last.completedAt,
                )))) {
      throw const AssessmentInvariantViolation(
        'Voiding requires an Appraiser, time, and reason.',
      );
    }
  }

  IntakeAssessment acceptCapture(Capture capture) {
    if (status != IntakeAssessmentStatus.draft) {
      throw const AssessmentInvariantViolation(
        'Captures can only be added to a Draft assessment.',
      );
    }
    if (captures.any((existing) => existing.id == capture.id)) {
      throw AssessmentInvariantViolation(
        'Capture ${capture.id} already belongs to this assessment.',
      );
    }
    return _copyWith(
      updatedAt: capture.acceptedAt.toUtc(),
      captures: [...captures, capture],
    );
  }

  IntakeAssessment recordObservation(DamageObservation observation) {
    _requireDraft(
      'Damage Observations can only be recorded in a Draft assessment.',
    );
    if (!captures.any((capture) => capture.id == observation.captureId)) {
      throw AssessmentInvariantViolation(
        'Observation ${observation.id} references an unknown Capture.',
      );
    }
    if (observations.any((existing) => existing.id == observation.id)) {
      throw AssessmentInvariantViolation(
        'Observation ${observation.id} already exists.',
      );
    }
    return _copyWith(observations: [...observations, observation]);
  }

  IntakeAssessment addFinding(DamageFinding finding) {
    _requireDraft('Damage Findings can only be added to a Draft assessment.');
    if (findings.any((existing) => existing.id == finding.id)) {
      throw AssessmentInvariantViolation(
        'Finding ${finding.id} already exists.',
      );
    }
    final captureIds = captures.map((capture) => capture.id).toSet();
    final observationIds = observations
        .map((observation) => observation.id)
        .toSet();
    if (finding.supportingCaptureIds.isEmpty ||
        !captureIds.containsAll(finding.supportingCaptureIds)) {
      throw const AssessmentInvariantViolation(
        'A Finding requires known supporting Captures.',
      );
    }
    if (!observationIds.containsAll(finding.observationIds)) {
      throw const AssessmentInvariantViolation(
        'A Finding cannot reference an unknown Damage Observation.',
      );
    }
    if (finding.observationIds.isEmpty &&
        (finding.manualEvidenceNote?.trim().isEmpty ?? true)) {
      throw const AssessmentInvariantViolation(
        'A manual Finding requires an Appraiser evidence note.',
      );
    }
    return _copyWith(findings: [...findings, finding]);
  }

  IntakeAssessment correctFinding({
    required DamageFinding replacement,
    required AssessmentCorrection correction,
  }) {
    final index = findings.indexWhere(
      (finding) => finding.id == correction.findingId,
    );
    if (index == -1 ||
        correction.original != findings[index] ||
        correction.replacement != replacement ||
        replacement.id != correction.findingId) {
      throw const AssessmentInvariantViolation(
        'A correction must preserve the current original Finding.',
      );
    }
    if (correction.authorProfileId.trim().isEmpty ||
        correction.reason.trim().isEmpty) {
      throw const AssessmentInvariantViolation(
        'A correction requires an author and reason.',
      );
    }
    return applyFindingCorrection(correction);
  }

  IntakeAssessment applyFindingCorrection(AssessmentCorrection correction) {
    _requireDraft(
      'Damage Findings can only be corrected in a Draft assessment.',
    );
    if (correction.authorProfileId.trim().isEmpty ||
        correction.reason.trim().isEmpty ||
        correction.id.trim().isEmpty ||
        (correction.originals.isEmpty && correction.replacements.isEmpty) ||
        !_hasValidCorrectionShape(correction)) {
      throw const AssessmentInvariantViolation(
        'A correction requires an operation, author, time, and reason.',
      );
    }
    final originalIds = correction.originals.map((value) => value.id).toSet();
    if (originalIds.length != correction.originals.length ||
        correction.originals.any(
          (original) => !findings.any((current) => current == original),
        )) {
      throw const AssessmentInvariantViolation(
        'A correction must preserve every current original Finding.',
      );
    }
    final remaining = findings
        .where((finding) => !originalIds.contains(finding.id))
        .toList();
    final replacementIds = correction.replacements
        .map((value) => value.id)
        .toSet();
    if (replacementIds.length != correction.replacements.length ||
        replacementIds.any(
          (id) => remaining.any((finding) => finding.id == id),
        )) {
      throw const AssessmentInvariantViolation(
        'Correction replacement Findings require unique identities.',
      );
    }
    for (final replacement in correction.replacements) {
      final captureIds = captures.map((capture) => capture.id).toSet();
      final observationIds = observations.map((item) => item.id).toSet();
      if (replacement.supportingCaptureIds.isEmpty ||
          !captureIds.containsAll(replacement.supportingCaptureIds) ||
          !observationIds.containsAll(replacement.observationIds)) {
        throw const AssessmentInvariantViolation(
          'Correction replacement Findings require known evidence.',
        );
      }
      if (replacement.observationIds.isEmpty &&
          (replacement.manualEvidenceNote?.trim().isEmpty ?? true)) {
        throw const AssessmentInvariantViolation(
          'A manual Finding requires an Appraiser evidence note.',
        );
      }
    }
    final insertionIndex = correction.originals.isEmpty
        ? remaining.length
        : findings.indexWhere((finding) => originalIds.contains(finding.id));
    remaining.insertAll(insertionIndex, correction.replacements);
    return _copyWith(
      updatedAt: correction.occurredAt.toUtc(),
      findings: remaining,
      corrections: [...corrections, correction],
    );
  }

  bool _hasValidCorrectionShape(AssessmentCorrection correction) {
    final originals = correction.originals;
    final replacements = correction.replacements;
    return switch (correction.kind) {
      AssessmentCorrectionKind.add =>
        originals.isEmpty &&
            replacements.length == 1 &&
            correction.findingId == replacements.single.id,
      AssessmentCorrectionKind.merge =>
        originals.length >= 2 &&
            replacements.length == 1 &&
            correction.findingId == replacements.single.id,
      AssessmentCorrectionKind.split =>
        originals.length == 1 &&
            replacements.length >= 2 &&
            correction.findingId == originals.single.id,
      AssessmentCorrectionKind.confirm ||
      AssessmentCorrectionKind.dismiss ||
      AssessmentCorrectionKind.edit ||
      AssessmentCorrectionKind.uncertainty ||
      AssessmentCorrectionKind.undetermined =>
        originals.length == 1 &&
            replacements.length == 1 &&
            correction.findingId == originals.single.id &&
            correction.findingId == replacements.single.id,
    };
  }

  IntakeAssessment recordEstimate(AssessmentEstimate estimate) {
    if (status != IntakeAssessmentStatus.draft) {
      throw const AssessmentInvariantViolation(
        'An Assessment Estimate can only be revised while the assessment is Draft.',
      );
    }
    final confirmedFindingIds = findings
        .where((finding) => finding.reviewState == FindingReviewState.confirmed)
        .map((finding) => finding.id)
        .toSet();
    final confirmedFindingById = {
      for (final finding in findings)
        if (finding.reviewState == FindingReviewState.confirmed)
          finding.id: finding,
    };
    final reviewedEstimate = AssessmentEstimate(
      operations: estimate.operations,
      assumptions: estimate.assumptions,
      reviewedByProfileId: estimate.reviewedByProfileId,
      reviewedAt: estimate.reviewedAt,
      sourceVersion: estimate.sourceVersion,
      overrides: estimate.overrides,
      reviewedFindingSignatures: {
        for (final entry in confirmedFindingById.entries)
          entry.key: _findingReviewSignature(entry.value),
      },
      missingPricingAcknowledgedAt: estimate.missingPricingAcknowledgedAt,
      missingPricingAcknowledgedByProfileId:
          estimate.missingPricingAcknowledgedByProfileId,
    );
    _validateEstimate(reviewedEstimate, confirmedFindingIds);
    return _copyWith(
      updatedAt: reviewedEstimate.reviewedAt.toUtc(),
      estimate: reviewedEstimate,
      replaceEstimate: true,
    );
  }

  void _requireDraft(String message) {
    if (status != IntakeAssessmentStatus.draft) {
      throw AssessmentInvariantViolation(message);
    }
  }

  void _validateEstimate(AssessmentEstimate estimate, Set<String> findingIds) {
    if (estimate.reviewedByProfileId.trim().isEmpty ||
        estimate.sourceVersion.trim().isEmpty ||
        estimate.assumptions.any((assumption) => assumption.trim().isEmpty)) {
      throw const AssessmentInvariantViolation(
        'An Assessment Estimate requires complete review provenance.',
      );
    }
    final operationIds = <String>{};
    final pricedCurrencies = <String>{};
    for (final operation in estimate.operations) {
      if (operation.id.trim().isEmpty ||
          operation.description.trim().isEmpty ||
          !operationIds.add(operation.id)) {
        throw const AssessmentInvariantViolation(
          'Repair Operations require unique identities and descriptions.',
        );
      }
      if (operation.findingIds.isEmpty ||
          operation.findingIds.toSet().length != operation.findingIds.length ||
          !findingIds.containsAll(operation.findingIds)) {
        throw const AssessmentInvariantViolation(
          'A Repair Operation requires unique, Confirmed Damage Findings.',
        );
      }
      final hasAnyPrice =
          operation.minimumCents != null ||
          operation.maximumCents != null ||
          operation.currency != null ||
          operation.pricingSourceVersion != null;
      if (hasAnyPrice && !operation.hasPricing) {
        throw const AssessmentInvariantViolation(
          'Pricing must be complete or explicitly unavailable.',
        );
      }
      if (operation.hasPricing &&
          (operation.minimumCents! < 0 ||
              operation.maximumCents! < 0 ||
              operation.minimumCents! > operation.maximumCents! ||
              operation.currency!.trim().isEmpty ||
              operation.pricingSourceVersion!.trim().isEmpty)) {
        throw const AssessmentInvariantViolation(
          'A Repair Operation requires a valid supported price range.',
        );
      }
      if (operation.hasPricing) pricedCurrencies.add(operation.currency!);
    }
    if (pricedCurrencies.length > 1) {
      throw const AssessmentInvariantViolation(
        'A Draft Estimate cannot combine different pricing currencies.',
      );
    }
    final overrideIds = <String>{};
    for (final override in estimate.overrides) {
      if (override.id.trim().isEmpty ||
          !overrideIds.add(override.id) ||
          override.operationId.trim().isEmpty ||
          override.authorProfileId.trim().isEmpty ||
          override.reason.trim().isEmpty ||
          override.original.id != override.operationId ||
          override.replacement.id != override.operationId ||
          !_listEquals(
            override.original.findingIds,
            override.replacement.findingIds,
          ) ||
          override.original.findingIds.isEmpty ||
          override.replacement.findingIds.isEmpty ||
          !findingIds.containsAll(override.original.findingIds) ||
          !findingIds.containsAll(override.replacement.findingIds)) {
        throw const AssessmentInvariantViolation(
          'Estimate Overrides require complete original and replacement provenance.',
        );
      }
      for (final value in [override.original, override.replacement]) {
        final hasAnyPrice =
            value.minimumCents != null ||
            value.maximumCents != null ||
            value.currency != null ||
            value.pricingSourceVersion != null;
        if (value.description.trim().isEmpty ||
            (hasAnyPrice && !value.hasPricing) ||
            (value.hasPricing &&
                (value.minimumCents! < 0 ||
                    value.maximumCents! < 0 ||
                    value.minimumCents! > value.maximumCents! ||
                    value.currency!.trim().isEmpty ||
                    value.pricingSourceVersion!.trim().isEmpty))) {
          throw const AssessmentInvariantViolation(
            'Estimate Override values require complete operation and pricing provenance.',
          );
        }
      }
    }
    final hasAcknowledgmentTime = estimate.missingPricingAcknowledgedAt != null;
    final acknowledgmentAuthor = estimate.missingPricingAcknowledgedByProfileId;
    if (hasAcknowledgmentTime != (acknowledgmentAuthor != null) ||
        (acknowledgmentAuthor?.trim().isEmpty ?? false) ||
        (hasAcknowledgmentTime && !estimate.isPartial)) {
      throw const AssessmentInvariantViolation(
        'A Partial Estimate acknowledgment requires an author, time, and missing pricing.',
      );
    }
  }

  IntakeAssessment recordSeverity(SeverityAssessment severity) {
    if (status != IntakeAssessmentStatus.draft) {
      throw const AssessmentInvariantViolation(
        'A Severity Assessment can only be revised while the assessment is Draft.',
      );
    }
    final findingById = {for (final finding in findings) finding.id: finding};
    final captureIds = captures.map((capture) => capture.id).toSet();
    final finding = findingById[severity.findingId];
    final reviewedSeverity = SeverityAssessment(
      findingId: severity.findingId,
      reviewedLevel: severity.reviewedLevel,
      evidenceCaptureIds: severity.evidenceCaptureIds,
      reviewerProfileId: severity.reviewerProfileId,
      reviewedAt: severity.reviewedAt,
      reason: severity.reason,
      originalSuggestion: severity.originalSuggestion,
      uncertainty: severity.uncertainty,
      followUpNeed: severity.followUpNeed,
      followUpOverrideReason: severity.followUpOverrideReason,
      limitation: severity.limitation,
      automationSourceVersion: severity.automationSourceVersion,
      automationLimitation: severity.automationLimitation,
      suggestionEvidenceCaptureIds: severity.suggestionEvidenceCaptureIds,
      suggestionIsSynthetic: severity.suggestionIsSynthetic,
      reviewHistory: severity.reviewHistory,
      reviewedFindingSignature: finding == null
          ? null
          : _findingReviewSignature(finding),
    );
    _validateSeverity(reviewedSeverity, findingById, captureIds);
    final revised =
        severityAssessments
            .where((existing) => existing.findingId != severity.findingId)
            .toList()
          ..add(reviewedSeverity);
    return _copyWith(
      updatedAt: reviewedSeverity.reviewedAt.toUtc(),
      severityAssessments: revised,
    );
  }

  IntakeAssessment recordLimitations({
    required List<String> limitations,
    required DateTime reviewedAt,
  }) {
    _requireDraft(
      'Assessment limitations can only be revised while the assessment is Draft.',
    );
    if (limitations.any((value) => value.trim().isEmpty)) {
      throw const AssessmentInvariantViolation(
        'Assessment limitations cannot be blank.',
      );
    }
    return _copyWith(
      updatedAt: reviewedAt.toUtc(),
      limitations: List.unmodifiable(limitations.map((value) => value.trim())),
    );
  }

  IntakeAssessment complete({
    required String revisionId,
    required DateTime completedAt,
    required bool noVisibleDamageConfirmed,
  }) {
    if (status != IntakeAssessmentStatus.draft) {
      throw const AssessmentInvariantViolation(
        'Only a Draft Intake Assessment can be completed.',
      );
    }
    final confirmedFindings = findings
        .where((finding) => finding.reviewState == FindingReviewState.confirmed)
        .toList();
    _validateCompletionGate(
      confirmedFindings: confirmedFindings,
      noVisibleDamageConfirmed: noVisibleDamageConfirmed,
    );
    if (confirmedFindings.isEmpty != noVisibleDamageConfirmed) {
      throw const AssessmentInvariantViolation(
        'No Visible Damage must be explicitly confirmed only when there are no Confirmed Findings.',
      );
    }
    final currentEstimate = estimate;
    if (currentEstimate == null) {
      throw const AssessmentInvariantViolation(
        'Review the Assessment Estimate before completing.',
      );
    }
    final completedTime = completedAt.toUtc();
    final revision = PreliminaryDamageAssessmentRevision(
      id: revisionId,
      revisionNumber: completedRevisions.length + 1,
      completedAt: completedTime,
      completedByProfileId: appraiserProfile.id,
      completedByName: appraiserProfile.displayName,
      vehicleSnapshot: Vehicle.fromJson(vehicle.toJson()),
      captures: captures
          .map((value) => Capture.fromJson(value.toJson()))
          .toList(),
      observations: observations
          .map((value) => DamageObservation.fromJson(value.toJson()))
          .toList(),
      confirmedFindings: confirmedFindings
          .map((value) => DamageFinding.fromJson(value.toJson()))
          .toList(),
      corrections: corrections
          .map((value) => AssessmentCorrection.fromJson(value.toJson()))
          .toList(),
      estimate: AssessmentEstimate.fromJson(currentEstimate.toJson()),
      severityAssessments: severityAssessments
          .map((value) => SeverityAssessment.fromJson(value.toJson()))
          .toList(),
      limitations: List.of(limitations),
      isNoVisibleDamageOutcome: noVisibleDamageConfirmed,
    );
    final completed = _copyWith(
      updatedAt: completedTime,
      status: IntakeAssessmentStatus.completed,
      completedRevisions: [...completedRevisions, revision],
    );
    completed.validateForPersistence();
    return completed;
  }

  void _validateCompletionGate({
    required List<DamageFinding> confirmedFindings,
    required bool noVisibleDamageConfirmed,
  }) {
    if (captures.isEmpty) {
      throw const AssessmentInvariantViolation(
        'Accept at least one Capture before completing.',
      );
    }
    if (findings.any(
      (finding) =>
          finding.reviewState == FindingReviewState.proposed &&
          finding.reviewOutcome == null,
    )) {
      throw const AssessmentInvariantViolation(
        'Review every Proposed Finding before completing.',
      );
    }
    if (findings.any(
      (finding) =>
          finding.reviewOutcome == FindingReviewOutcome.undetermined &&
          finding.additionalViewRequests.isNotEmpty &&
          (finding.additionalViewOverrideReason?.trim().isEmpty ?? true),
    )) {
      throw const AssessmentInvariantViolation(
        'Explain every overridden Finding evidence request before completing.',
      );
    }
    if (confirmedFindings.isEmpty != noVisibleDamageConfirmed) {
      throw const AssessmentInvariantViolation(
        'No Visible Damage must be explicitly confirmed only when there are no Confirmed Findings.',
      );
    }
    final currentEstimate = estimate;
    if (currentEstimate == null) {
      throw const AssessmentInvariantViolation(
        'Review the Assessment Estimate before completing.',
      );
    }
    if (currentEstimate.isPartial &&
        currentEstimate.missingPricingAcknowledgedAt == null) {
      throw const AssessmentInvariantViolation(
        'Acknowledge missing pricing before completing a Partial Estimate.',
      );
    }
    final estimatedFindingIds = currentEstimate.operations
        .expand((operation) => operation.findingIds)
        .toSet();
    final confirmedFindingIds = confirmedFindings
        .map((finding) => finding.id)
        .toSet();
    if (!estimatedFindingIds.containsAll(confirmedFindingIds)) {
      throw const AssessmentInvariantViolation(
        'Every Confirmed Finding must be represented in the Assessment Estimate.',
      );
    }
    if (confirmedFindings.any(
      (finding) => !isEstimateReviewCurrentFor(finding),
    )) {
      throw const AssessmentInvariantViolation(
        'Review the Assessment Estimate after changing a Confirmed Finding.',
      );
    }
    final severityByFinding = {
      for (final severity in severityAssessments) severity.findingId: severity,
    };
    if (!severityByFinding.keys.toSet().containsAll(confirmedFindingIds)) {
      throw const AssessmentInvariantViolation(
        'Review Severity for every Confirmed Finding before completing.',
      );
    }
    if (confirmedFindings.any(
      (finding) => !isSeverityReviewCurrentFor(finding),
    )) {
      throw const AssessmentInvariantViolation(
        'Review Severity after changing a Confirmed Finding.',
      );
    }
    if (severityAssessments.any(
      (severity) =>
          severity.followUpNeed != null &&
          (severity.followUpOverrideReason?.trim().isEmpty ?? true),
    )) {
      throw const AssessmentInvariantViolation(
        'Explain every overridden Severity evidence request before completing.',
      );
    }
  }

  void _validateRevision(PreliminaryDamageAssessmentRevision revision) {
    if (revision.vehicleSnapshot.id.trim().isEmpty ||
        revision.captures.isEmpty ||
        revision.limitations.any((value) => value.trim().isEmpty)) {
      throw const AssessmentInvariantViolation(
        'A completed revision requires a Vehicle snapshot, accepted evidence, and valid limitations.',
      );
    }
    final revisionCaptureIds = <String>{};
    for (final capture in revision.captures) {
      if (capture.id.trim().isEmpty ||
          capture.localPath.trim().isEmpty ||
          capture.acceptedByProfileId.trim().isEmpty ||
          !revisionCaptureIds.add(capture.id)) {
        throw const AssessmentInvariantViolation(
          'A completed revision requires complete unique Capture provenance.',
        );
      }
    }
    final revisionObservationIds = <String>{};
    for (final observation in revision.observations) {
      if (observation.id.trim().isEmpty ||
          !revisionObservationIds.add(observation.id) ||
          !revisionCaptureIds.contains(observation.captureId) ||
          observation.modelIdentifier.trim().isEmpty ||
          observation.runtimeIdentifier.trim().isEmpty) {
        throw const AssessmentInvariantViolation(
          'A completed revision requires complete unique observation provenance.',
        );
      }
    }
    final revisionFindingIds = <String>{};
    final revisionFindingById = <String, DamageFinding>{};
    for (final finding in revision.confirmedFindings) {
      if (finding.reviewState != FindingReviewState.confirmed ||
          finding.id.trim().isEmpty ||
          !revisionFindingIds.add(finding.id) ||
          finding.supportingCaptureIds.isEmpty ||
          !revisionCaptureIds.containsAll(finding.supportingCaptureIds) ||
          !revisionObservationIds.containsAll(finding.observationIds) ||
          (finding.vehicleComponent?.trim().isEmpty ?? true) ||
          (finding.damageType?.trim().isEmpty ?? true) ||
          (finding.observationIds.isEmpty &&
              (finding.manualEvidenceNote?.trim().isEmpty ?? true))) {
        throw const AssessmentInvariantViolation(
          'A completed revision requires complete Confirmed Finding evidence.',
        );
      }
      revisionFindingById[finding.id] = finding;
    }
    final revisionCorrectionIds = <String>{};
    for (final correction in revision.corrections) {
      if (correction.id.trim().isEmpty ||
          !revisionCorrectionIds.add(correction.id) ||
          correction.findingId.trim().isEmpty ||
          correction.authorProfileId.trim().isEmpty ||
          correction.reason.trim().isEmpty ||
          (correction.originals.isEmpty && correction.replacements.isEmpty) ||
          !_hasValidCorrectionShape(correction)) {
        throw const AssessmentInvariantViolation(
          'A completed revision requires complete unique correction provenance.',
        );
      }
      for (final value in [
        ...correction.originals,
        ...correction.replacements,
      ]) {
        if (value.supportingCaptureIds.isEmpty ||
            !revisionCaptureIds.containsAll(value.supportingCaptureIds) ||
            !revisionObservationIds.containsAll(value.observationIds)) {
          throw const AssessmentInvariantViolation(
            'A completed revision correction requires known frozen evidence.',
          );
        }
      }
    }
    if (revision.confirmedFindings.isEmpty !=
        revision.isNoVisibleDamageOutcome) {
      throw const AssessmentInvariantViolation(
        'A completed revision must preserve its No Visible Damage outcome.',
      );
    }
    _validateEstimate(revision.estimate, revisionFindingIds);
    final estimatedFindingIds = revision.estimate.operations
        .expand((operation) => operation.findingIds)
        .toSet();
    if (!estimatedFindingIds.containsAll(revisionFindingIds) ||
        (revision.estimate.isPartial &&
            revision.estimate.missingPricingAcknowledgedAt == null)) {
      throw const AssessmentInvariantViolation(
        'A completed revision requires reviewed estimate coverage and acknowledgments.',
      );
    }
    if (revision.confirmedFindings.any(
      (finding) =>
          revision.estimate.reviewedFindingSignatures[finding.id] !=
          _findingReviewSignature(finding),
    )) {
      throw const AssessmentInvariantViolation(
        'A completed revision requires an Estimate reviewed against its frozen Findings.',
      );
    }
    final severityFindingIds = <String>{};
    for (final severity in revision.severityAssessments) {
      if (!severityFindingIds.add(severity.findingId)) {
        throw const AssessmentInvariantViolation(
          'A completed revision has duplicate Severity Assessments.',
        );
      }
      _validateSeverity(severity, revisionFindingById, revisionCaptureIds);
      if (severity.reviewedFindingSignature !=
          _findingReviewSignature(revisionFindingById[severity.findingId]!)) {
        throw const AssessmentInvariantViolation(
          'A completed revision requires Severity reviewed against its frozen Finding.',
        );
      }
      if (severity.followUpNeed != null &&
          (severity.followUpOverrideReason?.trim().isEmpty ?? true)) {
        throw const AssessmentInvariantViolation(
          'A completed revision must preserve every Severity evidence override.',
        );
      }
    }
    if (!severityFindingIds.containsAll(revisionFindingIds)) {
      throw const AssessmentInvariantViolation(
        'A completed revision requires Severity for every Confirmed Finding.',
      );
    }
  }

  IntakeAssessment reopen({required DateTime reopenedAt}) {
    if (status != IntakeAssessmentStatus.completed) {
      throw const AssessmentInvariantViolation(
        'Only a Completed Intake Assessment can be reopened.',
      );
    }
    return _copyWith(
      updatedAt: reopenedAt.toUtc(),
      status: IntakeAssessmentStatus.draft,
    );
  }

  IntakeAssessment voidAssessment({
    required DateTime voidedAt,
    required String reason,
  }) {
    if (status == IntakeAssessmentStatus.voided) {
      throw const AssessmentInvariantViolation(
        'A Voided Intake Assessment cannot be voided again.',
      );
    }
    if (reason.trim().isEmpty) {
      throw const AssessmentInvariantViolation('Voiding requires a reason.');
    }
    final voidedTime = voidedAt.toUtc();
    return _copyWith(
      updatedAt: voidedTime,
      status: IntakeAssessmentStatus.voided,
      voidRecord: AssessmentVoidRecord(
        voidedByProfileId: appraiserProfile.id,
        voidedByName: appraiserProfile.displayName,
        voidedAt: voidedTime,
        reason: reason.trim(),
      ),
      replaceVoidRecord: true,
    );
  }

  void _validateSeverity(
    SeverityAssessment severity,
    Map<String, DamageFinding> findingById,
    Set<String> captureIds,
  ) {
    final finding = findingById[severity.findingId];
    if (finding == null ||
        finding.reviewState != FindingReviewState.confirmed) {
      throw const AssessmentInvariantViolation(
        'A Severity Assessment requires a Confirmed Damage Finding.',
      );
    }
    if (severity.evidenceCaptureIds.isEmpty ||
        severity.evidenceCaptureIds.toSet().length !=
            severity.evidenceCaptureIds.length ||
        !captureIds.containsAll(severity.evidenceCaptureIds) ||
        !finding.supportingCaptureIds.toSet().containsAll(
          severity.evidenceCaptureIds,
        )) {
      throw const AssessmentInvariantViolation(
        'A Severity Assessment requires evidence linked to its Confirmed Finding.',
      );
    }
    if (severity.reviewerProfileId.trim().isEmpty ||
        severity.reason.trim().isEmpty ||
        (severity.uncertainty?.trim().isEmpty ?? false) ||
        (severity.followUpNeed?.trim().isEmpty ?? false) ||
        (severity.followUpOverrideReason?.trim().isEmpty ?? false) ||
        (severity.limitation?.trim().isEmpty ?? false) ||
        (severity.automationSourceVersion?.trim().isEmpty ?? false) ||
        (severity.automationLimitation?.trim().isEmpty ?? false)) {
      throw const AssessmentInvariantViolation(
        'A Severity Assessment requires a reviewer and reason.',
      );
    }
    if (severity.reviewedLevel == SeverityLevel.undetermined &&
        ((severity.uncertainty?.trim().isEmpty ?? true) ||
            (severity.followUpNeed?.trim().isEmpty ?? true))) {
      throw const AssessmentInvariantViolation(
        'Undetermined Severity requires stated uncertainty and a specific additional-view request.',
      );
    }
    if (severity.reviewedLevel != SeverityLevel.undetermined &&
        (severity.followUpNeed?.trim().isNotEmpty ?? false) &&
        (severity.followUpOverrideReason?.trim().isEmpty ?? true)) {
      throw const AssessmentInvariantViolation(
        'A determined Severity Assessment with an unmet additional-view request requires an override reason.',
      );
    }
    if (severity.reviewedLevel != SeverityLevel.undetermined &&
        finding.hasConflictingViews &&
        (severity.uncertainty?.trim().isEmpty ?? true)) {
      throw const AssessmentInvariantViolation(
        'A determined Severity Assessment must preserve conflicting-view uncertainty.',
      );
    }
    if (severity.followUpNeed == null &&
        severity.followUpOverrideReason != null) {
      throw const AssessmentInvariantViolation(
        'An additional-view override requires an additional-view request.',
      );
    }
    if (severity.originalSuggestion == null &&
        (severity.suggestionEvidenceCaptureIds.isNotEmpty ||
            severity.suggestionIsSynthetic)) {
      throw const AssessmentInvariantViolation(
        'Suggestion provenance requires an original severity suggestion.',
      );
    }
    if (severity.originalSuggestion != null &&
        (severity.originalSuggestion == SeverityLevel.undetermined ||
            (severity.automationSourceVersion?.trim().isEmpty ?? true) ||
            severity.suggestionEvidenceCaptureIds.isEmpty ||
            severity.suggestionEvidenceCaptureIds.toSet().length !=
                severity.suggestionEvidenceCaptureIds.length ||
            !finding.supportingCaptureIds.toSet().containsAll(
              severity.suggestionEvidenceCaptureIds,
            ))) {
      throw const AssessmentInvariantViolation(
        'An original severity suggestion requires complete source and evidence provenance.',
      );
    }
    DateTime? previousReviewAt;
    for (final review in severity.reviewHistory) {
      if (review.reviewerProfileId.trim().isEmpty ||
          review.reason.trim().isEmpty ||
          review.evidenceCaptureIds.isEmpty ||
          review.evidenceCaptureIds.toSet().length !=
              review.evidenceCaptureIds.length ||
          !finding.supportingCaptureIds.toSet().containsAll(
            review.evidenceCaptureIds,
          ) ||
          (review.uncertainty?.trim().isEmpty ?? false) ||
          (review.followUpNeed?.trim().isEmpty ?? false) ||
          (review.followUpOverrideReason?.trim().isEmpty ?? false) ||
          (review.limitation?.trim().isEmpty ?? false) ||
          (previousReviewAt != null &&
              !review.reviewedAt.isAfter(previousReviewAt)) ||
          !review.reviewedAt.isBefore(severity.reviewedAt)) {
        throw const AssessmentInvariantViolation(
          'Severity review history requires ordered, finding-linked provenance.',
        );
      }
      if ((review.reviewedLevel == SeverityLevel.undetermined &&
              (review.uncertainty == null || review.followUpNeed == null)) ||
          (review.reviewedLevel != SeverityLevel.undetermined &&
              review.followUpNeed != null &&
              review.followUpOverrideReason == null) ||
          (review.reviewedLevel != SeverityLevel.undetermined &&
              finding.hasConflictingViews &&
              review.uncertainty == null) ||
          (review.followUpNeed == null &&
              review.followUpOverrideReason != null)) {
        throw const AssessmentInvariantViolation(
          'Severity review history must preserve uncertainty and follow-up decisions.',
        );
      }
      previousReviewAt = review.reviewedAt;
    }
  }

  IntakeAssessment _copyWith({
    DateTime? updatedAt,
    IntakeAssessmentStatus? status,
    List<Capture>? captures,
    List<DamageObservation>? observations,
    List<DamageFinding>? findings,
    List<AssessmentCorrection>? corrections,
    AssessmentEstimate? estimate,
    bool replaceEstimate = false,
    List<SeverityAssessment>? severityAssessments,
    List<PreliminaryDamageAssessmentRevision>? completedRevisions,
    List<String>? limitations,
    AssessmentVoidRecord? voidRecord,
    bool replaceVoidRecord = false,
  }) => IntakeAssessment._(
    id: id,
    vehicle: vehicle,
    appraiserProfile: appraiserProfile,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    status: status ?? this.status,
    captures: List.unmodifiable(captures ?? this.captures),
    observations: List.unmodifiable(observations ?? this.observations),
    findings: List.unmodifiable(findings ?? this.findings),
    corrections: List.unmodifiable(corrections ?? this.corrections),
    estimate: replaceEstimate ? estimate : this.estimate,
    severityAssessments: List.unmodifiable(
      severityAssessments ?? this.severityAssessments,
    ),
    completedRevisions: List.unmodifiable(
      completedRevisions ?? this.completedRevisions,
    ),
    limitations: List.unmodifiable(limitations ?? this.limitations),
    voidRecord: replaceVoidRecord ? voidRecord : this.voidRecord,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'vehicle': vehicle.toJson(),
    'appraiserProfile': appraiserProfile.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'status': status.name,
    'captures': captures.map((capture) => capture.toJson()).toList(),
    'observations': observations
        .map((observation) => observation.toJson())
        .toList(),
    'findings': findings.map((finding) => finding.toJson()).toList(),
    'corrections': corrections
        .map((correction) => correction.toJson())
        .toList(),
    'estimate': estimate?.toJson(),
    'severityAssessments': severityAssessments
        .map((severity) => severity.toJson())
        .toList(),
    'completedRevisions': completedRevisions
        .map((revision) => revision.toJson())
        .toList(),
    'limitations': limitations,
    'voidRecord': voidRecord?.toJson(),
  };

  factory IntakeAssessment.fromJson(Map<String, Object?> json) =>
      IntakeAssessment._(
        id: json['id']! as String,
        vehicle: Vehicle.fromJson(
          Map<String, Object?>.from(json['vehicle']! as Map),
        ),
        appraiserProfile: AppraiserProfile.fromJson(
          Map<String, Object?>.from(json['appraiserProfile']! as Map),
        ),
        createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
        updatedAt: DateTime.parse(json['updatedAt']! as String).toUtc(),
        status: IntakeAssessmentStatus.values.byName(json['status']! as String),
        captures: List.unmodifiable(
          (json['captures'] as List? ?? const []).map(
            (capture) =>
                Capture.fromJson(Map<String, Object?>.from(capture as Map)),
          ),
        ),
        observations: List.unmodifiable(
          (json['observations'] as List? ?? const []).map(
            (observation) => DamageObservation.fromJson(
              Map<String, Object?>.from(observation as Map),
            ),
          ),
        ),
        findings: List.unmodifiable(
          (json['findings'] as List? ?? const []).map(
            (finding) => DamageFinding.fromJson(
              Map<String, Object?>.from(finding as Map),
            ),
          ),
        ),
        corrections: List.unmodifiable(
          (json['corrections'] as List? ?? const []).map(
            (correction) => AssessmentCorrection.fromJson(
              Map<String, Object?>.from(correction as Map),
            ),
          ),
        ),
        estimate: switch (json['estimate']) {
          final Map value => AssessmentEstimate.fromJson(
            Map<String, Object?>.from(value),
          ),
          _ => null,
        },
        severityAssessments: List.unmodifiable(
          (json['severityAssessments'] as List? ?? const []).map(
            (severity) => SeverityAssessment.fromJson(
              Map<String, Object?>.from(severity as Map),
            ),
          ),
        ),
        completedRevisions: List.unmodifiable(
          (json['completedRevisions'] as List? ?? const []).map(
            (revision) => PreliminaryDamageAssessmentRevision.fromJson(
              Map<String, Object?>.from(revision as Map),
            ),
          ),
        ),
        limitations: List.unmodifiable(
          (json['limitations'] as List? ?? const []).cast<String>(),
        ),
        voidRecord: switch (json['voidRecord']) {
          final Map value => AssessmentVoidRecord.fromJson(
            Map<String, Object?>.from(value),
          ),
          _ => null,
        },
      );

  @override
  bool operator ==(Object other) =>
      other is IntakeAssessment &&
      other.id == id &&
      other.vehicle == vehicle &&
      other.appraiserProfile == appraiserProfile &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.status == status &&
      _listEquals(other.captures, captures) &&
      _listEquals(other.observations, observations) &&
      _listEquals(other.findings, findings) &&
      _listEquals(other.corrections, corrections) &&
      other.estimate == estimate &&
      _listEquals(other.severityAssessments, severityAssessments) &&
      _listEquals(other.completedRevisions, completedRevisions) &&
      _listEquals(other.limitations, limitations) &&
      other.voidRecord == voidRecord;

  @override
  int get hashCode => Object.hash(
    id,
    vehicle,
    appraiserProfile,
    createdAt,
    updatedAt,
    status,
    Object.hashAll(captures),
    Object.hashAll(observations),
    Object.hashAll(findings),
    Object.hashAll(corrections),
    estimate,
    Object.hashAll(severityAssessments),
    Object.hashAll(completedRevisions),
    Object.hashAll(limitations),
    voidRecord,
  );
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> left, Map<K, V> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

String _findingReviewSignature(DamageFinding finding) =>
    jsonEncode(finding.toJson());
