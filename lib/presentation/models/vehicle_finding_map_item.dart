import '../../models/vehicle_component.dart';

/// Presentation state for a finding marker in the review vehicle map.
enum VehicleFindingMapState {
  proposed,
  uncertain,
  confirmed,
  undetermined,
  manual,
}

/// The map's display-ready projection of a Damage Finding.
class VehicleFindingMapItem {
  const VehicleFindingMapItem({
    required this.findingId,
    required this.componentId,
    required this.damageType,
    required this.state,
    this.confidence,
    this.evidenceCount = 0,
  }) : assert(confidence == null || (confidence >= 0 && confidence <= 1)),
       assert(evidenceCount >= 0);

  final String findingId;
  final VehicleComponentId componentId;
  final String damageType;
  final VehicleFindingMapState state;
  final double? confidence;
  final int evidenceCount;
}
