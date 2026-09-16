import 'dart:io';

import 'package:flutter/material.dart';
import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/widgets/assessment_date_time.dart';

class AssessmentEvidenceSelector extends StatelessWidget {
  const AssessmentEvidenceSelector({
    super.key,
    required this.label,
    required this.captures,
    required this.initialIds,
    required this.onChanged,
    this.requiredSelection = true,
  });

  final String label;
  final List<Capture> captures;
  final List<String> initialIds;
  final ValueChanged<List<String>> onChanged;
  final bool requiredSelection;

  @override
  Widget build(BuildContext context) => FormField<List<String>>(
    key: key,
    initialValue: List.of(initialIds),
    validator: (ids) => requiredSelection && (ids?.isEmpty ?? true)
        ? '$label is required.'
        : null,
    builder: (field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        if (captures.isEmpty) const Text('No accepted Captures available.'),
        for (final (index, capture) in captures.indexed)
          CheckboxListTile(
            key: Key('evidence-choice-${capture.id}'),
            contentPadding: EdgeInsets.zero,
            value: field.value?.contains(capture.id) ?? false,
            secondary: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox.square(
                dimension: 56,
                child: Image.file(
                  File(capture.localPath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
            title: Text('Capture ${index + 1}'),
            subtitle: Text(
              '${capture.source == CaptureSource.camera ? 'Camera still' : 'Imported image'} • ${formatAssessmentDateTime(context, capture.acceptedAt)}',
            ),
            onChanged: (selected) {
              final ids = List<String>.of(field.value ?? const []);
              if (selected ?? false) {
                if (!ids.contains(capture.id)) ids.add(capture.id);
              } else {
                ids.remove(capture.id);
              }
              field.didChange(ids);
              onChanged(ids);
            },
          ),
        if (field.errorText != null)
          Text(
            field.errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}

class AssessmentObservationSelector extends StatelessWidget {
  const AssessmentObservationSelector({
    super.key,
    required this.label,
    required this.observations,
    required this.captures,
    required this.initialIds,
    required this.onChanged,
  });

  final String label;
  final List<DamageObservation> observations;
  final List<Capture> captures;
  final List<String> initialIds;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) => FormField<List<String>>(
    key: key,
    initialValue: List.of(initialIds),
    builder: (field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        for (final (index, observation) in observations.indexed)
          CheckboxListTile(
            key: Key('observation-choice-${observation.id}'),
            contentPadding: EdgeInsets.zero,
            value: field.value?.contains(observation.id) ?? false,
            secondary: _observationThumbnail(observation),
            title: Text('Observation ${index + 1}: ${observation.rawClass}'),
            subtitle: Text(
              '${(observation.confidence * 100).toStringAsFixed(1)}% confidence',
            ),
            onChanged: (selected) {
              final ids = List<String>.of(field.value ?? const []);
              if (selected ?? false) {
                if (!ids.contains(observation.id)) ids.add(observation.id);
              } else {
                ids.remove(observation.id);
              }
              field.didChange(ids);
              onChanged(ids);
            },
          ),
      ],
    ),
  );

  Widget _observationThumbnail(DamageObservation observation) {
    final capture = captures
        .where((value) => value.id == observation.captureId)
        .firstOrNull;
    if (capture == null) return const Icon(Icons.broken_image_outlined);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox.square(
        dimension: 56,
        child: Image.file(
          File(capture.localPath),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}
