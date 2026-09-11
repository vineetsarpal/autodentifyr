import 'package:flutter/material.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_estimate_controller.dart';

class AssessmentEstimateScreen extends StatefulWidget {
  const AssessmentEstimateScreen({super.key, required this.controller});

  final AssessmentEstimateController controller;

  @override
  State<AssessmentEstimateScreen> createState() =>
      _AssessmentEstimateScreenState();
}

class _AssessmentEstimateScreenState extends State<AssessmentEstimateScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.state.phase == AssessmentEstimatePhase.idle) {
      widget.controller.load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Draft Estimate')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => _buildState(widget.controller.state),
      ),
    ),
  );

  Widget _buildState(AssessmentEstimateControllerState state) {
    if (state.phase == AssessmentEstimatePhase.idle ||
        state.phase == AssessmentEstimatePhase.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final assessment = state.assessment;
    if (assessment == null) {
      return Center(
        child: Text(state.message ?? 'Intake Assessment unavailable.'),
      );
    }
    final estimate = assessment.estimate;
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
        Row(
          children: [
            Expanded(
              child: Text(
                estimate?.isPartial ?? false
                    ? 'Partial Estimate'
                    : 'Draft Estimate',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.icon(
              key: const Key('recalculate-estimate'),
              onPressed: state.phase == AssessmentEstimatePhase.calculating
                  ? null
                  : () => widget.controller.submit(
                      const RecalculateEstimateAction(),
                    ),
              icon: const Icon(Icons.refresh),
              label: const Text('Recalculate'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Only versioned, supported prices contribute to the known subtotal.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (state.phase == AssessmentEstimatePhase.calculating) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (estimate == null) ...[
          const SizedBox(height: 24),
          const Text(
            'Recalculate to create Repair Operations from Confirmed Findings.',
          ),
        ] else ...[
          const SizedBox(height: 20),
          for (final operation in estimate.operations) ...[
            _operationCard(operation),
            const SizedBox(height: 12),
          ],
          Text(
            _subtotalLabel(estimate),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Assumptions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                key: const Key('edit-estimate-assumptions'),
                onPressed: () => _editAssumptions(estimate),
                child: const Text('Edit'),
              ),
            ],
          ),
          for (final assumption in estimate.assumptions) Text('• $assumption'),
          const SizedBox(height: 20),
          Text(
            '${estimate.overrides.length} recorded '
            '${estimate.overrides.length == 1 ? 'override' : 'overrides'}',
          ),
          if (estimate.isPartial) ...[
            const SizedBox(height: 16),
            if (estimate.missingPricingAcknowledgedAt == null)
              FilledButton(
                key: const Key('acknowledge-partial-estimate'),
                onPressed: () => widget.controller.submit(
                  const AcknowledgePartialEstimateAction(),
                ),
                child: const Text('Acknowledge missing pricing'),
              )
            else
              const Text('Missing pricing acknowledged'),
          ],
        ],
      ],
    );
  }

  Widget _operationCard(RepairOperation operation) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            operation.description,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Supports ${operation.findingIds.length} Confirmed '
            '${operation.findingIds.length == 1 ? 'Finding' : 'Findings'}',
          ),
          const SizedBox(height: 4),
          Text(_priceLabel(operation)),
          const SizedBox(height: 8),
          OutlinedButton(
            key: Key('override-${operation.id}'),
            onPressed: () => _overrideOperation(operation),
            child: const Text('Override'),
          ),
        ],
      ),
    ),
  );

  String _priceLabel(RepairOperation operation) {
    if (!operation.hasPricing) return 'Pricing unavailable';
    return '${operation.currency} '
        '${_money(operation.minimumCents!)}–${_money(operation.maximumCents!)}';
  }

  String _subtotalLabel(AssessmentEstimate estimate) {
    final minimum = estimate.knownMinimumTotalCents;
    final maximum = estimate.knownMaximumTotalCents;
    if (minimum == null || maximum == null) {
      return 'Known subtotal unavailable';
    }
    final currency = estimate.operations
        .firstWhere((operation) => operation.hasPricing)
        .currency!;
    return 'Known subtotal: $currency ${_money(minimum)}–${_money(maximum)}';
  }

  String _money(int cents) => (cents / 100).toStringAsFixed(2);

  Future<void> _overrideOperation(RepairOperation operation) async {
    final description = TextEditingController(text: operation.description);
    final minimum = TextEditingController(
      text: operation.minimumCents?.toString() ?? '',
    );
    final maximum = TextEditingController(
      text: operation.maximumCents?.toString() ?? '',
    );
    final currency = TextEditingController(text: operation.currency ?? '');
    final source = TextEditingController(
      text: operation.pricingSourceVersion ?? '',
    );
    final reason = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Override Repair Operation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(description, 'Description', 'operation-description'),
              _field(minimum, 'Minimum cents', 'minimum-cents', numeric: true),
              _field(maximum, 'Maximum cents', 'maximum-cents', numeric: true),
              _field(currency, 'Currency', 'currency'),
              _field(
                source,
                'Pricing source version',
                'pricing-source-version',
              ),
              _field(reason, 'Override reason', 'override-reason'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('submit-estimate-action'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save override'),
          ),
        ],
      ),
    );
    final action = OverrideRepairOperationAction(
      operationId: operation.id,
      description: description.text,
      minimumCents: int.tryParse(minimum.text),
      maximumCents: int.tryParse(maximum.text),
      currency: _nullable(currency.text),
      pricingSourceVersion: _nullable(source.text),
      reason: reason.text,
    );
    if (submitted != true) return;
    await widget.controller.submit(action);
  }

  Future<void> _editAssumptions(AssessmentEstimate estimate) async {
    final assumptions = TextEditingController(
      text: estimate.assumptions.join('\n'),
    );
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit assumptions'),
        content: TextField(
          key: const Key('estimate-assumptions'),
          controller: assumptions,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'One assumption per line',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('submit-estimate-action'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save assumptions'),
          ),
        ],
      ),
    );
    final action = EditEstimateAssumptionsAction(
      assumptions.text
          .split('\n')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
    );
    if (submitted != true) return;
    await widget.controller.submit(action);
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      key: Key(key),
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    ),
  );

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
