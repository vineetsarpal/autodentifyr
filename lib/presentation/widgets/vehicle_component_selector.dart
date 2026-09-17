import 'package:flutter/material.dart';

import 'package:autodentifyr/models/vehicle_component.dart';
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
  final bool requiredSelection;
}

class _VehicleComponentSelectorBody extends StatelessWidget {
  const _VehicleComponentSelectorBody({
    required this.label,
    required this.value,
    required this.detectorResult,
    required this.requiredSelection,
    required this.errorText,
    required this.onSelected,
  });

  final String label;
  final VehicleComponentId? value;
  final VehicleComponentDetectorResult? detectorResult;
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
                final selected = await Navigator.of(context)
                    .push<VehicleComponentId>(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => VehicleComponentPickerScreen(
                          existingId: value,
                          detectorResult: detectorResult,
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
