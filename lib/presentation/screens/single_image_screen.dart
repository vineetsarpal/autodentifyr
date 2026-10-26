import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/utils/map_converter.dart';
import 'package:ultralytics_yolo/utils/error_handler.dart';
import 'package:autodentifyr/core/theme/app_palette.dart';
import 'package:autodentifyr/services/model_manager.dart';
import 'package:autodentifyr/models/models.dart';
import 'package:autodentifyr/presentation/widgets/estimate_disclaimer_icon.dart';
import 'package:autodentifyr/presentation/widgets/photo_detections_button.dart';

/// A screen for analyzing damage from uploaded images
class SingleImageScreen extends StatefulWidget {
  const SingleImageScreen({super.key});

  @override
  State<SingleImageScreen> createState() => _SingleImageScreenState();
}

class _SingleImageScreenState extends State<SingleImageScreen> {
  final _picker = ImagePicker();
  final GlobalKey _screenshotKey = GlobalKey();
  List<Map<String, dynamic>> _detections = [];
  Uint8List? _processedImageBytes;
  late YOLO _yolo;
  String? _modelPath;
  bool _isModelReady = false;
  bool _isProcessing = false;
  late final ModelManager _modelManager;

  // Price estimation mapping (synced with camera mode)
  static const Map<String, double> _priceMap = {
    'front-windscreen-damage': 650.0,
    'headlight-damage': 350.0,
    'rear-windscreen-damage': 550.0,
    'runningboard-damage': 400.0,
    'sidemirror-damage': 250.0,
    'taillight-damage': 300.0,
    'bonnet-dent': 450.0,
    'boot-dent': 450.0,
    'doorouter-dent': 500.0,
    'fender-dent': 350.0,
    'front-bumper-dent': 400.0,
    'quaterpanel-dent': 550.0,
    'rear-bumper-dent': 400.0,
    'roof-dent': 750.0,
  };

  @override
  void initState() {
    super.initState();
    _modelManager = ModelManager();
    _initializeYOLO();
  }

  /// Initializes the YOLO model for inference
  Future<void> _initializeYOLO() async {
    try {
      _modelPath = await _modelManager.getModelPath(ModelType.detect);
      if (_modelPath == null) return;
      _yolo = YOLO(modelPath: _modelPath!, task: ModelType.detect.task);
      await _yolo.loadModel();
      // loadModel registers a lazy instance; compile it before enabling input.
      await _yolo.predictorInstance();
      if (mounted) setState(() => _isModelReady = true);
    } catch (e) {
      if (mounted) {
        final error = YOLOErrorHandler.handleError(
          e,
          'Failed to load model $_modelPath for task ${ModelType.detect.task.name}',
        );
        _showSnackBar('Error loading model: ${error.message}');
      }
    }
  }

  /// Picks an image from the gallery and runs inference
  Future<void> _pickAndPredict() async {
    if (!_isModelReady) {
      return _showSnackBar('Model is loading, please wait...');
    }

    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _isProcessing = true);

    try {
      final bytes = await file.readAsBytes();
      final result = await _yolo.predict(bytes);

      if (mounted) {
        final detections = result['boxes'] is List
            ? MapConverter.convertBoxesList(result['boxes'] as List)
            : <Map<String, dynamic>>[];

        // Debug: Print detection structure
        debugPrint('Found ${detections.length} detections');
        if (detections.isNotEmpty) {
          debugPrint('First detection keys: ${detections.first.keys.toList()}');
          debugPrint('First detection: ${detections.first}');
        }

        // Preserve Ultralytics boxes, class labels, and confidence values.
        final baseImage = result['annotatedImage'] as Uint8List? ?? bytes;
        final previewBytes = await compute(
          _processImageWithAnnotations,
          _ImageProcessingRequest(
            imageBytes: baseImage,
            detections: detections,
          ),
        );

        setState(() {
          _detections = detections;
          _processedImageBytes = previewBytes;
          _isProcessing = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() => _isProcessing = false);
        debugPrint('Error processing image: $e');
        debugPrint('Stack trace: $stackTrace');
        _showSnackBar(
          'Error processing image: ${e.toString().split('\n').first}',
        );
      }
    }
  }

  /// Calculate total price estimate
  double _calculateTotalPrice() {
    double total = 0;
    for (final detection in _detections) {
      final className =
          (detection['className'] as String?)?.toLowerCase() ?? '';
      total += _priceMap[className] ?? 0;
    }
    return total;
  }

  /// Share the current view as a screenshot (includes stats and image)
  Future<void> _shareImage() async {
    try {
      final boundary =
          _screenshotKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      setState(() => _isProcessing = true);

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/autodentifyr_upload_report.png';
        final file = File(filePath);

        if (await file.exists()) {
          await file.delete();
        }

        await file.writeAsBytes(bytes);

        if (mounted) {
          setState(() => _isProcessing = false);
          await SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
        }
      } else {
        if (mounted) setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
      _showSnackBar('Error sharing report: $e');
    }
  }

