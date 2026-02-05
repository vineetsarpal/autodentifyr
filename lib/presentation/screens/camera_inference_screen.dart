import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:autodentifyr/models/models.dart';
import 'package:autodentifyr/presentation/controllers/camera_inference_controller.dart';
import 'package:autodentifyr/presentation/widgets/camera_inference_content.dart';
import 'package:autodentifyr/presentation/widgets/camera_inference_overlay.dart';
import 'package:autodentifyr/presentation/widgets/camera_controls.dart';
import 'package:autodentifyr/presentation/widgets/threshold_slider.dart';
import 'package:autodentifyr/presentation/widgets/bounding_box_overlay.dart';
import 'package:autodentifyr/core/theme/app_palette.dart';

/// A screen that demonstrates real-time YOLO inference using the device camera.
///
/// This screen provides:
/// - Live camera feed with YOLO car damage detection
/// - Adjustable thresholds (confidence, IoU, max detections)
/// - Camera controls (flip, zoom)
/// - Performance metrics (FPS)
class CameraInferenceScreen extends StatefulWidget {
  const CameraInferenceScreen({super.key});

  @override
  State<CameraInferenceScreen> createState() => _CameraInferenceScreenState();
}

class _CameraInferenceScreenState extends State<CameraInferenceScreen>
    with WidgetsBindingObserver {
  late final CameraInferenceController _controller;
  int _rebuildKey = 0;
  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = CameraInferenceController();
    _controller.initialize().catchError((error) {
      if (mounted) {
        _showError('Model Loading Error', error.toString());
      }
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if route is current (we've navigated back to this screen)
    final route = ModalRoute.of(context);
    if (route?.isCurrent == true) {
      // Force rebuild when navigating back to ensure camera restarts
      // The rebuild will create a new YOLOView which will automatically start the camera
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _rebuildKey++;
          });
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Restart camera when app is resumed (e.g. back from share sheet)
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _rebuildKey++;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(title: const Text('Live Camera'), centerTitle: true),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, child) {
          return Stack(
            children: [
              RepaintBoundary(
                key: _captureKey,
                child: Stack(
                  children: [
                    CameraInferenceContent(
                      key: ValueKey('camera_content_$_rebuildKey'),
                      controller: _controller,
                      rebuildKey: _rebuildKey,
                    ),
                    BoundingBoxOverlay(
                      results: _controller.currentResults,
                      controller: _controller,
                    ),
                    CameraInferenceOverlay(
                      controller: _controller,
                      isLandscape: isLandscape,
                    ),
                  ],
                ),
              ),
              ThresholdSlider(
                activeSlider: _controller.activeSlider,
                confidenceThreshold: _controller.confidenceThreshold,
                onValueChanged: _controller.updateSliderValue,
                onClose: () => _controller.toggleSlider(SliderType.none),
                isLandscape: isLandscape,
              ),
              CameraControls(
                currentZoomLevel: _controller.currentZoomLevel,
                activeSlider: _controller.activeSlider,
                onZoomChanged: _controller.setZoomLevel,
                onSliderToggled: _controller.toggleSlider,
                onCapture: _captureScreenshot,
                isLandscape: isLandscape,
                isCapturing: _controller.isCapturing,
              ),
              if (_controller.capturedImage != null)
                _buildCapturedImageOverlay(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _captureScreenshot() async {
    try {
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Capture at 1.0 pixel ratio as the screen is already high enough
      // and excessive resolution might slow down sharing.
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        _controller.setCapturedImage(bytes);
      }
    } catch (e) {
      debugPrint('Error capturing screenshot: $e');
    }
  }

  void _showError(String title, String message) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  Widget _buildCapturedImageOverlay() {
    return Container(
      color: AppPalette.overlayBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Captured Frame',
                  style: TextStyle(
                    color: AppPalette.whiteColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppPalette.whiteColor, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      _controller.capturedImage!,
                      width: MediaQuery.of(context).size.width * 0.8,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _controller.clearCapturedImage,
                      icon: const Icon(Icons.close, size: 24),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.redColor,
                        foregroundColor: AppPalette.whiteColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Builder(
                      builder: (context) {
                        return ElevatedButton.icon(
                          onPressed: () {
                            final box =
                                context.findRenderObject() as RenderBox?;
                            _controller.shareCapturedImage(
                              sharePositionOrigin: box != null
                                  ? box.localToGlobal(Offset.zero) & box.size
                                  : null,
                            );
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.blueColor,
                            foregroundColor: AppPalette.whiteColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
