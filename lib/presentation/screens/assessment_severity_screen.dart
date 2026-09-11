import 'package:flutter/material.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_severity_controller.dart';
import 'package:autodentifyr/services/assessment_severity_source.dart';

class AssessmentSeverityScreen extends StatefulWidget {
  const AssessmentSeverityScreen({super.key, required this.controller});

  final AssessmentSeverityController controller;

  @override
  State<AssessmentSeverityScreen> createState() =>
      _AssessmentSeverityScreenState();
}

class _AssessmentSeverityScreenState extends State<AssessmentSeverityScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.state.phase == AssessmentSeverityPhase.idle) {
      widget.controller.load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review severity')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => _buildState(widget.controller.state),
      ),
    ),
  );

  Widget _buildState(AssessmentSeverityControllerState state) {
    if (state.phase == AssessmentSeverityPhase.idle ||
        state.phase == AssessmentSeverityPhase.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final assessment = state.assessment;
    final batch = state.suggestionBatch;
    if (assessment == null || batch == null) {
      return Center(
        child: Text(state.message ?? 'Intake Assessment unavailable.'),
      );
    }
    final confirmed = assessment.findings
        .where((finding) => finding.reviewState == FindingReviewState.confirmed)
        .toList();
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
          batch.isSupported
              ? 'Suggestion source available'
              : 'Automation unavailable',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (batch.limitation != null) Text(batch.limitation!),
        const SizedBox(height: 16),
        Text(
          'Pilot extent anchors',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text('Minor — Localized visible extent'),
        const Text('Moderate — Intermediate visible extent'),
        const Text('Severe — Widespread visible extent'),
        const Text('Undetermined — Evidence insufficient'),
        const SizedBox(height: 20),
        for (final finding in confirmed) ...[
          _findingCard(assessment, batch, finding),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _findingCard(
    IntakeAssessment assessment,
    SeveritySuggestionBatch batch,
    DamageFinding finding,
  ) {
    final current = assessment.severityAssessments
        .where((severity) => severity.findingId == finding.id)
        .firstOrNull;
    final suggestion = batch.suggestions
        .where((value) => value.findingId == finding.id)
        .firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${finding.vehicleComponent} • ${finding.damageType}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (finding.hasConflictingViews) const Text('Conflicting captures'),
            const SizedBox(height: 6),
            if (suggestion != null)
              Text(
                '${batch.isSynthetic ? 'Synthetic workflow-only suggestion' : 'Suggestion'}: '
                '${_levelName(suggestion.level)}',
              ),
            if (current == null)
              const Text('Not reviewed')
            else ...[
              Text(
                'Appraiser conclusion: ${_levelName(current.reviewedLevel)} — '
                '${_shortAnchor(current.reviewedLevel)}',
              ),
              Text(
                'Evidence Captures: ${current.evidenceCaptureIds.join(', ')}',
              ),
              if (current.originalSuggestion != null)
                Text(
                  'Original suggestion: ${_levelName(current.originalSuggestion!)}'
                  '${current.suggestionIsSynthetic ? ' (synthetic workflow only)' : ''}',
                ),
              if (current.automationSourceVersion != null)
                Text('Suggestion source: ${current.automationSourceVersion}'),
              if (current.suggestionEvidenceCaptureIds.isNotEmpty)
                Text(
                  'Suggestion evidence: '
                  '${current.suggestionEvidenceCaptureIds.join(', ')}',
                ),
              Text('Reviewed by ${current.reviewerProfileId}'),
              Text(
                'Reviewed at ${current.reviewedAt.toUtc().toIso8601String()}',
              ),
              Text('Reason: ${current.reason}'),
              if (current.uncertainty != null)
                Text('Uncertainty: ${current.uncertainty}'),
              if (current.followUpNeed != null)
                Text('Additional view requested: ${current.followUpNeed}'),
              if (current.followUpOverrideReason != null)
                Text('Override: ${current.followUpOverrideReason}'),
              if (current.limitation != null) Text(current.limitation!),
              for (final review in current.reviewHistory)
                Text(
                  'Earlier review: ${_levelName(review.reviewedLevel)} by '
                  '${review.reviewerProfileId} at '
                  '${review.reviewedAt.toUtc().toIso8601String()} — '
                  '${review.reason}',
                ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              key: Key('review-severity-${finding.id}'),
              onPressed: () => _review(finding, current),
              child: Text(current == null ? 'Review severity' : 'Review again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _review(
    DamageFinding finding,
    SeverityAssessment? current,
  ) async {
    final action = await showDialog<ReviewSeverityAction>(
      context: context,
      builder: (context) =>
          _SeverityReviewDialog(finding: finding, current: current),
    );
    if (action != null) await widget.controller.submit(action);
  }

  static String _levelName(SeverityLevel level) => switch (level) {
    SeverityLevel.minor => 'Minor',
    SeverityLevel.moderate => 'Moderate',
    SeverityLevel.severe => 'Severe',
    SeverityLevel.undetermined => 'Undetermined',
  };

  static String _shortAnchor(SeverityLevel level) => switch (level) {
    SeverityLevel.minor => 'Localized',
    SeverityLevel.moderate => 'Intermediate',
    SeverityLevel.severe => 'Widespread',
    SeverityLevel.undetermined => 'Evidence insufficient',
  };
}

class _SeverityReviewDialog extends StatefulWidget {
  const _SeverityReviewDialog({required this.finding, this.current});

  final DamageFinding finding;
  final SeverityAssessment? current;

  @override
  State<_SeverityReviewDialog> createState() => _SeverityReviewDialogState();
}

class _SeverityReviewDialogState extends State<_SeverityReviewDialog> {
  late SeverityLevel _level;
  late final TextEditingController _evidence;
  late final TextEditingController _reason;
  late final TextEditingController _uncertainty;
  late final TextEditingController _additionalView;
  late final TextEditingController _overrideReason;
  late final TextEditingController _limitation;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _level = current?.reviewedLevel ?? SeverityLevel.undetermined;
    _evidence = TextEditingController(
      text: (current?.evidenceCaptureIds ?? widget.finding.supportingCaptureIds)
          .join(', '),
    );
    _reason = TextEditingController(text: current?.reason ?? '');
    _uncertainty = TextEditingController(text: current?.uncertainty ?? '');
    _additionalView = TextEditingController(text: current?.followUpNeed ?? '');
    _overrideReason = TextEditingController(
      text: current?.followUpOverrideReason ?? '',
    );
    _limitation = TextEditingController(text: current?.limitation ?? '');
  }

  @override
  void dispose() {
    _evidence.dispose();
    _reason.dispose();
    _uncertainty.dispose();
    _additionalView.dispose();
    _overrideReason.dispose();
    _limitation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Review Severity Assessment'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<SeverityLevel>(
            key: const Key('severity-level'),
            initialValue: _level,
            items: [
              for (final level in SeverityLevel.values)
                DropdownMenuItem(
                  value: level,
                  child: Text(_AssessmentSeverityScreenState._levelName(level)),
                ),
            ],
            onChanged: (value) => setState(() => _level = value!),
            decoration: const InputDecoration(labelText: 'Conclusion'),
          ),
          _field(_evidence, 'Evidence Capture IDs', 'severity-evidence'),
          _field(_reason, 'Reason', 'severity-reason'),
          _field(_uncertainty, 'Uncertainty', 'severity-uncertainty'),
          _field(
            _additionalView,
            'Specific additional-view request',
            'severity-additional-view',
          ),
          _field(
            _overrideReason,
            'Additional-view override reason',
            'severity-override-reason',
          ),
          _field(_limitation, 'Limitation', 'severity-limitation'),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('submit-severity-review'),
        onPressed: () => Navigator.pop(
          context,
          ReviewSeverityAction(
            findingId: widget.finding.id,
            reviewedLevel: _level,
            evidenceCaptureIds: _csv(_evidence.text),
            reason: _reason.text,
            uncertainty: _nullable(_uncertainty.text),
            additionalViewRequest: _nullable(_additionalView.text),
            additionalViewOverrideReason: _nullable(_overrideReason.text),
            limitation: _nullable(_limitation.text),
          ),
        ),
        child: const Text('Save review'),
      ),
    ],
  );

  Widget _field(TextEditingController controller, String label, String key) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextField(
          key: Key(key),
          controller: controller,
          decoration: InputDecoration(labelText: label),
        ),
      );

  List<String> _csv(String value) => value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
