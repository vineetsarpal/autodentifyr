import 'dart:io';

import 'package:flutter/material.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/models/vehicle_component.dart';
import 'package:autodentifyr/presentation/controllers/assessment_finding_review_controller.dart';
import 'package:autodentifyr/presentation/controllers/assessment_progress.dart';
import 'package:autodentifyr/presentation/models/vehicle_component_existing_finding.dart';
import 'package:autodentifyr/presentation/models/vehicle_finding_map_item.dart';
import 'package:autodentifyr/presentation/screens/vehicle_component_map_screen.dart';
import 'package:autodentifyr/presentation/screens/vehicle_component_picker_screen.dart';
import 'package:autodentifyr/presentation/widgets/assessment_evidence_selector.dart';
import 'package:autodentifyr/presentation/widgets/observation_evidence.dart';
import 'package:autodentifyr/presentation/widgets/vehicle_component_selector.dart';
import 'package:autodentifyr/services/vehicle_component_detector_adapter.dart';

class AssessmentFindingReviewScreen extends StatefulWidget {
  const AssessmentFindingReviewScreen({
    super.key,
    required this.controller,
    this.onContinue,
  });

  final AssessmentFindingReviewController controller;
  final VoidCallback? onContinue;

  @override
  State<AssessmentFindingReviewScreen> createState() =>
      _AssessmentFindingReviewScreenState();
}

