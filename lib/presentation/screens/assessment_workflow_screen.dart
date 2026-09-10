import 'package:flutter/material.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_workflow_controller.dart';

typedef AssessmentStageOpener =
    Future<void> Function(BuildContext context, String assessmentId);

class AssessmentWorkflowScreen extends StatefulWidget {
  const AssessmentWorkflowScreen({
    super.key,
    required this.controller,
    required this.openEvidence,
    required this.openFindings,
    required this.openEstimate,
    required this.openSeverity,
    required this.openCompletion,
  });

  final AssessmentWorkflowController controller;
  final AssessmentStageOpener openEvidence;
  final AssessmentStageOpener openFindings;
  final AssessmentStageOpener openEstimate;
  final AssessmentStageOpener openSeverity;
  final AssessmentStageOpener openCompletion;

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
    appBar: AppBar(title: const Text('Intake Assessments')),
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
                  title: Text(assessment.vehicle.id),
                  subtitle: Text(
                    '${_statusName(assessment.status)} • ${assessment.appraiserProfile.displayName}\n'
                    'Updated ${assessment.updatedAt.toLocal()}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .push<void>(
                        MaterialPageRoute(
                          builder: (context) => _AssessmentWorkspaceScreen(
                            assessmentId: assessment.id,
                            controller: widget.controller,
                            openEvidence: widget.openEvidence,
                            openFindings: widget.openFindings,
                            openEstimate: widget.openEstimate,
                            openSeverity: widget.openSeverity,
                            openCompletion: widget.openCompletion,
                            startAnother: _startAssessment,
                          ),
                        ),
                      )
                      .then((_) => widget.controller.load()),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _startAssessment([Vehicle? existingVehicle]) async {
    var vehicleId = existingVehicle?.id ?? '';
    var vin = existingVehicle?.vin ?? '';
    var licencePlate = existingVehicle?.licencePlate ?? '';
    var appraiserId = '';
    var appraiserName = '';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existingVehicle == null
              ? 'New Intake Assessment'
              : 'Another Intake Assessment',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(
                initialValue: vehicleId,
                label: 'Vehicle ID',
                key: 'vehicle-id',
                onChanged: (value) => vehicleId = value,
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
              _field(
                initialValue: appraiserId,
                label: 'Appraiser Profile ID',
                key: 'appraiser-id',
                onChanged: (value) => appraiserId = value,
              ),
              _field(
                initialValue: appraiserName,
                label: 'Appraiser name',
                key: 'appraiser-name',
                onChanged: (value) => appraiserName = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('start-assessment'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start Draft'),
          ),
        ],
      ),
    );
    final vehicle = Vehicle(
      id: vehicleId.trim(),
      vin: _optional(vin),
      licencePlate: _optional(licencePlate),
    );
    final appraiser = AppraiserProfile(
      id: appraiserId.trim(),
      displayName: appraiserName.trim(),
    );
    if (submitted == true) {
      await widget.controller.startAssessment(
        vehicle: vehicle,
        appraiserProfile: appraiser,
      );
    }
  }

  Widget _field({
    required String initialValue,
    required String label,
    required String key,
    required ValueChanged<String> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      key: Key(key),
      initialValue: initialValue,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
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
    required this.startAnother,
  });

  final String assessmentId;
  final AssessmentWorkflowController controller;
  final AssessmentStageOpener openEvidence;
  final AssessmentStageOpener openFindings;
  final AssessmentStageOpener openEstimate;
  final AssessmentStageOpener openSeverity;
  final AssessmentStageOpener openCompletion;
  final Future<void> Function([Vehicle? vehicle]) startAnother;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Assessment workspace')),
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                assessment.vehicle.id,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(_statusName(assessment.status)),
              Text('Appraiser: ${assessment.appraiserProfile.displayName}'),
              if (assessment.vehicle.vin != null)
                Text('VIN: ${assessment.vehicle.vin}'),
              if (assessment.vehicle.licencePlate != null)
                Text('Licence plate: ${assessment.vehicle.licencePlate}'),
              const SizedBox(height: 20),
              _stage(
                key: 'open-evidence',
                icon: Icons.add_a_photo_outlined,
                label: 'Capture evidence',
                enabled: editable,
                onPressed: openEvidence,
                context: context,
              ),
              _stage(
                key: 'open-findings',
                icon: Icons.fact_check_outlined,
                label: 'Review Findings',
                enabled: editable,
                onPressed: openFindings,
                context: context,
              ),
              _stage(
                key: 'open-estimate',
                icon: Icons.receipt_long_outlined,
                label: 'Review Assessment Estimate',
                enabled: editable,
                onPressed: openEstimate,
                context: context,
              ),
              _stage(
                key: 'open-severity',
                icon: Icons.monitor_heart_outlined,
                label: 'Review Severity',
                enabled: editable,
                onPressed: openSeverity,
                context: context,
              ),
              _stage(
                key: 'open-completion',
                icon: Icons.task_alt_outlined,
                label: editable ? 'Completion Gate' : 'Revisions and Reports',
                enabled: true,
                onPressed: openCompletion,
                context: context,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await startAnother(assessment.vehicle);
                  if (context.mounted) Navigator.pop(context);
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

  Widget _stage({
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
      trailing: const Icon(Icons.chevron_right),
      onTap: enabled
          ? () async {
              await onPressed(context, assessmentId);
              await controller.load();
            }
          : null,
    ),
  );
}

String _statusName(IntakeAssessmentStatus status) => switch (status) {
  IntakeAssessmentStatus.draft => 'Draft',
  IntakeAssessmentStatus.completed => 'Completed',
  IntakeAssessmentStatus.voided => 'Voided',
};
