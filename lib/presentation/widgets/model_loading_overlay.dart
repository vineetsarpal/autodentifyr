import 'package:flutter/material.dart';
import 'package:autodentifyr/core/theme/app_palette.dart';

/// A loading overlay widget that displays model loading progress
class ModelLoadingOverlay extends StatelessWidget {
  const ModelLoadingOverlay({
    super.key,
    required this.loadingMessage,
    required this.downloadProgress,
  });

  final String loadingMessage;
  final double downloadProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppPalette.overlayBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/app_icon.png',
              width: 120,
              height: 120,
              color: AppPalette.whiteColor.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            const Text(
              'Damage Decoded',
              style: TextStyle(
                color: AppPalette.appGreen,
                fontSize: 14,
                letterSpacing: 3,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              loadingMessage,
              style: const TextStyle(
                color: AppPalette.whiteColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (downloadProgress > 0) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: downloadProgress,
                  backgroundColor: AppPalette.separatorColor,
                  valueColor: const AlwaysStoppedAnimation(
                    AppPalette.whiteColor,
                  ),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${(downloadProgress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: AppPalette.whiteColor,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
