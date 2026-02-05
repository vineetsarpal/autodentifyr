import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ultralytics_yolo/models/yolo_result.dart';
import 'package:ultralytics_yolo/widgets/yolo_controller.dart';
import 'package:ultralytics_yolo/utils/error_handler.dart';
import 'package:autodentifyr/models/models.dart';
import 'package:autodentifyr/services/model_manager.dart';

/// Controller that manages the state and business logic for camera inference
class CameraInferenceController extends ChangeNotifier {
  // Detection state
  int _detectionCount = 0;
  double _currentFps = 0.0;
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();
  double _totalPriceEstimate = 0.0;
  List<YOLOResult> _currentResults = [];
  final Set<String> _discoveredLabels = {};

  // Threshold state (Simplified to confidence only)
  double _confidenceThreshold = 0.5;
  SliderType _activeSlider = SliderType.none;

  // Model state
  final ModelType _selectedModel = ModelType.detect;
  bool _isModelLoading = false;
  String? _modelPath;
  String _loadingMessage = '';
  double _downloadProgress = 0.0;

  // Camera state
  double _currentZoomLevel = 1.0;
  Uint8List? _capturedImage;
  final bool _isCapturing = false;

  // Controllers
  final _yoloController = YOLOViewController();
  late final ModelManager _modelManager;

  // Performance optimization
  bool _isDisposed = false;
  Future<void>? _loadingFuture;

  // Getters
  int get detectionCount => _detectionCount;
  double get currentFps => _currentFps;
  double get totalPriceEstimate => _totalPriceEstimate;
  List<YOLOResult> get currentResults => _currentResults;
  double get confidenceThreshold => _confidenceThreshold;
  SliderType get activeSlider => _activeSlider;
  ModelType get selectedModel => _selectedModel;
  bool get isModelLoading => _isModelLoading;
  String? get modelPath => _modelPath;
  String get loadingMessage => _loadingMessage;
  double get downloadProgress => _downloadProgress;
  double get currentZoomLevel => _currentZoomLevel;
  YOLOViewController get yoloController => _yoloController;
  Uint8List? get capturedImage => _capturedImage;
  bool get isCapturing => _isCapturing;

  CameraInferenceController() {
    _modelManager = ModelManager(
      onDownloadProgress: (progress) {
        _downloadProgress = progress;
        notifyListeners();
      },
      onStatusUpdate: (message) {
        _loadingMessage = message;
        notifyListeners();
      },
    );
  }

  /// Initialize the controller
  Future<void> initialize() async {
    await _loadModelForPlatform();
    _yoloController.setThresholds(
      confidenceThreshold: _confidenceThreshold,
      iouThreshold: 0.5, // Standard fallback
      numItemsThreshold: 20, // Standard fallback
    );
  }

  void onDetectionResults(List<YOLOResult> results) {
    if (_isDisposed) return;

    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastFpsUpdate).inMilliseconds;

    if (elapsed >= 1000) {
      _currentFps = _frameCount * 1000 / elapsed;
      _frameCount = 0;
      _lastFpsUpdate = now;
    }

    _currentResults = results;
    _detectionCount = results.length;
    _discoverLabels(results);
    _calculatePrice(results);
    notifyListeners();
  }

  void _discoverLabels(List<YOLOResult> results) {
    for (final res in results) {
      if (!_discoveredLabels.contains(res.className)) {
        _discoveredLabels.add(res.className);
        debugPrint('MODEL_DISCOVERY: New Class Found: "${res.className}"');
      }
    }
  }

  /// Map of damage types to estimated repair costs
  static const Map<String, double> _damagePrices = {
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

  void _calculatePrice(List<YOLOResult> results) {
    double total = 0;
    for (final result in results) {
      total += getPriceForLabel(result.className);
    }
    _totalPriceEstimate = total;
  }

  double getPriceForLabel(String label) {
    return _damagePrices[label.toLowerCase()] ?? 250.0;
  }

  /// Handle performance metrics
  void onPerformanceMetrics(double fps) {
    if (_isDisposed) return;

    if ((_currentFps - fps).abs() > 0.1) {
      _currentFps = fps;
      notifyListeners();
    }
  }

  void onZoomChanged(double zoomLevel) {
    if (_isDisposed) return;

    if ((_currentZoomLevel - zoomLevel).abs() > 0.01) {
      _currentZoomLevel = zoomLevel;
      notifyListeners();
    }
  }

  void toggleSlider(SliderType type) {
    if (_isDisposed) return;

    _activeSlider = (_activeSlider == type) ? SliderType.none : type;
    notifyListeners();
  }

  void updateSliderValue(double value) {
    if (_isDisposed) return;

    if (_activeSlider == SliderType.confidence) {
      if ((_confidenceThreshold - value).abs() > 0.01) {
        _confidenceThreshold = value;
        _yoloController.setConfidenceThreshold(value);
        notifyListeners();
      }
    }
  }

  void setZoomLevel(double zoomLevel) {
    if (_isDisposed) return;

    if ((_currentZoomLevel - zoomLevel).abs() > 0.01) {
      _currentZoomLevel = zoomLevel;
      _yoloController.setZoomLevel(zoomLevel);
      notifyListeners();
    }
  }

  Future<void> _loadModelForPlatform() async {
    if (_isDisposed) return;

    if (_loadingFuture != null) {
      await _loadingFuture;
      return;
    }

    _loadingFuture = _performModelLoading();
    try {
      await _loadingFuture;
    } finally {
      _loadingFuture = null;
    }
  }

  Future<void> _performModelLoading() async {
    if (_isDisposed) return;

    _isModelLoading = true;
    _loadingMessage = 'Loading ${_selectedModel.modelName} model...';
    _downloadProgress = 0.0;
    _detectionCount = 0;
    _currentFps = 0.0;
    notifyListeners();

    try {
      final modelPath = await _modelManager.getModelPath(_selectedModel);

      if (_isDisposed) return;

      _modelPath = modelPath;
      _isModelLoading = false;
      _loadingMessage = '';
      _downloadProgress = 0.0;
      notifyListeners();

      if (modelPath == null) {
        throw Exception('Failed to load ${_selectedModel.modelName} model');
      }
    } catch (e) {
      if (_isDisposed) return;

      final error = YOLOErrorHandler.handleError(
        e,
        'Failed to load model ${_selectedModel.modelName} for task ${_selectedModel.task.name}',
      );

      _isModelLoading = false;
      _loadingMessage = 'Failed to load model: ${error.message}';
      _downloadProgress = 0.0;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setCapturedImage(Uint8List image) async {
    _capturedImage = image;
    notifyListeners();
  }

  void clearCapturedImage() {
    _capturedImage = null;
    notifyListeners();
  }

  Future<void> shareCapturedImage({Rect? sharePositionOrigin}) async {
    if (_capturedImage == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/autodentifyr_capture.png';
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }

      await file.writeAsBytes(_capturedImage!);

      if (await file.exists()) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(filePath)],
            sharePositionOrigin: sharePositionOrigin,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
