import 'package:flutter/material.dart';

import 'package:autodentifyr/models/assessment.dart';
import 'package:autodentifyr/presentation/controllers/assessment_estimate_controller.dart';

class AssessmentEstimateScreen extends StatefulWidget {
  const AssessmentEstimateScreen({
    super.key,
    required this.controller,
    this.onContinue,
  });

  final AssessmentEstimateController controller;
  final VoidCallback? onContinue;

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
    bottomNavigationBar: widget.onContinue == null
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final state = widget.controller.state;
                  return FilledButton(
                    key: const Key('continue-assessment'),
                    onPressed: state.phase == AssessmentEstimatePhase.ready
                        ? widget.onContinue
                        : null,
                    child: state.phase == AssessmentEstimatePhase.calculating
                        ? const Text('Updating estimate...')
                        : const Text('Continue to final review'),
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
    final formKey = GlobalKey<FormState>();
    var saving = false;
    String? saveError;
    bool hasAnyPrice() => [
      minimum,
      maximum,
      currency,
      source,
    ].any((controller) => controller.text.trim().isNotEmpty);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            scrollable: true,
            title: const Text('Override Repair Operation'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(
                      description,
                      'Description',
                      'operation-description',
                      required: true,
                      multiline: true,
                    ),
                    _field(
                      minimum,
                      'Minimum cents',
                      'minimum-cents',
                      numeric: true,
                      requiredWhen: hasAnyPrice,
                      onChanged: (_) => setDialogState(() {}),
                      validator: (value) {
                        final amount = int.tryParse(value?.trim() ?? '');
                        if (amount != null && amount < 0) {
                          return 'Minimum cents must be nonnegative.';
                        }
                        if ((value?.trim().isNotEmpty ?? false) &&
                            amount == null) {
                          return 'Enter whole cents.';
                        }
                        return null;
                      },
                    ),
                    _field(
                      maximum,
                      'Maximum cents',
                      'maximum-cents',
                      numeric: true,
                      requiredWhen: hasAnyPrice,
                      onChanged: (_) => setDialogState(() {}),
                      validator: (value) {
                        final amount = int.tryParse(value?.trim() ?? '');
                        if ((value?.trim().isNotEmpty ?? false) &&
                            amount == null) {
                          return 'Enter whole cents.';
                        }
                        if (amount != null && amount < 0) {
                          return 'Maximum cents must be nonnegative.';
                        }
                        final min = int.tryParse(minimum.text.trim());
                        if (amount != null && min != null && amount < min) {
                          return 'Maximum cents must be at least minimum cents.';
                        }
                        return null;
                      },
                    ),
                    _field(
                      currency,
                      'Currency',
                      'currency',
                      requiredWhen: hasAnyPrice,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    _field(
                      source,
                      'Pricing source version',
                      'pricing-source-version',
                      requiredWhen: hasAnyPrice,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    _field(
                      reason,
                      'Override reason',
                      'override-reason',
                      required: true,
                      multiline: true,
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
                key: const Key('submit-estimate-action'),
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          saving = true;
                          saveError = null;
                        });
                        await widget.controller.submit(
                          OverrideRepairOperationAction(
                            operationId: operation.id,
                            description: description.text,
                            minimumCents: int.tryParse(minimum.text),
                            maximumCents: int.tryParse(maximum.text),
                            currency: _nullable(currency.text),
                            pricingSourceVersion: _nullable(source.text),
                            reason: reason.text,
                          ),
                        );
                        if (!dialogContext.mounted) return;
                        if (widget.controller.state.phase ==
                            AssessmentEstimatePhase.ready) {
                          Navigator.pop(dialogContext);
                        } else {
                          setDialogState(() {
                            saving = false;
                            saveError =
                                widget.controller.state.message ??
                                'Unable to save override.';
                          });
                        }
                      },
                child: const Text('Save override'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editAssumptions(AssessmentEstimate estimate) async {
    final assumptions = TextEditingController(
      text: estimate.assumptions.join('\n'),
    );
    var saving = false;
    String? saveError;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: const Text('Edit assumptions'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('estimate-assumptions'),
                    controller: assumptions,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'One assumption per line',
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
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('submit-estimate-action'),
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() {
                          saving = true;
                          saveError = null;
                        });
                        await widget.controller.submit(
                          EditEstimateAssumptionsAction(
                            assumptions.text
                                .split('\n')
                                .map((value) => value.trim())
                                .where((value) => value.isNotEmpty)
                                .toList(),
                          ),
                        );
                        if (!dialogContext.mounted) return;
                        if (widget.controller.state.phase ==
                            AssessmentEstimatePhase.ready) {
                          Navigator.pop(dialogContext);
                        } else {
                          setDialogState(() {
                            saving = false;
                            saveError =
                                widget.controller.state.message ??
                                'Unable to save assumptions.';
                          });
                        }
                      },
                child: const Text('Save assumptions'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    bool numeric = false,
    bool multiline = false,
    bool required = false,
    bool Function()? requiredWhen,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(required || (requiredWhen?.call() ?? false) ? '$label *' : label),
        const SizedBox(height: 6),
        TextFormField(
          key: Key(key),
          controller: controller,
          onChanged: onChanged,
          minLines: multiline ? 2 : 1,
          maxLines: multiline ? 4 : 1,
          keyboardType: numeric
              ? TextInputType.number
              : multiline
              ? TextInputType.multiline
              : TextInputType.text,
          textInputAction: multiline
              ? TextInputAction.newline
              : TextInputAction.next,
          validator: (value) {
            if ((required || (requiredWhen?.call() ?? false)) &&
                (value?.trim().isEmpty ?? true)) {
              return '$label is required.';
            }
            return validator?.call(value);
          },
          decoration: InputDecoration(hintText: label),
        ),
      ],
    ),
  );

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
