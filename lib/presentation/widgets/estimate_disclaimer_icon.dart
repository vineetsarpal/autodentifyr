import 'package:flutter/material.dart';
import 'package:autodentifyr/core/theme/app_palette.dart';

const String kEstimateDisclaimerMessage =
    'Cost estimates provided by AutoDentifyr are for informational purposes only. Values are shown in USD and represent baseline repair costs based on detected damage type and U.S. national average pricing. Actual repair costs may vary by vehicle make/model/year, labor rates, parts availability or quality, regional market conditions, taxes and fees, and any additional or hidden damage found during in-person inspection. These estimates do not constitute a quote or a guarantee of final repair costs.';

void showEstimateDisclaimerDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Estimate Disclaimer'),
      content: const Text(kEstimateDisclaimerMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class EstimateDisclaimerIcon extends StatelessWidget {
  const EstimateDisclaimerIcon({
    super.key,
    this.size = 18,
    this.color = AppPalette.yellowColor,
    this.tooltip = 'Estimate information',
  });

  final double size;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => showEstimateDisclaimerDialog(context),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      visualDensity: VisualDensity.compact,
      splashRadius: 16,
      icon: Icon(Icons.info_outline_rounded, size: size, color: color),
    );
  }
}
