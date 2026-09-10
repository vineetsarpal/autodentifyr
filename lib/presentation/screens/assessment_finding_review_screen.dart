import 'dart:io';

import 'package:flutter/material.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_finding_review_controller.dart';

class AssessmentFindingReviewScreen extends StatefulWidget {
  const AssessmentFindingReviewScreen({super.key, required this.controller});

  final AssessmentFindingReviewController controller;

  @override
  State<AssessmentFindingReviewScreen> createState() =>
      _AssessmentFindingReviewScreenState();
}

class _AssessmentFindingReviewScreenState
    extends State<AssessmentFindingReviewScreen> {
  final Set<String> _selectedFindingIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.controller.state.phase == FindingReviewPhase.idle) {
      widget.controller.load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review findings')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => _buildState(widget.controller.state),
      ),
    ),
  );

  Widget _buildState(FindingReviewControllerState state) {
    if (state.phase == FindingReviewPhase.idle ||
        state.phase == FindingReviewPhase.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final assessment = state.assessment;
    if (assessment == null) {
      return Center(
        child: Text(state.message ?? 'Intake Assessment unavailable.'),
      );
    }
    final proposedCount = assessment.findings
        .where((finding) => finding.reviewState == FindingReviewState.proposed)
        .length;
    return Column(
      children: [
        if (state.message != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(state.message!),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$proposedCount Proposed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilledButton.icon(
                key: const Key('add-manual-finding'),
                onPressed: _addManual,
                icon: const Icon(Icons.add),
                label: const Text('Add manual Finding'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('merge-selected'),
                onPressed: _selectedFindingIds.length >= 2
                    ? _mergeSelected
                    : null,
                child: const Text('Merge selected'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: assessment.findings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _buildFinding(assessment, assessment.findings[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildFinding(
    IntakeAssessment assessment,
    DamageFinding finding,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                key: Key('select-${finding.id}'),
                value: _selectedFindingIds.contains(finding.id),
                onChanged: (selected) => setState(() {
                  if (selected ?? false) {
                    _selectedFindingIds.add(finding.id);
                  } else {
                    _selectedFindingIds.remove(finding.id);
                  }
                }),
              ),
              Expanded(
                child: Text(
                  _reviewLabel(finding),
                  key: Key('status-${finding.id}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (finding.reviewState == FindingReviewState.proposed) ...[
            for (final observation in assessment.observations.where(
              (observation) => finding.observationIds.contains(observation.id),
            ))
              ..._buildObservationEvidence(assessment, observation),
            if (_hasAppraiserEdit(assessment, finding))
              Text('${finding.vehicleComponent} • ${finding.damageType}')
            else ...[
              const Text('Vehicle Component: Appraiser confirmation required'),
              const Text('Damage Type: Appraiser confirmation required'),
            ],
          ] else
            Text(
              finding.vehicleComponent == null || finding.damageType == null
                  ? 'Component and Damage Type not yet confirmed'
                  : '${finding.vehicleComponent} • ${finding.damageType}',
            ),
          if (finding.hasConflictingViews) ...[
            const SizedBox(height: 4),
            const Text('Conflicting views'),
          ],
          for (final request in finding.additionalViewRequests) Text(request),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: Key('confirm-${finding.id}'),
                onPressed: () => _confirm(finding),
                child: const Text('Confirm'),
              ),
              OutlinedButton(
                key: Key('edit-${finding.id}'),
                onPressed: () => _edit(finding),
                child: const Text('Edit'),
              ),
              OutlinedButton(
                key: Key('dismiss-${finding.id}'),
                onPressed: () => _dismiss(finding),
                child: const Text('Dismiss'),
              ),
              OutlinedButton(
                key: Key('uncertainty-${finding.id}'),
                onPressed: () => _recordUncertainty(finding),
                child: const Text('Uncertainty'),
              ),
              OutlinedButton(
                key: Key('undetermined-${finding.id}'),
                onPressed: () => _markUndetermined(finding),
                child: const Text('Undetermined'),
              ),
              OutlinedButton(
                key: Key('split-${finding.id}'),
                onPressed: () => _split(finding),
                child: const Text('Split'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  List<Widget> _buildObservationEvidence(
    IntakeAssessment assessment,
    DamageObservation observation,
  ) {
    final capture = _captureById(assessment, observation.captureId);
    final captureSource = switch (capture?.source) {
      CaptureSource.camera => 'Camera still',
      CaptureSource.import => 'Imported image',
      null => 'Capture',
    };
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (capture != null) ...[
            Semantics(
              button: true,
              label: 'Enlarge model evidence for ${observation.rawClass}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('open-finding-observation-${observation.id}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showObservationEvidence(capture, observation),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox.square(
                      dimension: 96,
                      child: Image.file(
                        File(capture.localPath),
                        key: Key('finding-observation-image-${observation.id}'),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Colors.black12,
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Model observation: ${observation.rawClass}'),
                const SizedBox(height: 4),
                Text(
                  '${(observation.confidence * 100).toStringAsFixed(1)}% '
                  'confidence',
                ),
                const SizedBox(height: 4),
                Text('$captureSource • Capture ${observation.captureId}'),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
    ];
  }

  Future<void> _showObservationEvidence(
    Capture capture,
    DamageObservation observation,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _ObservationEvidenceViewer(
        capture: capture,
        observation: observation,
      ),
    ),
  );

  Capture? _captureById(IntakeAssessment assessment, String captureId) {
    for (final capture in assessment.captures) {
      if (capture.id == captureId) return capture;
    }
    return null;
  }

  bool _hasAppraiserEdit(IntakeAssessment assessment, DamageFinding finding) =>
      assessment.corrections.any(
        (correction) =>
            correction.kind == AssessmentCorrectionKind.edit &&
            correction.replacements.any(
              (replacement) => replacement.id == finding.id,
            ),
      );

  String _reviewLabel(DamageFinding finding) => switch (finding.reviewState) {
    FindingReviewState.proposed =>
      finding.reviewOutcome == FindingReviewOutcome.undetermined
          ? 'Undetermined'
          : 'Proposed',
    FindingReviewState.confirmed => 'Confirmed',
    FindingReviewState.dismissed => 'Dismissed',
  };

  Future<void> _confirm(DamageFinding finding) async {
    final values = await _showFields(
      title: 'Confirm Finding',
      fields: [
        _Field(
          'vehicleComponent',
          'Vehicle Component',
          'vehicle-component',
          finding.vehicleComponent ?? '',
        ),
        _Field(
          'damageType',
          'Damage Type',
          'damage-type',
          finding.damageType ?? '',
        ),
        const _Field('reason', 'Reason', 'reason'),
        const _Field(
          'override',
          'Additional-view override reason',
          'override-reason',
        ),
      ],
    );
    if (values == null) return;
    await widget.controller.submit(
      ConfirmFindingAction(
        findingId: finding.id,
        vehicleComponent: values['vehicleComponent']!,
        damageType: values['damageType']!,
        reason: values['reason']!,
        additionalViewOverrideReason: _nullable(values['override']!),
      ),
    );
  }

  Future<void> _edit(DamageFinding finding) async {
    final values = await _showFields(
      title: 'Edit Finding',
      fields: [
        _Field(
          'vehicleComponent',
          'Vehicle Component',
          'vehicle-component',
          finding.vehicleComponent ?? '',
        ),
        _Field(
          'damageType',
          'Damage Type',
          'damage-type',
          finding.damageType ?? '',
        ),
        _Field(
          'captures',
          'Supporting Capture IDs',
          'capture-ids',
          finding.supportingCaptureIds.join(', '),
        ),
        const _Field('reason', 'Reason', 'reason'),
      ],
    );
    if (values == null) return;
    await widget.controller.submit(
      EditFindingAction(
        findingId: finding.id,
        vehicleComponent: values['vehicleComponent']!,
        damageType: values['damageType']!,
        supportingCaptureIds: _csv(values['captures']!),
        reason: values['reason']!,
      ),
    );
  }

  Future<void> _dismiss(DamageFinding finding) async {
    final values = await _showFields(
      title: 'Dismiss Finding',
      fields: const [
        _Field('reason', 'Reason', 'reason'),
        _Field(
          'override',
          'Additional-view override reason',
          'override-reason',
        ),
      ],
    );
    if (values == null) return;
    await widget.controller.submit(
      DismissFindingAction(
        findingId: finding.id,
        reason: values['reason']!,
        additionalViewOverrideReason: _nullable(values['override']!),
      ),
    );
  }

  Future<void> _addManual() async {
    final values = await _showFields(
      title: 'Add manual Finding',
      fields: const [
        _Field('vehicleComponent', 'Vehicle Component', 'vehicle-component'),
        _Field('damageType', 'Damage Type', 'damage-type'),
        _Field('captures', 'Supporting Capture IDs', 'capture-ids'),
        _Field('observations', 'Matching Observation IDs', 'observation-ids'),
        _Field('evidenceNote', 'Appraiser evidence note', 'evidence-note'),
        _Field('reason', 'Reason', 'reason'),
      ],
    );
    if (values == null) return;
    await widget.controller.submit(
      AddManualFindingAction(
        vehicleComponent: values['vehicleComponent']!,
        damageType: values['damageType']!,
        supportingCaptureIds: _csv(values['captures']!),
        observationIds: _csv(values['observations']!),
        evidenceNote: values['evidenceNote']!,
        reason: values['reason']!,
      ),
    );
  }

  Future<void> _recordUncertainty(DamageFinding finding) async {
    final requests = TextEditingController(
      text: finding.additionalViewRequests.join('\n'),
    );
    final reason = TextEditingController();
    var conflicting = finding.hasConflictingViews;
    final action = await showDialog<RecordFindingUncertaintyAction>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record uncertainty'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  key: const Key('conflicting-views'),
                  value: conflicting,
                  onChanged: (value) =>
                      setDialogState(() => conflicting = value ?? false),
                  title: const Text('Conflicting views'),
                  contentPadding: EdgeInsets.zero,
                ),
                TextField(
                  key: const Key('additional-views'),
                  controller: requests,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Specific additional-view requests',
                  ),
                ),
                TextField(
                  key: const Key('reason'),
                  controller: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('submit-action'),
              onPressed: () => Navigator.pop(
                context,
                RecordFindingUncertaintyAction(
                  findingId: finding.id,
                  hasConflictingViews: conflicting,
                  additionalViewRequests: requests.text
                      .split('\n')
                      .map((value) => value.trim())
                      .where((value) => value.isNotEmpty)
                      .toList(),
                  reason: reason.text,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (action != null) await widget.controller.submit(action);
  }

  Future<void> _markUndetermined(DamageFinding finding) async {
    final values = await _showFields(
      title: 'Mark Undetermined',
      fields: const [
        _Field('reason', 'Reason', 'reason'),
        _Field(
          'override',
          'Additional-view override reason',
          'override-reason',
        ),
      ],
    );
    if (values == null) return;
    await widget.controller.submit(
      MarkFindingUndeterminedAction(
        findingId: finding.id,
        reason: values['reason']!,
        additionalViewOverrideReason: _nullable(values['override']!),
      ),
    );
  }

  Future<void> _mergeSelected() async {
    final values = await _showFields(
      title: 'Merge Findings',
      fields: const [
        _Field('vehicleComponent', 'Vehicle Component', 'vehicle-component'),
        _Field('damageType', 'Damage Type', 'damage-type'),
        _Field('reason', 'Reason', 'reason'),
        _Field(
          'override',
          'Additional-view override reason',
          'override-reason',
        ),
      ],
    );
    if (values == null) return;
    await widget.controller.submit(
      MergeFindingsAction(
        findingIds: _selectedFindingIds.toList(),
        vehicleComponent: values['vehicleComponent']!,
        damageType: values['damageType']!,
        reason: values['reason']!,
        additionalViewOverrideReason: _nullable(values['override']!),
      ),
    );
    if (mounted && widget.controller.state.phase == FindingReviewPhase.ready) {
      setState(_selectedFindingIds.clear);
    }
  }

  Future<void> _split(DamageFinding finding) async {
    final values = await _showFields(
      title: 'Split Finding',
      fields: const [
        _Field('part1Component', 'First Vehicle Component', 'part-1-component'),
        _Field('part1Type', 'First Damage Type', 'part-1-type'),
        _Field(
          'part1Observations',
          'First Observation IDs',
          'part-1-observations',
        ),
        _Field('part1Captures', 'First Capture IDs', 'part-1-captures'),
        _Field(
          'part2Component',
          'Second Vehicle Component',
          'part-2-component',
        ),
        _Field('part2Type', 'Second Damage Type', 'part-2-type'),
        _Field(
          'part2Observations',
          'Second Observation IDs',
          'part-2-observations',
        ),
        _Field('part2Captures', 'Second Capture IDs', 'part-2-captures'),
        _Field('reason', 'Reason', 'reason'),
        _Field(
          'override',
          'Additional-view override reason',
          'override-reason',
        ),
      ],
    );
    if (values == null) return;
    await widget.controller.submit(
      SplitFindingAction(
        findingId: finding.id,
        parts: [
          SplitFindingPart(
            vehicleComponent: values['part1Component']!,
            damageType: values['part1Type']!,
            observationIds: _csv(values['part1Observations']!),
            supportingCaptureIds: _csv(values['part1Captures']!),
          ),
          SplitFindingPart(
            vehicleComponent: values['part2Component']!,
            damageType: values['part2Type']!,
            observationIds: _csv(values['part2Observations']!),
            supportingCaptureIds: _csv(values['part2Captures']!),
          ),
        ],
        reason: values['reason']!,
        additionalViewOverrideReason: _nullable(values['override']!),
      ),
    );
  }

  Future<Map<String, String>?> _showFields({
    required String title,
    required List<_Field> fields,
  }) async {
    final controllers = {
      for (final field in fields)
        field.name: TextEditingController(text: field.initial),
    };
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    key: Key(field.keyName),
                    controller: controllers[field.name],
                    decoration: InputDecoration(labelText: field.label),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('submit-action'),
            onPressed: () => Navigator.pop(context, {
              for (final entry in controllers.entries)
                entry.key: entry.value.text,
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return result;
  }
}

class _ObservationEvidenceViewer extends StatelessWidget {
  const _ObservationEvidenceViewer({
    required this.capture,
    required this.observation,
  });

  final Capture capture;
  final DamageObservation observation;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: CloseButton(
        key: const Key('close-model-evidence'),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Model evidence'),
    ),
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${observation.rawClass} • '
                  '${(observation.confidence * 100).toStringAsFixed(1)}% '
                  'confidence',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text('Pinch to zoom and drag to inspect the detection.'),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => InteractiveViewer(
                minScale: 1,
                maxScale: 8,
                boundaryMargin: const EdgeInsets.all(80),
                child: Center(
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Stack(
                      children: [
                        Image.file(
                          File(capture.localPath),
                          key: Key('model-evidence-image-${observation.id}'),
                          width: constraints.maxWidth,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, _, _) => SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight * 0.6,
                            child: const ColoredBox(
                              color: Colors.black12,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 64,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              key: Key(
                                'finding-observation-bounds-${observation.id}',
                              ),
                              painter: _ObservationBoundsPainter(
                                bounds: observation.bounds,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ObservationBoundsPainter extends CustomPainter {
  const _ObservationBoundsPainter({required this.bounds, required this.color});

  final ObservationBounds bounds;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final left = bounds.left.clamp(0.0, 1.0).toDouble();
    final top = bounds.top.clamp(0.0, 1.0).toDouble();
    final right = (bounds.left + bounds.width).clamp(0.0, 1.0).toDouble();
    final bottom = (bounds.top + bounds.height).clamp(0.0, 1.0).toDouble();
    final rectangle = Rect.fromLTRB(
      left * size.width,
      top * size.height,
      right * size.width,
      bottom * size.height,
    );
    final shadow = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(rectangle, shadow);
    canvas.drawRect(rectangle, outline);
  }

  @override
  bool shouldRepaint(_ObservationBoundsPainter oldDelegate) =>
      oldDelegate.bounds != bounds || oldDelegate.color != color;
}

class _Field {
  const _Field(this.name, this.label, this.keyName, [this.initial = '']);

  final String name;
  final String label;
  final String keyName;
  final String initial;
}

String? _nullable(String value) => value.trim().isEmpty ? null : value;

List<String> _csv(String value) => value
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();
