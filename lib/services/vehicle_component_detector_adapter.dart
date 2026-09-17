import 'package:autodentifyr/models/vehicle_component.dart';

/// The explicit relationship between a detector class and vehicle components.
sealed class VehicleComponentDetectorResult {
  const VehicleComponentDetectorResult(this.detectorClass);

  final String detectorClass;
}

/// The detector class identifies exactly one canonical component.
final class ExactVehicleComponentDetectorResult
    extends VehicleComponentDetectorResult {
  const ExactVehicleComponentDetectorResult(
    super.detectorClass,
    this.componentId,
  );

  final VehicleComponentId componentId;
}

/// The detector class names a part category that has multiple valid positions.
final class CandidateVehicleComponentDetectorResult
    extends VehicleComponentDetectorResult {
  const CandidateVehicleComponentDetectorResult(
    super.detectorClass,
    this.componentIds,
  );

  final List<VehicleComponentId> componentIds;
}

/// Converts detector terminology without inferring a vehicle side or position.
abstract final class VehicleComponentDetectorAdapter {
  static VehicleComponentDetectorResult resolve(String detectorClass) =>
      switch (detectorClass) {
        'bonnet-dent' => const ExactVehicleComponentDetectorResult(
          'bonnet-dent',
          VehicleComponentId.hood,
        ),
        'headlight-damage' => const CandidateVehicleComponentDetectorResult(
          'headlight-damage',
          [VehicleComponentId.leftHeadlight, VehicleComponentId.rightHeadlight],
        ),
        'front-windscreen-damage' => const ExactVehicleComponentDetectorResult(
          'front-windscreen-damage',
          VehicleComponentId.frontWindscreen,
        ),
        'rear-windscreen-damage' => const ExactVehicleComponentDetectorResult(
          'rear-windscreen-damage',
          VehicleComponentId.rearWindscreen,
        ),
        'runningboard-damage' =>
          const CandidateVehicleComponentDetectorResult('runningboard-damage', [
            VehicleComponentId.leftRunningBoard,
            VehicleComponentId.rightRunningBoard,
          ]),
        'sidemirror-damage' => const CandidateVehicleComponentDetectorResult(
          'sidemirror-damage',
          [VehicleComponentId.leftMirror, VehicleComponentId.rightMirror],
        ),
        'taillight-damage' => const CandidateVehicleComponentDetectorResult(
          'taillight-damage',
          [VehicleComponentId.leftTaillight, VehicleComponentId.rightTaillight],
        ),
        'boot-dent' => const CandidateVehicleComponentDetectorResult(
          'boot-dent',
          [VehicleComponentId.trunkLid, VehicleComponentId.tailgate],
        ),
        'doorouter-dent' =>
          const CandidateVehicleComponentDetectorResult('doorouter-dent', [
            VehicleComponentId.leftFrontDoor,
            VehicleComponentId.leftRearDoor,
            VehicleComponentId.rightFrontDoor,
            VehicleComponentId.rightRearDoor,
          ]),
        'fender-dent' =>
          const CandidateVehicleComponentDetectorResult('fender-dent', [
            VehicleComponentId.leftFrontFender,
            VehicleComponentId.rightFrontFender,
          ]),
        // The model's published class uses this spelling; canonical IDs do not.
        'quaterpanel-dent' =>
          const CandidateVehicleComponentDetectorResult('quaterpanel-dent', [
            VehicleComponentId.leftRearQuarterPanel,
            VehicleComponentId.rightRearQuarterPanel,
          ]),
        'front-bumper-dent' => const ExactVehicleComponentDetectorResult(
          'front-bumper-dent',
          VehicleComponentId.frontBumper,
        ),
        'rear-bumper-dent' => const ExactVehicleComponentDetectorResult(
          'rear-bumper-dent',
          VehicleComponentId.rearBumper,
        ),
        'roof-dent' => const ExactVehicleComponentDetectorResult(
          'roof-dent',
          VehicleComponentId.roof,
        ),
        _ => UnknownVehicleComponentDetectorResult(detectorClass),
      };

  /// Resolves ordered detector evidence without inferring a component position.
  ///
  /// IDs are de-duplicated in evidence order and, within each observation, in
  /// the adapter's candidate order. Unknown classes contribute no IDs.
  static VehicleComponentDetectorResult resolveAll(
    Iterable<String> detectorClasses,
  ) {
    final rawClasses = detectorClasses.toList(growable: false);
    final recognizedResults = <VehicleComponentDetectorResult>[];
    final componentIds = <VehicleComponentId>[];

    for (final detectorClass in rawClasses) {
      final result = resolve(detectorClass);
      switch (result) {
        case ExactVehicleComponentDetectorResult(:final componentId):
          recognizedResults.add(result);
          if (!componentIds.contains(componentId)) {
            componentIds.add(componentId);
          }
        case CandidateVehicleComponentDetectorResult(
          componentIds: final candidateIds,
        ):
          recognizedResults.add(result);
          for (final componentId in candidateIds) {
            if (!componentIds.contains(componentId)) {
              componentIds.add(componentId);
            }
          }
        case UnknownVehicleComponentDetectorResult():
          break;
      }
    }

    if (recognizedResults.isEmpty) {
      return UnknownVehicleComponentDetectorResult(
        rawClasses.isEmpty ? '' : rawClasses.first,
      );
    }
    final detectorClass = recognizedResults.first.detectorClass;
    return switch (componentIds) {
      [final componentId] => ExactVehicleComponentDetectorResult(
        detectorClass,
        componentId,
      ),
      _ => CandidateVehicleComponentDetectorResult(
        detectorClass,
        List.unmodifiable(componentIds),
      ),
    };
  }
}

/// The detector class has no supported mapping to a vehicle component.
final class UnknownVehicleComponentDetectorResult
    extends VehicleComponentDetectorResult {
  const UnknownVehicleComponentDetectorResult(super.detectorClass);
}