class _AssessmentFindingReviewScreenState
    extends State<AssessmentFindingReviewScreen> {
  final Set<String> _selectedFindingIds = {};
  bool _isMergeMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller.state.phase == FindingReviewPhase.idle) {
      widget.controller.load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: _isMergeMode
          ? IconButton(
              key: const Key('cancel-merge-mode'),
              tooltip: 'Cancel merge selection',
              onPressed: _leaveMergeMode,
              icon: const Icon(Icons.close),
            )
          : null,
      title: Text(_isMergeMode ? 'Select findings' : 'Review findings'),
      actions: _isMergeMode
          ? [
              TextButton(
                key: const Key('merge-selected'),
                onPressed: _selectedFindingIds.length >= 2
                    ? _mergeSelected
                    : null,
                child: const Text('Merge'),
              ),
            ]
          : [
              PopupMenuButton<String>(
                key: const Key('assessment-actions-menu'),
                tooltip: 'Assessment actions',
                onSelected: _handleAssessmentAction,
                itemBuilder: (context) {
                  final assessment = widget.controller.state.assessment;
                  final canMerge =
                      assessment != null &&
                      _mergeCandidates(assessment).length >= 2;
                  return [
                    const PopupMenuItem(
                      key: Key('add-manual-finding'),
                      value: 'add',
                      child: Text('Add finding'),
                    ),
                    if (canMerge)
                      const PopupMenuItem(
                        value: 'merge',
                        child: Text('Merge findings'),
                      ),
                    const PopupMenuItem(
                      value: 'map',
                      child: Text('View vehicle map'),
                    ),
                  ];
                },
              ),
            ],
    ),
    bottomNavigationBar: widget.onContinue == null
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final state = widget.controller.state;
                  final assessment = state.assessment;
                  final remaining = assessment == null
                      ? null
                      : AssessmentProgress.fromAssessment(
                          assessment,
                        ).outstandingFor(AssessmentStage.findings);
                  return FilledButton(
                    key: const Key('continue-assessment'),
                    onPressed:
                        state.phase == FindingReviewPhase.ready &&
                            remaining == 0
                        ? widget.onContinue
                        : null,
                    child: state.phase == FindingReviewPhase.saving
                        ? const Text('Saving to device...')
                        : Text(
                            remaining == 0
                                ? 'Continue to severity'
                                : 'Review ${remaining ?? 0} remaining',
                          ),
                  );
                },
              ),
            ),
          ),
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
    final pendingFindings = _pendingFindings(assessment);
    final reviewedFindings = _reviewedFindings(assessment);
    final focusedFinding = pendingFindings.firstOrNull;
    if (_isMergeMode) return _buildMergeMode(assessment);
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
              focusedFinding == null
                  ? 'All findings reviewed'
                  : 'Finding 1 of ${pendingFindings.length}',
              key: const Key('finding-review-progress'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (focusedFinding != null)
                _buildFocusedFinding(assessment, focusedFinding),
              if (reviewedFindings.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildReviewedFindings(reviewedFindings),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMergeMode(IntakeAssessment assessment) {
    final candidates = _mergeCandidates(assessment);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Select at least two findings to combine.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        for (final finding in candidates)
          Card(
            child: CheckboxListTile(
              key: Key('select-${finding.id}'),
              value: _selectedFindingIds.contains(finding.id),
              title: Text(
                '${_componentLabel(finding.vehicleComponentId)} • '
                '${finding.damageType ?? 'Damage type not recorded'}',
              ),
              subtitle: Text(_reviewLabel(finding)),
              onChanged: (selected) => setState(() {
                if (selected ?? false) {
                  _selectedFindingIds.add(finding.id);
                } else {
                  _selectedFindingIds.remove(finding.id);
                }
              }),
            ),
          ),
      ],
    );
  }

  List<DamageFinding> _mergeCandidates(IntakeAssessment assessment) =>
      assessment.findings
          .where(
            (finding) => finding.reviewState != FindingReviewState.dismissed,
          )
          .toList(growable: false);

  void _leaveMergeMode() {
    setState(() {
      _isMergeMode = false;
      _selectedFindingIds.clear();
    });
  }

  List<DamageFinding> _pendingFindings(IntakeAssessment assessment) =>
      assessment.findings
          .where(
            (finding) =>
                finding.reviewState == FindingReviewState.proposed &&
                finding.reviewOutcome == null,
          )
          .toList(growable: false);

  List<DamageFinding> _reviewedFindings(IntakeAssessment assessment) =>
      assessment.findings
          .where(
            (finding) =>
                finding.reviewState != FindingReviewState.proposed ||
                finding.reviewOutcome != null,
          )
          .toList(growable: false);

  Widget _buildReviewedFindings(List<DamageFinding> findings) => Card(
    child: ExpansionTile(
      key: const Key('reviewed-findings'),
      title: Text('Reviewed (${findings.length})'),
      children: [
        for (final finding in findings)
          ListTile(
            key: Key('reviewed-finding-${finding.id}'),
            title: Text(
              '${_componentLabel(finding.vehicleComponentId)} • '
              '${finding.damageType ?? 'Damage type not recorded'}',
            ),
            subtitle: Text(_reviewLabel(finding)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => finding.reviewState == FindingReviewState.confirmed
                ? _edit(finding)
                : _confirm(finding),
          ),
      ],
    ),
  );

  Widget _buildFocusedFinding(
    IntakeAssessment assessment,
    DamageFinding finding,
  ) {
    final observations = assessment.observations
        .where((observation) => finding.observationIds.contains(observation.id))
        .toList(growable: false);
    final quickComponent = _quickConfirmComponent(assessment, finding);
    final canQuickConfirm =
        quickComponent != null &&
        (finding.damageType?.trim().isNotEmpty ?? false) &&
        finding.additionalViewRequests.isEmpty;
    return Card(
      key: Key('focused-finding-${finding.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Suggested finding',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  key: Key('finding-more-actions-${finding.id}'),
                  tooltip: 'More finding actions',
                  onSelected: (action) => _handleFindingAction(action, finding),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'uncertainty',
                      child: Text('Need more evidence'),
                    ),
                    PopupMenuItem(
                      value: 'undetermined',
                      child: Text('Cannot determine'),
                    ),
                    PopupMenuItem(value: 'split', child: Text('Split finding')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final observation in observations)
              ..._buildObservationEvidence(assessment, observation),
            Text('Suggested', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  key: const Key('focused-component'),
                  avatar: const Icon(Icons.directions_car_outlined),
                  label: Text(
                    quickComponent == null
                        ? 'Choose component'
                        : _componentLabel(quickComponent),
                  ),
                  onPressed: () => _confirm(finding),
                ),
                ActionChip(
                  key: const Key('focused-damage-type'),
                  avatar: const Icon(Icons.build_outlined),
                  label: Text(finding.damageType ?? 'Add damage type'),
                  onPressed: () => _confirm(finding),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: Key('not-damage-${finding.id}'),
                    onPressed: () => _notDamage(finding),
                    child: const Text('Not damage'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: Key('confirm-and-next-${finding.id}'),
                    onPressed: () => canQuickConfirm
                        ? _quickConfirm(finding, quickComponent)
                        : _confirm(finding),
                    child: Text(
                      canQuickConfirm ? 'Confirm & next' : 'Review details',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleAssessmentAction(String action) {
    switch (action) {
      case 'add':
        _startManualFinding();
      case 'merge':
        setState(() => _isMergeMode = true);
      case 'map':
        _openVehicleMap();
    }
  }

  void _handleFindingAction(String action, DamageFinding finding) {
    switch (action) {
      case 'uncertainty':
        _recordUncertainty(finding);
      case 'undetermined':
        _markUndetermined(finding);
      case 'split':
        _split(finding);
    }
  }

  VehicleComponentId? _quickConfirmComponent(
    IntakeAssessment assessment,
    DamageFinding finding,
  ) {
    if (finding.vehicleComponentId case final component?) return component;
    final observationIds = finding.observationIds.toSet();
    final detectorResult = VehicleComponentDetectorAdapter.resolveAll(
      assessment.observations
          .where((observation) => observationIds.contains(observation.id))
          .map((observation) => observation.rawClass),
    );
    return switch (detectorResult) {
      ExactVehicleComponentDetectorResult(:final componentId) => componentId,
      _ => null,
    };
  }

  Future<void> _quickConfirm(
    DamageFinding finding,
    VehicleComponentId component,
  ) => widget.controller.submit(
    ConfirmFindingAction(
      findingId: finding.id,
      vehicleComponentId: component,
      damageType: finding.damageType!,
      reason: 'Appraiser confirmed the displayed component and damage type.',
    ),
  );

  Future<void> _notDamage(DamageFinding finding) async {
    if (finding.additionalViewRequests.isNotEmpty) {
      await _dismiss(finding);
      return;
    }
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Text(
                'Why is this not damage?',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            for (final option in const [
              ('reflection', 'Reflection'),
              ('duplicate', 'Duplicate'),
              ('existing-mark', 'Existing mark'),
            ])
              ListTile(
                key: Key('dismiss-reason-${option.$1}'),
                title: Text(option.$2),
                onTap: () => Navigator.pop(sheetContext, option.$2),
              ),
            ListTile(
              key: const Key('dismiss-reason-other'),
              title: const Text('Other'),
              onTap: () => Navigator.pop(sheetContext, ''),
            ),
          ],
        ),
      ),
    );
    if (!mounted || reason == null) return;
    if (reason.isEmpty) {
      await _dismiss(finding);
      return;
    }
    await widget.controller.submit(
      DismissFindingAction(findingId: finding.id, reason: reason),
    );
  }

  List<VehicleFindingMapItem> _mapItems(IntakeAssessment assessment) =>
      assessment.findings
          .where(
            (finding) =>
                finding.reviewState != FindingReviewState.dismissed &&
                finding.vehicleComponentId != null,
          )
          .map((finding) {
            final observations = assessment.observations
                .where(
                  (observation) =>
                      finding.observationIds.contains(observation.id),
                )
                .toList(growable: false);
            final confidence = observations.isEmpty
                ? null
                : observations
                      .map((observation) => observation.confidence)
                      .reduce((a, b) => a > b ? a : b);
            final captureIds = {
              ...finding.supportingCaptureIds,
              ...observations.map((observation) => observation.captureId),
            };
            final state = finding.manualEvidenceNote != null
                ? VehicleFindingMapState.manual
                : finding.reviewOutcome == FindingReviewOutcome.undetermined
                ? VehicleFindingMapState.undetermined
                : finding.reviewState == FindingReviewState.confirmed
                ? VehicleFindingMapState.confirmed
                : finding.hasConflictingViews ||
                      finding.additionalViewRequests.isNotEmpty
                ? VehicleFindingMapState.uncertain
                : VehicleFindingMapState.proposed;
            return VehicleFindingMapItem(
              findingId: finding.id,
              componentId: finding.vehicleComponentId!,
              damageType: finding.damageType ?? 'Damage',
              state: state,
              confidence: confidence,
              evidenceCount: captureIds.length,
            );
          })
          .toList(growable: false);

  Future<VehicleComponentId?> _chooseComponent({
    VehicleComponentId? initialComponent,
  }) async {
    final assessment = widget.controller.state.assessment;
    if (assessment == null) return null;
    final dismissedCounts = <VehicleComponentId, int>{};
    for (final finding in assessment.findings.where(
      (finding) =>
          finding.reviewState == FindingReviewState.dismissed &&
          finding.vehicleComponentId != null,
    )) {
      dismissedCounts.update(
        finding.vehicleComponentId!,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return Navigator.of(context).push<VehicleComponentId>(
      MaterialPageRoute<VehicleComponentId>(
        fullscreenDialog: true,
        builder: (_) => VehicleComponentMapScreen(
          initialComponent: initialComponent,
          items: _mapItems(assessment),
          dismissedFindingCounts: dismissedCounts,
          onViewEvidence: _viewMapEvidence,
        ),
      ),
    );
  }

  Future<void> _openVehicleMap() async {
    await _chooseComponent();
  }

  Future<void> _startManualFinding() async {
    final selected = await _chooseComponent();
    if (!mounted || selected == null) return;
    await _addManual(initialComponent: selected);
  }

  Future<void> _viewMapEvidence(String findingId) async {
    final assessment = widget.controller.state.assessment;
    final finding = assessment?.findings
        .where((item) => item.id == findingId)
        .firstOrNull;
    if (assessment == null || finding == null) return;
    for (final observationId in finding.observationIds) {
      final observation = assessment.observations
          .where((item) => item.id == observationId)
          .firstOrNull;
      if (observation == null) continue;
      final capture = _captureById(assessment, observation.captureId);
      if (capture != null) {
        await _showObservationEvidence(capture, observation);
        return;
      }
    }
    for (final captureId in finding.supportingCaptureIds) {
      final capture = _captureById(assessment, captureId);
      if (capture != null) {
        await _showCaptureEvidence(capture);
        return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('No evidence is available for this finding.'),
        ),
      );
  }

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
                      dimension: 72,
                      child: ObservationImageOverlay(
                        capture: capture,
                        observation: observation,
                        imageKey: Key(
                          'finding-observation-image-${observation.id}',
                        ),
                        boundsKey: Key(
                          'finding-thumbnail-bounds-${observation.id}',
                        ),
                        outlineColor: Theme.of(context).colorScheme.tertiary,
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
                Text(
                  'Suggested ${observation.rawClass} • '
                  '${(observation.confidence * 100).toStringAsFixed(1)}% confidence',
                ),
                const SizedBox(height: 4),
                Text(captureSource),
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
      builder: (_) =>
          ObservationEvidenceViewer(capture: capture, observation: observation),
    ),
  );

  Capture? _captureById(IntakeAssessment assessment, String captureId) {
    for (final capture in assessment.captures) {
      if (capture.id == captureId) return capture;
    }
    return null;
  }

  VehicleComponentPickerEvidence? _pickerEvidenceFor(
    IntakeAssessment assessment,
    DamageFinding? finding,
  ) {
    if (finding == null || finding.observationIds.isEmpty) return null;
    final observationIds = finding.observationIds.toSet();
    final observations = assessment.observations
        .where((observation) => observationIds.contains(observation.id))
        .toList(growable: false);
    if (observations.isEmpty) return null;
    final captureIds = observations
        .map((observation) => observation.captureId)
        .toSet();
    final captures = assessment.captures
        .where((capture) => captureIds.contains(capture.id))
        .toList(growable: false);
    if (captures.isEmpty) return null;
    return VehicleComponentPickerEvidence(
      captures: captures,
      observations: observations,
      initiatingObservationId: observations.first.id,
    );
  }

  List<VehicleComponentExistingFinding> _existingFindingsFor(
    IntakeAssessment assessment,
    DamageFinding? currentFinding,
  ) => List.unmodifiable(
    assessment.findings
        .where(
          (finding) =>
              finding.id != currentFinding?.id &&
              finding.vehicleComponentId != null &&
              (finding.reviewState == FindingReviewState.proposed ||
                  finding.reviewState == FindingReviewState.confirmed),
        )
        .map(
          (finding) => VehicleComponentExistingFinding(
            id: finding.id,
            componentId: finding.vehicleComponentId!,
            reviewState: finding.reviewState,
            damageType: finding.damageType,
          ),
        )
        .toList(growable: false),
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
    await _showFields(
      title: 'Review finding',
      finding: finding,
      fields: [
        _Field(
          'vehicleComponent',
          'Vehicle Component',
          'vehicle-component',
          finding.vehicleComponentId?.wireValue ?? '',
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
      requiredFields: {'vehicleComponent', 'damageType', 'reason'},
      overrideRequired: finding.additionalViewRequests.isNotEmpty,
      actionFromValues: (values) => ConfirmFindingAction(
        findingId: finding.id,
        vehicleComponentId: VehicleComponentId.fromWire(
          values['vehicleComponent']!,
        ),
        damageType: values['damageType']!,
        reason: values['reason']!,
        additionalViewOverrideReason: _nullable(values['override']!),
      ),
    );
  }

  Future<void> _edit(DamageFinding finding) async {
    await _showFields(
      title: 'Edit Finding',
      finding: finding,
      fields: [
        _Field(
          'vehicleComponent',
          'Vehicle Component',
          'vehicle-component',
          finding.vehicleComponentId?.wireValue ?? '',
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
      requiredFields: {'vehicleComponent', 'damageType', 'captures', 'reason'},
      overrideRequired: false,
      actionFromValues: (values) => EditFindingAction(
        findingId: finding.id,
        vehicleComponentId: VehicleComponentId.fromWire(
          values['vehicleComponent']!,
        ),
        damageType: values['damageType']!,
        supportingCaptureIds: _csv(values['captures']!),
        reason: values['reason']!,
      ),
    );
  }

  Future<void> _dismiss(DamageFinding finding) async {
    await _showFields(
      title: 'Dismiss Finding',
      fields: const [
        _Field('reason', 'Reason', 'reason'),
        _Field(
          'override',
          'Additional-view override reason',
          'override-reason',
        ),
      ],
      requiredFields: {'reason'},
      overrideRequired: finding.additionalViewRequests.isNotEmpty,
      actionFromValues: (values) => DismissFindingAction(
        findingId: finding.id,
        reason: values['reason']!,
        additionalViewOverrideReason: _nullable(values['override']!),
      ),
    );
  }

  Future<void> _addManual({VehicleComponentId? initialComponent}) async {
    await _showFields(
      title: 'Add manual Finding',
      fields: [
        _Field(
          'vehicleComponent',
          'Vehicle Component',
          'vehicle-component',
          initialComponent?.wireValue ?? '',
        ),
        const _Field('damageType', 'Damage Type', 'damage-type'),
        const _Field('captures', 'Supporting Capture IDs', 'capture-ids'),
        const _Field(
          'observations',
          'Matching Observation IDs',
          'observation-ids',
        ),
        const _Field(
          'evidenceNote',
          'Appraiser evidence note',
          'evidence-note',
        ),
        const _Field('reason', 'Reason', 'reason'),
      ],
      requiredFields: {
        'vehicleComponent',
        'damageType',
        'captures',
        'evidenceNote',
        'reason',
      },
      overrideRequired: false,
      actionFromValues: (values) => AddManualFindingAction(
        vehicleComponentId: VehicleComponentId.fromWire(
          values['vehicleComponent']!,
        ),
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
    final formKey = GlobalKey<FormState>();
    var conflicting = finding.hasConflictingViews;
    var saving = false;
    String? saveError;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            scrollable: true,
            title: const Text('Record uncertainty'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
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
                    TextFormField(
                      key: const Key('additional-views'),
                      controller: requests,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Specific additional-view requests',
                      ),
                    ),
                    TextFormField(
                      key: const Key('reason'),
                      controller: reason,
                      minLines: 2,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Reason is required.'
                          : null,
                      decoration: const InputDecoration(labelText: 'Reason *'),
                    ),
                    if (saveError != null)
                      Text(
                        saveError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('submit-action'),
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          saving = true;
                          saveError = null;
                        });
                        await widget.controller.submit(
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
                        );
                        if (!context.mounted) return;
                        if (widget.controller.state.phase ==
                            FindingReviewPhase.ready) {
                          Navigator.pop(context);
                        } else {
                          setDialogState(() {
                            saving = false;
                            saveError =
                                widget.controller.state.message ??
                                'Unable to save uncertainty.';
                          });
                        }
                      },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markUndetermined(DamageFinding finding) async {
    await _showFields(
      title: 'Mark Undetermined',
      fields: const [
        _Field('reason', 'Reason', 'reason'),
        _Field(
          'override',
          'Additional-view override reason',
          'override-reason',
        ),
      ],
      requiredFields: {'reason'},
      overrideRequired: finding.additionalViewRequests.isNotEmpty,
      actionFromValues: (values) => MarkFindingUndeterminedAction(
        findingId: finding.id,
        reason: values['reason']!,
        additionalViewOverrideReason: _nullable(values['override']!),
      ),
    );
  }

  Future<void> _mergeSelected() async {
    await _showFields(
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
      requiredFields: {'vehicleComponent', 'damageType', 'reason'},
      overrideRequired: _selectedFindingIds.any(
        (id) => widget.controller.state.assessment!.findings.any(
          (finding) =>
              finding.id == id && finding.additionalViewRequests.isNotEmpty,
        ),
      ),
      actionFromValues: (values) => MergeFindingsAction(
        findingIds: _selectedFindingIds.toList(),
        vehicleComponentId: VehicleComponentId.fromWire(
          values['vehicleComponent']!,
        ),
        damageType: values['damageType']!,
        reason: values['reason']!,
        additionalViewOverrideReason: _nullable(values['override']!),
      ),
    );
    if (mounted && widget.controller.state.phase == FindingReviewPhase.ready) {
      setState(() {
        _selectedFindingIds.clear();
        _isMergeMode = false;
      });
    }
  }

  Future<void> _split(DamageFinding finding) async {
    await _showFields(
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
      requiredFields: {
        'part1Component',
        'part1Type',
        'part1Captures',
        'part2Component',
        'part2Type',
        'part2Captures',
        'reason',
      },
      overrideRequired: finding.additionalViewRequests.isNotEmpty,
      actionFromValues: (values) => SplitFindingAction(
        findingId: finding.id,
        parts: [
          SplitFindingPart(
            vehicleComponentId: VehicleComponentId.fromWire(
              values['part1Component']!,
            ),
            damageType: values['part1Type']!,
            observationIds: _csv(values['part1Observations']!),
            supportingCaptureIds: _csv(values['part1Captures']!),
          ),
          SplitFindingPart(
            vehicleComponentId: VehicleComponentId.fromWire(
              values['part2Component']!,
            ),
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

  Future<void> _showFields({
    required String title,
    DamageFinding? finding,
    required List<_Field> fields,
    required Set<String> requiredFields,
    required bool overrideRequired,
    required FindingReviewAction Function(Map<String, String>) actionFromValues,
  }) async {
    final assessment = widget.controller.state.assessment!;
    final componentIsSuggestion =
        finding?.reviewState == FindingReviewState.proposed;
    final hasExistingComponent = finding?.vehicleComponentId != null;
    final detectorResult =
        componentIsSuggestion && !hasExistingComponent && finding != null
        ? VehicleComponentDetectorAdapter.resolveAll(
            finding.observationIds.map(
              (observationId) => assessment.observations
                  .firstWhere((observation) => observation.id == observationId)
                  .rawClass,
            ),
          )
        : null;
    final pickerEvidence = _pickerEvidenceFor(assessment, finding);
    final existingFindings = _existingFindingsFor(assessment, finding);
    final controllers = {
      for (final field in fields)
        field.name: TextEditingController(
          text:
              componentIsSuggestion &&
                  !hasExistingComponent &&
                  field.name == 'vehicleComponent'
              ? ''
              : field.initial,
        ),
    };
    final formKey = GlobalKey<FormState>();
    String? saveError;
    var saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            scrollable: true,
            title: Text(title),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (finding != null) ...[
                      _dialogEvidence(assessment, finding),
                      const SizedBox(height: 12),
                    ],
                    for (final field in fields)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child:
                            field.name == 'vehicleComponent' ||
                                field.name.endsWith('Component')
                            ? VehicleComponentSelector(
                                key: Key(field.keyName),
                                label: field.label,
                                value:
                                    componentIsSuggestion &&
                                        !hasExistingComponent &&
                                        field.name == 'vehicleComponent'
                                    ? null
                                    : field.initial.isEmpty
                                    ? null
                                    : VehicleComponentId.fromWire(
                                        field.initial,
                                      ),
                                detectorResult:
                                    componentIsSuggestion &&
                                        !hasExistingComponent &&
                                        field.name == 'vehicleComponent'
                                    ? detectorResult
                                    : null,
                                evidence: pickerEvidence,
                                existingFindings: existingFindings,
                                onChanged: (value) =>
                                    controllers[field.name]!.text =
                                        value.wireValue,
                              )
                            : field.name == 'captures' ||
                                  field.name.endsWith('Captures')
                            ? AssessmentEvidenceSelector(
                                key: Key(field.keyName),
                                label: field.label.replaceAll(' IDs', 's'),
                                captures: assessment.captures,
                                initialIds: _csv(field.initial),
                                onChanged: (ids) =>
                                    controllers[field.name]!.text = ids.join(
                                      ', ',
                                    ),
                              )
                            : field.name == 'observations' ||
                                  field.name.endsWith('Observations')
                            ? AssessmentObservationSelector(
                                key: Key(field.keyName),
                                label: field.label.replaceAll(' IDs', 's'),
                                observations: assessment.observations,
                                captures: assessment.captures,
                                initialIds: _csv(field.initial),
                                onChanged: (ids) =>
                                    controllers[field.name]!.text = ids.join(
                                      ', ',
                                    ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    requiredFields.contains(field.name) ||
                                            (field.name == 'override' &&
                                                overrideRequired)
                                        ? '${field.label} *'
                                        : field.label,
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    key: Key(field.keyName),
                                    controller: controllers[field.name],
                                    minLines: _isNoteField(field.name) ? 2 : 1,
                                    maxLines: _isNoteField(field.name) ? 4 : 1,
                                    keyboardType: _isNoteField(field.name)
                                        ? TextInputType.multiline
                                        : TextInputType.text,
                                    textInputAction: _isNoteField(field.name)
                                        ? TextInputAction.newline
                                        : TextInputAction.next,
                                    validator: (value) =>
                                        (requiredFields.contains(field.name) ||
                                                (field.name == 'override' &&
                                                    overrideRequired)) &&
                                            (value?.trim().isEmpty ?? true)
                                        ? '${field.label} is required.'
                                        : null,
                                    decoration: InputDecoration(
                                      hintText: field.label,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    if (saveError != null)
                      Text(
                        saveError!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('submit-action'),
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          saving = true;
                          saveError = null;
                        });
                        await widget.controller.submit(
                          actionFromValues({
                            for (final entry in controllers.entries)
                              entry.key: entry.value.text,
                          }),
                        );
                        if (!dialogContext.mounted) return;
                        if (widget.controller.state.phase ==
                            FindingReviewPhase.ready) {
                          Navigator.pop(dialogContext);
                        } else {
                          setDialogState(() {
                            saving = false;
                            saveError =
                                widget.controller.state.message ??
                                'Unable to save Finding.';
                          });
                        }
                      },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogEvidence(IntakeAssessment assessment, DamageFinding finding) {
    final observation = assessment.observations
        .where((value) => finding.observationIds.contains(value.id))
        .firstOrNull;
    final capture = observation == null
        ? assessment.captures
              .where((value) => finding.supportingCaptureIds.contains(value.id))
              .firstOrNull
        : _captureById(assessment, observation.captureId);
    if (capture == null) return const Text('No supporting photo is available.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Supporting photo • tap to zoom'),
        const SizedBox(height: 6),
        InkWell(
          key: Key('dialog-evidence-${finding.id}'),
          onTap: () => observation == null
              ? _showCaptureEvidence(capture)
              : _showObservationEvidence(capture, observation),
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: observation == null
                ? Image.file(
                    File(capture.localPath),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.image_not_supported_outlined),
                  )
                : ObservationImageOverlay(
                    capture: capture,
                    observation: observation,
                    imageKey: Key('dialog-evidence-image-${finding.id}'),
                    boundsKey: Key('dialog-evidence-bounds-${finding.id}'),
                    outlineColor: Theme.of(context).colorScheme.tertiary,
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCaptureEvidence(Capture capture) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Supporting photo')),
            body: SafeArea(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 8,
                child: Center(
                  child: Image.file(
                    File(capture.localPath),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

String _componentLabel(VehicleComponentId? id) => id == null
    ? 'Component not selected'
    : VehicleComponentCatalog.byId(id).label;

class _Field {
  const _Field(this.name, this.label, this.keyName, [this.initial = '']);

  final String name;
  final String label;
  final String keyName;
  final String initial;
}

bool _isNoteField(String name) =>
    name == 'reason' || name == 'override' || name == 'evidenceNote';

String? _nullable(String value) => value.trim().isEmpty ? null : value;

List<String> _csv(String value) => value
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();
