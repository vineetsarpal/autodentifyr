import 'package:flutter/material.dart';

/// Exterior component positions are deliberately chosen by the Appraiser.
class VehicleComponentSelector extends StatelessWidget {
  const VehicleComponentSelector({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.requiredSelection = true,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final bool requiredSelection;

  static const positions = <String>[
    'front bumper',
    'hood',
    'left headlight',
    'right headlight',
    'left-front fender',
    'right-front fender',
    'left-front door',
    'right-front door',
    'left-rear door',
    'right-rear door',
    'left-rear quarter panel',
    'right-rear quarter panel',
    'roof',
    'trunk lid',
    'tailgate',
    'left taillight',
    'right taillight',
    'rear bumper',
    'left mirror',
    'right mirror',
  ];

  @override
  Widget build(BuildContext context) {
    final choices = [
      if (initialValue.trim().isNotEmpty && !positions.contains(initialValue))
        initialValue,
      ...positions,
    ];
    return FormField<String>(
      key: key,
      initialValue: initialValue,
      validator: (value) => requiredSelection && (value?.trim().isEmpty ?? true)
          ? '$label is required.'
          : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            requiredSelection ? '$label *' : label,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const _ExteriorDiagram(),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: Key('component-dropdown-$label'),
            initialValue: field.value?.isEmpty ?? true ? null : field.value,
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(
              hintText: 'Choose an exterior position',
              errorText: field.errorText,
            ),
            items: [
              for (final choice in choices)
                DropdownMenuItem(
                  value: choice,
                  child: Text(
                    choice == initialValue && !positions.contains(choice)
                        ? 'Keep existing: $choice'
                        : choice,
                    softWrap: true,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              field.didChange(value);
              onChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _ExteriorDiagram extends StatelessWidget {
  const _ExteriorDiagram();

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Exterior vehicle position guide: front at top, left and right sides, rear at bottom',
    child: ExcludeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          children: [
            Text('FRONT  •  bumper / headlights / hood'),
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    'LEFT\nmirror\ndoors\nfenders',
                    textAlign: TextAlign.center,
                  ),
                ),
                Icon(Icons.directions_car, size: 64),
                SizedBox(
                  width: 80,
                  child: Text(
                    'RIGHT\nmirror\ndoors\nfenders',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            Text('REAR  •  quarter panels / lights / bumper'),
          ],
        ),
      ),
    ),
  );
}
