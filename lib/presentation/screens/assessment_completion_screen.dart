import 'dart:io';

import 'package:flutter/material.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_completion_controller.dart';
import 'package:autodentifyr/presentation/widgets/assessment_date_time.dart';
import 'package:autodentifyr/services/assessment_report_delivery.dart';
import 'package:autodentifyr/services/assessment_report_service.dart';

typedef AssessmentReportArtifactCallback =
    Future<void> Function(AssessmentReportArtifact artifact);

class AssessmentCompletionScreen extends StatefulWidget {
  AssessmentCompletionScreen({
    super.key,
    required this.controller,
    AssessmentReportService? reportService,
    this.onReportArtifact,
    this.reportDelivery,
  }) : reportService = reportService ?? AssessmentReportService();

  final AssessmentCompletionController controller;
  final AssessmentReportService reportService;
  final AssessmentReportArtifactCallback? onReportArtifact;
  final AssessmentReportDelivery? reportDelivery;

  @override
  State<AssessmentCompletionScreen> createState() =>
      _AssessmentCompletionScreenState();
}

class _AssessmentCompletionScreenState
    extends State<AssessmentCompletionScreen> {
  bool _noVisibleDamageConfirmed = false;
  String? _selectedRevisionId;
  PreparedAssessmentReport? _preparedReport;
  bool _reportBusy = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller.state.phase == AssessmentCompletionPhase.idle) {
      widget.controller.load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Finish assessment')),
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
          _AssessmentSummary(
            vehicle: assessment.vehicle,
            appraiserName: assessment.appraiserProfile.displayName,
            captures: assessment.captures,
            findings: assessment.findings
                .where(
                  (finding) =>
                      finding.reviewState == FindingReviewState.confirmed,
                )
                .toList(),
            severities: assessment.severityAssessments,
            estimate: assessment.estimate,
            isSeverityCurrent: assessment.isSeverityReviewCurrentFor,
            isEstimateCurrent: assessment.isEstimateReviewCurrentFor,
          ),
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
            label: const Text('Finish assessment'),
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
                onSelected: _reportBusy
                    ? null
                    : (_) => setState(() {
                        _selectedRevisionId = revision.id;
                        _preparedReport = null;
                      }),
                label: Text('Revision ${revision.revisionNumber}'),
              ),
              subtitle: Text(
                '${revision.completedByName} • ${formatAssessmentDateTime(context, revision.completedAt)}',
              ),
            ),
        ],
        if (document != null) ...[
          const Divider(height: 32),
          Text(
            'Report preview • Revision ${document.revisionNumber}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          PreliminaryDamageAssessmentReportView(
            document: document,
            revision: assessment.completedRevisions
                .where((revision) => revision.id == selectedRevisionId)
                .first,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('render-pdf-report'),
                onPressed: _reportBusy
                    ? null
                    : () => _createReport(document, pdf: true),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Create PDF'),
              ),
              OutlinedButton.icon(
                key: const Key('render-shared-image-report'),
                onPressed: _reportBusy
                    ? null
                    : () => _createReport(document, pdf: false),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Create shared image'),
              ),
            ],
          ),
          if (_reportBusy) const LinearProgressIndicator(),
          if (_preparedReport case final prepared?
              when prepared.artifact.revisionId == selectedRevisionId) ...[
            const SizedBox(height: 12),
            Text(
              'Ready: ${prepared.fileName}',
              key: const Key('prepared-report-name'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (prepared.artifact.mimeType == 'image/png')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: Image.memory(
                    prepared.artifact.bytes,
                    key: const Key('shared-image-preview'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            const Text(
              'This file represents the selected completed revision. Review the report above before sending it.',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  key: const Key('open-prepared-report'),
                  onPressed: _reportBusy
                      ? null
                      : () => _runReportAction(
                          () => widget.reportDelivery!.open(prepared),
                          success: 'Opened ${prepared.fileName}.',
                          canceled: 'Opening canceled.',
                        ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
                TextButton.icon(
                  key: const Key('save-prepared-report'),
                  onPressed: _reportBusy
                      ? null
                      : () => _runReportAction(
                          () => widget.reportDelivery!.saveToFiles(prepared),
                          success: 'Saved ${prepared.fileName} to Files.',
                          canceled:
                              'Save canceled. Private report remains available.',
                        ),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Save to Files'),
                ),
                Builder(
                  builder: (buttonContext) => TextButton.icon(
                    key: const Key('share-prepared-report'),
                    onPressed: _reportBusy
                        ? null
                        : () {
                            final box =
                                buttonContext.findRenderObject() as RenderBox?;
                            final origin = box == null
                                ? Offset.zero & MediaQuery.sizeOf(context)
                                : box.localToGlobal(Offset.zero) & box.size;
                            _runReportAction(
                              () => widget.reportDelivery!.share(
                                prepared,
                                sharePositionOrigin: origin,
                              ),
                              success:
                                  'Share sheet opened for ${prepared.fileName}.',
                              canceled:
                                  'Share canceled. Nothing was sent by AutoDentifyr.',
                            );
                          },
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _createReport(
    AssessmentReportDocument document, {
    required bool pdf,
  }) async {
    setState(() => _reportBusy = true);
    try {
      final artifact = pdf
          ? await const AssessmentPdfReportRenderer().render(document)
          : const AssessmentSharedImageReportRenderer().render(document);
      await widget.onReportArtifact?.call(artifact);
      final prepared = await widget.reportDelivery?.prepare(artifact);
      if (!mounted) return;
      setState(() => _preparedReport = prepared);
      _reportMessage(
        prepared == null
            ? '${artifact.mimeType} report created.'
            : '${prepared.fileName} is ready. Open, save, or share it below.',
      );
    } catch (error) {
      if (mounted) _reportMessage('Could not create report: $error');
    } finally {
      if (mounted) setState(() => _reportBusy = false);
    }
  }

  Future<void> _runReportAction(
    Future<ReportDeliveryResult> Function() action, {
    required String success,
    required String canceled,
  }) async {
    setState(() => _reportBusy = true);
    try {
      final result = await action();
      if (mounted) {
        _reportMessage(
          result == ReportDeliveryResult.canceled ? canceled : success,
        );
      }
    } catch (error) {
      if (mounted) _reportMessage('Report action failed: $error');
    } finally {
      if (mounted) setState(() => _reportBusy = false);
    }
  }

  void _reportMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _voidAssessment() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _VoidAssessmentDialog(),
    );
    if (reason != null) {
      await widget.controller.voidAssessment(reason: reason);
    }
  }

  Future<void> _editLimitations(List<String> current) async {
    final limitations = await showDialog<List<String>>(
      context: context,
      builder: (context) => _EditLimitationsDialog(current: current),
    );
    if (limitations != null) {
      await widget.controller.updateLimitations(limitations);
    }
  }

  String _statusName(IntakeAssessmentStatus status) => switch (status) {
    IntakeAssessmentStatus.draft => 'Draft',
    IntakeAssessmentStatus.completed => 'Completed',
    IntakeAssessmentStatus.voided => 'Voided',
  };
}

class _VoidAssessmentDialog extends StatefulWidget {
  const _VoidAssessmentDialog();

  @override
  State<_VoidAssessmentDialog> createState() => _VoidAssessmentDialogState();
}

class _VoidAssessmentDialogState extends State<_VoidAssessmentDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Void Intake Assessment'),
    content: TextField(
      key: const Key('void-reason'),
      controller: _reason,
      minLines: 2,
      maxLines: 4,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      decoration: const InputDecoration(labelText: 'Reason'),
    ),
    actions: [
      TextButton(
        key: const Key('cancel-void-assessment'),
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('confirm-void-assessment'),
        onPressed: () => Navigator.pop(context, _reason.text),
        child: const Text('Void'),
      ),
    ],
  );
}

class _EditLimitationsDialog extends StatefulWidget {
  const _EditLimitationsDialog({required this.current});

  final List<String> current;

  @override
  State<_EditLimitationsDialog> createState() => _EditLimitationsDialogState();
}

class _EditLimitationsDialogState extends State<_EditLimitationsDialog> {
  late final TextEditingController _limitations;

  @override
  void initState() {
    super.initState();
    _limitations = TextEditingController(text: widget.current.join('\n'));
  }

  @override
  void dispose() {
    _limitations.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Assessment limitations'),
    content: TextField(
      key: const Key('assessment-limitations'),
      controller: _limitations,
      minLines: 3,
      maxLines: 6,
      decoration: const InputDecoration(labelText: 'One limitation per line'),
    ),
    actions: [
      TextButton(
        key: const Key('cancel-assessment-limitations'),
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('save-assessment-limitations'),
        onPressed: () => Navigator.pop(
          context,
          _limitations.text
              .split('\n')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(),
        ),
        child: const Text('Save'),
      ),
    ],
  );
}

class PreliminaryDamageAssessmentReportView extends StatelessWidget {
  const PreliminaryDamageAssessmentReportView({
    super.key,
    required this.document,
    required this.revision,
  });

  final AssessmentReportDocument document;
  final PreliminaryDamageAssessmentRevision revision;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(document.title, style: Theme.of(context).textTheme.headlineSmall),
      for (final section in document.sections.where(
        (section) => section.heading == 'VOIDED',
      )) ...[
        Text(
          'VOIDED',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        for (final line in section.lines) Text(line),
      ],
      _AssessmentSummary(
        vehicle: revision.vehicleSnapshot,
        appraiserName: revision.completedByName,
        captures: revision.captures,
        findings: revision.confirmedFindings,
        severities: revision.severityAssessments,
        estimate: revision.estimate,
        noVisibleDamageOutcome: revision.isNoVisibleDamageOutcome,
      ),
      for (final section in document.sections.where(
        (section) =>
            section.heading == 'Limitations' || section.heading == 'Important',
      )) ...[
        const SizedBox(height: 12),
        Text(section.heading, style: Theme.of(context).textTheme.titleMedium),
        for (final line in section.lines) Text(line),
      ],
      ExpansionTile(
        key: const Key('report-audit-details'),
        title: const Text('Revision and technical history'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        children: [
          for (final section in document.sections.where(
            (section) =>
                section.heading.startsWith('Revision ') ||
                section.heading == 'Accepted evidence history' ||
                section.heading == 'Finding identities' ||
                section.heading == 'Correction provenance',
          ))
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.heading,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final line in section.lines) Text(line),
                  const SizedBox(height: 12),
                ],
              ),
            ),
        ],
      ),
    ],
  );
}

