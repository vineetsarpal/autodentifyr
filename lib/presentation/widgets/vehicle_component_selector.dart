import 'package:flutter/material.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/presentation/models/vehicle_component_existing_finding.dart';
import 'package:autodentifyr/presentation/models/vehicle_finding_map_item.dart';
import 'package:autodentifyr/presentation/screens/vehicle_component_map_screen.dart';
import 'package:autodentifyr/presentation/screens/vehicle_component_picker_screen.dart';
import 'package:autodentifyr/services/vehicle_component_detector_adapter.dart';

/// A read-only form launcher for choosing a position-specific exterior part.
class VehicleComponentSelector extends FormField<VehicleComponentId> {
  VehicleComponentSelector({
    super.key,
    required this.label,
    required VehicleComponentId? value,
    required this.onChanged,
    this.detectorResult,
    this.evidence,
    this.existingFindings = const [],
    this.requiredSelection = true,
  }) : super(
         initialValue: value,
         validator: (selected) => requiredSelection && selected == null
             ? '$label is required.'
             : null,
         builder: (field) => _VehicleComponentSelectorBody(
           label: label,
           value: field.value,
           detectorResult: detectorResult,
           evidence: evidence,
           existingFindings: existingFindings,
           requiredSelection: requiredSelection,
           errorText: field.errorText,
           onSelected: (selected) {
             field.didChange(selected);
             onChanged(selected);
           },
         ),
       );

  final String label;
  final ValueChanged<VehicleComponentId> onChanged;
  final VehicleComponentDetectorResult? detectorResult;
  final VehicleComponentPickerEvidence? evidence;
  final List<VehicleComponentExistingFinding> existingFindings;
  final bool requiredSelection;
}

class _VehicleComponentSelectorBody extends StatelessWidget {
  const _VehicleComponentSelectorBody({
    required this.label,
    required this.value,
    required this.detectorResult,
    required this.evidence,
    required this.existingFindings,
    required this.requiredSelection,
    required this.errorText,
    required this.onSelected,
  });

  final String label;
  final VehicleComponentId? value;
  final VehicleComponentDetectorResult? detectorResult;
  final VehicleComponentPickerEvidence? evidence;
  final List<VehicleComponentExistingFinding> existingFindings;
  final bool requiredSelection;
  final String? errorText;
  final ValueChanged<VehicleComponentId> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = value == null
        ? 'No component selected'
        : VehicleComponentCatalog.byId(value!).label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          requiredSelection ? '$label *' : label,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label:
              '$label: $selectedLabel. ${value == null ? 'Choose' : 'Change'} component.',
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: Key('component-selector-$label'),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size(48, 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                final suggestedComponents = switch (detectorResult) {
                  ExactVehicleComponentDetectorResult(:final componentId) => [
                    componentId,
                  ],
                  CandidateVehicleComponentDetectorResult(
                    :final componentIds,
                  ) =>
                    componentIds,
                  _ => const <VehicleComponentId>[],
                };
                final confidence = evidence?.observations.isEmpty ?? true
                    ? null
                    : evidence!.observations
                          .map((observation) => observation.confidence)
                          .reduce((a, b) => a > b ? a : b);
                final selected = await Navigator.of(context)
                    .push<VehicleComponentId>(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => VehicleComponentMapScreen(
                          initialComponent: value,
                          suggestedComponents: suggestedComponents,
                          suggestionConfidence: confidence,
                          items: existingFindings
                              .map(
                                (finding) => VehicleFindingMapItem(
                                  findingId: finding.id,
                                  componentId: finding.componentId,
                                  damageType:
                                      finding.damageType ?? 'Existing finding',
                                  state:
                                      finding.reviewState ==
                                          FindingReviewState.confirmed
                                      ? VehicleFindingMapState.confirmed
                                      : VehicleFindingMapState.proposed,
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    );
                if (selected != null) onSelected(selected);
              },
              child: Row(
                children: [
                  Expanded(child: Text(selectedLabel)),
                  Text(value == null ? 'Choose' : 'Change'),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
