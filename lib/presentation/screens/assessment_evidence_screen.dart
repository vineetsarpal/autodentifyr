import 'dart:io';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_evidence_controller.dart';
import 'package:flutter/material.dart';

class AssessmentEvidenceScreen extends StatefulWidget {
  const AssessmentEvidenceScreen({super.key, required this.controller});

  final AssessmentEvidenceController controller;

  @override
  State<AssessmentEvidenceScreen> createState() =>
      _AssessmentEvidenceScreenState();
}

class _AssessmentEvidenceScreenState extends State<AssessmentEvidenceScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.state.phase == AssessmentEvidencePhase.idle) {
      widget.controller.load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Assessment evidence')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => _buildState(widget.controller.state),
      ),
    ),
  );

  Widget _buildState(AssessmentEvidenceState state) {
    if (state.phase == AssessmentEvidencePhase.loading ||
        state.phase == AssessmentEvidencePhase.idle) {
      return const Center(child: CircularProgressIndicator());
    }
    final assessment = state.assessment;
    if (assessment == null) {
      return _MessagePanel(
        icon: Icons.error_outline,
        message: state.message ?? 'Intake Assessment unavailable.',
      );
    }
    final pending = state.pendingEvidence;
    if (pending != null) return _buildPending(state, pending);
    return _buildAssessment(state, assessment);
  }

  Widget _buildAssessment(
    AssessmentEvidenceState state,
    IntakeAssessment assessment,
  ) => Column(
    children: [
      if (state.message != null)
        _StatusBanner(
          message: state.message!,
          isError:
              state.phase == AssessmentEvidencePhase.permissionDenied ||
              state.phase == AssessmentEvidencePhase.acquisitionFailed,
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            assessment.captures.length == 1
                ? '1 accepted Capture'
                : '${assessment.captures.length} accepted Captures',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
      Expanded(
        child: assessment.captures.isEmpty
            ? const Center(child: Text('No accepted Captures yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: assessment.captures.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _CaptureCard(capture: assessment.captures[index]),
              ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('take-photo'),
                onPressed: widget.controller.stageCameraCapture,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take photo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('import-image'),
                onPressed: widget.controller.importImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Import image'),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildPending(
    AssessmentEvidenceState state,
    PendingAssessmentEvidence pending,
  ) {
    final busy =
        state.phase == AssessmentEvidencePhase.acquiring ||
        state.phase == AssessmentEvidencePhase.saving;
    final inferenceFailed =
        state.phase == AssessmentEvidencePhase.inferenceFailed;
    final saveFailed = state.phase == AssessmentEvidencePhase.saveFailed;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Review evidence',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          pending.source == CaptureSource.camera
              ? 'Camera still'
              : 'Imported image',
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              pending.evidence.bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Colors.black12,
                child: Center(child: Icon(Icons.image_outlined, size: 48)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${pending.observations.length} model ${pending.observations.length == 1 ? 'observation' : 'observations'}',
        ),
        if (state.message != null) ...[
          const SizedBox(height: 12),
          _StatusBanner(message: state.message!, isError: true),
        ],
        if (busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        if (inferenceFailed) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('retry-inference'),
            onPressed: widget.controller.retryInference,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry analysis'),
          ),
        ],
        if (saveFailed) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('retry-save'),
            onPressed: widget.controller.retrySave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Retry save'),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('reject-evidence'),
                onPressed: busy ? null : widget.controller.reject,
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('accept-evidence'),
                onPressed: busy ? null : widget.controller.accept,
                child: Text(
                  inferenceFailed ? 'Add without suggestions' : 'Accept',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CaptureCard extends StatelessWidget {
  const _CaptureCard({required this.capture});

  final Capture capture;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: SizedBox.square(
        dimension: 56,
        child: Image.file(
          File(capture.localPath),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.image_outlined),
        ),
      ),
      title: Text(
        capture.source == CaptureSource.camera
            ? 'Camera still'
            : 'Imported image',
      ),
      subtitle: Text(
        '${capture.orientation.name} • ${capture.capturedAt.toLocal()}',
      ),
    ),
  );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Material(
    color: isError
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(8),
    child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
  );
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