class _AssessmentSummary extends StatelessWidget {
  const _AssessmentSummary({
    required this.vehicle,
    required this.appraiserName,
    required this.captures,
    required this.findings,
    required this.severities,
    required this.estimate,
    this.noVisibleDamageOutcome = false,
    this.isSeverityCurrent,
    this.isEstimateCurrent,
  });

  final Vehicle vehicle;
  final String appraiserName;
  final List<Capture> captures;
  final List<DamageFinding> findings;
  final List<SeverityAssessment> severities;
  final AssessmentEstimate? estimate;
  final bool noVisibleDamageOutcome;
  final bool Function(DamageFinding)? isSeverityCurrent;
  final bool Function(DamageFinding)? isEstimateCurrent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      Text(
        vehicle.displayLabel ?? 'Vehicle ${vehicle.id}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (vehicle.vin != null) Text('VIN: ${vehicle.vin}'),
      if (vehicle.licencePlate != null)
        Text('Licence plate: ${vehicle.licencePlate}'),
      Text('Appraiser: $appraiserName'),
      const SizedBox(height: 12),
      Text('Photos', style: Theme.of(context).textTheme.titleMedium),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final capture in captures)
            Semantics(
              label: 'Photo ${capture.id}',
              child: SizedBox(
                width: 140,
                height: 100,
                child: Image.file(
                  File(capture.localPath),
                  key: Key('summary-photo-${capture.id}'),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        'Confirmed findings',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (findings.isEmpty)
        Text(
          noVisibleDamageOutcome
              ? 'No supported visible exterior damage.'
              : 'No confirmed findings yet.',
        ),
      for (final finding in findings) ...[
        Text('${finding.vehicleComponent} • ${finding.damageType}'),
        if (isSeverityCurrent != null && !isSeverityCurrent!(finding))
          const Text('Severity review needs updating.'),
        for (final severity in severities.where(
          (value) => value.findingId == finding.id,
        )) ...[
          Text(
            isSeverityCurrent != null && !isSeverityCurrent!(finding)
                ? 'Earlier severity: ${_severityName(severity.reviewedLevel)} (stale)'
                : 'Severity: ${_severityName(severity.reviewedLevel)}',
          ),
          if (severity.uncertainty != null)
            Text(
              isSeverityCurrent != null && !isSeverityCurrent!(finding)
                  ? 'Earlier uncertainty (stale): ${severity.uncertainty}'
                  : 'Uncertainty: ${severity.uncertainty}',
            ),
          if (severity.followUpNeed != null)
            Text(
              isSeverityCurrent != null && !isSeverityCurrent!(finding)
                  ? 'Earlier follow-up (stale): ${severity.followUpNeed}'
                  : 'Follow-up: ${severity.followUpNeed}',
            ),
        ],
        if (finding.hasConflictingViews)
          const Text('Finding has conflicting views.'),
      ],
      const SizedBox(height: 12),
      Text(
        estimate?.isPartial ?? false
            ? 'Partial Estimate • pricing gaps'
            : 'Assessment Estimate',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (estimate == null) const Text('Estimate has not been reviewed.'),
      if (isEstimateCurrent != null &&
          findings.any((finding) => !isEstimateCurrent!(finding)))
        const Text('Estimate review needs updating for changed findings.'),
      for (final operation in estimate?.operations ?? const <RepairOperation>[])
        Text(
          operation.hasPricing
              ? '${operation.description}: ${operation.currency} '
                    '${(operation.minimumCents! / 100).toStringAsFixed(2)}–'
                    '${(operation.maximumCents! / 100).toStringAsFixed(2)}'
              : '${operation.description}: pricing unavailable',
        ),
      for (final assumption in estimate?.assumptions ?? const <String>[])
        Text('Assumption: $assumption'),
    ],
  );
}

String _severityName(SeverityLevel level) => switch (level) {
  SeverityLevel.minor => 'Minor',
  SeverityLevel.moderate => 'Moderate',
  SeverityLevel.severe => 'Severe',
  SeverityLevel.undetermined => 'Undetermined',
};
