import 'package:flutter/material.dart';
import 'package:autodentifyr/presentation/widgets/assessment_date_time.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_workflow_controller.dart';
import 'package:autodentifyr/presentation/controllers/assessment_progress.dart';
import 'package:autodentifyr/services/assessment_repository.dart';

typedef AssessmentStageOpener =
    Future<void> Function(BuildContext context, String assessmentId);
typedef GuidedAssessmentStageOpener =
    Future<bool?> Function(
      BuildContext context,
      String assessmentId,
      AssessmentStage stage,
    );

String _vehicleLabel(Vehicle vehicle) {
  final label = vehicle.displayLabel?.trim();
  if (label != null && label.isNotEmpty) return label;
  final plate = vehicle.licencePlate?.trim();
  if (plate != null && plate.isNotEmpty) return 'Plate $plate';
  final vin = vehicle.vin?.trim();
  if (vin != null && vin.isNotEmpty) return 'VIN $vin';
  if (!vehicle.id.startsWith('vehicle-')) return vehicle.id;
  final generatedPart = vehicle.id.substring('vehicle-'.length);
  final shortId = generatedPart.length > 8
      ? generatedPart.substring(generatedPart.length - 8)
      : generatedPart;
  return 'Vehicle $shortId';
}

class AssessmentWorkflowScreen extends StatefulWidget {
  const AssessmentWorkflowScreen({
    super.key,
    required this.controller,
    required this.openEvidence,
    required this.openFindings,
    required this.openEstimate,
    required this.openSeverity,
    required this.openCompletion,
    this.openGuidedStage,
  });

  final AssessmentWorkflowController controller;
  final AssessmentStageOpener openEvidence;
  final AssessmentStageOpener openFindings;
  final AssessmentStageOpener openEstimate;
  final AssessmentStageOpener openSeverity;
  final AssessmentStageOpener openCompletion;
  final GuidedAssessmentStageOpener? openGuidedStage;

  @override
  State<AssessmentWorkflowScreen> createState() =>
      _AssessmentWorkflowScreenState();
}