  void _showSnackBar(String msg) => mounted
      ? ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppPalette.errorColor),
        )
      : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.blackColor,
      appBar: AppBar(
        title: const Text('Analyze Photo'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (_processedImageBytes != null)
                  _buildImageView()
                else
                  _buildEmptyState(),
                if (_isProcessing) _buildLoadingOverlay(),
              ],
            ),
          ),
          if (_processedImageBytes != null) _buildMoreActions(),
        ],
      ),
      floatingActionButton: _processedImageBytes != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _isModelReady && !_isProcessing
                  ? _pickAndPredict
                  : null,
              icon: const Icon(Icons.photo_library),
              label: const Text('Select Image'),
              backgroundColor: AppPalette.appGreen,
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 100,
            color: AppPalette.greyColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            _isModelReady ? 'Select an image to analyze' : 'Loading model...',
            style: const TextStyle(color: AppPalette.greyColor, fontSize: 18),
          ),
          if (!_isModelReady) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: AppPalette.appGreen),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: AppPalette.overlayBackgroundColor,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppPalette.appGreen),
            SizedBox(height: 16),
            Text(
              'Analyzing damage...',
              style: TextStyle(color: AppPalette.whiteColor, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageView() {
    final totalPrice = _calculateTotalPrice();

    return RepaintBoundary(
      key: _screenshotKey,
      child: Container(
        color: AppPalette.blackColor, // Background for screenshot
        child: Column(
          children: [
            // Stats bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppPalette.barBackgroundColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PhotoDetectionsButton(
                    detections: _detections.map((detection) {
                      final rawName =
                          (detection['className'] as String?)?.toLowerCase() ??
                          'unknown';
                      final name = rawName
                          .replaceAll('doorouter', 'door outer')
                          .replaceAll('quaterpanel', 'quarter panel')
                          .replaceAll('-', ' ');
                      return (
                        name: name[0].toUpperCase() + name.substring(1),
                        confidence: (detection['confidence'] as num?)
                            ?.toDouble(),
                        estimate: _priceMap[rawName],
                      );
                    }).toList(),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatItem(
                        icon: Icons.attach_money,
                        label: 'Total Estimate',
                        value: '\$${totalPrice.toStringAsFixed(0)}',
                        valueColor: AppPalette.yellowColor,
                      ),
                      const SizedBox(width: 6),
                      const EstimateDisclaimerIcon(
                        size: 16,
                        color: AppPalette.greyColor,
                        tooltip: 'Estimate disclaimer',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Image display
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.memory(
                    _processedImageBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.blackColor,
        boxShadow: [
          BoxShadow(
            color: AppPalette.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _processedImageBytes = null;
                    _detections = [];
                  });
                },
                icon: const Icon(Icons.close),
                label: const Text('Close'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.redColor,
                  foregroundColor: AppPalette.whiteColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareImage,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.blueColor,
                  foregroundColor: AppPalette.whiteColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppPalette.greyColor, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppPalette.greyColor, fontSize: 12),
            ),
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppPalette.whiteColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Data class for image processing request
class _ImageProcessingRequest {
  final Uint8List imageBytes;
  final List<Map<String, dynamic>> detections;

  _ImageProcessingRequest({required this.imageBytes, required this.detections});
}

/// Add costs and matching numbers without replacing Ultralytics annotations.
Future<Uint8List> _processImageWithAnnotations(
  _ImageProcessingRequest request,
) async {
  final image = img.decodeImage(request.imageBytes);
  if (image == null) return request.imageBytes;

  final oriented = img.bakeOrientation(image);
  final font = oriented.width > 1500 ? img.arial48 : img.arial24;
  final badgeHeight = font.lineHeight + 8;
  final color = img.ColorRgb8(0, 220, 180);

  for (var index = 0; index < request.detections.length; index++) {
    final detection = request.detections[index];
    final box = detection['normalizedBox'] is Map
        ? detection['normalizedBox'] as Map
        : detection;
    final left = (box['left'] ?? box['x1_norm']) as num?;
    final top = (box['top'] ?? box['y1_norm']) as num?;
    final bottom = (box['bottom'] ?? box['y2_norm']) as num?;
    if (left == null || top == null || bottom == null) {
      continue;
    }

    final x1 = (left.clamp(0, 1) * (oriented.width - 1)).round();
    final y1 = (top.clamp(0, 1) * (oriented.height - 1)).round();
    final y2 = (bottom.clamp(0, 1) * (oriented.height - 1)).round();
    final className = (detection['className'] as String?)?.toLowerCase() ?? '';
    final price = _SingleImageScreenState._priceMap[className] ?? 250.0;
    final priceText = '\$${price.toStringAsFixed(0)}';
    final priceWidth = priceText.length * (font.size ~/ 2 + 4) + 12;
    img.fillRect(
      oriented,
      x1: x1,
      y1: y1,
      x2: x1 + priceWidth,
      y2: y1 + badgeHeight,
      color: img.ColorRgb8(255, 255, 0),
    );
    img.drawString(
      oriented,
      priceText,
      font: font,
      x: x1 + 6,
      y: y1 + 4,
      color: img.ColorRgb8(0, 0, 0),
    );
    final number = '${index + 1}';
    final badgeWidth = number.length * (font.size ~/ 2 + 4) + 12;
    final badgeX = x1.clamp(
      0,
      (oriented.width - badgeWidth).clamp(0, oriented.width),
    );
    final badgeY = (y2 - badgeHeight).clamp(
      0,
      (oriented.height - badgeHeight).clamp(0, oriented.height),
    );
    img.fillRect(
      oriented,
      x1: badgeX,
      y1: badgeY,
      x2: badgeX + badgeWidth,
      y2: badgeY + badgeHeight,
      color: color,
    );
    img.drawString(
      oriented,
      number,
      font: font,
      x: badgeX + 6,
      y: badgeY + 4,
      color: img.ColorRgb8(0, 0, 0),
    );
  }

  return Uint8List.fromList(img.encodePng(oriented));
}
