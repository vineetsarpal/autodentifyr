import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/models/vehicle_component.dart';

/// Immutable, read-only context for another finding already attached to a part.
class VehicleComponentExistingFinding {
  const VehicleComponentExistingFinding({
    required this.id,
    required this.componentId,
    required this.reviewState,
    required this.damageType,
  });

  final String id;
  final VehicleComponentId componentId;
  final FindingReviewState reviewState;
  final String? damageType;

  String get statusLabel =>
      reviewState == FindingReviewState.confirmed ? 'Confirmed' : 'Proposed';
}
