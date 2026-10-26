import 'package:flutter/material.dart';
import 'package:autodentifyr/core/theme/app_palette.dart';

typedef PhotoDetectionDetails = ({
  String name,
  double? confidence,
  double? estimate,
});

/// Opens the numbered photo findings without navigating away from the image.
class PhotoDetectionsButton extends StatelessWidget {
  const PhotoDetectionsButton({super.key, required this.detections});

  final List<PhotoDetectionDetails> detections;

  void _showDetections(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Detected damages (${detections.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close detected damages',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Numbers match the boxes on your photo. AI detections may be incorrect.',
            ),
            const SizedBox(height: 16),
            if (detections.isEmpty)
              const Text('No damage detected. This does not rule out damage.'),
            for (var index = 0; index < detections.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(detections[index].name),
                subtitle: Text(
                  detections[index].confidence == null
                      ? 'Confidence unavailable'
                      : '${(detections[index].confidence!.clamp(0, 1) * 100).toStringAsFixed(0)}% confidence',
                ),
                trailing: Text(
                  detections[index].estimate == null
                      ? 'Not priced'
                      : '\$${detections[index].estimate!.toStringAsFixed(0)}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'View detected damages',
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showDetections(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppPalette.greyColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detections',
                  style: TextStyle(color: AppPalette.greyColor, fontSize: 12),
                ),
                Text(
                  '${detections.length}',
                  style: const TextStyle(
                    color: AppPalette.whiteColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
