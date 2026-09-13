import 'package:flutter/material.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_completion_controller.dart';
import 'package:autodentifyr/services/assessment_report_service.dart';

typedef AssessmentReportArtifactCallback =
    Future<void> Function(AssessmentReportArtifact artifact);

class AssessmentCompletionScreen extends StatefulWidget {
  AssessmentCompletionScreen({
    super.key,
    required this.controller,
    AssessmentReportService? reportService,
    this.onReportArtifact,
  }) : reportService = reportService ?? AssessmentReportService();

  final AssessmentCompletionController controller;
  final AssessmentReportService reportService;
  final AssessmentReportArtifactCallback? onReportArtifact;

  @override
  State<AssessmentCompletionScreen> createState() =>
      _AssessmentCompletionScreenState();
}

class _AssessmentCompletionScreenState
    extends State<AssessmentCompletionScreen> {
  bool _noVisibleDamageConfirmed = false;
  String? _selectedRevisionId;

  @override
  void initState() {
    super.initState();
    if (widget.controller.state.phase == AssessmentCompletionPhase.idle) {
      widget.controller.load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Complete assessment')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => _buildState(widget.controller.state),
      ),
    ),
  );

  Widget _buildState(AssessmentCompletionState state) {
    if (state.phase == AssessmentCompletionPhase.idle ||
        state.phase == AssessmentCompletionPhase.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final assessment = state.assessment;
    if (assessment == null) {
      return Center(
        child: Text(state.message ?? 'Intake Assessment unavailable.'),
      );
    }
    final confirmedCount = assessment.findings
        .where((finding) => finding.reviewState == FindingReviewState.confirmed)
        .length;
    final substantiveBlockers = state.completionBlockers
        .where(
          (blocker) =>
              blocker.code !=
              CompletionBlockerCode.noVisibleDamageConfirmationRequired,
        )
        .toList();
    final selectedRevisionId =
        _selectedRevisionId ??
        (assessment.completedRevisions.isEmpty
            ? null
            : assessment.completedRevisions.last.id);
    final document = selectedRevisionId == null
        ? null
        : widget.reportService.build(
            assessment: assessment,
            revisionId: selectedRevisionId,
          );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.message != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(state.message!),
            ),
          ),
        Text(
          _statusName(assessment.status),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        if (assessment.status == IntakeAssessmentStatus.draft) ...[
          Text(
            'Review before completing',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('Vehicle: ${assessment.vehicle.id}'),
          if (assessment.vehicle.vin != null)
            Text('VIN: ${assessment.vehicle.vin}'),
          if (assessment.vehicle.licencePlate != null)
            Text('Licence plate: ${assessment.vehicle.licencePlate}'),
          const SizedBox(height: 8),
          Text(
            assessment.estimate?.isPartial ?? false
                ? 'Partial Estimate reviewed'
                : 'Assessment Estimate reviewed',
          ),
          for (final assumption
              in assessment.estimate?.assumptions ?? const <String>[])
            Text(assumption),
          const SizedBox(height: 8),
          Text('Limitations', style: Theme.of(context).textTheme.titleMedium),
          if (assessment.limitations.isEmpty)
            const Text('No additional limitations recorded.')
          else
            for (final limitation in assessment.limitations) Text(limitation),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('edit-assessment-limitations'),
              onPressed: state.phase == AssessmentCompletionPhase.saving
                  ? null
                  : () => _editLimitations(assessment.limitations),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Edit limitations'),
            ),
          ),
          const Text(
            'Completing confirms the displayed estimate, assumptions, limitations, and Appraiser attribution.',
          ),
          const SizedBox(height: 20),
          Text(
            'Completion Gate',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final blocker in substantiveBlockers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.error_outline),
              title: Text(blocker.message),
            ),
          if (confirmedCount == 0)
            CheckboxListTile(
              key: const Key('confirm-no-visible-damage'),
              contentPadding: EdgeInsets.zero,
              value: _noVisibleDamageConfirmed,
              onChanged: state.phase == AssessmentCompletionPhase.saving
                  ? null
                  : (value) => setState(
                      () => _noVisibleDamageConfirmed = value ?? false,
                    ),
              title: const Text(
                'Confirm that no supported visible exterior damage was found.',
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('complete-assessment'),
            onPressed:
                state.phase == AssessmentCompletionPhase.saving ||
                    substantiveBlockers.isNotEmpty ||
                    (confirmedCount == 0 && !_noVisibleDamageConfirmed)
                ? null
                : () => widget.controller.complete(
                    noVisibleDamageConfirmed: confirmedCount == 0,
                  ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Complete assessment'),
          ),
        ] else if (assessment.status == IntakeAssessmentStatus.completed) ...[
          FilledButton.icon(
            key: const Key('reopen-assessment'),
            onPressed: state.phase == AssessmentCompletionPhase.saving
                ? null
                : widget.controller.reopen,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Reopen as Draft'),
          ),
        ],
        if (assessment.status != IntakeAssessmentStatus.voided) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('void-assessment'),
            onPressed: state.phase == AssessmentCompletionPhase.saving
                ? null
                : _voidAssessment,
            icon: const Icon(Icons.block),
            label: const Text('Void assessment'),
          ),
        ],
        if (assessment.completedRevisions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Revision history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final revision in assessment.completedRevisions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: ChoiceChip(
                key: Key('revision-${revision.id}'),
                selected: selectedRevisionId == revision.id,
                onSelected: (_) =>
                    setState(() => _selectedRevisionId = revision.id),
                label: Text('Revision ${revision.revisionNumber}'),
              ),
              subtitle: Text(
                '${revision.completedByName} - ${revision.completedAt.toUtc().toIso8601String()}',
              ),
            ),
        ],
        if (document != null) ...[
          const Divider(height: 32),
          PreliminaryDamageAssessmentReportView(document: document),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('render-pdf-report'),
                onPressed: () async => _deliver(
                  await const AssessmentPdfReportRenderer().render(document),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Create PDF'),
              ),
              OutlinedButton.icon(
                key: const Key('render-shared-image-report'),
                onPressed: () => _deliver(
                  const AssessmentSharedImageReportRenderer().render(document),
                ),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Create shared image'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _deliver(AssessmentReportArtifact artifact) async {
    await widget.onReportArtifact?.call(artifact);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${artifact.mimeType} report created.')),
    );
  }

  Future<void> _voidAssessment() async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void Intake Assessment'),
        content: TextField(
          key: const Key('void-reason'),
          controller: reason,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-void-assessment'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    final value = reason.text;
    reason.dispose();
    if (confirmed == true) {
      await widget.controller.voidAssessment(reason: value);
    }
  }

  Future<void> _editLimitations(List<String> current) async {
    final limitations = TextEditingController(text: current.join('\n'));
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assessment limitations'),
        content: TextField(
          key: const Key('assessment-limitations'),
          controller: limitations,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'One limitation per line',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('save-assessment-limitations'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final values = limitations.text
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    limitations.dispose();
    if (submitted == true) {
      await widget.controller.updateLimitations(values);
    }
  }

  String _statusName(IntakeAssessmentStatus status) => switch (status) {
    IntakeAssessmentStatus.draft => 'Draft',
    IntakeAssessmentStatus.completed => 'Completed',
    IntakeAssessmentStatus.voided => 'Voided',
  };
}

class PreliminaryDamageAssessmentReportView extends StatelessWidget {
  const PreliminaryDamageAssessmentReportView({
    super.key,
    required this.document,
  });

  final AssessmentReportDocument document;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(document.title, style: Theme.of(context).textTheme.headlineSmall),
      for (final section in document.sections) ...[
        const SizedBox(height: 12),
        Text(section.heading, style: Theme.of(context).textTheme.titleMedium),
        for (final line in section.lines) Text(line),
      ],
    ],
  );
}