class _AssessmentWorkflowScreenState extends State<AssessmentWorkflowScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.state.phase == AssessmentWorkflowPhase.idle) {
      widget.controller.load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Assessment Workspace')),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('new-assessment'),
      onPressed: () => _startAssessment(),
      icon: const Icon(Icons.add),
      label: const Text('New assessment'),
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => _buildState(widget.controller.state),
      ),
    ),
  );

  Widget _buildState(AssessmentWorkflowState state) {
    if (state.phase == AssessmentWorkflowPhase.idle ||
        (state.phase == AssessmentWorkflowPhase.loading &&
            state.assessments.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: widget.controller.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (state.message != null)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(state.message!),
              ),
            ),
          if (state.assessments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(
                child: Text('No device-local Intake Assessments yet.'),
              ),
            )
          else ...[
            Text(
              '${state.vehicles.length} Vehicle${state.vehicles.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final assessment in state.assessments)
              Card(
                child: ListTile(
                  key: Key('assessment-${assessment.id}'),
                  title: Text(_vehicleLabel(assessment.vehicle)),
                  subtitle: Text(
                    '${_statusName(assessment.status)} • ${assessment.appraiserProfile.displayName}\n'
                    'Updated ${formatAssessmentDateTime(context, assessment.updatedAt)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openWorkspace(assessment.id),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _openWorkspace(String assessmentId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => _AssessmentWorkspaceScreen(
          assessmentId: assessmentId,
          controller: widget.controller,
          openEvidence: widget.openEvidence,
          openFindings: widget.openFindings,
          openEstimate: widget.openEstimate,
          openSeverity: widget.openSeverity,
          openCompletion: widget.openCompletion,
          openGuidedStage: widget.openGuidedStage,
          startAnother: _startAssessment,
        ),
      ),
    );
    await widget.controller.load();
  }

  Future<void> _startAssessment([Vehicle? existingVehicle]) async {
    final vehicles = widget.controller.state.vehicles;
    final profiles = widget.controller.state.appraiserProfiles;
    Vehicle? selectedVehicle = existingVehicle == null
        ? null
        : vehicles
              .where((vehicle) => vehicle.id == existingVehicle.id)
              .firstOrNull;
    AppraiserProfile? selectedProfile = profiles.firstOrNull;
    var createVehicle = existingVehicle == null;
    var createProfile = profiles.isEmpty;
    var displayLabel = '';
    var vin = '';
    var licencePlate = '';
    var appraiserName = '';
    String? newVehicleId;
    String? newProfileId;
    final formKey = GlobalKey<FormState>();
    String? saveError;
    var saving = false;
    final createdId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(
              existingVehicle == null
                  ? 'New Intake Assessment'
                  : 'Another Intake Assessment',
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (vehicles.isNotEmpty) ...[
                      Wrap(
                        key: const Key('vehicle-choice'),
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Existing vehicle'),
                            selected: !createVehicle,
                            onSelected: saving
                                ? null
                                : (_) => setDialogState(
                                    () => createVehicle = false,
                                  ),
                          ),
                          ChoiceChip(
                            label: const Text('New vehicle'),
                            selected: createVehicle,
                            onSelected: saving
                                ? null
                                : (_) => setDialogState(
                                    () => createVehicle = true,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (!createVehicle)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Vehicle *'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<Vehicle>(
                            key: const Key('vehicle-selector'),
                            isExpanded: true,
                            itemHeight: null,
                            initialValue: selectedVehicle,
                            items: [
                              for (final vehicle in vehicles)
                                DropdownMenuItem(
                                  value: vehicle,
                                  child: Text(
                                    _vehicleLabel(vehicle),
                                    softWrap: true,
                                  ),
                                ),
                            ],
                            onChanged: saving
                                ? null
                                : (value) => setDialogState(
                                    () => selectedVehicle = value,
                                  ),
                            validator: (value) =>
                                value == null ? 'Select a Vehicle.' : null,
                            decoration: const InputDecoration(
                              hintText: 'Select a Vehicle',
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _field(
                        initialValue: displayLabel,
                        label: 'Vehicle description (optional)',
                        key: 'vehicle-display-label',
                        onChanged: (value) => displayLabel = value,
                      ),
                      _field(
                        initialValue: vin,
                        label: 'VIN (optional)',
                        key: 'vehicle-vin',
                        onChanged: (value) => vin = value,
                      ),
                      _field(
                        initialValue: licencePlate,
                        label: 'Licence plate (optional)',
                        key: 'vehicle-licence-plate',
                        onChanged: (value) => licencePlate = value,
                      ),
                    ],
                    if (profiles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        key: const Key('appraiser-choice'),
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Select Appraiser'),
                            selected: !createProfile,
                            onSelected: saving
                                ? null
                                : (_) => setDialogState(
                                    () => createProfile = false,
                                  ),
                          ),
                          ChoiceChip(
                            label: const Text('New Appraiser'),
                            selected: createProfile,
                            onSelected: saving
                                ? null
                                : (_) => setDialogState(
                                    () => createProfile = true,
                                  ),
                          ),
                        ],
                      ),
                    ],
                    if (!createProfile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Declared Appraiser Profile *'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<AppraiserProfile>(
                            key: const Key('appraiser-selector'),
                            isExpanded: true,
                            itemHeight: null,
                            initialValue: selectedProfile,
                            items: [
                              for (final profile in profiles)
                                DropdownMenuItem(
                                  value: profile,
                                  child: Text(
                                    profile.displayName,
                                    softWrap: true,
                                  ),
                                ),
                            ],
                            onChanged: saving
                                ? null
                                : (value) => setDialogState(
                                    () => selectedProfile = value,
                                  ),
                            validator: (value) => value == null
                                ? 'Select an Appraiser Profile.'
                                : null,
                            decoration: const InputDecoration(
                              hintText: 'Select an Appraiser Profile',
                            ),
                          ),
                        ],
                      )
                    else
                      _field(
                        initialValue: appraiserName,
                        label: 'Appraiser name',
                        key: 'appraiser-name',
                        required: true,
                        onChanged: (value) => appraiserName = value,
                      ),
                    const Text(
                      'Appraiser Profiles are device-local declared identities.',
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
                key: const Key('start-assessment'),
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          saving = true;
                          saveError = null;
                        });
                        final createdId = await widget.controller
                            .startAssessment(
                              vehicle: createVehicle
                                  ? Vehicle(
                                      id: newVehicleId ??= widget.controller
                                          .generateVehicleId(),
                                      displayLabel: _optional(displayLabel),
                                      vin: _optional(vin),
                                      licencePlate: _optional(licencePlate),
                                    )
                                  : selectedVehicle!,
                              appraiserProfile: createProfile
                                  ? AppraiserProfile(
                                      id: newProfileId ??= widget.controller
                                          .generateAppraiserProfileId(),
                                      displayName: appraiserName.trim(),
                                    )
                                  : selectedProfile!,
                            );
                        if (!dialogContext.mounted) return;
                        if (createdId != null) {
                          Navigator.pop(dialogContext, createdId);
                        } else {
                          setDialogState(() {
                            saving = false;
                            saveError =
                                widget.controller.state.message ??
                                'Unable to save Intake Assessment.';
                          });
                        }
                      },
                child: const Text('Start Draft'),
              ),
            ],
          ),
        ),
      ),
    );
    if (createdId != null && mounted) await _openWorkspace(createdId);
  }

  Widget _field({
    required String initialValue,
    required String label,
    required String key,
    required ValueChanged<String> onChanged,
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(required ? '$label *' : label),
        const SizedBox(height: 6),
        TextFormField(
          key: Key(key),
          initialValue: initialValue,
          onChanged: onChanged,
          validator: required
              ? (value) => (value?.trim().isEmpty ?? true)
                    ? '$label is required.'
                    : null
              : null,
          decoration: InputDecoration(hintText: label),
        ),
      ],
    ),
  );

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _AssessmentWorkspaceScreen extends StatelessWidget {
  const _AssessmentWorkspaceScreen({
    required this.assessmentId,
    required this.controller,
    required this.openEvidence,
    required this.openFindings,
    required this.openEstimate,
    required this.openSeverity,
    required this.openCompletion,
    required this.openGuidedStage,
    required this.startAnother,
  });

  final String assessmentId;
  final AssessmentWorkflowController controller;
  final AssessmentStageOpener openEvidence;
  final AssessmentStageOpener openFindings;
  final AssessmentStageOpener openEstimate;
  final AssessmentStageOpener openSeverity;
  final AssessmentStageOpener openCompletion;
  final GuidedAssessmentStageOpener? openGuidedStage;
  final Future<void> Function([Vehicle? vehicle]) startAnother;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Assessment Workspace')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final assessment = controller.state.assessments
              .where((value) => value.id == assessmentId)
              .firstOrNull;
          if (assessment == null) {
            return const Center(child: Text('Intake Assessment unavailable.'));
          }
          final editable = assessment.status == IntakeAssessmentStatus.draft;
          final deleting =
              controller.state.phase == AssessmentWorkflowPhase.deleting;
          final progress = AssessmentProgress.fromAssessment(assessment);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _vehicleLabel(assessment.vehicle),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(_statusName(assessment.status)),
              if (editable) ...[
                Text(
                  '${progress.readyStageCount} of 5 stages ready • '
                  '${progress.outstandingCount} outstanding before completion',
                ),
                LinearProgressIndicator(value: progress.readyStageCount / 5),
              ],
              Text('Appraiser: ${assessment.appraiserProfile.displayName}'),
              if (assessment.vehicle.vin != null)
                Text('VIN: ${assessment.vehicle.vin}'),
              if (assessment.vehicle.licencePlate != null)
                Text('Licence plate: ${assessment.vehicle.licencePlate}'),
              const SizedBox(height: 20),
              _stage(
                stage: AssessmentStage.evidence,
                progress: progress,
                key: 'open-evidence',
                icon: Icons.add_a_photo_outlined,
                label: 'Capture evidence',
                enabled: editable,
                onPressed: openEvidence,
                context: context,
              ),
              _stage(
                stage: AssessmentStage.findings,
                progress: progress,
                key: 'open-findings',
                icon: Icons.fact_check_outlined,
                label: 'Review Findings',
                enabled: editable,
                onPressed: openFindings,
                context: context,
              ),
              _stage(
                stage: AssessmentStage.severity,
                progress: progress,
                key: 'open-severity',
                icon: Icons.monitor_heart_outlined,
                label: 'Review Severity',
                enabled: editable,
                onPressed: openSeverity,
                context: context,
              ),
              _stage(
                stage: AssessmentStage.estimate,
                progress: progress,
                key: 'open-estimate',
                icon: Icons.receipt_long_outlined,
                label: 'Review Assessment Estimate',
                enabled: editable,
                onPressed: openEstimate,
                context: context,
              ),
              _stage(
                stage: AssessmentStage.finalReview,
                progress: progress,
                key: 'open-completion',
                icon: Icons.task_alt_outlined,
                label: editable ? 'Finish assessment' : 'Revisions and Reports',
                enabled: true,
                onPressed: openCompletion,
                context: context,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('delete-assessment'),
                onPressed: deleting
                    ? null
                    : () => _deleteAssessment(context, assessment),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete assessment'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await startAnother(assessment.vehicle);
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('New assessment for this Vehicle'),
              ),
            ],
          );
        },
      ),
    ),
  );

  Future<void> _deleteAssessment(
    BuildContext context,
    IntakeAssessment assessment,
  ) async {
    final status = _statusName(assessment.status);
    final historical = assessment.status != IntakeAssessmentStatus.draft;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          historical ? 'Delete historical assessment?' : 'Delete assessment?',
        ),
        content: Text(
          historical
              ? 'Permanently delete the $status Intake Assessment for '
                    '${_vehicleLabel(assessment.vehicle)}? This will permanently '
                    'remove all completed revisions and audit history. This '
                    'cannot be undone. Exported Reports and backups are '
                    'unaffected.'
              : 'Delete the Draft assessment for '
                    '${_vehicleLabel(assessment.vehicle)}? Its history and '
                    'device-local evidence will be permanently removed. '
                    'Exported Reports and backups are unaffected.',
        ),
        actions: [
          TextButton(
            key: const Key('delete-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('delete-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: const Text('Delete assessment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await controller.deleteAssessment(assessmentId);
    if (!context.mounted) return;
    if (result is AssessmentDeleted) {
      Navigator.pop(context);
      return;
    }
    final message = result is AssessmentDeleteNotFound
        ? 'This assessment was already deleted. The workspace has been refreshed.'
        : result is AssessmentDeleteFailed
        ? result.message
        : 'Unable to delete the assessment.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _stage({
    required AssessmentStage stage,
    required AssessmentProgress progress,
    required String key,
    required IconData icon,
    required String label,
    required bool enabled,
    required AssessmentStageOpener onPressed,
    required BuildContext context,
  }) => Card(
    child: ListTile(
      key: Key(key),
      enabled: enabled,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(_stageSubtitle(progress, stage)),
      trailing: const Icon(Icons.chevron_right),
      onTap: enabled
          ? () async {
              if (openGuidedStage == null) {
                await onPressed(context, assessmentId);
                await controller.load();
              } else {
                var current = stage;
                while (true) {
                  final continueNext = await openGuidedStage!(
                    context,
                    assessmentId,
                    current,
                  );
                  await controller.load();
                  if (!context.mounted ||
                      continueNext != true ||
                      controller.state.phase != AssessmentWorkflowPhase.ready ||
                      current.next == null) {
                    break;
                  }
                  current = current.next!;
                }
              }
            }
          : null,
    ),
  );

  String _stageSubtitle(AssessmentProgress progress, AssessmentStage stage) {
    if (progress.assessment.status != IntakeAssessmentStatus.draft) {
      return _statusName(progress.assessment.status);
    }
    final summary = switch (stage) {
      AssessmentStage.evidence =>
        '${progress.acceptedCaptureCount} accepted Captures',
      AssessmentStage.findings =>
        '${progress.proposedDecisionCount} Proposed decisions needed',
      AssessmentStage.severity =>
        '${progress.currentSeverityReviewCount} of ${progress.confirmedFindingCount} Confirmed reviewed',
      AssessmentStage.estimate =>
        '${progress.currentEstimateReviewCount} of ${progress.confirmedFindingCount} Confirmed current',
      AssessmentStage.finalReview => 'Final review',
    };
    final prerequisite = progress.prerequisiteFor(stage);
    if (prerequisite != null) return '$summary • $prerequisite';
    return '$summary • ${progress.readyFor(stage) ? 'Ready' : '${progress.outstandingFor(stage)} outstanding'}';
  }
}

String _statusName(IntakeAssessmentStatus status) => switch (status) {
  IntakeAssessmentStatus.draft => 'Draft',
  IntakeAssessmentStatus.completed => 'Completed',
  IntakeAssessmentStatus.voided => 'Voided',
};
