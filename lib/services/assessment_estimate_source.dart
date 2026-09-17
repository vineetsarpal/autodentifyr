import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/models/vehicle_component.dart';

class SuggestedRepairOperation {
  const SuggestedRepairOperation({
    required this.operationId,
    required this.findingId,
    required this.description,
    this.minimumCents,
    this.maximumCents,
    this.currency,
    this.pricingSourceVersion,
  });

  final String operationId;
  final String findingId;
  final String description;
  final int? minimumCents;
  final int? maximumCents;
  final String? currency;
  final String? pricingSourceVersion;
}

abstract interface class AssessmentEstimateSource {
  String get version;

  bool get supportsNumericPricing;

  Future<List<SuggestedRepairOperation>> suggestOperations(
    List<DamageFinding> confirmedFindings,
  );
}

class UnavailableAssessmentEstimateSource implements AssessmentEstimateSource {
  const UnavailableAssessmentEstimateSource();

  @override
  String get version => 'unsupported-pricing-v1';

  @override
  bool get supportsNumericPricing => false;

  @override
  Future<List<SuggestedRepairOperation>> suggestOperations(
    List<DamageFinding> confirmedFindings,
  ) async => [
    for (final finding in confirmedFindings)
      SuggestedRepairOperation(
        operationId: 'review-${_componentId(finding)}',
        findingId: finding.id,
        description:
            'Review shared repair operation for ${_componentLabel(finding)}',
      ),
  ];

  String _componentId(DamageFinding finding) {
    return finding.vehicleComponentId?.wireValue ?? 'unknown-component';
  }

  String _componentLabel(DamageFinding finding) {
    final id = finding.vehicleComponentId;
    if (id == null) return 'an unassigned component';
    return VehicleComponentCatalog.byId(id).label;
  }
}
